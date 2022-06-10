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

def _opa_policy_test_impl(ctx):
    opa = ctx.toolchains["@bazel_toolchain_opa//:toolchain_type"].toolinfo
    executable = opa.tool
    
    runfiles = ctx.runfiles(files = [])
    runfiles = runfiles.merge(ctx.attr._bash_runfiles[DefaultInfo].default_runfiles)
    
    policies = []
    for policy in ctx.files.srcs:
        policies.append(policy.path)

    opa_exec = " ".join([
        "exec",
        "./%s" % executable.short_path,
        "test",
        "-v",
    ] + policies)

    command_exec = " ".join([opa_exec] + ['"$@"'] )

    out_file = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = out_file,
        content = "\n".join([_CONTENT_PREFIX] + [command_exec]),
        is_executable = True,
    )

    runfiles = runfiles.merge(ctx.runfiles(files = ctx.files.srcs + [executable]))

    return [
        DefaultInfo(
            files = depset([]),
            runfiles = runfiles,
            executable = out_file,
        ),
    ]

opa_policy_test = rule(
    implementation = _opa_policy_test_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = True
        ),
        "_bash_runfiles": attr.label(
            default = Label("@bazel_tools//tools/bash/runfiles"),
        ),
    },
    toolchains = [
        "@bazel_toolchain_opa//:toolchain_type",
    ],
    test = True,
)
