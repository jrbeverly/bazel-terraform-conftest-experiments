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
    out = ctx.actions.declare_directory(ctx.label.name)
    ctx.actions.run(
        executable = "terraform",
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
            files = depset([ctx.file.bundle])
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
        )
    },
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



# genrule(
#     name = "hello_gen",
#     outs = ["hello.txt"],
#     cmd = "echo hello world >$@",
# )


# How to make this executable?
# https://github.com/bazelbuild/rules_go/blob/master/go/private/rules/binary.bzl#L117
# https://github.com/bazelbuild/rules_go/blob/master/go/private/context.bzl#L381
# https://github.com/bazelbuild/rules_go/blob/master/go/private/go_toolchain.bzl#L75
# https://github.com/bazelbuild/rules_go/blob/master/go/private/providers.bzl#L56

# Like the go binary, I suspect we'll need:
#    A Provider (TerraformCLI)
#    A Toolchain (use local `terraform` or download - extract from someone elses)
#    Means of providing that SDK to the runs

def _terraform_workspace_impl(ctx):
    bundle = ctx.attr.src[TerraformBundleInfo]
    # print(bundle.workspace)
    out = ctx.actions.declare_file("%s.tfstate" % ctx.label.name)
    ctx.actions.run(
        executable = "terraform",
        inputs = [bundle.workspace],
        use_default_shell_env = True,
        arguments = [
            "-chdir=%s" % bundle.workspace.path,
            "apply",
            "-auto-approve",
            "-state=%s" % out.path
        ],
        mnemonic = "TerraformInit",
        outputs = [out],
    )
    return [
        DefaultInfo(
            files = depset([out])
        ),
    ]

terraform_workspace = rule(
    implementation = _terraform_workspace_impl,
    attrs = {
        "src": attr.label(
            providers = [TerraformBundleInfo]
        ),
    },
)