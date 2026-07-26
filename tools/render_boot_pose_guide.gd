extends SceneTree

const SOURCE := "res://design/references/boot_h01_pose_guide.svg"
const OUTPUT := "res://design/references/boot_h01_pose_guide.png"


func _initialize() -> void:
	var image := Image.load_from_file(SOURCE)
	if image == null or image.is_empty():
		push_error("Failed to load pose guide SVG: %s" % SOURCE)
		quit(1)
		return
	var error := image.save_png(OUTPUT)
	if error != OK:
		push_error("Failed to save pose guide PNG: %s" % error_string(error))
		quit(1)
		return
	print("saved pose guide: ", OUTPUT, " ", image.get_size())
	quit(0)
