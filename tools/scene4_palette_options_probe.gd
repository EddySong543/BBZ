extends Node

const ProbeOutput := preload("res://tools/probe_output.gd")
const BATTLE_SCREEN4_PATH := "res://src/ui/battle_screen4.tscn"

const DEPTH_NODES: Array[StringName] = [
	&"FarForest",
	&"BackgroundBottomLeaves",
	&"BackgroundTree",
	&"BackgroundTree2",
	&"BackgroundTopLeaves2",
	&"BattlePlatformDepthShadow",
	&"BattlePlatform",
	&"LeftTree2",
	&"RightTree2",
]

const FOREGROUND_NODES: Array[StringName] = [
	&"BattlePlatformDepthShadow",
	&"BattlePlatform",
	&"LeftTree2",
	&"RightTree2",
]


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i.ZERO
	BattleSetup.reset()
	var screen := (
			load(BATTLE_SCREEN4_PATH) as PackedScene
	).instantiate() as Control
	add_child(screen)
	await get_tree().create_timer(1.0).timeout
	var stage := screen.get_node("StageSlot/Stage") as BattleStage
	stage.pointer_parallax = false
	stage.set("_pnx", 0.0)
	stage.call("_process", 0.0)
	stage.set_process(false)
	var spirits := stage.get_node("AchievementLeafSpirits")
	spirits.auto_ambient = false
	var ambient_timer := spirits.get_node_or_null("AmbientTimer") as Timer
	if ambient_timer != null:
		ambient_timer.stop()
	# Palette comparison is about the environment. Hide the transient battle cue
	# so all three captures share exactly the same UI state.
	var big_turn_label := screen.get_node_or_null("BigTurnLabel") as Control
	if big_turn_label != null:
		big_turn_label.hide()

	var variants: Array[Dictionary] = [
		{
			"file": "scene4_palette_a_clean_teal.png",
			"shadow": Color("08242b"),
			"mid": Color("205157"),
			"light": Color("72958a"),
			"tint": Color("4c7772"),
			"haze": Color("638581"),
			"sky_shadow": Color("0b282d"),
			"sky_mid": Color("2b5b59"),
			"sky_light": Color("86a493"),
			"saturation": 0.54,
			"post_tint": Color(0.92, 1.02, 1.03, 1.0),
			"post_shadow": Color(0.84, 1.02, 1.07, 1.0),
			"post_highlight": Color(0.98, 1.04, 1.01, 1.0),
			"ambient": Color("668f82"),
		},
		{
			"file": "scene4_palette_b_moonlit_bluegreen.png",
			"shadow": Color("081d2b"),
			"mid": Color("184552"),
			"light": Color("668d94"),
			"tint": Color("356778"),
			"haze": Color("4c7480"),
			"sky_shadow": Color("091f30"),
			"sky_mid": Color("1f4d5d"),
			"sky_light": Color("789ca1"),
			"saturation": 0.58,
			"post_tint": Color(0.9, 1.0, 1.06, 1.0),
			"post_shadow": Color(0.78, 0.98, 1.12, 1.0),
			"post_highlight": Color(0.94, 1.03, 1.08, 1.0),
			"ambient": Color("527f86"),
		},
		{
			"file": "scene4_palette_c_sage_pine.png",
			"shadow": Color("172822"),
			"mid": Color("3a584c"),
			"light": Color("8b9f8d"),
			"tint": Color("687f72"),
			"haze": Color("788d82"),
			"sky_shadow": Color("1a2e28"),
			"sky_mid": Color("466558"),
			"sky_light": Color("a0ad98"),
			"saturation": 0.42,
			"post_tint": Color(0.98, 1.02, 0.99, 1.0),
			"post_shadow": Color(0.94, 1.02, 0.98, 1.0),
			"post_highlight": Color(1.02, 1.03, 0.96, 1.0),
			"ambient": Color("788f7f"),
		},
		{
			"file": "scene4_palette_ref34_luminous_grove.png",
			"shadow": Color("03221f"),
			"mid": Color("245b46"),
			"light": Color("a8c957"),
			"tint": Color("3f765d"),
			"haze": Color("75bcb3"),
			"sky_shadow": Color("031f20"),
			"sky_mid": Color("17483f"),
			"sky_light": Color("8bd8d5"),
			"saturation": 0.74,
			"post_tint": Color(0.94, 1.02, 0.98, 1.0),
			"post_shadow": Color(0.76, 1.0, 0.95, 1.0),
			"post_highlight": Color(1.08, 1.08, 0.82, 1.0),
			"ambient": Color("557f6c"),
			"ref34_style": true,
		},
	]

	for variant: Dictionary in variants:
		_apply_variant(stage, screen, variant)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var output_path := ProbeOutput.path(String(variant["file"]))
		var error := get_viewport().get_texture().get_image().save_png(
				output_path)
		if error != OK:
			push_error("Scene4 palette preview save failed: %s" % output_path)
			BattleSetup.reset()
			get_tree().quit(1)
			return
		print("SCENE4_PALETTE_PREVIEW: saved=", output_path)

	BattleSetup.reset()
	get_tree().quit(0)


