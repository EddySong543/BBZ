extends Node

## 第一阶段格线语言预览：只在截图进程中修改 GroundArtLayer 的材质参数。
## 正式 ExpeditionScreen、TileSet、地表资产与已通过的圆角基准均不写回。

const HeroDataScript := preload("res://src/battle/hero_data.gd")
const ProbeOutput := preload("res://tools/probe_output.gd")

const PREVIEWS: Array[Dictionary] = [
	{
		"file": "exped_weak_grid_a_framed_round.png",
		"cell_inset_px": 1.0,
		"corner_radius_px": 16.0,
		"pixel_step_px": 4.0,
		"border_px": 2.0,
		"gap_color": Color("203a33"),
		"border_color": Color("3b5233"),
	},
	{
		"file": "exped_weak_grid_b_continuous.png",
		"cell_inset_px": 0.0,
		"corner_radius_px": 0.0,
		"pixel_step_px": 4.0,
		"border_px": 0.0,
		"gap_color": Color("203a33"),
		"border_color": Color("3b5233"),
	},
	{
		"file": "exped_weak_grid_c_subtle_round.png",
		"cell_inset_px": 0.65,
		"corner_radius_px": 12.0,
		"pixel_step_px": 4.0,
		"border_px": 0.85,
		"gap_color": Color("233a31"),
		"border_color": Color("31462f"),
	},
]


func _ready() -> void:
	var window := get_window()
	window.content_scale_size = Vector2i(1920, 1080)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

	var screen := (load("res://src/expedition/expedition_screen.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().create_timer(0.35).timeout
	screen.seed_value = 777
	screen._on_hero_selected(HeroDataScript.create_launch_pool()[2])
	await get_tree().create_timer(0.45).timeout

	# 三张图锁定同一逻辑位置、同一镜头与同一光影时刻，仅比较格边语言。
	screen.map.player = Vector2i(9, 7)
	screen.map._reveal_around(screen.map.player)
	screen._camera_initialized = false
	screen._refresh()
	await get_tree().create_timer(0.20).timeout
	screen.set_process(false)

	for preview: Dictionary in PREVIEWS:
		_apply_ground_style(screen.ground_cell_mat, preview)
		screen.ground_art.queue_redraw()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		await _shot(String(preview["file"]))

	get_tree().quit()


func _apply_ground_style(material: ShaderMaterial, preview: Dictionary) -> void:
	material.set_shader_parameter("cell_inset_px", float(preview["cell_inset_px"]))
	material.set_shader_parameter("corner_radius_px", float(preview["corner_radius_px"]))
	material.set_shader_parameter("pixel_step_px", float(preview["pixel_step_px"]))
	material.set_shader_parameter("border_px", float(preview["border_px"]))
	material.set_shader_parameter("gap_color", preview["gap_color"])
	material.set_shader_parameter("border_color", preview["border_color"])


func _shot(file_name: String) -> void:
	var output_path: String = ProbeOutput.path(file_name)
	var image := get_viewport().get_texture().get_image()
	assert(image.get_size() == Vector2i(1920, 1080))
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Could not save %s: %s" % [output_path, error_string(error)])
	else:
		print("saved: ", output_path)
