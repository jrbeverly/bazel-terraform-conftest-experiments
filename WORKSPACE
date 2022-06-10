workspace(name = "conftest-terraform-workflow")

load("//:bazel/rules/deps.bzl", "bazel_dependencies")

bazel_dependencies()

load("@rules_pkg//:deps.bzl", "rules_pkg_dependencies")

rules_pkg_dependencies()

load(
    "@io_bazel_rules_docker//repositories:repositories.bzl",
    container_repositories = "repositories",
)

container_repositories()

load("@io_bazel_rules_docker//repositories:deps.bzl", container_deps = "deps")

container_deps()

load("@rules_toolchains//:defs.bzl", "register_external_toolchains")

register_external_toolchains(
    name = "external_toolchains",
    toolchains = {
        "//:bazel/toolchains/terraform.toolchain": "bazel_toolchain_terraform",
        "//:bazel/toolchains/conftest.toolchain": "bazel_toolchain_conftest",
        "//:bazel/toolchains/opa.toolchain": "bazel_toolchain_opa",
    },
)

load("@external_toolchains//:deps.bzl", "install_toolchains")

install_toolchains()
