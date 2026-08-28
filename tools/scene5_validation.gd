extends SceneTree

const SCENE5_PATH := "res://src/ui/scenes/scene5.tscn"
const BATTLE5_PATH := "res://src/ui/battle_screen5.tscn"
const SKY_PATH := "res://assets/scenes/scene5/scene5_sky.png"
const SKY_OVERLAY_PATH := (
		"res://assets/scenes/scene5/scene5_sky_overlay.png")
const FAR_WHEAT_PATH := "res://assets/scenes/scene5/scene5_far_wheat.png"
const DISTANT_FIELD_PATH := (
		"res://assets/scenes/scene5/scene5_distant_field.png")
const GROUND_PATH := "res://assets/scenes/scene5/scene5_ground.png"
const NEAR_WHEAT_PATH := (
		"res://assets/scenes/scene5/scene5_near_wheat.png")
const WIND_SHADER_PATH := (
		"res://assets/shaders/scene5_wheat_wind.gdshader")
const SUN_RAY_SHADER_PATH := (
		"res://assets/shaders/scene5_sun_rays.gdshader")
const CHAFF_ATLAS_PATH := (
		"res://assets/scenes/scene5/scene5_wind_chaff_atlas.png")
const WIND_SCRIPT_PATH := (
		"res://src/ui/components/scene5_wind_field.gd")
const CROP_CIRCLE_SCRIPT_PATH := (
		"res://src/ui/components/scene5_crop_circle.gd")
const CHARACTER_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene5_character_light.gdshader")
const WHEAT_MESH_SCRIPT_PATH := (
		"res://src/ui/components/scene5_wheat_mesh.gd")
const PIXEL_CLOUD_SHADER_PATH := (
		"res://assets/shaders/canvas_env_dark_smoke.gdshader")
const DISTANT_WHEAT_SHADER_PATH := (
		"res://assets/shaders/scene5_distant_wheat_light.gdshader")


