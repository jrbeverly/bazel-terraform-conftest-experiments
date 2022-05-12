load("//:bazel/macros/toolchains.bzl", "parse_toolchain_file")
load("//:bazel/macros/http_toolchain.bzl", "register_external_toolchain")

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
