@tool
extends Control

## 临时 Buff 调整场景只负责把真实 BattleStatusRow 固定在预览中心。
## 所有可调参数都在子节点 BuffPreview 的 Inspector 中，正式战斗不依赖本脚本。

@export var preview_center := Vector2(960.0, 540.0)

@onready var _buff_preview: Control = $BuffPreview


func _ready() -> void:
	set_process(true)
	_center_preview()


func _process(_delta: float) -> void:
	_center_preview()


func _center_preview() -> void:
	if not is_instance_valid(_buff_preview):
		return
	var icon_center_x := float(_buff_preview.call("icon_alignment_center_x"))
	_buff_preview.position = Vector2(
			preview_center.x - icon_center_x,
			preview_center.y - _buff_preview.size.y * 0.5).round()