func _apply_variant(
		stage: BattleStage,
		screen: Control,
		variant: Dictionary
) -> void:
	var shadow := variant["shadow"] as Color
	var mid := variant["mid"] as Color
	var light := variant["light"] as Color
	var tint := variant["tint"] as Color
	var haze := variant["haze"] as Color
	var base_saturation := float(variant["saturation"])
	var ref34_style := bool(variant.get("ref34_style", false))

	var sky := stage.get_node("Sky") as TextureRect
	var sky_material := sky.material as ShaderMaterial
	sky_material.set_shader_parameter("shadow_color", variant["sky_shadow"])
	sky_material.set_shader_parameter("mid_color", variant["sky_mid"])
	sky_material.set_shader_parameter("light_color", variant["sky_light"])
	sky_material.set_shader_parameter("grade_strength", 0.96)

	for node_name: StringName in DEPTH_NODES:
		var art := stage.get_node(NodePath(node_name)) as TextureRect
		var material := art.material as ShaderMaterial
		var is_foreground := node_name in FOREGROUND_NODES
		var is_distant := node_name in [
			&"FarForest", &"BackgroundBottomLeaves",
		]
		var role_shadow := shadow
		var role_mid := mid
		var role_light := light
		if ref34_style and node_name == &"BattlePlatform":
			role_shadow = Color("06251f")
			role_mid = Color("4d733a")
			role_light = Color("c8dd63")
		elif ref34_style and is_foreground:
			role_shadow = Color("031b1c")
			role_mid = Color("174438")
			role_light = Color("5f7e49")
		elif ref34_style and is_distant:
			role_shadow = Color("062625")
			role_mid = Color("22594c")
			role_light = Color("6aa582")
		elif ref34_style:
			role_shadow = Color("04221f")
			role_mid = Color("205745")
			role_light = Color("91b65b")
		elif is_foreground:
			role_shadow = shadow.darkened(0.2)
			role_mid = mid.darkened(0.08)
			role_light = light.darkened(0.05)
		elif is_distant:
			role_shadow = shadow.lightened(0.05)
			role_mid = mid.lightened(0.08)
			role_light = light.lightened(0.08)
		material.set_shader_parameter("saturation",
				base_saturation + (0.08 if is_foreground else 0.0))
		material.set_shader_parameter("tint_color", tint)
		material.set_shader_parameter("tint_strength",
				0.34 if is_distant else 0.29)
		material.set_shader_parameter("haze_color", haze)
		material.set_shader_parameter("palette_shadow", role_shadow)
		material.set_shader_parameter("palette_mid", role_mid)
		material.set_shader_parameter("palette_light", role_light)
		material.set_shader_parameter("palette_strength",
				(0.9 if is_distant else 0.84) if ref34_style
				else (0.84 if is_distant else 0.76))
		if ref34_style:
			var brightness_by_node: Dictionary[StringName, float] = {
				&"FarForest": 0.74,
				&"BackgroundBottomLeaves": 0.69,
				&"BackgroundTree": 0.73,
				&"BackgroundTree2": 0.71,
				&"BackgroundTopLeaves2": 0.68,
				&"BattlePlatformDepthShadow": 0.42,
				&"BattlePlatform": 0.96,
				&"LeftTree2": 0.60,
				&"RightTree2": 0.62,
			}
			material.set_shader_parameter(
					"brightness", brightness_by_node[node_name])
			material.set_shader_parameter(
					"contrast", 1.18 if node_name == &"BattlePlatform"
					else (1.08 if is_foreground else 1.1))
			material.set_shader_parameter("highlight_rolloff", 0.05)
			material.set_shader_parameter(
					"haze_strength", 0.12 if is_distant else 0.04)

	for stone_name: StringName in [
		&"RuinStone1", &"RuinStone2", &"RuinStone3", &"RuinStone4",
	]:
		var stone := stage.get_node(NodePath(stone_name)) as TextureRect
		var material := stone.material as ShaderMaterial
		material.set_shader_parameter(
				"shadow_color",
				Color("05231f") if ref34_style else shadow.darkened(0.12))
		material.set_shader_parameter(
				"mid_color",
				Color("315f43") if ref34_style else mid.darkened(0.05))
		material.set_shader_parameter(
				"light_color",
				Color("92aa58") if ref34_style else light.darkened(0.18))

	var post_fx := screen.get_node("PostFX") as ColorRect
	var post_material := post_fx.material as ShaderMaterial
	post_material.set_shader_parameter("saturation", 1.0)
	post_material.set_shader_parameter("tint_color", variant["post_tint"])
	post_material.set_shader_parameter("tint_strength", 0.08)
	post_material.set_shader_parameter("shadow_tint", variant["post_shadow"])
	post_material.set_shader_parameter("highlight_tint", variant["post_highlight"])
	post_material.set_shader_parameter("split_strength", 0.07)
	post_material.set_shader_parameter("grain_amount", 0.0)
	if ref34_style:
		post_material.set_shader_parameter("brightness", 0.99)
		post_material.set_shader_parameter("contrast", 1.14)
		post_material.set_shader_parameter("saturation", 1.0)
		post_material.set_shader_parameter("tint_strength", 0.04)
		post_material.set_shader_parameter("split_strength", 0.11)

	for side: String in ["P1", "P2"]:
		var display := screen.get(
				"%s_char_display" % side.to_lower()) as Control
		var sprite := display.get_node(
				"SubViewport/AnimatedSprite2D") as AnimatedSprite2D
		var material := sprite.material as ShaderMaterial
		material.set_shader_parameter(
				"forest_ambient_color", variant["ambient"])
		material.set_shader_parameter("shadow_tint", tint.lightened(0.08))
		material.set_shader_parameter("fill_color", haze.darkened(0.06))
		material.set_shader_parameter(
				"rim_color",
				Color("86cdd0") if ref34_style else light.darkened(0.02))
