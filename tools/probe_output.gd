extends RefCounted

## Shared output resolver for visual probes.
## Override with `-- probe-output=<absolute directory>` or BBZ_PROBE_OUTPUT.

const DEFAULT_DIR := "user://probe-output"

static var _announced := false


static func path(file_name: String) -> String:
	var root := OS.get_environment("BBZ_PROBE_OUTPUT").strip_edges()
	for raw_arg in OS.get_cmdline_user_args():
		var arg := String(raw_arg)
		if arg.begins_with("probe-output="):
			root = arg.trim_prefix("probe-output=").strip_edges()
	if root.is_empty():
		root = DEFAULT_DIR
	if root.begins_with("user://") or root.begins_with("res://"):
		root = ProjectSettings.globalize_path(root)
	root = root.replace("\\", "/").trim_suffix("/")
	var err := DirAccess.make_dir_recursive_absolute(root)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_error("ProbeOutput: cannot create output directory %s (err=%d)" % [root, err])
	if not _announced:
		print("PROBE_OUTPUT_DIR: ", root)
		_announced = true
	return root.path_join(file_name)
