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
        provider = ExternallyManagedToolChainInfo(
            name = contents["Name"],
            version = contents["Version"],
            path = platform["Executable"],
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
            archive = "tool_{}_{}".format(contents["Name"], platform["Name"]),
            tool = "@tool_{}_{}//:{}".format(contents["Name"], platform["Name"], platform["Executable"]),
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
        "tool": "Docs",
        "toolchain": "",
    },
)
