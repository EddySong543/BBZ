class_name ItemSlotRow
extends Control

## 道具栏组件（M2 显示 + M3 交互）：横排 3 个槽，按 BattleCore 经济状态刷新。
## interactive=true 时（P1 本地玩家）每槽可点击 → 发 slot_clicked(槽位)，由 battle_screen 分派
## 开格 / 抽 / 使用 / refill；interactive=false 时（P2·AI 道具-blind）仅显示、不吃点击。
## "凹陷嵌槽"观感（区别于凸起头像框）= 深色外框 + 内底；无美术期显示"道具名 + 维度色"。
## ⚠ 占位实现：程序化建子节点 + 默认配色/尺寸，待 Eddy 在编辑器定稿后 scene 化 + 换美术。
##   位置由 battle_screen 的 ITEM_ROW_POS_* 常量控制（先猜值，F6 看了再调）。
## 用法：add_child 到 HUD 下 → interactive/connect（仅 P1）→ 每次 _update_all 调 refresh(battle, player, staged)。

signal slot_clicked(slot: int)

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
const READY_RING := Color("dcc060")   # 本回合可用/可操作提示边（暖金）
const STAGED_RING := Color("f2e08a")  # 已点选「本回合使用」高亮边（亮金）

## interactive：本地玩家行可点击。setter 立即把按钮 mouse_filter 设为 STOP（匹配 HeroFrame 的
## 无条件模式·去掉 refresh 时序依赖）；P2（false）→ IGNORE，不吃点击。
var interactive := false:
	set(v):
		interactive = v
		for b in _buttons:
			b.mouse_filter = Control.MOUSE_FILTER_STOP if v else Control.MOUSE_FILTER_IGNORE

var _bgs: Array[ColorRect] = []
var _labels: Array[Label] = []
var _rings: Array[ColorRect] = []     # 槽位提示外环（ready/staged），平时隐藏
var _buttons: Array[Button] = []


func _ready() -> void:
	custom_minimum_size = Vector2(SLOT_W * 3 + GAP * 2, SLOT_H)
	# 根容器不拦截点击：只让每个槽的按钮(STOP)接收。否则容器自身(默认 STOP)会吞掉点击——
	# 尤其 P1/P2 两排叠同位置时，上层(P2)容器抢先吃掉点击 → P1 按钮永远收不到。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(3):
		var base := Vector2(i * (SLOT_W + GAP), 0.0)
		# 提示外环（最底层，比框大 3px → 显为描边；平时隐藏）。
		var ring := ColorRect.new()
		ring.color = READY_RING
		ring.position = base - Vector2(3, 3)
		ring.size = Vector2(SLOT_W + 6, SLOT_H + 6)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.visible = false
		add_child(ring)
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
		# 点击层（透明 flat 按钮，铺满整格）：仅 interactive 时吃点击。
		var btn := Button.new()
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.position = base
		btn.size = Vector2(SLOT_W, SLOT_H)
		# 按 interactive 当前值定（setter 在 _ready 前已被赋值时此处生效；P2 默认 IGNORE）。
		btn.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
		btn.pressed.connect(_on_slot_pressed.bind(i))
		add_child(btn)
		_rings.append(ring)
		_bgs.append(bg)
		_labels.append(lbl)
		_buttons.append(btn)


func _on_slot_pressed(slot: int) -> void:
	if interactive:
		slot_clicked.emit(slot)


## 按经济状态刷新 3 个槽。battle 未启用经济（槽空）时安全跳过。
## staged：本回合已点选「使用」的槽位（仅 P1 传入；用于金边高亮）。
func refresh(battle: BattleCore, player: int, staged: Array = []) -> void:
	if battle == null or player < 0 or player >= battle.slots.size():
		return
	if battle.slots[player].size() < 3 or _bgs.size() < 3:
		return
	for i in range(3):
		var st: int = battle.slot_state(player, i)
		var bg: ColorRect = _bgs[i]
		var lbl: Label = _labels[i]
		var ring: ColorRect = _rings[i]
		var ready := false   # 本回合是否「有可操作动作」（决定 ready 提示边）
		match st:
			BattleCore.SlotState.SEALED:
				bg.color = SEALED_COL
				if battle.turn_number >= int(BattleCore.SLOT_UNLOCK_TURN[i]):
					lbl.text = "可开"
					ready = battle.can_open_slot(player, i)
				else:
					lbl.text = "—"
			BattleCore.SlotState.OPENED:
				bg.color = Color(0.18, 0.16, 0.10, 0.9)
				if battle.can_draw_slot(player, i):
					lbl.text = "可抽"
					ready = true
				else:
					lbl.text = "开格\n(锁)"
			BattleCore.SlotState.CHARGING:
				var item: ItemData = battle.slot_item(player, i)
				var nm: String = item.item_name if item != null else ""
				if battle.slot_ready(player, i):
					bg.color = _dim_color(item)
					lbl.text = nm + "\n✓用" if staged.has(i) else nm
					ready = true
				else:
					bg.color = Color(0.30, 0.22, 0.08, 0.9)
					lbl.text = nm + "\n(锁)"
			BattleCore.SlotState.EMPTY:
				bg.color = Color(0.12, 0.12, 0.12, 0.8)
				if battle.can_refill(player, i):
					lbl.text = "可补"
					ready = true
				else:
					lbl.text = "空"
		lbl.modulate = Color.WHITE
		# 提示外环：已点选使用 = 亮金边；否则本回合可操作 = 暖金边（仅 interactive）。
		if staged.has(i):
			ring.color = STAGED_RING
			ring.visible = true
		elif interactive and ready:
			ring.color = READY_RING
			ring.visible = true
		else:
			ring.visible = false
		# 点击层 mouse_filter 由 interactive setter / _ready 统一管理（无 refresh 时序依赖）。


func _dim_color(item: ItemData) -> Color:
	if item == null:
		return SEALED_COL
	return DIM_COLOR.get(item.dimension, Color(0.42, 0.42, 0.47))
