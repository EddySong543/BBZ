extends SceneTree

const EffectTextFormatterScript := preload("res://src/ui/effect_text_formatter.gd")

var _codex_script: Script
var _effect_catalog: Script


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_codex_script = load("res://src/ui/codex_screen.gd") as Script
	_effect_catalog = load("res://src/battle/effect_catalog.gd") as Script
	var packed := load("res://src/ui/codex_screen.tscn") as PackedScene
	if packed == null:
		_fail("unified codex scene could not be loaded")
		return
	var codex := packed.instantiate() as Control
	root.add_child(codex)
	await process_frame
	var effect_bookmark := codex.get_node("BookmarkLayer/EffectBookmark") as Button
	var item_bookmark := codex.get_node("BookmarkLayer/ItemBookmark") as Button
	var rarity := codex.get_node("BookmarkLayer/RarityBookmarks") as Control
	if not is_equal_approx(
			effect_bookmark.position.y - item_bookmark.get_rect().end.y, 6.0):
		_fail("effect bookmark rest gap is invalid: %.2f" % effect_bookmark.position.y)
		return
	codex.call("show_section", _codex_script.Section.ITEM)
	await process_frame
	if not is_equal_approx(effect_bookmark.position.y - rarity.get_rect().end.y, 6.0):
		_fail("effect bookmark did not clear rarity tabs: %.2f" % effect_bookmark.position.y)
		return
	codex.call("show_section", _codex_script.Section.EFFECT)
	await create_timer(0.22).timeout
	var gallery := codex.call("get_gallery", _codex_script.Section.EFFECT) as Control
	var native_layer := codex.get_node("NativeTextLayer") as Control
	native_layer.call("sync_now")
	if not gallery.visible or rarity.visible:
		_fail("effect chapter visibility contract failed")
		return
	if int(native_layer.call("mirror_count")) < 9:
		_fail("effect chapter native text mirrors are incomplete: %d" % int(native_layer.call("mirror_count")))
		return
	var effect_list := gallery.get_node("EffectList") as Control
	if effect_list.get_child_count() != (_effect_catalog.call("all") as Array).size():
		_fail("effect entry count mismatch")
		return
	var first_row_left := effect_list.position.x + 24.0
	var first_row_right := effect_list.position.x + 377.0 + 310.0
	if absf((first_row_left + first_row_right) * 0.5 - 493.0) > 0.5:
		_fail("effect list is not centered on left page")
		return
	var effect_wash := gallery.get_node("DetailArea/EffectIconWash") as TextureRect
	var effect_icon := gallery.get_node("DetailArea/EffectIcon") as TextureRect
	if effect_wash.texture == null \
			or effect_wash.texture.resource_path != \
			"res://assets/ui/hero_codex_portrait_wash.png" \
			or absf(effect_wash.get_rect().get_center().x \
			- effect_icon.get_rect().get_center().x) > 0.01:
		_fail("effect icon wash carrier contract failed")
		return
	var detail_name := gallery.get_node("DetailArea/EffectName") as Label
	var second := effect_list.get_child(1) as Button
	second.mouse_entered.emit()
	await process_frame
	if detail_name.text != "附加效果":
		_fail("hover changed detail page: %s" % detail_name.text)
		return
	for button_node: Node in effect_list.get_children():
		var button := button_node as Button
		if not button.text.is_empty():
			_fail("effect entry still uses Button.text: %s" % button.name)
			return
		var icon := button.get_node("Icon") as TextureRect
		var name_label := button.get_node("NameLabel") as Label
		var mirror := native_layer.call("mirror_for_source", name_label) as Label
		if mirror == null:
			_fail("missing native label mirror: %s" % button.name)
			return
		if not icon.texture is AtlasTexture:
			_fail("icon was not normalized to visible bounds: %s" % button.name)
			return
		if _canvas_rect(icon).end.x + 8.0 > _canvas_rect(mirror).position.x:
			_fail("icon and final native text overlap: %s" % button.name)
			return
	var first := effect_list.get_child(0) as Button
	if not (first.get_node("SelectionPointer") as Control).visible \
			or first.get_node_or_null("SelectionBar") != null:
		_fail("effect selection language does not match hero/item gallery")
		return
	var effect_mirror_count := int(native_layer.call("mirror_count"))
	codex.call("show_section", _codex_script.Section.HERO)
	await create_timer(0.22).timeout
	var hero_gallery := codex.call("get_gallery", _codex_script.Section.HERO) as Control
	hero_gallery.call("_select", 5)
	await process_frame
	native_layer.call("sync_now")
	var skill_detail := hero_gallery.find_child("SkillDetail", true, false) as Label
	if skill_detail.text.contains("毒素：") or not skill_detail.text.contains("1层毒素"):
		_fail("hero effect glossary was not reduced: %s" % skill_detail.text)
		return
	var keyword_labels := hero_gallery.get("_d_keyword_labels") as Array
	if keyword_labels.size() != 1 or (keyword_labels[0] as Label).text != "毒素":
		_fail("hero effect keyword segment mismatch")
		return
	var detail_segments := hero_gallery.get("_d_detail_segment_labels") as Array
	var reconstructed := ""
	var final_line_ends: Dictionary = {}
	for segment_variant: Variant in detail_segments:
		var segment := segment_variant as Label
		reconstructed += segment.text
		var segment_mirror := native_layer.call("mirror_for_source", segment) as Label
		if segment_mirror != null:
			var mirror_font := segment_mirror.get_theme_font("font")
			var mirror_size := segment_mirror.get_theme_font_size("font_size")
			var advance := mirror_font.get_string_size(segment_mirror.text,
					HORIZONTAL_ALIGNMENT_LEFT, -1.0, mirror_size).x
			var line_id := String(segment.get_meta(EffectTextFormatterScript.META_LINE_ID))
			if final_line_ends.has(line_id) \
					and segment_mirror.position.x < float(final_line_ends[line_id]):
				_fail("native effect text runs overlap at %s" % segment.text)
				return
			final_line_ends[line_id] = segment_mirror.position.x + advance
	if skill_detail.visible or reconstructed != skill_detail.text:
		_fail("hero detail was not rebuilt from exclusive text segments")
		return
	var keyword := keyword_labels[0] as Label
	var keyword_mirror := native_layer.call("mirror_for_source", keyword) as Label
	if keyword_mirror == null or not (keyword_mirror.get_theme_font("font") is FontVariation):
		_fail("hero effect keyword did not enter native text layer")
		return
	if not is_equal_approx(
			(keyword_mirror.get_theme_font("font") as FontVariation).variation_embolden,
			0.8):
		_fail("hero effect keyword does not match effect gallery weight")
		return
	print("CODEX_EFFECT_PROBE_OK entries=%d rest_y=%.2f item_y=%.2f mirrors=%d" % [
		effect_list.get_child_count(),
		_codex_script.EFFECT_BOOKMARK_REST_Y,
		_codex_script.EFFECT_BOOKMARK_ITEM_Y,
		effect_mirror_count,
	])
	codex.queue_free()
	await process_frame
	quit(0)


func _canvas_rect(control: Control) -> Rect2:
	var transform := control.get_global_transform_with_canvas()
	var top_left := transform * Vector2.ZERO
	var bottom_right := transform * control.size
	return Rect2(top_left.min(bottom_right), (bottom_right - top_left).abs())


func _fail(message: String) -> void:
	push_error("CODEX_EFFECT_PROBE_FAIL %s" % message)
	quit(1)
