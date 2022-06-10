load("@rules_pkg//pkg:tar.bzl", "pkg_tar")
load("@rules_pkg//pkg:mappings.bzl", "pkg_files")

# This is heavily leveraging https://github.com/bazelbuild/rules_pkg/blob/main/examples/rich_structure/BUILD

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

_BAZEL_WORKSPACE_PREAMBLE = """
if [ -z "${BUILD_WORKSPACE_DIRECTORY-}" ]; then
  echo "error: BUILD_WORKSPACE_DIRECTORY not set" >&2
  exit 1
fi
"""


def terraform_source(name, srcs, modules = []):
    """Function description.

    Args:
        name: argument description, can be
        multiline with additional indentation.
        srcs: sources
        modules: modules
    """
    pkg_tar(
        name = name,
        srcs = srcs + modules,
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

TerraformWorkspaceInfo = provider(
        doc = "A terraform workspace.",
        fields = {
            "state": "Path to state file relative to workspace root",
            "output": "Path to output json relative to workspace root",
            "plan": "Path to the plan file relative to workspace root",
            "tfplanjson": "Path to the plan file relative to workspace root, as json",
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

def terraform_package(name, srcs, modules = {}):
    """Function description.

    Args:
        name: argument description, can be
        multiline with additional indentation.
        srcs: sources
        modules: modules
    """
    label_src = "%s.source" % (name)
    label_init = "%s.init" % (name)
    label_bundle = "%s.bundle" % (name)

    module_labels = []
    idx = 0
    for label, path in modules.items():
        remap_dir = "_%s_module_%s" % (name, idx)
        pkg_files(
            name = remap_dir,
            srcs = [label],
            prefix = path,
        )
        module_labels.append(remap_dir)

    terraform_source(
        name = label_src,
        srcs = srcs + module_labels,
    )

    _terraform_init(
        name = label_init,
        src = ":%s" % (label_src),
    )

    terraform_bundle(
        name = label_bundle,
        dir = ":%s" % (label_init),
    )

    _terraform_package(
        name = name,
        bundle = ":%s" % (label_bundle),
        workspace = ":%s" % (label_init),
    )

def _terraform_path(workspace_name, package, name):
    adjusted_label_name = name.split('.')[0]
    if workspace_name == "":
        return "%s/%s" % (package, adjusted_label_name)
    return "%s/%s/%s" % (workspace_name, package, adjusted_label_name)

def _terraform_command_impl(ctx, command, arguments):
    terraform = ctx.toolchains["@bazel_toolchain_terraform//:toolchain_type"].toolinfo
    bundle = ctx.attr.src[TerraformBundleInfo]
    executable = terraform.tool
    
    runfiles = ctx.runfiles(files = [])
    runfiles = runfiles.merge(ctx.attr._bash_runfiles[DefaultInfo].default_runfiles)

    pre_actions = ""
    for action in ctx.attr.pre_actions:
        default_runfiles = action[DefaultInfo].default_runfiles
        if default_runfiles != None:
            runfiles = runfiles.merge(default_runfiles)
        
        pre_actions += " ".join([
            "./%s" % action[DefaultInfo].files_to_run.executable.short_path,
            ";",
            "\n"
        ])
    
    terraform_exec = " ".join([
        "exec",
        "./%s" % executable.short_path,
        "-chdir=%s" % bundle.workspace.short_path,
    ])

    output_dir = _terraform_path(ctx.label.workspace_name, ctx.label.package, ctx.label.name)
 
    plan_file = '.bazel/%s/terraform.tfplan' % output_dir
    plan_file_json = '.bazel/%s/tfplan.json' % output_dir
    output_file = '.bazel/%s/output.json' % output_dir
    state_file = '.bazel/%s/terraform.tfstate' % output_dir

    substitutions = {
        "tfplan": '"$BUILD_WORKSPACE_DIRECTORY/%s"' % plan_file,
        "tfplanjson": '"$BUILD_WORKSPACE_DIRECTORY/%s"' % plan_file_json,
        "tfoutput": '"$BUILD_WORKSPACE_DIRECTORY/%s"' % output_file,
        "tfstate": '"$BUILD_WORKSPACE_DIRECTORY/%s"' % state_file,
        "tfdir": '"$BUILD_WORKSPACE_DIRECTORY/.bazel/%s"' % output_dir,
    }
    str_args = [
        "%s" % v.format(**substitutions)
        for v in arguments
    ]

    redirect = []
    if ctx.attr.stdout != "":
        redirect = [">", ctx.attr.stdout.format(**substitutions)]

    command_exec = " ".join([terraform_exec] + [command] + str_args +  ['"$@"'] + redirect )

    out_file = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = out_file,
        content = "\n".join([_CONTENT_PREFIX, _BAZEL_WORKSPACE_PREAMBLE] + [pre_actions] + [command_exec]),
        is_executable = True,
    )

    runfiles = runfiles.merge(ctx.runfiles(files = [bundle.workspace, executable]))

    return [
        DefaultInfo(
            files = depset([bundle.workspace]),
            runfiles = runfiles,
            executable = out_file,
        ),
        TerraformWorkspaceInfo(
            state = state_file,
            output = output_file,
            plan = plan_file,
            tfplanjson = plan_file_json
        ),
    ]

def _terraform_workspace_impl(ctx):
    return _terraform_command_impl(ctx, ctx.attr.command, ctx.attr.arguments)


_terraform_workspace = rule(
    implementation = _terraform_workspace_impl,
    executable = True,
    attrs = {
        "command": attr.string(
        ),
        "stdout": attr.string(
        ),
        "arguments": attr.string_list(
            doc = "List of command line arguments. Subject to $(location) expansion. See https://docs.bazel.build/versions/master/skylark/lib/ctx.html#expand_location",
        ),
        "src": attr.label(
            providers = [TerraformBundleInfo]
        ),
        "pre_actions": attr.label_list(),
        "_bash_runfiles": attr.label(
            default = Label("@bazel_tools//tools/bash/runfiles"),
        ),
    },
    toolchains = [
        "@bazel_toolchain_terraform//:toolchain_type",
    ],
)

def terraform_workspace(name, src):
    _terraform_workspace(
        name = "%s.plan" % name,
        src = src,
        command = "plan",
        arguments = [
            "-state={tfstate}",
            "-out={tfplan}",
        ]
    )

    _terraform_workspace(
        name = "%s.show" % name,
        src = src,
        command = "show",
        arguments = [
            "-json",
            "{tfplan}",
        ],
        stdout = "{tfplanjson}",
        pre_actions = [
            ":%s.plan" % name,
        ]
    )

    _terraform_workspace(
        name = "%s.apply" % name,
        src = src,
        command = "apply",
        arguments = [
            "-state={tfstate}",
            "{tfplan}",
        ],
        pre_actions = [
            ":%s.plan" % name,
        ]
    )

    _terraform_workspace(
        name = "%s.destroy" % name,
        src = src,
        command = "destroy",
        arguments = [
            "-state={tfstate}",
        ],
    )

    _terraform_workspace(
        name = "%s.output" % name,
        src = src,
        command = "output",
        arguments = [
            "-state={tfstate}",
            "-json",
        ],
        stdout = "{tfoutput}",
        pre_actions = [
            ":%s.apply" % name,
        ]
    )



def terraform_module(name, srcs, **kwargs):
    """Function description.

    Args:
        name: argument description, can be
        multiline with additional indentation.
        srcs: sources
        **kwargs: kwargs
    """
    pkg_files(
        name = name,
        srcs = srcs,
        **kwargs
    )

def _terraform_test_impl(ctx):
    conftest = ctx.toolchains["@bazel_toolchain_conftest//:toolchain_type"].toolinfo
    executable = conftest.tool
    bundle = ctx.attr.package[TerraformBundleInfo]
    
    runfiles = ctx.runfiles(files = [])
    runfiles = runfiles.merge(ctx.attr._bash_runfiles[DefaultInfo].default_runfiles)
    
    policies = []
    for policy in ctx.files.srcs:
        policies.append("-p")
        policies.append(policy.path)

    conftest_exec = " ".join([
        "exec",
        "./%s" % executable.short_path,
        "test",
    ] + policies + [bundle.workspace.short_path])

    command_exec = " ".join([conftest_exec] + ['"$@"'] )

    out_file = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = out_file,
        content = "\n".join([_CONTENT_PREFIX] + [command_exec]),
        is_executable = True,
    )

    runfiles = runfiles.merge(ctx.runfiles(files = ctx.files.srcs + [bundle.workspace, executable]))

    return [
        DefaultInfo(
            files = depset([bundle.workspace]),
            runfiles = runfiles,
            executable = out_file,
        ),
    ]

terraform_test = rule(
    implementation = _terraform_test_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = True
        ),
        "package": attr.label(
            providers = [TerraformBundleInfo]
        ),
        "_bash_runfiles": attr.label(
            default = Label("@bazel_tools//tools/bash/runfiles"),
        ),
    },
    toolchains = [
        "@bazel_toolchain_conftest//:toolchain_type",
    ],
    test = True
)

