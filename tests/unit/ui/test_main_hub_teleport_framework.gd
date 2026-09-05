extends GutTest

const SHOP_SCENE_PATH := "res://src/ui/main_hub/main_hub_shop.tscn"
const TELEPORT_SCENE_PATH := "res://src/ui/main_hub/main_hub_teleport.tscn"


func test_shop_scene_is_the_single_compact_service_hub() -> void:
	var packed := load(SHOP_SCENE_PATH) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var stage := packed.instantiate() as BattleStage
	add_child_autofree(stage)
	await get_tree().process_frame

	assert_true(stage is BattleStage)
	assert_eq(stage.get("district_id"), &"shop")
	var direct_children: Array[String] = []
	for child: Node in stage.get_children():
		direct_children.append(child.name)
	assert_eq(direct_children, [
		"Sky",
		"PixelCloud",
		"ShopBuilding",
		"Ground",
		"ActorLayer",
	])
	var actor_layer := stage.get_node("ActorLayer") as Control
	assert_not_null(actor_layer)
	assert_eq(actor_layer.get_child_count(), 1)
	assert_eq(actor_layer.get_child(0).name, "PlayerCharacter")
	for retired_name: String in [
		"Backdrop",
		"FarEnvironment",
		"MidEnvironment",
		"GroundEnvironment",
		"PortalLayer",
		"ForegroundEnvironment",
	]:
		assert_null(stage.get_node_or_null(retired_name))


