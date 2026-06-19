class_name ItemSlotRow
extends Control

## 道具栏组件（M2·占位）：横排 3 个槽，按 BattleCore 经济状态刷新。
## "凹陷嵌槽"观感（区别于凸起头像框）= 深色外框 + 内底；无美术期显示"道具名 + 维度色"。
## ⚠ 占位实现：程序化建子节点 + 默认配色/尺寸，待 Eddy 在编辑器定稿后 scene 化 + 换美术。
##   位置由 battle_screen 的 ITEM_ROW_POS_* 常量控制（先猜值，F6 看了再调）。
## 用法：add_child 到 HUD 下 → 每次 _update_all 调 refresh(battle, player)。

const SLOT_W := 88.0
const SLOT_H := 88.0
const GAP := 10.0

## 维度 → 占位底色（取自 battle-ui-color-palette 取向，可调）。
const DIM_COLOR := {
	"进攻": Color("b8402f"), "防御": Color("3f6fb0"), "能量": Color("d2a32a"),
	"节奏": Color("c47f33"), "状态": Color("4f9d52"), "干扰": Color("6f5bb0"),
	"导出": Color("5f8a9a"), "随机": Color("8a8f98"),
}
const FRAME_COL := Color(0.04, 0.04, 0.06, 0.65)
const SEALED_COL := Color(0.10, 0.10, 0.13, 0.85)

var _bgs: Array[ColorRect] = []
var _labels: Array[Label] = []


func _ready() -> void:
	custom_minimum_size = Vector2(SLOT_W * 3 + GAP * 2, SLOT_H)
	for i in range(3):
		var base := Vector2(i * (SLOT_W + GAP), 0.0)
		var frame := ColorRect.new()
		frame.color = FRAME_COL
		frame.position = base
		frame.size = Vector2(SLOT_W, SLOT_H)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(frame)
		var bg := ColorRect.new()
		bg.color = SEALED_COL
		bg.position = base + Vector2(4, 4)
		bg.size = Vector2(SLOT_W - 8, SLOT_H - 8)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		var lbl := Label.new()
		lbl.position = base
		lbl.size = Vector2(SLOT_W, SLOT_H)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lbl)
		_bgs.append(bg)
		_labels.append(lbl)


## 按经济状态刷新 3 个槽。battle 未启用经济（槽空）时安全跳过。
func refresh(battle: BattleCore, player: int) -> void:
	if battle == null or player < 0 or player >= battle.slots.size():
		return
	if battle.slots[player].size() < 3 or _bgs.size() < 3:
		return
	for i in range(3):
		var st: int = battle.slot_state(player, i)
		var bg: ColorRect = _bgs[i]
		var lbl: Label = _labels[i]
		match st:
			BattleCore.SlotState.SEALED:
				bg.color = SEALED_COL
				lbl.text = "+" if battle.turn_number >= int(BattleCore.SLOT_UNLOCK_TURN[i]) else "—"
			BattleCore.SlotState.OPENED:
				bg.color = Color(0.18, 0.16, 0.10, 0.9)
				lbl.text = "抽…" if battle.can_draw_slot(player, i) else "开格"
			BattleCore.SlotState.CHARGING:
				var item: ItemData = battle.slot_item(player, i)
				var nm: String = item.item_name if item != null else ""
				if battle.slot_ready(player, i):
					bg.color = _dim_color(item)
					lbl.text = nm
				else:
					bg.color = Color(0.30, 0.22, 0.08, 0.9)
					lbl.text = nm + "\n(锁)"
			BattleCore.SlotState.EMPTY:
				bg.color = Color(0.12, 0.12, 0.12, 0.8)
				lbl.text = "空"
		lbl.modulate = Color.WHITE


func _dim_color(item: ItemData) -> Color:
	if item == null:
		return SEALED_COL
	return DIM_COLOR.get(item.dimension, Color(0.42, 0.42, 0.47))
