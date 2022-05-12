def _copy_cmd(directory, files):
    return "\n".join(["cp {} {}/.".format(f.path, directory) for f in files])

def _helm_repository_impl(ctx):
    helm = ctx.toolchains["@bazel_toolchain_helm//:toolchain_type"].toolinfo
    yq = ctx.toolchains["@bazel_toolchain_yq//:toolchain_type"].toolinfo

    index = ctx.actions.declare_file("{}.yaml".format(ctx.attr.name))
    build_file = ctx.actions.declare_file("{}.sh".format(ctx.attr.name))
    chart_directory = ctx.actions.declare_directory("{}.charts".format(ctx.attr.name))
    ctx.actions.write(
        output = build_file,
        content = """
{copy_cmd}
{helm_path} repo index --debug {directory}/
{yq_path} -i e '(.generated = "1900-01-01T01:00:00.000000000Z") | ((.entries[] | .[]).created |= "1900-01-01T01:00:00.000000000Z")' {directory}/index.yaml
cp {directory}/index.yaml {output}
        """.format(
            copy_cmd = _copy_cmd(chart_directory.path, ctx.files.charts),
            directory = chart_directory.path,
            output = index.path,
            helm_path = helm.tool.path,
            yq_path = yq.tool.path,
        ),
    )
    ctx.actions.run(
        inputs = ctx.files.charts + [helm.tool, yq.tool],
        outputs = [index, chart_directory],
        mnemonic = "HelmRepositoryInitialize",
        progress_message = "Generating helm repository",
        executable = build_file,
    )
    return [DefaultInfo(files = depset([index]))]

helm_repository = rule(
    implementation = _helm_repository_impl,
    attrs = {
        "charts": attr.label_list(
            mandatory = True,
            doc = "Charts",
            allow_files = True,
        ),
    },
    toolchains = [
        "@bazel_toolchain_helm//:toolchain_type",
        "@bazel_toolchain_yq//:toolchain_type",
    ],
)
