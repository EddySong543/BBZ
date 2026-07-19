#!/bin/bash
# Shared safety bootstrap for project hooks.
# Always enter the project root because Claude Code Bash cwd can persist across calls.

hook_enter_project() {
    local hook_dir project_root
    hook_dir=$(cd -- "${BASH_SOURCE[0]%/*}" 2>/dev/null && pwd)
    project_root="${CLAUDE_PROJECT_DIR:-}"

    if [ -z "$project_root" ]; then
        project_root=$(cd -- "$hook_dir/../.." 2>/dev/null && pwd)
    fi

    if [ -z "$project_root" ] || [ ! -f "$project_root/project.godot" ]; then
        echo "Hook warning: cannot resolve the BBZ project root; hook skipped." >&2
        return 1
    fi

    if ! cd -- "$project_root" 2>/dev/null; then
        echo "Hook warning: cannot enter project root: $project_root; hook skipped." >&2
        return 1
    fi

    export CLAUDE_PROJECT_DIR="$project_root"
    return 0
}

hook_hash_stream() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 | awk '{print $1}'
    else
        cksum | awk '{print $1 ":" $2}'
    fi
}
