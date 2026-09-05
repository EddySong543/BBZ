@tool
class_name ItemFrameTuning
extends Resource

## 图鉴左/右页、战斗道具栏与行动顺序共用的唯一几何源。
## 数值逐项来自 item_frame_tuning_lab 的 262px 静态模板；正式界面只改变整体比例。

@export_group("Reference Layout (262 px)")
@export_range(1.0, 512.0, 1.0, "suffix:px") var reference_slot_size := 262.0
@export var frame_offset := Vector2(-36.98824, -38.52942)
@export var frame_size := Vector2(336.16912, 336.16910)
@export var frame_shadow_offset := Vector2(-32.98824, -30.52942)
@export var frame_shadow_size := Vector2(336.16912, 336.16910)
@export var cell_offset := Vector2(23.09632, 21.55515)
@export var cell_size := Vector2(216.0, 216.0)

@export_group("Item Art")
@export var item_art_offset := Vector2(46.61632, 45.07515)
@export var item_art_size := Vector2(168.96, 168.96)
@export var item_art_shadow_offset := Vector2(50.61632, 51.07515)
@export var item_art_shadow_size := Vector2(168.96, 168.96)
@export_range(0.1, 1.0, 0.01) var item_art_fill_ratio := 1.0
@export var item_art_optical_offset := Vector2.ZERO

@export_group("Stat Badge Root")
## 临时场景根节点是 70px，并以 2.5 倍显示；正式界面继续缩放整个节点，
## 避免不同字号重新栅格化后破坏用户在调参台看到的字形比例。
@export var badge_local_size := Vector2(70.0, 70.0)
@export var badge_reference_scale := Vector2(2.5, 2.5)
@export var energy_badge_position := Vector2(-74.0, -77.0)
@export var durability_badge_position := Vector2(173.0, -87.0)

@export_group("Energy Badge Children")
@export var energy_icon_rect := Rect2(0.0, 0.0, 70.0, 70.0)
@export var energy_number_rect := Rect2(0.39999998, 2.3999999, 70.0, 70.0)

@export_group("Durability Badge Children")
@export var durability_icon_rect := Rect2(15.0, 25.0, 30.0, 29.0)
@export var durability_number_rect := Rect2(-5.0, 5.0, 70.0, 70.0)

@export_group("Stat Number Style")
@export_range(1, 96, 1) var stat_font_size := 16
@export_range(0, 24, 1) var stat_outline_size := 5
@export_range(0.0, 2.0, 0.1) var stat_embolden := 0.7

@export_group("Seal")
## 调参台按用户要求不含封条；正式战斗锁定封条独立使用同一母版中心坐标。
@export var seal_center := Vector2(131.0, 131.0)
@export var seal_offset := Vector2.ZERO
@export var seal_size := Vector2(169.52942, 50.08824)
@export_range(-1.0, 1.0, 0.01, "radians") var seal_rotation := -0.30

@export_group("Surface Sizes")
@export_range(16.0, 320.0, 1.0, "suffix:px") var gallery_left_slot_size := 104.0
@export_range(32.0, 512.0, 1.0, "suffix:px") var gallery_right_slot_size := 262.0
@export_range(16.0, 160.0, 1.0, "suffix:px") var battle_slot_size := 68.0
@export_range(16.0, 160.0, 0.001, "suffix:px") var sequence_slot_size := 57.67335


func profile_slot_size(profile: StringName) -> float:
	match profile:
		&"gallery_right":
			return gallery_right_slot_size
		&"battle":
			return battle_slot_size
		&"sequence":
			return sequence_slot_size
		_:
			return gallery_left_slot_size


func layout(profile: StringName, slot_origin: Vector2 = Vector2.ZERO,
		slot_size_override: float = -1.0) -> Dictionary:
	var slot_side := slot_size_override if slot_size_override > 0.0 \
			else profile_slot_size(profile)
	var scale_factor := slot_side / maxf(reference_slot_size, 1.0)
	var badge_scale := badge_reference_scale * scale_factor
	return {
		"profile": profile,
		"scale": scale_factor,
		"slot_rect": Rect2(slot_origin, Vector2.ONE * slot_side),
		"frame_rect": Rect2(slot_origin + frame_offset * scale_factor,
			frame_size * scale_factor),
		"frame_shadow_rect": Rect2(slot_origin + frame_shadow_offset * scale_factor,
			frame_shadow_size * scale_factor),
		"cell_rect": Rect2(slot_origin + cell_offset * scale_factor,
			cell_size * scale_factor),
		"item_art_rect": Rect2(slot_origin + item_art_offset * scale_factor,
			item_art_size * scale_factor),
		"item_art_shadow_rect": Rect2(
			slot_origin + item_art_shadow_offset * scale_factor,
			item_art_shadow_size * scale_factor),
		"badge_size": badge_local_size,
		"badge_scale": badge_scale,
		"cost_position": slot_origin + energy_badge_position * scale_factor,
		"durability_position": slot_origin + durability_badge_position * scale_factor,
		"energy_icon_rect": energy_icon_rect,
		"energy_number_rect": energy_number_rect,
		"durability_icon_rect": durability_icon_rect,
		"durability_number_rect": durability_number_rect,
		"font_size": stat_font_size,
		"outline_size": stat_outline_size,
		"embolden": stat_embolden,
		"seal_center": slot_origin + (seal_center + seal_offset) * scale_factor,
		"seal_size": seal_size * scale_factor,
		"seal_rotation": seal_rotation,
	}