func test_shop_scene_integrates_the_assigned_sky_and_dominant_shop() -> void:
	var packed := load(SHOP_SCENE_PATH) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var stage := packed.instantiate() as BattleStage
	add_child_autofree(stage)
	await get_tree().process_frame

	var sky := stage.get_node("Sky") as TextureRect
	assert_not_null(sky)
	assert_not_null(sky.texture)
	assert_eq(sky.texture.resource_path, "res://assets/ui/main_hub/sky.png")
	assert_eq(sky.texture.get_size(), Vector2(1672.0, 941.0))
	assert_eq(sky.size, Vector2(1920.0, 1080.0))
	assert_eq(sky.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	assert_eq(sky.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)

	var shop := stage.get_node("ShopBuilding") as TextureRect
	assert_not_null(shop)
	assert_not_null(shop.texture)
	assert_eq(shop.texture.resource_path, "res://assets/ui/main_hub/shop.png")
	assert_eq(shop.texture.get_size(), Vector2(1196.0, 928.0))
	var authored_shop_x := shop.position.x - stage.pointer_ground_offset().x
	assert_almost_eq(authored_shop_x + shop.size.x * 0.5, 960.0, 32.0)
	assert_gt(shop.size.x, 1600.0)
	assert_eq(shop.scale, Vector2.ONE)
	assert_eq(shop.get_meta("interaction_role"), &"warehouse_shop")


func test_shop_scene_reuses_the_scene9_pixel_cloud_as_a_direct_editable_layer() -> void:
	var packed := load(SHOP_SCENE_PATH) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var stage := packed.instantiate()
	add_child_autofree(stage)
	await get_tree().process_frame

	var cloud := stage.get_node("PixelCloud") as TextureRect
	assert_not_null(cloud)
	assert_eq(cloud.get_parent(), stage)
	assert_eq(cloud.get_script().resource_path,
			"res://src/ui/components/scene9_distant_pixel_cloud_bank.gd")
	assert_gt(cloud.size.x, 1920.0)
	assert_gt(cloud.size.y, 400.0)
	assert_eq(cloud.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(cloud.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_almost_eq(float(cloud.get_meta("parallax_factor")), 0.18, 0.001)
	var cloud_material := cloud.material as ShaderMaterial
	assert_not_null(cloud_material)
	assert_true(cloud_material.resource_local_to_scene)
	assert_not_null(cloud_material.shader)
	assert_eq(cloud_material.shader.resource_path,
			"res://assets/shaders/canvas_env_scene9_pixel_cloud_motion.gdshader")
	var signature := cloud.call("authored_signature") as Dictionary
	assert_true(signature.get("single_source_copy", false))


func test_shop_scene_integrates_the_assigned_editable_ground() -> void:
	var packed := load(SHOP_SCENE_PATH) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var stage := packed.instantiate() as BattleStage
	add_child_autofree(stage)
	await get_tree().process_frame

	var ground := stage.get_node("Ground") as TextureRect
	assert_not_null(ground)
	assert_not_null(ground.texture)
	assert_eq(ground.texture.resource_path, "res://assets/ui/main_hub/ground.png")
	assert_eq(ground.texture.get_size(), Vector2(408.0, 136.0))
	assert_gt(ground.size.x, 0.0)
	assert_gt(ground.size.y, 0.0)
	assert_eq(ground.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(ground.stretch_mode, TextureRect.STRETCH_SCALE)


func test_shop_scene_uses_unfiltered_map_character_and_shared_pointer_depth() -> void:
	var packed := load(SHOP_SCENE_PATH) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var stage := packed.instantiate() as BattleStage
	add_child_autofree(stage)
	await get_tree().process_frame

	var actor_layer := stage.get_node("ActorLayer") as Control
	var character := actor_layer.get_node("PlayerCharacter") as MainHubCharacter
	assert_not_null(character)
	assert_false(character.sprite_frames_path.is_empty())
	assert_true(ResourceLoader.exists(character.sprite_frames_path))
	assert_eq(character.walk_frames_path,
			"res://assets/sprites/heroes/h01/h01_walk.tres")
	assert_true(ResourceLoader.exists(character.walk_frames_path))
	assert_eq(character.size, Vector2(208.0, 208.0))
	assert_eq(character.pivot_offset, Vector2(104.0, 156.0))
	assert_almost_eq(character.content_scale(), 1.125, 0.001)
	var visual := character.get_node("Visual") as TextureRect
	assert_not_null(visual)
	assert_eq(visual.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_null(character.material)
	assert_null(visual.material)
	assert_eq(character.modulate, Color.WHITE)
	assert_eq(character.self_modulate, Color.WHITE)
	assert_true((character.get_script() as GDScript).is_tool(),
			"角色脚本必须在编辑器中生成静态预览")
	assert_not_null(character.current_texture(),
			"独立角色场景必须带默认 h01 预览，不能只在运行时才可见")
	assert_eq(character.visual_scale(), Vector2(1.5, 1.5))
	assert_gt(character.idle_frame_count(), 0)
	assert_eq(character.walk_frame_count(), 5)
	var authored_foot := character.position + character.pivot_offset
	assert_eq(character.foot_position(), authored_foot,
			"场景节点位置必须直接成为运行时出生点")
	assert_eq(stage.call("get_layer_contract"), {
		"Sky": 0.0,
		"PixelCloud": 0.18,
		"ShopBuilding": 1.0,
		"Ground": 1.0,
		"ActorLayer": 1.0,
	})

	var sky := stage.get_node("Sky") as TextureRect
	var cloud := stage.get_node("PixelCloud") as TextureRect
	var shop := stage.get_node("ShopBuilding") as TextureRect
	var ground := stage.get_node("Ground") as TextureRect
	var layer_bases := {
		"Sky": sky.position,
		"PixelCloud": cloud.position,
		"ShopBuilding": shop.position,
		"Ground": ground.position,
		"ActorLayer": actor_layer.position,
	}
	for layer: Control in [sky, cloud, shop, ground, actor_layer]:
		stage.set_layer_base_position(layer, layer.position)
	stage.pointer_parallax = false
	stage.pointer_zoom = 0.0
	stage.set("_pnx", 1.0)
	stage._process(0.0)
	assert_almost_eq(sky.position.x, float(layer_bases["Sky"].x), 0.001)
	assert_almost_eq(cloud.position.x,
			float(layer_bases["PixelCloud"].x) - stage.pointer_strength * 0.18,
			0.001)
	assert_almost_eq(shop.position.x,
			float(layer_bases["ShopBuilding"].x) - stage.pointer_strength, 0.001)
	assert_almost_eq(ground.position.x,
			float(layer_bases["Ground"].x) - stage.pointer_strength, 0.001)
	assert_almost_eq(actor_layer.position.x,
			float(layer_bases["ActorLayer"].x) - stage.pointer_strength, 0.001)
	assert_eq(character.foot_position(), authored_foot,
			"角色本地落脚点不被舞台视差反写")


func test_shop_character_has_one_shared_contact_shadow_for_every_hero() -> void:
	var packed := load(SHOP_SCENE_PATH) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var stage := packed.instantiate() as BattleStage
	add_child_autofree(stage)
	await get_tree().process_frame

	var character := stage.get_node("ActorLayer/PlayerCharacter") as MainHubCharacter
	var shadow := character.get_node("PlayerShadow") as MainHubCharacterShadow
	assert_not_null(shadow)
	assert_eq(character.get_child(0), shadow,
			"脚影必须位于角色画面下方")
	assert_eq(shadow.style_signature(), {
		"base_width": 62.0,
		"minimum_width": 42.0,
		"base_height": 12.0,
		"minimum_height": 8.0,
		"base_opacity": 0.46,
		"minimum_opacity": 0.24,
		"display_scale": 1.5,
		"current_lift": 0.0,
	})
	var original_signature := shadow.style_signature()
	character.configure_animation_resources(
			"res://assets/sprites/heroes/h02/h02_idle.tres", "")
	assert_eq(shadow.style_signature(), original_signature,
			"切换英雄资源不能改变公共脚影样式")


func test_shop_character_keeps_the_existing_continuous_movement_option() -> void:
	var packed := load(SHOP_SCENE_PATH) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var stage := packed.instantiate() as BattleStage
	add_child_autofree(stage)
	await get_tree().process_frame

	var character := stage.get_node("ActorLayer/PlayerCharacter") as MainHubCharacter
	assert_not_null(character)
	character.movement_style = MainHubCharacter.MovementStyle.CONTINUOUS
	var idle_texture := character.current_texture()
	var initial_foot := character.foot_position()
	var fixed_y := character.foot_position().y
	Input.action_press(&"ui_right")
	character._process(0.25)
	Input.action_release(&"ui_right")
	assert_eq(character.foot_position(), Vector2(initial_foot.x + 80.0, fixed_y),
			"ui_right 必须驱动主城角色向右移动")
	assert_eq(character.animation_state(), &"walk")
	assert_ne(character.current_texture(), idle_texture)
	assert_eq(character.current_texture().get_size(), Vector2(208.0, 208.0),
			"walk 每帧必须归一化到与主界面/PVE相同的角色画布")
	character.move_horizontal(1.0, 0.25)
	assert_eq(character.foot_position(), Vector2(initial_foot.x + 160.0, fixed_y))
	assert_eq(character.visual_scale(), Vector2(1.5, 1.5))
	character.move_horizontal(-1.0, 10.0)
	assert_eq(character.foot_position(), Vector2(120.0, fixed_y))
	assert_eq(character.visual_scale(), Vector2(-1.5, 1.5))
	character.move_horizontal(0.0, 0.0)
	assert_eq(character.animation_state(), &"idle")
	character.move_horizontal(1.0, 20.0)
	assert_eq(character.foot_position(), Vector2(1800.0, fixed_y))
	assert_almost_eq(character.position.y + character.pivot_offset.y,
			fixed_y, 0.001)


func test_shop_character_exposes_expedition_gait_without_replacing_continuous_motion() -> void:
	var packed := load(SHOP_SCENE_PATH) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var stage := packed.instantiate() as BattleStage
	add_child_autofree(stage)
	await get_tree().process_frame

	var character := stage.get_node("ActorLayer/PlayerCharacter") as MainHubCharacter
	assert_eq(character.movement_style, MainHubCharacter.MovementStyle.EXPEDITION_GAIT)
	var ground_y := character.foot_position().y
	character.move_horizontal(1.0, 0.2)
	assert_eq(character.animation_state(), &"walk")
	assert_almost_eq(character.foot_position().y, ground_y, 0.001,
			"远征步态的地面落脚线仍保持固定")
	assert_lt(character.visual_foot_position().y, ground_y,
			"远征步态必须产生离地跳步")
	assert_ne(character.visual_rotation(), 0.0)
	var shadow := character.get_node("PlayerShadow") as MainHubCharacterShadow
	assert_gt(float(shadow.style_signature().get("current_lift", 0.0)), 0.0)
	character.move_horizontal(0.0, 0.2)
	assert_eq(character.animation_state(), &"idle")
	assert_eq(character.visual_foot_position(), character.foot_position())
	assert_eq(character.visual_scale(), Vector2(1.5, 1.5))


func test_shop_first_ambient_layer_keeps_the_building_rigid() -> void:
	var packed := load(SHOP_SCENE_PATH) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var stage := packed.instantiate() as BattleStage
	add_child_autofree(stage)
	await get_tree().process_frame

	var shop := stage.get_node("ShopBuilding") as TextureRect
	assert_null(shop.material,
			"刚性建筑主体不得套用整体形变或呼吸材质")
	var glow := shop.get_node("WarmGlowOverlay") as TextureRect
	assert_not_null(glow)
	assert_eq(glow.texture, shop.texture)
	assert_eq(glow.size, shop.size)
	var glow_material := glow.material as ShaderMaterial
	assert_not_null(glow_material)
	assert_true(glow_material.resource_local_to_scene)
	assert_eq(glow_material.shader.resource_path,
			"res://assets/shaders/canvas_main_hub_shop_warm_glow.gdshader")
	assert_gt(float(glow_material.get_shader_parameter("pulse_speed")), 0.0)
	assert_gt(float(glow_material.get_shader_parameter("glow_strength")), 0.0)
	var smoke := shop.get_node("SmokeEmitter") as CPUParticles2D
	assert_not_null(smoke)
	assert_eq(smoke.amount, 8)
	assert_true(smoke.emitting)
	assert_true(smoke.local_coords)
	assert_not_null(smoke.texture)
	assert_eq(smoke.texture.get_size(), Vector2(16.0, 16.0))
	assert_gte(smoke.scale_amount_min * smoke.texture.get_width(), 14.0)
	assert_gte(smoke.scale_amount_max * smoke.texture.get_width(), 24.0)
	assert_gte(smoke.color.a, 0.5,
			"稀疏烟气不能靠极低透明度变得不可读")
	assert_gte(maxf(smoke.color.r, maxf(smoke.color.g, smoke.color.b)), 0.6)


func test_teleport_scene_is_now_a_separate_empty_design_surface() -> void:
	var packed := load(TELEPORT_SCENE_PATH) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var stage := packed.instantiate()
	add_child_autofree(stage)
	await get_tree().process_frame

	assert_true(stage is BattleStage)
	assert_eq(stage.get("district_id"), &"teleport")
	assert_eq(stage.get_child_count(), 0,
			"独立传送场景只保留根节点，等待下一轮专门设计")
	assert_eq(stage.call("get_layer_contract"), {})
