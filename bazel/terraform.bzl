load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

def terraform_package(name, srcs):
    pkg_tar(
        name = name,
        srcs = srcs,
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