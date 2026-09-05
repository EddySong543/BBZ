extends GutTest

const LAB_PATH := "res://src/ui/debug/item_frame_tuning_lab.tscn"
const TUNING_PATH := "res://src/ui/components/item_frame_tuning.tres"
const EDITABLE_NODE_PATHS: Array[String] = [
	"FrameDropShadow",
	"BackgroundCell",
	"ItemArtShadow",
	"Frame",
	"ItemArt",
	"EnergyBadge",
	"EnergyBadge/EnergyIcon",
	"EnergyBadge/EnergyNumberBox",
	"DurabilityBadge",
	"DurabilityBadge/DurabilityIcon",
	"DurabilityBadge/DurabilityNumberBox",
]


func test_lab_is_one_static_independent_item_frame() -> void:
	var packed := load(LAB_PATH) as PackedScene
	assert_not_null(packed)
	var lab := packed.instantiate() as Control
	add_child_autofree(lab)
	await get_tree().process_frame
	var template := lab.get_node("ItemFrameTemplate") as Control
	assert_not_null(template)
	assert_eq(template.size, Vector2(262.0, 262.0))
	for path: String in EDITABLE_NODE_PATHS:
		var editable_node := template.get_node_or_null(path) as Control
		assert_not_null(editable_node,
			"%s 必须是场景树中可直接选择的 Control 节点" % path)
	assert_null(template.find_child("Seal", true, false), "临时基准框不包含封条")
	assert_null(lab.get_script(), "临时场景不应靠工具脚本生成或覆盖节点几何")


func test_lab_scene_has_no_formal_tuning_or_runtime_component_dependency() -> void:
	var source := FileAccess.get_file_as_string(LAB_PATH)
	assert_false(source.contains("item_frame_tuning.tres"),
		"临时模板不得绑定正式排版配置")
	assert_false(source.contains("item_frame_view.gd"),
		"临时模板不得实例化正式运行组件")
	assert_false(source.contains("item_frame_tuning_inspector.gd"),
		"临时模板不得使用配置代理替代可拖动节点")
	assert_false(source.contains("seal"), "临时模板源码不应包含封条节点或参数")


