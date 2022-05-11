load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

def terraform_package(name, srcs):
    pkg_tar(
        name = name,
        srcs = srcs,
    )