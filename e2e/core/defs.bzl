"Simple rule to test nodejs toolchain"

_BASH_SRC = """#!{bash}
# --- begin runfiles.bash initialization v2 ---
# Copy-pasted from the Bazel Bash runfiles library v2.
set -uo pipefail; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${{RUNFILES_DIR:-/dev/null}}/$f" 2>/dev/null || \
source "$(grep -sm1 "^$f " "${{RUNFILES_MANIFEST_FILE:-/dev/null}}" | cut -f2- -d' ')" 2>/dev/null || \
source "$0.runfiles/$f" 2>/dev/null || \
source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
{{ echo>&2 "ERROR: cannot find $f"; exit 1; }}; f=; set -e
# --- end runfiles.bash initialization v2 ---

NODE_PATH=$(rlocation node_modules/acorn)/.. \\
    $(rlocation {node}) \\
    $(rlocation {entry_point}) \\
    {args} $@
"""

def _strip_external(path):
    return path[len("external/"):] if path.startswith("external/") else path

# Get the path to lookup the file in runfiles manifest
def _to_manifest_path(ctx, file):
    if file.short_path.startswith("../"):
        return file.short_path[3:]
    else:
        return ctx.workspace_name + "/" + file.short_path

def _my_nodejs_impl(ctx):
    bash_bin = ctx.toolchains["@bazel_tools//tools/sh:toolchain_type"].path
    node_bin = ctx.toolchains["@rules_nodejs//nodejs:toolchain_type"].nodeinfo
    launcher = ctx.actions.declare_file("_%s_launcher.sh" % ctx.label.name)
    ctx.actions.write(
        launcher,
        _BASH_SRC.format(
            bash = bash_bin,
            node = _strip_external(node_bin.target_tool_path),
            entry_point = _to_manifest_path(ctx, ctx.file.entry_point),
            args = " ".join(ctx.attr.args),
        ),
        is_executable = True,
    )
    all_files = ctx.files.data + ctx.files._runfiles_lib + [ctx.file.entry_point] + node_bin.tool_files
    runfiles = ctx.runfiles(
        files = all_files,
        transitive_files = depset(all_files),
        root_symlinks = {
            "node_modules/acorn": ctx.files.data[0],
        },
    )
    return DefaultInfo(
        executable = launcher,
        runfiles = runfiles,
    )

my_nodejs = rule(
    implementation = _my_nodejs_impl,
    doc = "Example of translating inputs to outputs using node",
    attrs = {
        "data": attr.label_list(allow_files = True),
        "entry_point": attr.label(allow_single_file = True),
        "_runfiles_lib": attr.label(default = "@bazel_tools//tools/bash/runfiles"),
    },
    executable = True,
    toolchains = [
        "@bazel_tools//tools/sh:toolchain_type",
        "@rules_nodejs//nodejs:toolchain_type",
    ],
)
