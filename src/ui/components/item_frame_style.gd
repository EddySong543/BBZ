class_name ItemFrameStyle
extends RefCounted

## 图鉴 / 战斗道具栏 / 道具三选一共用的唯一道具框视觉配置。
## 手动调色只改此文件：字典键 1/2/3 分别是普通/稀有/传说。

const FRAME_TEXTURE := preload("res://assets/ui/item_frame.png")
const CELL_SHADER := preload("res://assets/shaders/canvas_ui_item_cell_bg.gdshader")
const FRAME_SHADER := preload("res://assets/shaders/canvas_ui_item_frame_palette.gdshader")
const LEGENDARY_TEXTURE := preload("res://assets/ui/gold_bottom.png")

const CELL_TOP := {1: Color("#6E9BD2"), 2: Color("#9A7FD0")}
const CELL_BOTTOM := {1: Color("#88AEDE"), 2: Color("#B098E0")}
const FRAME_SHADOW := {
	1: Color("#102C4A"), 2: Color("#2A1246"), 3: Color("#4A2F08"),
}
const FRAME_MID := {
	1: Color("#4A86C2"), 2: Color("#8050BC"), 3: Color("#C78F27"),
}
const FRAME_HIGHLIGHT := {
	1: Color("#B9D9F2"), 2: Color("#D6B1F2"), 3: Color("#F7DE9A"),
}

const DROP_SHADOW_OFFSET := Vector2(2.0, 4.0)
const DROP_SHADOW_COLOR := Color(0.02, 0.012, 0.008, 0.34)
const ITEM_ART_SHADOW_OFFSET := Vector2(2.0, 3.0)
const ITEM_ART_SHADOW_COLOR := Color(0.02, 0.012, 0.008, 0.38)

const LEGENDARY_TINT := Color.WHITE
const LEGENDARY_TOP_DARKENING := 0.18
const FRAME_ART_SCALE := 87.25 / 68.0
const FRAME_OFFSET_RATIO := Vector2(-9.6 / 68.0, -10.0 / 68.0)
const CELL_INSET_RATIO := 5.5 / 68.0


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
	shadow.texture = texture
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shadow.position = art_position + item_art_shadow_offset(art_size)
	shadow.size = art_size
	shadow.self_modulate = ITEM_ART_SHADOW_COLOR
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return shadow


static func apply_cell_palette(material: ShaderMaterial, tier: int, tint_multiplier: Color = Color.WHITE) -> void:
	var key := clampi(tier, 1, 3)
	var legendary := key == 3
	material.set_shader_parameter("fill_color", CELL_TOP.get(key, CELL_TOP[1]) * tint_multiplier)
	material.set_shader_parameter("inner_color", CELL_BOTTOM.get(key, CELL_BOTTOM[1]) * tint_multiplier)
	material.set_shader_parameter("center_glow", 1.0)
	material.set_shader_parameter("vertical_gradient", 0.0 if legendary else 1.0)
	material.set_shader_parameter("material_lighting", 0.0)
	material.set_shader_parameter("cloud_on", 0.0)
	material.set_shader_parameter("use_tex", 1.0 if legendary else 0.0)
	material.set_shader_parameter("tex_tint", LEGENDARY_TINT * tint_multiplier)
	material.set_shader_parameter("tex_top_darkening",
			LEGENDARY_TOP_DARKENING if legendary else 0.0)
	if legendary:
		material.set_shader_parameter("bg_tex", LEGENDARY_TEXTURE)
