load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

def _terraform_package_impl(ctx):
    out = ctx.actions.declare_directory(ctx.label.name)
    # TF_DATA_DIR
    ctx.actions.run(
        executable = "terraform",
        inputs = ctx.files.src,
        use_default_shell_env = True,
        arguments = [
            "-chdir=%s" % out.path,
            "init",
            "-from-module=../%s" % ctx.file.src.basename
        ],
        mnemonic = "TerraformInit",
        outputs = [out],
    )
    return [DefaultInfo(files = depset([out]))]

_terraform_package = rule(
    implementation = _terraform_package_impl,
    attrs = {
        "src": attr.label(
            allow_single_file = True
        ),
    },
)

def terraform_package(name, srcs):
    src_package = "%s_src" % (name)
    init_pkg = "%s_init" % (name)

    pkg_tar(
        name = src_package,
        srcs = srcs,
        extension = "tar.gz",
    )

    _terraform_package(
        name = init_pkg,
        src = src_package,
    )

    pkg_tar(
        name = name,
        srcs = [":%s" % (init_pkg)],
        extension = "tar.gz",
        mode = "777"
    )

def _terraform_plan_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(
        output = out,
        content = "Hello\n",
    )
    return [DefaultInfo(files = depset([out]))]


terraform_plan = rule(
    implementation = _terraform_plan_impl,
    attrs = {
        "src": attr.label(),
    },
)

# def terraform_plan(name, src):
#     pkg_tar(
#         name = name,
#         srcs = srcs,
#     )

# def terraform_apply(name, src):
#     pkg_tar(
#         name = name,
#         srcs = srcs,
#     )