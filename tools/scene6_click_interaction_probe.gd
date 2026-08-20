extends Node

const SCENE6 := preload("res://src/ui/scenes/scene6.tscn")


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	var stage := SCENE6.instantiate() as BattleStage
	add_child(stage)
	await get_tree().process_frame
	await get_tree().process_frame
	var interaction := stage.get_node("ClickInteraction") as Scene6ClickInteraction
	var secrets := stage.get_node("MagmaSecrets") as Scene6MagmaSecrets
	interaction.click_cooldown_sec = 0.0
	secrets.reveal_cooldown_sec = 3.6
	secrets.legend_roll_override = 1.0
	var foreground_point := _find_point(
			interaction, Scene6ClickInteraction.InteractionKind.FOREGROUND_SPARK,
			Rect2(0.0, 300.0, 1920.0, 780.0))
	var magma_left := _find_point(
			interaction, Scene6ClickInteraction.InteractionKind.MAGMA_BUBBLE,
			Rect2(120.0, 834.0, 760.0, 246.0))
	var magma_right := _find_point(
			interaction, Scene6ClickInteraction.InteractionKind.MAGMA_BUBBLE,
			Rect2(1040.0, 834.0, 760.0, 246.0))
	var midground_point := _find_point(
			interaction, Scene6ClickInteraction.InteractionKind.MIDGROUND_SPIT,
			Rect2(0.0, 0.0, 1920.0, 834.0))
	var found_all := foreground_point.x >= 0.0 and magma_left.x >= 0.0 \
			and magma_right.x >= 0.0 and midground_point.x >= 0.0
	if found_all:
		await _push_click(foreground_point)
		await _push_click(magma_left)
		await _push_click(midground_point)
	await get_tree().create_timer(0.12).timeout
	var foreground_count := (stage.get_node("ForegroundClickFX") \
			as Scene6ClickEffectCanvas).active_effect_count()
	var magma_count := (stage.get_node("MagmaClickFX") \
			as Scene6ClickEffectCanvas).active_effect_count()
	var midground_count := (stage.get_node("MidgroundClickFX") \
			as Scene6ClickEffectCanvas).active_effect_count()
	var base_effects_active := foreground_count == 1 and magma_count == 1 \
			and midground_count == 1

	# The first magma click above already counted; three more reveal the hilt.
	if found_all:
		for _index: int in 3:
			await _push_click(magma_left)
	await get_tree().create_timer(0.82).timeout
	var first_positions := secrets.get_active_secret_positions()
	var first_immediate := secrets.get_hilt_spawn_count() == 1 \
			and secrets.active_secret_count() == 1 \
			and first_positions.size() == 1 \
			and first_positions[0].distance_to(magma_left) < 5.0

	# An attempt while occupied becomes only a splash and is never queued.
	if found_all:
		for _index: int in 4:
			await _push_click(magma_right)
	var occupied_suppressed := secrets.get_suppressed_reveal_count() == 1 \
			and secrets.get_tip_spawn_count() == 0 \
			and secrets.active_secret_count() == 1 \
			and secrets.pending_secret_count() == 0 \
			and secrets.active_ripple_count() >= 1

	# The hilt is gone, but the short post-sink cooldown still rejects one rise.
	await get_tree().create_timer(2.35).timeout
	if found_all:
		for _index: int in 4:
			await _push_click(magma_right)
	var cooldown_suppressed := secrets.active_secret_count() == 0 \
			and secrets.get_suppressed_reveal_count() == 2 \
			and secrets.get_tip_spawn_count() == 0 \
			and secrets.pending_secret_count() == 0

	# Once cooldown expires, the next qualified click rises immediately there.
	await get_tree().create_timer(0.65).timeout
	if found_all:
		for _index: int in 4:
			await _push_click(magma_right)
	await get_tree().create_timer(0.80).timeout
	var second_positions := secrets.get_active_secret_positions()
	var tip_immediate := secrets.get_tip_spawn_count() == 1 \
			and secrets.active_secret_count() == 1 \
			and second_positions.size() == 1 \
			and second_positions[0].distance_to(magma_right) < 5.0

	# Let the ordinary tip finish and force the low-probability branch so the
	# probe can verify the generated legendary asset and its restrained FX.
	await get_tree().create_timer(3.15).timeout
	var return_contacts_before_legendary := \
			secrets.get_return_contact_ripple_count()
	var closure_bubbles_before_legendary := \
			secrets.get_closure_bubble_spawn_count()
	secrets.legend_roll_override = 0.0
	var legendary_point := magma_right
	if found_all:
		for _index: int in 4:
			await _push_click(legendary_point)
	var legendary_fx_started := secrets.active_ripple_count() >= 1
	await get_tree().create_timer(2.05).timeout
	var legendary_positions := secrets.get_active_secret_positions()
	var legendary_pocket := secrets.get_node("LegendaryPocketRuntime") as Control
	var legendary_sprite := legendary_pocket.get_child(0) as Sprite2D
	var legendary_matches_ordinary_occlusion := legendary_pocket.get_parent() == secrets \
			and legendary_pocket.z_index == 0 \
			and secrets.get_index() \
					< stage.get_node("BattlePlatform").get_index()
	var legendary_aura := stage.get_node_or_null(
			"LegendaryForgeAuraRuntime") as ColorRect
	var legendary_aura_present := legendary_aura != null
	var legendary_surface_y := legendary_pocket.size.y - 4.0
	var legendary_bottom := legendary_sprite.position.y \
			+ float(legendary_sprite.texture.get_height()) \
					* legendary_sprite.scale.y * 0.5
	var legendary_hovering := legendary_bottom <= legendary_surface_y - 4.0 \
			and legendary_bottom >= legendary_surface_y - 12.0
	var legendary_active := secrets.get_legendary_spawn_count() == 1 \
			and secrets.get_active_kind() \
					== Scene6MagmaSecrets.SecretKind.LEGENDARY_BLADE \
			and secrets.active_secret_count() == 1 \
			and legendary_positions.size() == 1 \
			and legendary_positions[0].distance_to(legendary_point) < 5.0 \
			and legendary_fx_started and legendary_hovering
	RenderingServer.force_draw(false, 0.0)
	var shown_image := get_viewport().get_texture().get_image()
	legendary_pocket.visible = false
	RenderingServer.force_draw(false, 0.0)
	var hidden_image := get_viewport().get_texture().get_image()
	var rendered_pixels := _count_pixel_differences(
			shown_image, hidden_image, Rect2(0.0, 650.0, 1920.0, 430.0))
	legendary_pocket.visible = true

	# Sample during the long aerial hover and isolate the parent draw pass from
	# the sprite to prove the forge atmosphere remains around it without using
	# the old pasted-on gold spokes.
	await get_tree().create_timer(1.25).timeout
	var legendary_still_hovering := secrets.active_secret_count() == 1 \
			and secrets.active_ripple_count() >= 1
	legendary_pocket.visible = false
	RenderingServer.force_draw(false, 0.0)
	var persistent_forge_image := get_viewport().get_texture().get_image()
	secrets.visible = false
	legendary_aura.visible = false
	RenderingServer.force_draw(false, 0.0)
	var no_secret_fx_image := get_viewport().get_texture().get_image()
	var persistent_forge_pixels := _count_pixel_differences(
			persistent_forge_image, no_secret_fx_image,
			Rect2(legendary_point.x - 180.0, 650.0, 360.0, 430.0))
	var aura_edge_pixels := 9999
	if legendary_aura != null:
		var aura_rect := Rect2(legendary_aura.position, legendary_aura.size)
		aura_edge_pixels = _count_pixel_differences(
				persistent_forge_image, no_secret_fx_image,
				Rect2(aura_rect.position, Vector2(aura_rect.size.x, 4.0)))
		aura_edge_pixels += _count_pixel_differences(
				persistent_forge_image, no_secret_fx_image,
				Rect2(aura_rect.position, Vector2(4.0, aura_rect.size.y - 12.0)))
		aura_edge_pixels += _count_pixel_differences(
				persistent_forge_image, no_secret_fx_image,
				Rect2(aura_rect.end.x - 4.0, aura_rect.position.y,
						4.0, aura_rect.size.y - 12.0))
	var forge_bounds := _difference_bounds(
			persistent_forge_image, no_secret_fx_image,
			Rect2(legendary_point.x - 180.0, 650.0, 360.0, 430.0))
	var forge_soft_bounds := _difference_bounds(
			persistent_forge_image, no_secret_fx_image,
			Rect2(legendary_point.x - 180.0, 650.0, 360.0, 430.0), 0.025)
	var surface_gold_pixels := _count_changed_gold_pixels(
			persistent_forge_image, no_secret_fx_image,
			Rect2(legendary_point.x - 84.0,
					legendary_point.y - 18.0, 168.0, 48.0))
	var forge_gold_pixels := _count_changed_gold_pixels(
			persistent_forge_image, no_secret_fx_image,
			Rect2(legendary_point.x - 84.0,
					legendary_point.y - 168.0, 168.0, 196.0))
	var forge_bottom_bounds := _difference_bounds(
			persistent_forge_image, no_secret_fx_image,
			Rect2(legendary_point.x - 120.0,
					legendary_point.y - 56.0, 240.0, 40.0), 0.04)
	var forge_top_bounds := _difference_bounds(
			persistent_forge_image, no_secret_fx_image,
			Rect2(legendary_point.x - 120.0,
					legendary_point.y - 152.0, 240.0, 64.0), 0.04)
	var legendary_blade_width := float(legendary_sprite.texture.get_width()) \
			* legendary_sprite.scale.x
	var forge_opens_upward := forge_top_bounds.size.x \
			>= forge_bottom_bounds.size.x + 20
	var forge_base_clears_blade := forge_bottom_bounds.size.x \
			> legendary_blade_width
	var forge_has_vertical_presence := forge_bounds.size.x >= 48.0 \
			and forge_bounds.size.y >= 112.0
	secrets.visible = true
	legendary_aura.visible = true
	legendary_pocket.visible = true
	# Sample halfway through the sink. The atmosphere must already be fading
	# with the blade instead of remaining at full strength until submersion.
	await get_tree().create_timer(2.85).timeout
	var legendary_sinking := secrets.active_secret_count() == 1
	legendary_pocket.visible = false
	RenderingServer.force_draw(false, 0.0)
	var sinking_forge_image := get_viewport().get_texture().get_image()
	secrets.visible = false
	legendary_aura.visible = false
	RenderingServer.force_draw(false, 0.0)
	var sinking_base_image := get_viewport().get_texture().get_image()
	var sinking_forge_pixels := _count_pixel_differences(
			sinking_forge_image, sinking_base_image,
			Rect2(legendary_point.x - 180.0, 650.0, 360.0, 430.0))
	var forge_fades_while_sinking := sinking_forge_pixels >= 8 \
			and sinking_forge_pixels < persistent_forge_pixels * 0.78
	secrets.visible = true
	legendary_aura.visible = true
	legendary_pocket.visible = true
	await get_tree().create_timer(1.45).timeout
	var legendary_contact_ripple := secrets.active_secret_count() == 0 \
			and secrets.get_return_contact_ripple_count() \
					== return_contacts_before_legendary + 1
	var legendary_closure_bubble := secrets.get_closure_bubble_spawn_count() \
			== closure_bubbles_before_legendary + 1 \
			and secrets.active_closure_bubble_count() == 1

	var passed := found_all and base_effects_active and first_immediate \
			and occupied_suppressed and cooldown_suppressed and tip_immediate \
			and legendary_active and rendered_pixels >= 24 \
			and legendary_still_hovering and persistent_forge_pixels >= 24 \
			and legendary_aura_present and aura_edge_pixels <= 8 \
			and return_contacts_before_legendary == 2 \
			and closure_bubbles_before_legendary == 2 \
			and surface_gold_pixels <= 96 and forge_has_vertical_presence \
			and forge_opens_upward and forge_base_clears_blade \
			and legendary_sinking and forge_fades_while_sinking \
			and legendary_contact_ripple and legendary_closure_bubble \
			and legendary_matches_ordinary_occlusion
	print("SCENE6_CLICK_INTERACTION_PROBE: ", "PASS" if passed else "FAIL",
			" hilt=", first_immediate,
			" occupied_splash=", occupied_suppressed,
			" cooldown_splash=", cooldown_suppressed,
			" tip=", tip_immediate,
			" legendary=", legendary_active,
			" legend_count=", secrets.get_legendary_spawn_count(),
			" active_kind=", secrets.get_active_kind(),
			" active_count=", secrets.active_secret_count(),
			" legend_positions=", legendary_positions,
			" legend_target=", legendary_point,
			" pending=", secrets.pending_secret_count(),
			" rendered_pixels=", rendered_pixels,
			" persistent_forge_pixels=", persistent_forge_pixels,
			" aura_present=", legendary_aura_present,
			" aura_edge_pixels=", aura_edge_pixels,
			" surface_gold_pixels=", surface_gold_pixels,
			" forge_gold_pixels=", forge_gold_pixels,
			" forge_bounds=", forge_bounds,
			" forge_soft_bounds=", forge_soft_bounds,
			" forge_bottom_bounds=", forge_bottom_bounds,
			" forge_top_bounds=", forge_top_bounds,
			" forge_opens_upward=", forge_opens_upward,
			" blade_width=", legendary_blade_width,
			" forge_base_clears_blade=", forge_base_clears_blade,
			" forge_vertical=", forge_has_vertical_presence,
			" sinking_forge_pixels=", sinking_forge_pixels,
			" forge_fades_while_sinking=", forge_fades_while_sinking,
			" hovering=", legendary_hovering,
			" return_contacts_before_legendary=", return_contacts_before_legendary,
			" closure_bubbles_before_legendary=", closure_bubbles_before_legendary,
			" contact_ripple=", legendary_contact_ripple,
			" closure_bubble=", legendary_closure_bubble,
			" ordinary_occlusion_layer=", legendary_matches_ordinary_occlusion,
			" natural_point=", legendary_point)
	stage.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if passed else 1)


