SCHEMA_TOOLCHAIN_NAME = "Name"
SCHEMA_TOOLCHAIN_VERSION = "Version"
SCHEMA_TOOLCHAIN_TOOLCHAINS = "Toolchains"

# Enrich this to provide all the predefined versions of the files
def _read_toolchain_file(ctx, filename):
    contents = ctx.read(filename)
    toolchain = {
        SCHEMA_TOOLCHAIN_NAME: None,
        SCHEMA_TOOLCHAIN_VERSION: None,
        SCHEMA_TOOLCHAIN_TOOLCHAINS: [],
    }
    entry = None
    for line in contents.splitlines():
        if line.startswith("#"):
            continue

        if line.strip() == "":
            continue

        if line.startswith("["):
            platform = line.strip()[1:-1]
            entry = {
                "Name": platform,
            }
            toolchain[SCHEMA_TOOLCHAIN_TOOLCHAINS].append(entry)
            continue

        tokens = [
            w.strip()
            for w in line.split("=")
            if len(w.strip()) > 0
        ]
        if len(tokens) > 2:
            if line.contains("#"):
                fail("{} does not support trailing comments. Line was [{}] but wanted key=value".format(filename, line))
            fail("{} does not match the expected format. Line was [{}] but wanted key=value".format(filename, line))

        if entry == None:
            toolchain[tokens[0]] = tokens[1]
        else:
            entry[tokens[0]] = tokens[1]

    return toolchain

def parse_toolchain_file(ctx, filename):
    contents = _read_toolchain_file(ctx, filename)

    providers = []
    for platform in contents[SCHEMA_TOOLCHAIN_TOOLCHAINS]:
        is_archive = platform.get("IsArchive", "true")
        tool = "@tool_{}_{}//file".format(contents["Name"], platform["Name"])

        if is_archive == "true":
            tool = "@tool_{}_{}//:{}".format(contents["Name"], platform["Name"], platform["Executable"])
        
        provider = ExternallyManagedToolChainInfo(
            name = contents["Name"],
            version = contents["Version"],
            path = platform.get("Executable", None),
            urls = [platform["URL"]],
            sha256 = platform["Sha256Sum"],
            exec_compatible_with = [
                "@platforms//os:%s" % platform["OS"],
                "@platforms//cpu:%s" % platform["CPU"],
            ],
            target_compatible_with = [
                "@platforms//os:%s" % platform["OS"],
                "@platforms//cpu:%s" % platform["CPU"],
            ],
            archive_opts = platform.get("ArchivePrefix", None),
            is_archive = is_archive,
            archive = "tool_{}_{}".format(contents["Name"], platform["Name"]),
            tool = tool,
            toolchain = "{}_{}_toolchain".format(contents["Name"], platform["Name"]),
        )
        providers.append(provider)

    return ExternallyManagedToolInfo(
        name = contents["Name"],
        version = contents["Version"],
        toolchains = providers,
    )

ExternallyManagedToolInfo = provider(
    doc = "",
    fields = {
        "name": "",
        "version": "",
        "toolchains": "Docs",
    },
)

ExternallyManagedToolChainInfo = provider(
    doc = "Externally managed toolchain through use of file.",
    fields = {
        "name": "",
        "version": "",
        "path": "",
        "urls": "",
        "sha256": "",
        "exec_compatible_with": "",
        "target_compatible_with": "",
        "archive": "",
        "archive_opts": "",
        "is_archive": "",
        "tool": "Docs",
        "toolchain": "",
    },
)

def _bazel_load(tool):
    return """load("@{rule}//:deps.bzl", install_{name}_toolchain = "install_toolchain")""".format(
        name = tool["name"],
        rule = tool["rule"],
    )

def _load_all_toolchains_impl(repository_ctx):
    tools = []
    for toolchain, rule_name in repository_ctx.attr.toolchains.items():
        toolchain_path = repository_ctx.path(toolchain)
        tool = parse_toolchain_file(repository_ctx, toolchain_path)

        tools.append({
            "name": tool.name,
            "rule": rule_name,
            "tool": tool,
        })

    repository_ctx.file("BUILD.bazel", "")
    repository_ctx.file(
        "deps.bzl",
        """{load_rules}

def install_toolchains():
    {install_rules}
    """.format(
            load_rules = "\n".join([_bazel_load(tool) for tool in tools]),
            install_rules = "\n    ".join(["install_{}_toolchain()".format(tool["name"]) for tool in tools]),
        ),
    )