func test_manual_node_edits_do_not_change_formal_layout_resource() -> void:
	var tuning := load(TUNING_PATH) as ItemFrameTuning
	var before := tuning.layout(&"gallery_right")
	var lab := (load(LAB_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(lab)
	await get_tree().process_frame
	var template := lab.get_node("ItemFrameTemplate") as Control
	var energy := template.get_node("EnergyBadge") as Control
	var energy_number := template.get_node("EnergyBadge/EnergyNumberBox") as Label
	var item_art := template.get_node("ItemArt") as TextureRect
	energy.position += Vector2(7.0, 9.0)
	energy_number.size += Vector2(4.0, 3.0)
	item_art.position += Vector2(-5.0, 2.0)
	item_art.size += Vector2(8.0, -6.0)
	var after := tuning.layout(&"gallery_right")
	assert_eq(after["frame_rect"], before["frame_rect"])
	assert_eq(after["item_art_rect"], before["item_art_rect"])
	assert_eq(after["cost_position"], before["cost_position"])
	assert_eq(after["durability_position"], before["durability_position"])


func test_saved_manual_composition_is_preserved_without_symmetry_assumptions() -> void:
	var lab := (load(LAB_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(lab)
	await get_tree().process_frame
	var template := lab.get_node("ItemFrameTemplate") as Control
	var frame := template.get_node("Frame") as TextureRect
	var cell := template.get_node("BackgroundCell") as ColorRect
	var item_art := template.get_node("ItemArt") as TextureRect
	var energy := template.get_node("EnergyBadge") as Control
	var durability := template.get_node("DurabilityBadge") as Control
	var energy_icon := template.get_node("EnergyBadge/EnergyIcon") as TextureRect
	var durability_icon := template.get_node(
		"DurabilityBadge/DurabilityIcon") as TextureRect
	var energy_number := template.get_node("EnergyBadge/EnergyNumberBox") as Label
	var durability_number := template.get_node(
		"DurabilityBadge/DurabilityNumberBox") as Label
	_assert_rect_approx(frame.get_rect(), Rect2(-36.98824, -38.52942, 336.16912, 336.16910))
	_assert_rect_approx(cell.get_rect(), Rect2(23.09632, 21.55515, 216.0, 216.0))
	_assert_rect_approx(item_art.get_rect(), Rect2(46.61632, 45.07515, 168.96, 168.96))
	_assert_vec_approx(energy.position, Vector2(-74.0, -77.0))
	_assert_vec_approx(durability.position, Vector2(173.0, -87.0))
	_assert_vec_approx(energy.scale, Vector2(2.5, 2.5))
	_assert_vec_approx(durability.scale, Vector2(2.5, 2.5))
	_assert_rect_approx(energy_icon.get_rect(), Rect2(0.0, 0.0, 70.0, 70.0))
	_assert_rect_approx(durability_icon.get_rect(), Rect2(15.0, 25.0, 30.0, 29.0))
	_assert_rect_approx(energy_number.get_rect(),
		Rect2(0.39999998, 2.3999999, 70.0, 70.0))
	_assert_rect_approx(durability_number.get_rect(), Rect2(-5.0, 5.0, 70.0, 70.0))
	for number_box: Label in [energy_number, durability_number]:
		assert_eq(number_box.get_theme_font_size("font_size"), 16)
		assert_eq(number_box.get_theme_constant("outline_size"), 5)


func test_formal_tuning_is_an_exact_scaled_copy_of_the_saved_lab() -> void:
	var lab := (load(LAB_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(lab)
	await get_tree().process_frame
	var template := lab.get_node("ItemFrameTemplate") as Control
	var tuning := load(TUNING_PATH) as ItemFrameTuning
	var frame := template.get_node("Frame") as Control
	var frame_shadow := template.get_node("FrameDropShadow") as Control
	var cell := template.get_node("BackgroundCell") as Control
	var item_art := template.get_node("ItemArt") as Control
	var item_shadow := template.get_node("ItemArtShadow") as Control
	var energy := template.get_node("EnergyBadge") as Control
	var durability := template.get_node("DurabilityBadge") as Control
	var energy_icon := template.get_node("EnergyBadge/EnergyIcon") as Control
	var durability_icon := template.get_node("DurabilityBadge/DurabilityIcon") as Control
	var energy_number := template.get_node("EnergyBadge/EnergyNumberBox") as Label
	var durability_number := template.get_node("DurabilityBadge/DurabilityNumberBox") as Label
	for profile: StringName in [&"gallery_left", &"gallery_right", &"battle", &"sequence"]:
		var layout := tuning.layout(profile)
		var factor: float = layout["scale"]
		_assert_rect_approx(layout["frame_rect"], _scaled_rect(frame.get_rect(), factor))
		_assert_rect_approx(layout["frame_shadow_rect"],
			_scaled_rect(frame_shadow.get_rect(), factor))
		_assert_rect_approx(layout["cell_rect"], _scaled_rect(cell.get_rect(), factor))
		_assert_rect_approx(layout["item_art_rect"],
			_scaled_rect(item_art.get_rect(), factor))
		_assert_rect_approx(layout["item_art_shadow_rect"],
			_scaled_rect(item_shadow.get_rect(), factor))
		_assert_vec_approx(layout["cost_position"], energy.position * factor)
		_assert_vec_approx(layout["durability_position"], durability.position * factor)
		_assert_vec_approx(layout["badge_size"], energy.size)
		_assert_vec_approx(layout["badge_scale"], energy.scale * factor)
		_assert_rect_approx(layout["energy_icon_rect"], energy_icon.get_rect())
		_assert_rect_approx(layout["durability_icon_rect"], durability_icon.get_rect())
		_assert_rect_approx(layout["energy_number_rect"], energy_number.get_rect())
		_assert_rect_approx(layout["durability_number_rect"], durability_number.get_rect())
		assert_eq(layout["font_size"], 16)
		assert_eq(layout["outline_size"], 5)


func test_formal_gallery_and_battle_row_consume_the_shared_layout() -> void:
	var gallery := (load("res://src/ui/item_gallery_screen.tscn") as PackedScene).instantiate()
	add_child_autofree(gallery)
	await get_tree().process_frame
	var card := gallery._cards[0] as Button
	var left_layout := ItemFrameStyle.item_frame_layout(
		&"gallery_left", Vector2.ZERO, gallery._grid_box_size())
	assert_eq((card.get_node("Frame") as TextureRect).get_rect(), left_layout["frame_rect"])
	assert_eq((card.get_node("Cell") as ColorRect).get_rect(), left_layout["cell_rect"])
	_assert_badge_matches_layout(card.get_node("UseCostBadge") as IconBadge,
		&"energy", left_layout)
	_assert_badge_matches_layout(card.get_node("DurabilityBadge") as IconBadge,
		&"durability", left_layout)

	# 右页不持有第二套坐标：从正式框反推唯一 origin 后，框、图案与两个角标
	# 必须完整命中同一个 262px master layout。
	var detail_frame := gallery.get_node("DetailArea/DetailFrame") as TextureRect
	var right_master := ItemFrameStyle.item_frame_layout(&"gallery_right")
	var detail_origin: Vector2 = detail_frame.position \
		- (right_master["frame_rect"] as Rect2).position
	var right_layout := ItemFrameStyle.item_frame_layout(&"gallery_right", detail_origin)
	_assert_rect_approx(detail_frame.get_rect(), right_layout["frame_rect"])
	_assert_rect_approx(
		(gallery.get_node("DetailArea/DetailCell") as ColorRect).get_rect(),
		right_layout["cell_rect"])
	var detail_icon := gallery.get_node("DetailArea/ItemIcon") as TextureRect
	_assert_rect_approx(detail_icon.get_meta("visible_alpha_rect"),
		right_layout["item_art_rect"])
	_assert_badge_matches_layout(
		gallery.get_node("DetailArea/UseCostBadge") as IconBadge,
		&"energy", right_layout)
	_assert_badge_matches_layout(
		gallery.get_node("DetailArea/DurabilityBadge") as IconBadge,
		&"durability", right_layout)
	assert_almost_eq(float(right_layout["scale"]), 1.0, 0.000001,
		"右页必须是262px master的1:1输出，不得另写一套排版")
	assert_almost_eq(float(left_layout["scale"]),
		gallery._grid_box_size() / 262.0, 0.000001,
		"左页只能由同一个262px master整体等比缩小")

	var row := ItemSlotRow.new()
	add_child_autofree(row)
	await get_tree().process_frame
	var battle_layout := ItemFrameStyle.item_frame_layout(
		&"battle", Vector2.ZERO, ItemSlotRow.SLOT_W)
	assert_eq((row._tex_frames[0] as TextureRect).get_rect(), battle_layout["frame_rect"])
	assert_eq((row._cells[0] as ColorRect).get_rect(), battle_layout["cell_rect"])
	_assert_badge_matches_layout(row._cost_badges[0] as IconBadge,
		&"energy", battle_layout)
	_assert_badge_matches_layout(row._durability_badges[0] as IconBadge,
		&"durability", battle_layout)


func test_template_uses_real_item_frame_item_and_stat_textures() -> void:
	var lab := (load(LAB_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(lab)
	await get_tree().process_frame
	var template := lab.get_node("ItemFrameTemplate") as Control
	var frame := template.get_node("Frame") as TextureRect
	var item_art := template.get_node("ItemArt") as TextureRect
	var energy_icon := template.get_node("EnergyBadge/EnergyIcon") as TextureRect
	var durability_icon := template.get_node(
		"DurabilityBadge/DurabilityIcon") as TextureRect
	assert_eq(frame.texture.resource_path, "res://assets/ui/item_frame.png")
	assert_true(item_art.texture is AtlasTexture)
	assert_eq((item_art.texture as AtlasTexture).atlas.resource_path,
		"res://assets/sprites/items/v2/生锈的飞镖.png")
	assert_true(energy_icon.texture is AtlasTexture)
	assert_eq((energy_icon.texture as AtlasTexture).atlas.resource_path,
		"res://assets/ui/icons/energy_idle.png")
	assert_eq(durability_icon.texture.resource_path,
		"res://assets/ui/icons/item_durability.png")


func _assert_badge_matches_layout(badge: IconBadge, kind: StringName,
		layout: Dictionary) -> void:
	var durability := kind == &"durability"
	_assert_vec_approx(badge.position,
		layout["durability_position"] if durability else layout["cost_position"])
	_assert_vec_approx(badge.size, layout["badge_size"])
	_assert_vec_approx(badge.scale, layout["badge_scale"])
	var icon := badge.get_node("Icon") as TextureRect
	var number_box := badge.get_node("Num") as Label
	_assert_rect_approx(icon.get_rect(), layout[
		"durability_icon_rect" if durability else "energy_icon_rect"])
	_assert_rect_approx(number_box.get_rect(), layout[
		"durability_number_rect" if durability else "energy_number_rect"])
	assert_eq(number_box.get_theme_font_size("font_size"), int(layout["font_size"]))
	assert_eq(number_box.get_theme_constant("outline_size"), int(layout["outline_size"]))


func _scaled_rect(rect: Rect2, factor: float) -> Rect2:
	return Rect2(rect.position * factor, rect.size * factor)


func _assert_vec_approx(actual: Vector2, expected: Vector2,
		tolerance: float = 0.001) -> void:
	assert_almost_eq(actual.x, expected.x, tolerance)
	assert_almost_eq(actual.y, expected.y, tolerance)


func _assert_rect_approx(actual: Rect2, expected: Rect2,
		tolerance: float = 0.001) -> void:
	_assert_vec_approx(actual.position, expected.position, tolerance)
	_assert_vec_approx(actual.size, expected.size, tolerance)
