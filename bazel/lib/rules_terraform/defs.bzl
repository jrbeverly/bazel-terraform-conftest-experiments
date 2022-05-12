load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

def terraform_source(name, srcs):
    """Function description.

    Args:
        name: argument description, can be
        multiline with additional indentation.
        srcs: sources
    """
    pkg_tar(
        name = name,
        srcs = srcs,
        extension = "tar.gz",
    )

def terraform_bundle(name, dir):
    """Function description.

    Args:
        name: argument description, can be
        multiline with additional indentation.
        dir: sources
    """
    pkg_tar(
        name = name,
        srcs = [ dir ],
        extension = "tar.gz",
        mode = "777"
    )


def _terraform_init_impl(ctx):
    terraform = ctx.toolchains["@bazel_toolchain_terraform//:toolchain_type"].toolinfo

    out = ctx.actions.declare_directory(ctx.label.name)
    ctx.actions.run(
        executable = terraform.tool,
        inputs = ctx.files.src,
        use_default_shell_env = True,
        arguments = [
            "-chdir=%s" % out.path,
            "init",
            "-from-module=../%s" % ctx.file.src.basename
        ],
        env = {
            "TF_DATA_DIR": "%s/.terraform" % out.path,
        },
        mnemonic = "TerraformInit",
        outputs = [out],
    )
    return [
        DefaultInfo(
            files = depset([out])
        ),
    ]

_terraform_init = rule(
    implementation = _terraform_init_impl,
    attrs = {
        "src": attr.label(
            allow_single_file = True
        ),
    },
    toolchains = [
        "@bazel_toolchain_terraform//:toolchain_type",
    ],
)

TerraformBundleInfo = provider(
        doc = "A terraform bundle.",
        fields = {
            "package": "a tar.gz file containing the fully packaged terraform",
            "workspace": "A directory containing the fully initialized terraform workspace",
        },
    )

def _terraform_package_impl(ctx):
    return [
        DefaultInfo(
            files = depset([ctx.file.bundle]),
        ),
        TerraformBundleInfo(
            package = ctx.file.bundle,
            workspace = ctx.files.workspace[0],
        ),
    ]

_terraform_package = rule(
    implementation = _terraform_package_impl,
    attrs = {
        "bundle": attr.label(
            allow_single_file = True
        ),
        "workspace": attr.label(
            allow_single_file = False
        ),
    },
    toolchains = [
        "@bazel_toolchain_terraform//:toolchain_type",
    ],
)

def terraform_package(name, srcs):
    """Function description.

    Args:
        name: argument description, can be
        multiline with additional indentation.
        srcs: sources
    """
    label_src = "%s.source" % (name)
    label_bundle = "%s.bundle" % (name)
    label_pkg = "%s.pkg" % (name)

    terraform_source(
        name = label_src,
        srcs = srcs,
    )

    _terraform_init(
        name = label_bundle,
        src = ":%s" % (label_src),
    )

    terraform_bundle(
        name = label_pkg,
        dir = ":%s" % (label_bundle),
    )

    _terraform_package(
        name = name,
        bundle = ":%s" % (label_pkg),
        workspace = ":%s" % (label_bundle),
    )

def _terraform_workspace_impl(ctx):
    bundle = ctx.attr.src[TerraformBundleInfo]
    return [
        DefaultInfo(
            files = depset([bundle.workspace]),
            runfiles = ctx.runfiles(files = [bundle.workspace]),
            executable = ctx.executable.tool,
        ),
    ]

terraform_workspace = rule(
    implementation = _terraform_workspace_impl,
    executable = True,
    attrs = {
        "src": attr.label(
            providers = [TerraformBundleInfo]
        ),
        "tool": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            default = "//:terraform",
        ),
    },
)
