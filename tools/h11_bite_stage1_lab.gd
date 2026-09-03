extends Control

const SHEET_PATH := "res://assets/effects/h11_bite/h11_bite_stage1_sheet.png"
const CELL_SIZE := Vector2i(208, 208)


func _ready() -> void:
	set_meta("formal_battle_integration", false)
	var sheet: Texture2D = load(SHEET_PATH) as Texture2D
	if sheet == null:
		push_error("H11 stage1 sheet is missing: %s" % SHEET_PATH)
		return
	_assign_frame($OpenFrame as TextureRect, sheet, 0)
	_assign_frame($ClosedFrame as TextureRect, sheet, 1)


func _assign_frame(target: TextureRect, sheet: Texture2D,
		frame_index: int) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(frame_index * CELL_SIZE.x, 0, CELL_SIZE.x, CELL_SIZE.y)
	target.texture = atlas
	target.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