func _push_click(point: Vector2) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = point
	click.global_position = point
	get_window().push_input(click)
	await get_tree().process_frame


func _find_point(
		interaction: Scene6ClickInteraction,
		interaction_kind: int,
		search_rect: Rect2
) -> Vector2:
	var start := Vector2i(search_rect.position)
	var end := Vector2i(search_rect.end)
	for y: int in range(start.y, end.y, 4):
		for x: int in range(start.x, end.x, 4):
			var point := Vector2(x, y)
			if interaction.get_interaction_kind_at_canvas_position(point) \
					== interaction_kind:
				return point
	return Vector2(-1.0, -1.0)


func _count_pixel_differences(
		first: Image,
		second: Image,
		region: Rect2
) -> int:
	if first == null or second == null or first.is_empty() or second.is_empty():
		return 0
	var clipped := region.intersection(Rect2(Vector2.ZERO, first.get_size()))
	var count := 0
	for y: int in range(int(clipped.position.y), int(clipped.end.y)):
		for x: int in range(int(clipped.position.x), int(clipped.end.x)):
			var first_color := first.get_pixel(x, y)
			var second_color := second.get_pixel(x, y)
			if absf(first_color.r - second_color.r) \
					+ absf(first_color.g - second_color.g) \
					+ absf(first_color.b - second_color.b) \
					+ absf(first_color.a - second_color.a) >= 0.08:
				count += 1
	return count