def _terraform_policy_impl(ctx):
    conftest = ctx.toolchains["@bazel_toolchain_conftest//:toolchain_type"].toolinfo
    executable = conftest.tool
    workspace = ctx.attr.workspace[TerraformWorkspaceInfo]
    
    runfiles = ctx.runfiles(files = [])
    runfiles = runfiles.merge(ctx.attr._bash_runfiles[DefaultInfo].default_runfiles)

    default_runfiles = ctx.attr.workspace[DefaultInfo].default_runfiles
    if default_runfiles != None:
        runfiles = runfiles.merge(default_runfiles)
    
    pre_actions = " ".join([
        "./%s" % ctx.attr.workspace[DefaultInfo].files_to_run.executable.short_path,
        ";",
        "\n"
    ])

    policies = []
    for policy in ctx.files.srcs:
        policies.append("-p")
        policies.append(policy.path)

    conftest_exec = " ".join([
        "exec",
        "./%s" % executable.short_path,
        "test",
    ] + policies + ['"$BUILD_WORKSPACE_DIRECTORY/%s"' % workspace.tfplanjson])

    command_exec = " ".join([conftest_exec] + ['"$@"'] )

    out_file = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = out_file,
        content = "\n".join([_CONTENT_PREFIX, _BAZEL_WORKSPACE_PREAMBLE]+ [pre_actions] + [command_exec]),
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

terraform_policy = rule(
    implementation = _terraform_policy_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = True
        ),
        "workspace": attr.label(
            providers = [TerraformWorkspaceInfo]
        ),
        "_bash_runfiles": attr.label(
            default = Label("@bazel_tools//tools/bash/runfiles"),
        ),
    },
    toolchains = [
        "@bazel_toolchain_conftest//:toolchain_type",
    ],
    executable = True
)
