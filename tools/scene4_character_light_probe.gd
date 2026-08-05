extends Node

const ProbeOutput := preload("res://tools/probe_output.gd")


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i.ZERO
	BattleSetup.reset()
	var packed := load("res://src/ui/battle_screen4.tscn") as PackedScene
	var screen := packed.instantiate()
	add_child(screen)
	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(screen):
		get_tree().quit(1)
		return

	var stage := screen.get_node("StageSlot/Stage") as BattleStage
	stage.set_process(false)
	screen.set_process(false)
	stage.set("_pnx", 0.0)
	stage.call("_process", 0.0)
	screen.call("_process", 0.0)

	var p1_sprite := _character_sprite(screen, "P1")
	var p2_sprite := _character_sprite(screen, "P2")
	if p1_sprite == null or p2_sprite == null:
		push_error("Scene4 character-light probe could not resolve both live sprites")
		BattleSetup.reset()
		get_tree().quit(1)
		return
	for sprite: AnimatedSprite2D in [p1_sprite, p2_sprite]:
		sprite.pause()
		sprite.frame = 0

	var post_material := (
			screen.get_node("PostFX") as ColorRect
	).material as ShaderMaterial
	post_material.set_shader_parameter("grain_amount", 0.0)
	post_material.set_shader_parameter("impact_strength", 0.0)

	var p1_material := p1_sprite.material as ShaderMaterial
	var p2_material := p2_sprite.material as ShaderMaterial
	_reset_peak(p1_material)
	_reset_peak(p2_material)
	await _shot(ProbeOutput.path("scene4_character_light_base.png"))

	p1_material.set_shader_parameter("flash_amount", 1.0)
	p1_material.set_shader_parameter("rim_strength", 1.07)
	await _shot(ProbeOutput.path("scene4_character_light_p1_peak.png"))
	_reset_peak(p1_material)

	p2_material.set_shader_parameter("flash_amount", 1.0)
	p2_material.set_shader_parameter("rim_strength", 1.07)
	await _shot(ProbeOutput.path("scene4_character_light_p2_peak.png"))
	_reset_peak(p2_material)

	print(
			"SCENE4_CHARACTER_LIGHT_PROBE: PASS exposure=",
			p1_material.get_shader_parameter("scene_exposure"),
			" flash_peak=",
			p1_material.get_shader_parameter("flash_peak_strength"),
			" rim_peak=",
			p1_material.get_shader_parameter("rim_peak_strength"))
	BattleSetup.reset()
	get_tree().quit(0)


func _character_sprite(screen: Control, side: String) -> AnimatedSprite2D:
	return screen.get_node(
			"WorldGroup/%sCharDisplay/SubViewport/AnimatedSprite2D" % side
	) as AnimatedSprite2D


func _reset_peak(material: ShaderMaterial) -> void:
	material.set_shader_parameter("flash_amount", 0.0)
	material.set_shader_parameter("rim_strength", 0.045)


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	if not is_instance_valid(self):
		return
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Scene4 character-light probe could not save %s (error=%d)" % [
			path,
			error,
		])