func _count_changed_gold_pixels(
		first: Image,
		second: Image,
		region: Rect2
) -> int:
	if first == null or second == null or first.is_empty() or second.is_empty():
		return 0
	var clipped := region.intersection(Rect2(Vector2.ZERO, first.get_size()))
	var count := 0
	for y: int in range(int(clipped.position.y), int(clipped.end.y)):
		for x: int in range(int(clipped.position.x), int(clipped.end.x)):
			var forge_color := first.get_pixel(x, y)
			var base_color := second.get_pixel(x, y)
			var difference := absf(forge_color.r - base_color.r) \
					+ absf(forge_color.g - base_color.g) \
					+ absf(forge_color.b - base_color.b)
			if difference >= 0.08 and forge_color.r >= 0.72 \
					and forge_color.g >= 0.34 \
					and forge_color.b <= 0.22:
				count += 1
	return count


func _difference_bounds(
		first: Image,
		second: Image,
		region: Rect2,
		threshold: float = 0.08
) -> Rect2i:
	if first == null or second == null or first.is_empty() or second.is_empty():
		return Rect2i()
	var clipped := region.intersection(Rect2(Vector2.ZERO, first.get_size()))
	var minimum := Vector2i(int(clipped.end.x), int(clipped.end.y))
	var maximum := Vector2i(int(clipped.position.x) - 1,
			int(clipped.position.y) - 1)
	for y: int in range(int(clipped.position.y), int(clipped.end.y)):
		for x: int in range(int(clipped.position.x), int(clipped.end.x)):
			var first_color := first.get_pixel(x, y)
			var second_color := second.get_pixel(x, y)
			var difference := absf(first_color.r - second_color.r) \
					+ absf(first_color.g - second_color.g) \
					+ absf(first_color.b - second_color.b) \
					+ absf(first_color.a - second_color.a)
			if difference < threshold:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)
