class_name ItemFrameStyle
extends RefCounted

## 图鉴 / 战斗道具栏 / 道具三选一共用的唯一道具框视觉配置。
## 手动调色只改此文件：字典键 1/2/3 分别是普通/稀有/传说。

const FRAME_TEXTURE := preload("res://assets/ui/item_frame.png")
const CELL_SHADER := preload("res://assets/shaders/canvas_ui_item_cell_bg.gdshader")
const FRAME_SHADER := preload("res://assets/shaders/canvas_ui_item_frame_palette.gdshader")
const ItemCatalogScript := preload("res://src/battle/item_catalog.gd")

# 方案 2：三档统一使用高识别完整纵向渐变；框体只做同色相的明暗分层，不压成暗底。
const CELL_TOP := {
	1: ItemCatalogScript.RARITY_NORMAL,
	2: ItemCatalogScript.RARITY_RARE,
	3: ItemCatalogScript.RARITY_LEGENDARY,
}
const CELL_BOTTOM := {
	1: Color("#65A0E3"),
	2: Color("#9870D1"),
	3: Color("#E5B349"),
}
const FRAME_SHADOW := {
	1: Color("#2E639E"), 2: Color("#56358A"), 3: Color("#9F6818"),
}
const FRAME_MID := {
	1: Color("#356DB2"), 2: Color("#623DA1"), 3: Color("#AD741B"),
}
const FRAME_HIGHLIGHT := {
	1: Color("#9BC7EF"), 2: Color("#C3A5E4"), 3: Color("#F3D077"),
}

const DROP_SHADOW_OFFSET := Vector2(2.0, 4.0)
const DROP_SHADOW_COLOR := Color(0.02, 0.012, 0.008, 0.34)
const ITEM_ART_SHADOW_OFFSET := Vector2(2.0, 3.0)
const ITEM_ART_SHADOW_COLOR := Color(0.02, 0.012, 0.008, 0.38)
# 正式素材本身承担默认朝向；框内展示不得再追加装饰性旋转。
# 背包中玩家实际旋转物件时，仍由 item_grid_art_layout 单独跟随占格方向旋转。
const ITEM_ART_ROTATION := 0.0
const ITEM_ART_FILL_RATIO := 0.88
const ITEM_ALPHA_THRESHOLD := 0.04
const STAT_BADGE_INSET_RATIO := 0.10

const FRAME_ART_SCALE := 87.25 / 68.0
const FRAME_OFFSET_RATIO := Vector2(-9.6 / 68.0, -10.0 / 68.0)
const CELL_INSET_RATIO := 5.5 / 68.0

static var _alpha_bounds_cache: Dictionary = {}


