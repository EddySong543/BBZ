extends Node

const BOOT_SCREEN_PATH := "res://src/ui/boot_screen.tscn"
const OUTPUT_ROOT := "D:/Game/BoBoZan/_probe_output/boot_palette_previews"
const DESIGN_SIZE := Vector2i(1920, 1080)

const PALETTES := {
	"B": {
		"background": Color("#e7dec9"),
		"shadow": Vector3(0.356863, 0.352941, 0.341176),
		"mid": Vector3(0.505882, 0.494118, 0.462745),
		"light": Vector3(0.698039, 0.674510, 0.623529),
		"contour": Color(0.419608, 0.407843, 0.384314, 0.42),
		"foreground": Color("#5b5a57"),
		"text": Color(0.184314, 0.192157, 0.196078, 0.96),
	},
	"C": {
		"background": Color("#d7dce6"),
		"shadow": Vector3(0.274510, 0.329412, 0.419608),
		"mid": Vector3(0.423529, 0.478431, 0.564706),
		"light": Vector3(0.627451, 0.666667, 0.729412),
		"contour": Color(0.337255, 0.396078, 0.486275, 0.42),
		"foreground": Color("#46546b"),
		"text": Color(0.145098, 0.196078, 0.278431, 0.96),
	},
}


func _ready() -> void:
	var packed := load(BOOT_SCREEN_PATH) as PackedScene
	if packed == null:
		push_error("Boot palette preview could not load the Boot screen.")
		get_tree().quit(1)
		return
	var boot := packed.instantiate() as Control
	add_child(boot)
	await get_tree().process_frame
	await get_tree().process_frame
	DisplayServer.window_set_size(DESIGN_SIZE)
	await get_tree().process_frame

	var intro := boot.get_node_or_null("IntroController") as BootIntroController
	if intro == null:
		push_error("Boot palette preview is missing IntroController.")
		get_tree().quit(1)
		return
	intro.finish_immediately()
	await get_tree().create_timer(0.18).timeout
	boot.process_mode = Node.PROCESS_MODE_DISABLED

	if DirAccess.make_dir_recursive_absolute(OUTPUT_ROOT) != OK:
		push_error("Boot palette preview output directory could not be created.")
		get_tree().quit(1)
		return
	for palette_name: String in ["B", "C"]:
		_apply_palette(boot, PALETTES[palette_name])
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var output_path := "%s/palette_%s.png" % [
			OUTPUT_ROOT,
			palette_name.to_lower(),
		]
		if image.save_png(output_path) != OK:
			push_error("Boot palette preview could not save %s." % output_path)
			get_tree().quit(1)
			return
		print(
			"BOOT_PALETTE_PREVIEW_OK: palette=%s size=%dx%d path=%s"
			% [
				palette_name,
				image.get_width(),
				image.get_height(),
				output_path,
			])
	get_tree().quit()


func _apply_palette(boot: Control, palette: Dictionary) -> void:
	var stage := boot.get_node("BackgroundStage") as Control
	var intro_base := boot.get_node("IntroBlackBase") as ColorRect
	intro_base.color = palette["background"]
	var paper := stage.get_node("PaperBase") as ColorRect
	var paper_material := paper.material as ShaderMaterial
	paper_material.set_shader_parameter(&"paper_color", palette["background"])
	var contours := stage.get_node("PressureContours") as ColorRect
	var contour_material := contours.material as ShaderMaterial
	contour_material.set_shader_parameter(&"wave_color", palette["contour"])
	for layer_name: String in ["BlueBase", "BlueMid", "BlueLight"]:
		var layer := stage.get_node(layer_name) as TextureRect
		var material := layer.material as ShaderMaterial
		material.set_shader_parameter(&"palette_shadow", palette["shadow"])
		material.set_shader_parameter(&"palette_mid", palette["mid"])
		material.set_shader_parameter(&"palette_light", palette["light"])
	var foreground := stage.get_node("ForegroundBrush") as TextureRect
	var foreground_material := foreground.material as ShaderMaterial
	foreground_material.set_shader_parameter(&"tint_color", palette["foreground"])
	var main_buttons := boot.get_node("BootMenu/MainButtons") as VBoxContainer
	for child: Node in main_buttons.get_children():
		if child is Button:
			var button := child as Button
			for color_name: StringName in [
				&"font_color",
				&"font_hover_color",
				&"font_focus_color",
				&"font_pressed_color",
				&"font_hover_pressed_color",
			]:
				button.add_theme_color_override(color_name, palette["text"])
