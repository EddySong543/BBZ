extends SceneTree

const FISH_SCRIPT := preload("res://src/ui/components/scene2_waterfall_fish_leap.gd")
const OUTPUT_PATH := "D:/Game/BoBoZan/_probe_output/scene2_waterfall_fish_asset_preview.png"


func _init() -> void:
	var fish := FISH_SCRIPT.new()
	var image := fish.fish_asset_image()
	image.resize(540, 300, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(OUTPUT_PATH.get_base_dir())
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("SCENE2_FISH_ASSET_PREVIEW: save failed with %s" % error)
		quit(1)
		return
	print("SCENE2_FISH_ASSET_PREVIEW: PASS path=", OUTPUT_PATH)
	quit(0)
