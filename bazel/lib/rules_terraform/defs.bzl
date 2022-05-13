load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

_CONTENT_PREFIX = """#!/usr/bin/env bash

# --- begin runfiles.bash initialization v2 ---
# Copy-pasted from the Bazel Bash runfiles library v2.
set -uo pipefail; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \\
 source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \\
 source "$0.runfiles/$f" 2>/dev/null || \\
 source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \\
 source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \\
 { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v2 ---

# Export RUNFILES_* envvars (and a couple more) for subprocesses.
runfiles_export_envvars

"""


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
    terraform = ctx.toolchains["@bazel_toolchain_terraform//:toolchain_type"].toolinfo
    bundle = ctx.attr.src[TerraformBundleInfo]
    
    runfiles = ctx.runfiles().merge(ctx.attr._bash_runfiles[DefaultInfo].default_runfiles)

    executable = terraform.tool
    
    str_args = [
        "%s" % ctx.expand_location(v)
        for v in ctx.attr.arguments
    ]

    terraform_exec = " ".join([
        "exec",
        "./%s" % executable.short_path,
        "-chdir=%s" % bundle.workspace.short_path,
    ])

    command_exec = " ".join([terraform_exec] + str_args + ['"$@"\n'])

    out_file = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = out_file,
        content = "\n".join([_CONTENT_PREFIX] + [command_exec]),
        is_executable = True,
    )

    runfiles = runfiles.merge(ctx.runfiles(files = [bundle.workspace, executable]))

    return [
        DefaultInfo(
            files = depset([bundle.workspace]),
            runfiles = runfiles,
            executable = out_file,
        ),
    ]
    # return [DefaultInfo(
    #     files = depset([out_file]),
    #     runfiles = runfiles.merge(ctx.runfiles(files = ctx.files.data + [executable])),
    #     executable = out_file,
    # )]


terraform_workspace = rule(
    implementation = _terraform_workspace_impl,
    executable = True,
    attrs = {
        "arguments": attr.string_list(
            doc = "List of command line arguments. Subject to $(location) expansion. See https://docs.bazel.build/versions/master/skylark/lib/ctx.html#expand_location",
        ),
        "src": attr.label(
            providers = [TerraformBundleInfo]
        ),
        "_bash_runfiles": attr.label(
            default = Label("@bazel_tools//tools/bash/runfiles"),
        ),
    },
    toolchains = [
        "@bazel_toolchain_terraform//:toolchain_type",
    ],
)
