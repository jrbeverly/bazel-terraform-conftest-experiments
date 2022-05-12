load("//:bazel/macros/toolchains.bzl", "parse_toolchain_file")

def _archive_rule(provider):
    additional = ""
    if provider.archive_opts != None:
        additional = "\n        strip_prefix = \"%s\"," % (provider.archive_opts)

    return """
    http_archive(
        name = "{name}",
        url = "{url}",
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
        """load("@conftest-terraform-workflow//:bazel/macros/http_toolchain.bzl", "externally_managed_toolchain")

package(default_visibility = ["//visibility:public"])

toolchain_type(name = "toolchain_type")

{rules}
""".format(rules = "\n".join(toolchain_rules)),
    )

    repository_ctx.file(
        "deps.bzl",
        """load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

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