func _initialize() -> void:
	var failures: Array[String] = []
	if not ResourceLoader.exists(SCENE5_PATH):
		failures.append("missing Scene5 stage")
	if not ResourceLoader.exists(BATTLE5_PATH):
		failures.append("missing BattleScreen5 composition")

	if ResourceLoader.exists(SCENE5_PATH):
		var stage := (load(SCENE5_PATH) as PackedScene).instantiate() as BattleStage
		root.add_child(stage)
		await process_frame
		var expected_layers: Array[String] = [
			"Sky",
			"SunRayField",
			"SkyOverlay",
			"UpperCloud",
			"HorizonHaze",
			"DistantWheat",
			"MidFarWheat",
			"ClickLeavesMidFar",
			"FarWheat",
			"ClickLeavesFar",
			"FarWheatCoverBack",
			"ClickLeavesCover",
			"CropCircle",
			"MidFieldHaze",
			"Atmosphere",
			"AmbientChaff",
			"BattlePlatform",
			"GustChaff",
			"NearWheatLeft",
		]
		for layer_name: String in expected_layers:
			if not stage.has_node(layer_name):
				failures.append("missing Scene5 layer %s" % layer_name)
		var texture_layers: Dictionary[String, String] = {
			"Sky": SKY_PATH,
			"SkyOverlay": SKY_OVERLAY_PATH,
			"MidFarWheat": FAR_WHEAT_PATH,
			"FarWheat": FAR_WHEAT_PATH,
			"FarWheatCoverBack": FAR_WHEAT_PATH,
			"NearWheatLeft": NEAR_WHEAT_PATH,
		}
		for layer_name: String in texture_layers:
			var layer := stage.get_node_or_null(layer_name) as CanvasItem
			var texture := layer.get("texture") as Texture2D \
					if layer != null else null
			if texture == null \
					or texture.resource_path != texture_layers[layer_name]:
				failures.append("Scene5 %s is not connected" % layer_name)
		var distant_field := stage.get_node_or_null("DistantWheat") as TextureRect
		if distant_field == null or distant_field.texture == null \
				or distant_field.texture.resource_path != DISTANT_FIELD_PATH:
			failures.append("Scene5 farbg distant field is not connected")
		var rays := stage.get_node_or_null("SunRayField") as ColorRect
		var ray_material := rays.material as ShaderMaterial if rays != null else null
		if ray_material == null or ray_material.shader == null \
				or ray_material.shader.resource_path != SUN_RAY_SHADER_PATH:
			failures.append("Scene5 sunlight ray field is not connected")
		elif float(ray_material.get_shader_parameter("ray_width_scale")) < 2.4 \
				or float(ray_material.get_shader_parameter("gate_speed")) < 0.5 \
				or not ray_material.shader.code.contains("slow_gate"):
			failures.append("Scene5 sunlight lacks the Scene4-style gated fan")
		var upper_cloud := stage.get_node_or_null("UpperCloud") as Control
		if upper_cloud == null or upper_cloud.get_child_count() != 1:
			failures.append("Scene5 primary procedural upper cloud is not exclusive")
		else:
			for child: Node in upper_cloud.get_children():
				var band := child as ColorRect
				var material := band.material as ShaderMaterial if band != null else null
				if material == null or material.shader == null \
						or material.shader.resource_path != PIXEL_CLOUD_SHADER_PATH:
					failures.append("Scene5 cloud band is not connected")
					continue
				var flow_speed := float(material.get_shader_parameter("flow_speed"))
				if flow_speed > -0.0025 or flow_speed < -0.0045 \
						or float(material.get_shader_parameter("smooth_flow")) != 0.0 \
						or float(material.get_shader_parameter("motion_blend")) != 1.0 \
						or float(material.get_shader_parameter("lobe_profile")) != 1.0 \
						or float(material.get_shader_parameter("inner_contrast")) != 0.0:
					failures.append("Scene5 cloud band changed shape or moves too quickly")
			var main_band := upper_cloud.get_node_or_null("CloudMain") as ColorRect
			var main_material := main_band.material as ShaderMaterial \
					if main_band != null else null
			if main_band == null or main_band.size != Vector2(2080.0, 300.0) \
					or main_material == null \
					or float(main_material.get_shader_parameter("seed")) != 35.0 \
					or float(main_material.get_shader_parameter("alpha_max")) < 0.32:
				failures.append("Scene5 main cloud does not preserve the original silhouette")
		var wind_field := stage.get_node_or_null("WindField")
		if wind_field == null or wind_field.get_script() == null \
				or wind_field.get_script().resource_path != WIND_SCRIPT_PATH:
			failures.append("Scene5 wind field controller is not connected")
		if stage.has_node("MidWheat"):
			failures.append("Scene5 still contains the rejected alpha-split MidWheat")
		for layer_name: String in [
			"MidFarWheat",
			"FarWheat",
			"FarWheatCoverBack",
			"NearWheatLeft",
		]:
			var wind_layer := stage.get_node_or_null(layer_name) as Control
			var material := wind_layer.material as ShaderMaterial \
					if wind_layer != null else null
			if wind_layer == null or wind_layer.get_script() == null \
					or wind_layer.get_script().resource_path != WHEAT_MESH_SCRIPT_PATH:
				failures.append("Scene5 %s is not a complete wheat mesh" % layer_name)
			if material == null or material.shader == null \
					or material.shader.resource_path != WIND_SHADER_PATH:
				failures.append("Scene5 %s wind material is not connected" % layer_name)
			elif float(material.get_shader_parameter("cluster_count")) < 8.0:
				failures.append("Scene5 %s lacks cluster wind variation" % layer_name)
		var far_material := (
				stage.get_node("FarWheat") as Control
				).material as ShaderMaterial
		var mid_far_wheat := stage.get_node_or_null("MidFarWheat") as Control
		var mid_far_material := mid_far_wheat.material as ShaderMaterial \
				if mid_far_wheat != null else null
		var distant_factor := float(distant_field.get_meta("parallax_factor")) \
				if distant_field != null else 0.0
		var mid_far_factor := float(mid_far_wheat.get_meta("parallax_factor")) \
				if mid_far_wheat != null else 0.0
		var far_factor := float(stage.get_node("FarWheat").get_meta("parallax_factor"))
		if distant_field == null \
				or mid_far_material == null \
				or mid_far_material == far_material \
				or int(mid_far_wheat.get("mesh_columns")) < 80 \
				or int(mid_far_wheat.get("mesh_rows")) < 18 \
				or distant_field.get_index() >= mid_far_wheat.get_index() \
				or mid_far_wheat.get_index() >= stage.get_node("FarWheat").get_index() \
				or distant_factor >= mid_far_factor \
				or mid_far_factor >= far_factor:
			failures.append("Scene5 derived mid-far wheat lacks a true depth slot")
		elif float(mid_far_material.get_shader_parameter("field_wave_speed")) \
				>= float(far_material.get_shader_parameter("field_wave_speed")) \
				or float(mid_far_material.get_shader_parameter("shape_wave_vertical_px")) < 2.0 \
				or float(mid_far_material.get_shader_parameter("shape_wave_vertical_px")) > 3.2 \
				or float(mid_far_material.get_shader_parameter("shape_wave_horizontal_px")) < 1.0 \
				or float(mid_far_material.get_shader_parameter("shape_wave_horizontal_px")) > 2.2 \
				or float(mid_far_material.get_shader_parameter("depth_haze_strength")) \
				<= float(far_material.get_shader_parameter("depth_haze_strength")):
			failures.append("Scene5 derived mid-far wheat is not visually differentiated")
		var cover_back := stage.get_node_or_null("FarWheatCoverBack") as Control
		var cover_back_material := cover_back.material as ShaderMaterial \
				if cover_back != null else null
		if cover_back == null or cover_back_material == null \
				or int(cover_back.get("mesh_columns")) < 88 \
				or int(cover_back.get("mesh_rows")) < 20 \
				or stage.get_node("FarWheat").get_index() >= cover_back.get_index() \
				or cover_back.get_index() >= stage.get_node("MidFieldHaze").get_index():
			failures.append("Scene5 lacks the retained FarWheat back cover layer")
		elif float(cover_back_material.get_shader_parameter("clip_top")) < 0.36:
			failures.append("Scene5 FarWheat back cover lost its authored crop")
		var wind_paths: Array[NodePath] = wind_field.get("wind_layer_paths") \
				if wind_field != null else []
		if not wind_paths.has(NodePath("../FarWheatCoverBack")) \
				or wind_paths.has(NodePath("")):
			failures.append("Scene5 retained FarWheat cover is outside the wind field")
		if float(far_material.get_shader_parameter("field_wave_strength")) < 0.08 \
				or float(far_material.get_shader_parameter("geometry_y_start")) < 0.38:
			failures.append("Scene5 far pixel wheat lacks a source-highlight wave")
		if float(far_material.get_shader_parameter("field_highlight_threshold")) < 0.55 \
				or float(far_material.get_shader_parameter("field_highlight_rest")) != 1.0 \
				or float(far_material.get_shader_parameter("field_highlight_demote")) != 0.0 \
				or float(far_material.get_shader_parameter("field_wave_speed")) > 0.025 \
				or not far_material.shader.code.contains("source_highlight_mask") \
				or not far_material.shader.code.contains("moving_wave_mask"):
			failures.append("Scene5 far pixel wheat does not migrate source highlights")
		if float(far_material.get_shader_parameter("depth_haze_strength")) < 0.1:
			failures.append("Scene5 far/mid wheat lacks depth separation")
		var far_wheat := stage.get_node("FarWheat") as Control
		if int(far_wheat.get("mesh_columns")) < 128 \
				or int(far_wheat.get("mesh_rows")) < 24 \
				or float(far_material.get_shader_parameter("shape_wave_vertical_px")) < 3.5 \
				or float(far_material.get_shader_parameter("shape_wave_horizontal_px")) < 2.0 \
				or not far_material.shader.code.contains("traveling_shape_wave"):
			failures.append("Scene5 far wheat lacks high-density shape waves")
		var distant_material := distant_field.material as ShaderMaterial \
				if distant_field != null else null
		if distant_material == null or distant_material.shader == null \
				or distant_material.shader.resource_path != DISTANT_WHEAT_SHADER_PATH \
				or not distant_material.shader.code.contains("gold_region_mask") \
				or not is_equal_approx(
						float(distant_material.get_shader_parameter("wave_speed")),
						float(far_material.get_shader_parameter("field_wave_speed"))) \
				or not is_equal_approx(
						float(distant_material.get_shader_parameter("wave_phase")),
						float(far_material.get_shader_parameter("field_wave_phase"))) \
				or float(distant_material.get_shader_parameter("light_strength")) < 0.55:
			failures.append("Scene5 distant gold wheat does not share the far wave")
		elif float(distant_material.get_shader_parameter("bottom_edge_trim")) < 0.8 \
				or not distant_material.shader.code.contains("ridge_bottom_edge_mask"):
			failures.append("Scene5 distant wheat still exposes its straight bottom ridge")
		var near_material := (
				stage.get_node("NearWheatLeft") as Control
				).material as ShaderMaterial
		if float(near_material.get_shader_parameter("inertia_mix")) < 0.2:
			failures.append("Scene5 near wheat lacks inertial follow-through")
		if float(near_material.get_shader_parameter("sway_px")) < 5.0 \
				or float(near_material.get_shader_parameter("gust_px")) < 8.0:
			failures.append("Scene5 near wheat response is still too restrained")
		if near_material.shader.code.contains("click_bend"):
			failures.append("Scene5 near wheat still contains removed click bending")
		var click_leaf_names: Array[String] = [
			"ClickLeavesMidFar",
			"ClickLeavesFar",
			"ClickLeavesCover",
		]
		var last_click_factor := 0.0
		var last_click_alpha := 0.0
		var expected_click_amounts: Array[int] = [6, 8, 10]
		for index: int in click_leaf_names.size():
			var leaf_name := click_leaf_names[index]
			var click_particles := stage.get_node_or_null(leaf_name) as CPUParticles2D
			if click_particles == null or not click_particles.one_shot \
					or click_particles.texture == null \
					or click_particles.texture.get_size() != Vector2(6.0, 3.0):
				failures.append("Scene5 %s far streak particles are not connected" % leaf_name)
				continue
			var click_factor := float(click_particles.get_meta("parallax_factor"))
			if click_factor <= last_click_factor \
					or click_particles.amount != expected_click_amounts[index] \
					or click_particles.lifetime > 1.8 \
					or click_particles.fixed_fps != 0 \
					or not click_particles.fract_delta \
					or click_particles.direction.y != -1.0 \
					or click_particles.initial_velocity_max > 34.0 \
					or click_particles.gravity.y < 14.0 \
					or click_particles.emission_shape \
							!= CPUParticles2D.EMISSION_SHAPE_RECTANGLE \
					or click_particles.color.a <= last_click_alpha \
					or click_particles.color.a > 0.62:
				failures.append("Scene5 %s lacks visible depth-matched pixel streaks" % leaf_name)
			last_click_factor = click_factor
			last_click_alpha = click_particles.color.a
		var click_leaf_paths: Array[NodePath] = wind_field.get("click_leaf_paths") \
				if wind_field != null else []
		if click_leaf_paths.size() != 9 \
				or not wind_field.has_signal("far_wheat_clicked") \
				or not wind_field.has_method("try_trigger_at_canvas_position") \
				or wind_field.has_method("trigger_near_click") \
				or not wind_field.has_method("trigger_far_leaves") \
				or not wind_field.has_method("get_streak_group_count") \
				or int(wind_field.call("get_streak_group_count")) != 3 \
				or not is_equal_approx(
						float(wind_field.get("click_repeat_radius_px")), 160.0):
			failures.append("Scene5 click controller is incomplete")
		var wind_source := FileAccess.get_file_as_string(WIND_SCRIPT_PATH)
		if not wind_source.contains("_group_is_active") \
				or not wind_source.contains("click_repeat_radius_px"):
			failures.append("Scene5 far streak pool cannot separate active locations")
		var crop_circle := stage.get_node_or_null("CropCircle")
		var crop_script := crop_circle.get_script() as Script \
				if crop_circle != null else null
		var crop_layer_paths: Array[NodePath] = crop_circle.get(
				"wheat_layer_paths") if crop_circle != null else []
		if crop_circle == null or crop_script == null \
				or crop_script.resource_path != CROP_CIRCLE_SCRIPT_PATH \
				or crop_layer_paths.size() != 3 \
				or int(crop_circle.get("required_clicks")) != 5 \
				or not is_equal_approx(
						float(crop_circle.get("trigger_probability")), 0.08) \
				or not is_equal_approx(
						float(crop_circle.get("achievement_window_sec")), 8.0) \
				or not is_equal_approx(
						float(crop_circle.get("cluster_radius_px")), 320.0) \
				or not is_equal_approx(
						float(crop_circle.get("reveal_duration_sec")), 1.2) \
				or not is_equal_approx(
						float(crop_circle.get("hold_duration_sec")), 4.5) \
				or not is_equal_approx(
						float(crop_circle.get("recover_duration_sec")), 1.5) \
				or not crop_circle.has_method("is_achievement_completed") \
				or not crop_circle.has_method("is_visual_active"):
			failures.append("Scene5 crop-circle achievement contract is incomplete")
		var crop_source := FileAccess.get_file_as_string(CROP_CIRCLE_SCRIPT_PATH)
		if not crop_source.contains("_rng.randf()") \
				or crop_source.contains("cooldown"):
			failures.append("Scene5 crop circle is not a random low-probability secret")
		var crop_depth_scale := 0.0
		for layer_name: String in [
			"MidFarWheat",
			"FarWheat",
			"FarWheatCoverBack",
		]:
			var crop_material := (stage.get_node(layer_name) as CanvasItem).material \
					as ShaderMaterial
			var depth_scale := float(crop_material.get_shader_parameter(
					"crop_circle_depth_scale"))
			var half_size := crop_material.get_shader_parameter(
					"crop_circle_half_size") as Vector2
			if depth_scale <= crop_depth_scale \
					or half_size.x < 0.34 \
					or half_size.y > 0.1 \
					or half_size.x / maxf(half_size.y, 0.001) < 3.5 \
					or float(crop_material.get_shader_parameter(
							"crop_circle_strength")) != 0.0 \
					or float(crop_material.get_shader_parameter(
							"crop_circle_reveal")) != 0.0:
				failures.append(
						"Scene5 crop circle does not span three ordered wheat depths")
			crop_depth_scale = depth_scale
		if not near_material.shader.code.contains("crop_circle_mask") \
				or not near_material.shader.code.contains("crop_circle_uv_offset") \
				or not near_material.shader.code.contains(
						"texture(TEXTURE, crop_source_uv)") \
				or not near_material.shader.code.contains("SCREEN_UV") \
				or near_material.shader.code.contains("pressed_gold"):
			failures.append(
					"Scene5 crop circle is not integrated into the source wheat texture")
		var sky_input := stage.get_node("Sky") as Control
		var platform_input := stage.get_node("BattlePlatform") as Control
		if wind_field.get("click_input_target_path") != NodePath("../Sky") \
				or sky_input.mouse_filter != Control.MOUSE_FILTER_PASS \
				or platform_input.mouse_filter != Control.MOUSE_FILTER_IGNORE \
				or not wind_source.contains("func _on_click_input_gui_input") \
				or wind_source.contains("leaf_tween") \
				or wind_source.contains("func _unhandled_input"):
			failures.append("Scene5 click response bypasses the real GUI input path")
		var ambient := stage.get_node_or_null("AmbientChaff") as GPUParticles2D
		var gust := stage.get_node_or_null("GustChaff") as GPUParticles2D
		for particles: GPUParticles2D in [ambient, gust]:
			if particles == null or particles.texture == null \
					or particles.texture.resource_path != CHAFF_ATLAS_PATH:
				failures.append("Scene5 random chaff atlas is not connected")
				continue
			var atlas_material := particles.material as CanvasItemMaterial
			if atlas_material == null \
					or atlas_material.particles_anim_h_frames != 4 \
					or atlas_material.particles_anim_v_frames != 2:
				failures.append("Scene5 chaff atlas is not configured as 4x2")
		var platform := stage.get_node_or_null("BattlePlatform") as NinePatchRect
		if platform == null or platform.texture == null \
				or platform.texture.resource_path != GROUND_PATH:
			failures.append("Scene5 ground is not connected")
		if stage.has_node("Foreground") or stage.has_node("ForegroundOverlay"):
			failures.append("Scene5 still contains draft foreground placeholders")
		stage.free()

	if ResourceLoader.exists(BATTLE5_PATH):
		var screen := (load(BATTLE5_PATH) as PackedScene).instantiate() as Control
		var stage := screen.get_node_or_null("StageSlot/Stage") as BattleStage
		if stage == null or stage.scene_file_path != SCENE5_PATH:
			failures.append("BattleScreen5 does not statically mount Scene5")
		for node_name: String in ["P1CharDisplay", "P2CharDisplay", "P1Hud", "P2Hud", "Buttons"]:
			var inherited_node := screen.get_node_or_null(node_name)
			if inherited_node == null \
					and node_name.ends_with("CharDisplay"):
				inherited_node = screen.get_node_or_null(
						"WorldGroup/%s" % node_name)
			if inherited_node == null:
				failures.append("missing inherited battle node %s" % node_name)
		var occluder := screen.get_node_or_null(
				"WorldForegroundOccluder") as Control
		var occluder_texture := occluder.get("texture") as Texture2D \
				if occluder != null else null
		if occluder_texture == null \
				or occluder_texture.resource_path != NEAR_WHEAT_PATH:
			failures.append("Scene5 foreground occluder is not connected")
		else:
			var material := occluder.material as ShaderMaterial
			if material == null or material.shader == null \
					or material.shader.resource_path != WIND_SHADER_PATH:
				failures.append("Scene5 foreground occluder shader is not connected")
		for node_name: String in ["P1CharDisplay", "P2CharDisplay"]:
			var character := screen.get_node_or_null(node_name) as CharacterDisplay
			if character == null:
				character = screen.get_node_or_null(
						"WorldGroup/%s" % node_name) as CharacterDisplay
			var sprite := character.get_node_or_null(
					"SubViewport/AnimatedSprite2D") as AnimatedSprite2D \
					if character != null else null
			var material := sprite.material as ShaderMaterial \
					if sprite != null else null
			if character == null or character.rim_strength <= 0.0 \
					or character.rim_strength > 1.0 \
					or character.rim_width > 1.0 \
					or character.warmth_amount > 0.04 \
					or character.fill_amount > 0.04 \
					or material == null or material.shader == null \
					or material.shader.resource_path != CHARACTER_SHADER_PATH \
					or not material.shader.code.contains("luma_preserving_palette") \
					or not material.shader.code.contains("sun_band") \
					or not material.shader.code.contains("shadow_band") \
					or not material.shader.code.contains("idle_envelope") \
					or material.shader.code.contains("stepped_sun_band") \
					or material.shader.code.contains("stepped_shadow_band") \
					or not material.shader.code.contains("rim_palette_target") \
					or not material.shader.code.contains("sky_ambient") \
					or not material.shader.code.contains("field_bounce") \
					or float(material.get_shader_parameter("sun_key_amount")) > 0.2 \
					or float(material.get_shader_parameter("idle_light_amount")) > 0.04:
				failures.append("Scene5 %s lighting is not scene-specific" % node_name)
		if screen.has_method("_base_attack_response_direction"):
			if float(screen.call(
					"_base_attack_response_direction",
					ActionDef.Action.ATTACK,
					ActionDef.Action.BIG_ATTACK)) != -1.0:
				failures.append("P2 big wave does not drive response right-to-left")
		else:
			failures.append("Scene5 battle response direction matrix is missing")
		screen.free()

	if failures.is_empty():
		print("SCENE5_VALIDATION: PASS")
		quit(0)
		return

	for failure: String in failures:
		push_error("SCENE5_VALIDATION: %s" % failure)
	quit(1)