load_all_toolchains = repository_rule(
    _load_all_toolchains_impl,
    attrs = {
        "toolchains": attr.label_keyed_string_dict(
            mandatory = True,
        ),
    },
)

def register_external_toolchains(name, toolchains):
    for toolchain, rule_name in toolchains.items():
        register_external_toolchain(
            name = rule_name,
            toolchain = toolchain,
        )

    load_all_toolchains(
        name = name,
        toolchains = toolchains,
    )

def _archive_rule(provider):
    additional = ""
    if provider.archive_opts != None:
        additional = "\n        strip_prefix = \"%s\"," % (provider.archive_opts)

    if provider.is_archive == "false":
        return """
    http_file(
        name = "{name}",
        urls = [ "{url}" ],
        executable = True,
        sha256 = "{sha256}", {kwargs}
    )""".format(
        name = provider.archive,
        url = provider.urls[0],
        sha256 = provider.sha256,
        kwargs = additional,
    )

    return """
    http_archive(
        name = "{name}",
        urls = [ "{url}" ],
        sha256 = "{sha256}",
        build_file_content = OPEN_FILE_ARCHIVE, {kwargs}
    )""".format(
        name = provider.archive,
        url = provider.urls[0],
        sha256 = provider.sha256,
        kwargs = additional,
    )

def _toolchain_rules(provider):
    return """toolchain(
    name = "{name}",
    exec_compatible_with = {exec_compatible_with},
    target_compatible_with = {target_compatible_with},
    toolchain = ":{info}",
    toolchain_type = ":toolchain_type",
)

externally_managed_toolchain(
    name = "{info}",
    tool = "{tool}",
)
""".format(
        name = provider.toolchain,
        exec_compatible_with = provider.exec_compatible_with,
        target_compatible_with = provider.target_compatible_with,
        info = "{}info".format(provider.toolchain),
        tool = provider.tool,
    )

def _register_external_toolchain_impl(repository_ctx):
    toolchain_path = repository_ctx.path(repository_ctx.attr.toolchain)
    tool = parse_toolchain_file(repository_ctx, toolchain_path)
    providers = tool.toolchains

    toolchain_rules = []
    tool_archive_rules = []
    for provider in providers:
        toolchain_rule = _toolchain_rules(provider)
        toolchain_rules.append(toolchain_rule)

        tool_archive_rule = _archive_rule(provider)
        tool_archive_rules.append(tool_archive_rule)

    repository_ctx.file(
        "BUILD.bazel",
        """load("@rules_toolchains//:defs.bzl", "externally_managed_toolchain")

package(default_visibility = ["//visibility:public"])

toolchain_type(name = "toolchain_type")

{rules}
""".format(rules = "\n".join(toolchain_rules)),
    )

    repository_ctx.file(
        "deps.bzl",
        """load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive", "http_file")

OPEN_FILE_ARCHIVE = \"\"\"
package(default_visibility = ["//visibility:public"])
filegroup(
    name = "files",
    srcs = glob(["*","**/*"]),
)
\"\"\"

def install_toolchain():
    native.register_toolchains(
        {toolchains}
    )
{rules}
""".format(
            rules = "\n".join(tool_archive_rules),
            toolchains = ",\n        ".join([
                '"@{}//:{}"'.format(repository_ctx.name, toolchain.toolchain)
                for toolchain in providers
            ]),
        ),
    )

register_external_toolchain = repository_rule(
    _register_external_toolchain_impl,
    attrs = {
        "toolchain": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
    },
)

ExternallyManagedToolExecutableInfo = provider(
    doc = "Externally managed toolchain through use of file.",
    fields = {"tool": ""},
)

def _externally_managed_toolchain_impl(ctx):
    toolchain_info = platform_common.ToolchainInfo(
        toolinfo = ExternallyManagedToolExecutableInfo(
            tool = ctx.file.tool,
        ),
    )
    return [toolchain_info]

externally_managed_toolchain = rule(
    implementation = _externally_managed_toolchain_impl,
    attrs = {
        "tool": attr.label(
            executable = True,
            allow_single_file = True,
            mandatory = True,
            cfg = "host",
        ),
    },
)