static func make_frame_material(tier: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FRAME_SHADER
	apply_frame_palette(material, tier)
	return material


static func apply_frame_palette(material: ShaderMaterial, tier: int) -> void:
	var key := clampi(tier, 1, 3)
	material.set_shader_parameter("shadow_color", FRAME_SHADOW[key])
	material.set_shader_parameter("mid_color", FRAME_MID[key])
	material.set_shader_parameter("highlight_color", FRAME_HIGHLIGHT[key])


static func make_cell_material(tier: int, pixel_grid: float,
		corner_radius: float = 0.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CELL_SHADER
	apply_cell_palette(material, tier)
	material.set_shader_parameter("corner_radius", corner_radius)
	material.set_shader_parameter("pixel_grid", pixel_grid)
	return material


static func make_shadow_material(color: Color = DROP_SHADOW_COLOR) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FRAME_SHADER
	var opaque_color := Color(color.r, color.g, color.b, 1.0)
	material.set_shader_parameter("shadow_color", opaque_color)
	material.set_shader_parameter("mid_color", opaque_color)
	material.set_shader_parameter("highlight_color", opaque_color)
	return material


static func make_frame_shadow(frame_position: Vector2, frame_size: Vector2,
		node_name: String = "BottomShadow", offset: Vector2 = DROP_SHADOW_OFFSET,
		color: Color = DROP_SHADOW_COLOR) -> TextureRect:
	var shadow := TextureRect.new()
	shadow.name = node_name
	shadow.texture = FRAME_TEXTURE
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	shadow.position = frame_position + offset
	shadow.size = frame_size
	shadow.material = make_shadow_material(color)
	shadow.self_modulate = Color(1.0, 1.0, 1.0, color.a)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return shadow


## 道具图案投影与框体投影分层：它只复制图案 alpha，位于格底之上、金属框之下。
## 大图最多放大到 2 倍偏移，避免图鉴详情页出现悬浮过高的长投影。
static func item_art_shadow_offset(art_size: Vector2) -> Vector2:
	var scale_factor := clampf(minf(art_size.x, art_size.y) / 64.0, 1.0, 2.0)
	return (ITEM_ART_SHADOW_OFFSET * scale_factor).round()


static func make_item_art_shadow(texture: Texture2D, art_position: Vector2,
		art_size: Vector2, node_name: String = "ItemArtShadow") -> TextureRect:
	var shadow := TextureRect.new()
	shadow.name = node_name
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	shadow.self_modulate = ITEM_ART_SHADOW_COLOR
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	configure_item_art(shadow, texture, Rect2(art_position, art_size),
		item_art_shadow_offset(art_size))
	return shadow


## 用纹理真实 alpha 轮廓做光学归一化：透明留白不参与尺寸，可见包围盒始终留在框内。
## 所有“道具框内”美术都必须走此入口；背包格仍由实际占格方向单独处理。
static func configure_item_art(node: TextureRect, texture: Texture2D,
		target_rect: Rect2, optical_offset: Vector2 = Vector2.ZERO) -> void:
	configure_texture_visual(
		node, texture, target_rect, ITEM_ART_ROTATION, ITEM_ART_FILL_RATIO, optical_offset)
	node.set_meta("item_art_target_rect", target_rect)


## 通用的 alpha 光学布局。IconBadge 以 rotation=0 复用它，使来源尺寸不同的图标具有同一可见尺度。
static func configure_texture_visual(node: TextureRect, texture: Texture2D,
		target_rect: Rect2, visual_rotation: float = 0.0, fill_ratio: float = 1.0,
		optical_offset: Vector2 = Vector2.ZERO) -> void:
	node.texture = texture
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 0.0
	node.anchor_bottom = 0.0
	if texture == null or target_rect.size.x <= 0.0 or target_rect.size.y <= 0.0:
		node.position = target_rect.position + optical_offset
		node.size = target_rect.size
		node.pivot_offset = target_rect.size * 0.5
		node.rotation = visual_rotation
		node.set_meta("visible_alpha_rect", Rect2(node.position, Vector2.ZERO))
		return
	var alpha_bounds: Rect2 = texture_alpha_bounds(texture)
	var c := absf(cos(visual_rotation))
	var s := absf(sin(visual_rotation))
	var rotated_size := Vector2(
		alpha_bounds.size.x * c + alpha_bounds.size.y * s,
		alpha_bounds.size.x * s + alpha_bounds.size.y * c)
	var scale_factor := minf(
		target_rect.size.x / maxf(rotated_size.x, 1.0),
		target_rect.size.y / maxf(rotated_size.y, 1.0)) * clampf(fill_ratio, 0.05, 1.0)
	var texture_size := texture.get_size()
	var node_size := texture_size * scale_factor
	var visible_pivot := (alpha_bounds.position + alpha_bounds.size * 0.5) * scale_factor
	var visible_size := rotated_size * scale_factor
	var visible_center := target_rect.get_center() + optical_offset
	node.position = visible_center - visible_pivot
	node.size = node_size
	node.pivot_offset = visible_pivot
	node.rotation = visual_rotation
	node.set_meta("visible_alpha_rect", Rect2(visible_center - visible_size * 0.5, visible_size))
	node.set_meta("source_alpha_bounds", alpha_bounds)


static func texture_alpha_bounds(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()
	var cache_key := "%s:%d:%dx%d" % [
		texture.resource_path, texture.get_instance_id(), texture.get_width(), texture.get_height()]
	if _alpha_bounds_cache.has(cache_key):
		return _alpha_bounds_cache[cache_key]
	var fallback := Rect2(Vector2.ZERO, texture.get_size())
	var image := texture.get_image()
	if image == null or image.is_empty():
		_alpha_bounds_cache[cache_key] = fallback
		return fallback
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a < ITEM_ALPHA_THRESHOLD:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	var result := fallback
	if maximum.x >= minimum.x and maximum.y >= minimum.y:
		result = Rect2(Vector2(minimum), Vector2(maximum - minimum + Vector2i.ONE))
	_alpha_bounds_cache[cache_key] = result
	return result


## 费用 / 耐久固定贴在同一外框的左右上角，中心轴严格对称且不再漂到框外。
static func stat_badge_positions(frame_rect: Rect2, badge_size: Vector2) -> Dictionary:
	var inset := badge_size * STAT_BADGE_INSET_RATIO
	return {
		"cost": frame_rect.position + inset,
		"durability": Vector2(
			frame_rect.end.x - badge_size.x - inset.x,
			frame_rect.position.y + inset.y),
	}


static func apply_cell_palette(material: ShaderMaterial, tier: int, tint_multiplier: Color = Color.WHITE) -> void:
	var key := clampi(tier, 1, 3)
	material.set_shader_parameter("fill_color", CELL_TOP.get(key, CELL_TOP[1]) * tint_multiplier)
	material.set_shader_parameter("inner_color", CELL_BOTTOM.get(key, CELL_BOTTOM[1]) * tint_multiplier)
	material.set_shader_parameter("center_glow", 1.0)
	material.set_shader_parameter("vertical_gradient", 1.0)
	material.set_shader_parameter("material_lighting", 0.0)
	material.set_shader_parameter("cloud_on", 0.0)
	material.set_shader_parameter("use_tex", 0.0)
	material.set_shader_parameter("tex_top_darkening", 0.0)
