class_name CloneArea
extends Control

## 分身显示 placeholder — 3 个槽位（最多 1 个本体 + 2 个假身，shuffle 后顺序由 BattleCore 决定）。
## 默认全部 visible=false；通过 set_state(...) 更新。
## 用户点击某 slot 时发出 target_clicked 信号。

@export_enum("P1:0", "P2:1") var player: int = 0

const CLONE_W := 50.0
const CLONE_GAP := 5.0

signal target_clicked(display_pos: int)

@onready var _slots: Array[ColorRect] = [$Slot0, $Slot1, $Slot2]
@onready var _hp_labels: Array[Label] = [$Slot0Hp, $Slot1Hp, $Slot2Hp]


func _ready() -> void:
	for i in range(_slots.size()):
		var captured := i
		_slots[i].gui_input.connect(_on_slot_input.bind(captured))
		_slots[i].mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slots[i].visible = false
		_hp_labels[i].visible = false
		FontManager.apply(_hp_labels[i], 12)
		_hp_labels[i].add_theme_color_override("font_color", Color("#ff6666"))


## 更新分身显示。
## - order: 长度 0~3，每项是 0/1/2（1=本体，0/2=分身索引）
## - clone_hps: 长度最多 2（最多 2 个分身的 HP）
## - active_hp: 本体当前 HP
func set_state(order: Array, clone_hps: Array, active_hp: int) -> void:
	if not is_node_ready():
		return
	var n: int = order.size()
	if n == 0:
		for i in range(_slots.size()):
			_slots[i].visible = false
			_hp_labels[i].visible = false
		return
	var base_color := Color("#3388dd") if player == 0 else Color("#dd3333")
	var total_w: float = n * CLONE_W + (n - 1) * CLONE_GAP
	var start_x: float = -total_w / 2.0
	for display_pos in range(_slots.size()):
		if display_pos >= n:
			_slots[display_pos].visible = false
			_hp_labels[display_pos].visible = false
			continue
		_slots[display_pos].visible = true
		_hp_labels[display_pos].visible = true
		_slots[display_pos].position.x = start_x + display_pos * (CLONE_W + CLONE_GAP)
		_hp_labels[display_pos].position.x = start_x + display_pos * (CLONE_W + CLONE_GAP)
		var actual: int = order[display_pos]
		if actual == 1:
			_slots[display_pos].color = base_color
			_hp_labels[display_pos].text = "❤%d" % active_hp
		else:
			_slots[display_pos].color = Color("#555555")
			var ci: int = 0 if actual == 0 else 1
			var chp: int = clone_hps[ci] if ci < clone_hps.size() else 0
			_hp_labels[display_pos].text = "❤%d" % chp


## 启用/禁用目标点击模式（攻击选目标时启用）。
func set_target_mode(enabled: bool) -> void:
	if not is_node_ready():
		return
	var filter := Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for s in _slots:
		s.mouse_filter = filter


func _on_slot_input(event: InputEvent, display_pos: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var ev := event as InputEventMouseButton
	if not ev.pressed or ev.button_index != MOUSE_BUTTON_LEFT:
		return
	target_clicked.emit(display_pos)
