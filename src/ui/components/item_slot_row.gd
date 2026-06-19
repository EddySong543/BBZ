class_name ItemSlotRow
extends Control

## 道具栏组件（M2 显示 + M3 交互 + C 升级）：横排 3 个槽，按 BattleCore 经济状态刷新。
## interactive=true 时（P1 本地玩家）每槽可点击 → 发 slot_clicked(槽位)，由 battle_screen 分派
## 开格 / 抽 / 使用 / refill；interactive=false 时（P2·AI 道具-blind）仅显示、不吃点击。
## 像素框风格 = 完全照搬 HeroFrame（canvas_ui_pixel_frame 暖骨边 + 圆角 + round_mask 圆角填充）；
##   ready/暂存 = 边框本身转金（非另加 ring）。⚠ 位置/尺寸仍占位（ITEM_ROW_POS_*），待 F6 + 美术。
## 用法：add_child → interactive/connect（仅 P1）→ 每次 _update_all 调 refresh(battle, player, staged)。

signal slot_clicked(slot: int)
signal slot_upgrade_clicked(slot: int)   # 点击就绪可升级槽右上角「升」角标（C·升级线）

const SLOT_W := 88.0
const SLOT_H := 88.0
const GAP := 10.0

## 维度 → 填充底色（取自 battle-ui-color-palette 取向，可调）。
const DIM_COLOR := {
	"进攻": Color("b8402f"), "防御": Color("3f6fb0"), "能量": Color("d2a32a"),
	"节奏": Color("c47f33"), "状态": Color("4f9d52"), "干扰": Color("6f5bb0"),
	"导出": Color("5f8a9a"), "随机": Color("8a8f98"),
}
const SEALED_COL := Color(0.11, 0.10, 0.09, 1.0)   # 近黑暖底（同 HeroFrame fill）

## 像素边框 = HeroFrame 同款「暖骨边」（B 典籍朱印·已铺 menu/bp/battle）：高明度低饱和暖中性 → 清晰可见。
const PIXEL_FRAME_SHADER := preload("res://assets/shaders/canvas_ui_pixel_frame.gdshader")
const ROUND_MASK_SHADER := preload("res://assets/shaders/canvas_ui_round_mask.gdshader")
const EDGE_OUTER := Color(0.05, 0.045, 0.04)   # 近黑暖细描边
const EDGE_MID := Color(0.70, 0.64, 0.52)      # 暖骨色（边框主色·可见）
const EDGE_INNER := Color(0.42, 0.36, 0.26)    # 暖中性内线
const READY_MID := Color("dcc060")             # 本回合可用 → 边框转暖金
const STAGED_MID := Color("f2e08a")            # 已点选使用 → 边框转亮金
const PIXEL_GRID := 24.0                       # 同 HeroFrame（~3-4px/格）
const CORNER_RADIUS := 0.25                    # 同 HeroFrame 圆角

## interactive：本地玩家行可点击。setter 立即把按钮 mouse_filter 设为 STOP；P2（false）→ IGNORE。
var interactive := false:
	set(v):
		interactive = v
		for b in _buttons:
			b.mouse_filter = Control.MOUSE_FILTER_STOP if v else Control.MOUSE_FILTER_IGNORE

var _bgs: Array[ColorRect] = []
var _labels: Array[Label] = []
var _frame_mats: Array[ShaderMaterial] = []   # 每槽边框材质（refresh 调 edge_mid 做 ready/暂存金边）
var _buttons: Array[Button] = []
var _upgrade_btns: Array[Button] = []          # 每槽右上角「升」角标，仅就绪可升级时显示（C）


## 造像素边框 ShaderMaterial（道具框 / draft 卡共用）。grid 越大格越细。
static func make_pixel_frame_material(grid := PIXEL_GRID, corner := CORNER_RADIUS, aspect := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PIXEL_FRAME_SHADER
	m.set_shader_parameter("edge_outer", EDGE_OUTER)
	m.set_shader_parameter("edge_mid", EDGE_MID)
	m.set_shader_parameter("edge_inner", EDGE_INNER)
	m.set_shader_parameter("pixel_grid", grid)
	m.set_shader_parameter("border_px", 2.0)
	m.set_shader_parameter("noise_amt", 0.06)
	m.set_shader_parameter("corner_radius", corner)
	m.set_shader_parameter("aspect", aspect)
	return m


## 造圆角遮罩材质（给填充层切同款圆角·防方角戳出圆框）。
static func make_round_mask_material(grid := PIXEL_GRID, corner := CORNER_RADIUS) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ROUND_MASK_SHADER
	m.set_shader_parameter("corner_radius", corner)
	m.set_shader_parameter("pixel_grid", grid)
	return m


func _ready() -> void:
	custom_minimum_size = Vector2(SLOT_W * 3 + GAP * 2, SLOT_H)
	# 根容器不拦截点击：只让每个槽的按钮(STOP)接收。否则容器自身(默认 STOP)会吞掉点击
	#（尤其 P1/P2 两排叠同位置时，上层容器抢先吃掉点击）。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(3):
		var base := Vector2(i * (SLOT_W + GAP), 0.0)
		# 填充层（状态色·refresh 重染）在底 + 圆角遮罩；像素边框层在其上（中心透明露出填充）。
		var bg := ColorRect.new()
		bg.color = SEALED_COL
		bg.position = base
		bg.size = Vector2(SLOT_W, SLOT_H)
		bg.material = make_round_mask_material()
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		var frame := ColorRect.new()
		frame.color = Color.WHITE   # shader 乘 COLOR，须白
		frame.position = base
		frame.size = Vector2(SLOT_W, SLOT_H)
		var fmat := make_pixel_frame_material()
		frame.material = fmat
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(frame)
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
		btn.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
		btn.pressed.connect(_on_slot_pressed.bind(i))
		add_child(btn)
		# 升级角标（右上角小钮·铺在点击层之上 → 角落点击=升级、槽身=使用）。默认隐藏，refresh 控显。
		var up := Button.new()
		up.text = "升"
		up.focus_mode = Control.FOCUS_NONE
		up.position = base + Vector2(SLOT_W - 30.0, 2.0)
		up.size = Vector2(28.0, 24.0)
		up.add_theme_font_size_override("font_size", 12)
		up.visible = false
		up.pressed.connect(_on_upgrade_pressed.bind(i))
		add_child(up)
		_bgs.append(bg)
		_frame_mats.append(fmat)
		_labels.append(lbl)
		_buttons.append(btn)
		_upgrade_btns.append(up)


func _on_slot_pressed(slot: int) -> void:
	if interactive:
		slot_clicked.emit(slot)


func _on_upgrade_pressed(slot: int) -> void:
	if interactive:
		slot_upgrade_clicked.emit(slot)


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
		var ready := false   # 本回合是否「有可操作动作」（决定边框转金）
		match st:
			BattleCore.SlotState.SEALED:
				bg.color = SEALED_COL
				if battle.turn_number >= int(BattleCore.SLOT_UNLOCK_TURN[i]):
					lbl.text = "可开"
					ready = battle.can_open_slot(player, i)
				else:
					lbl.text = "—"
			BattleCore.SlotState.OPENED:
				bg.color = Color(0.18, 0.16, 0.10, 1.0)
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
					bg.color = Color(0.30, 0.22, 0.08, 1.0)
					lbl.text = nm + "\n(锁)"
			BattleCore.SlotState.EMPTY:
				bg.color = Color(0.12, 0.12, 0.12, 1.0)
				if battle.can_refill(player, i):
					lbl.text = "可补"
					ready = true
				else:
					lbl.text = "空"
		lbl.modulate = Color.WHITE
		# 边框转金：已点选使用=亮金 / 本回合可操作(仅 interactive)=暖金 / 否则=暖骨。
		var accent := EDGE_MID
		if staged.has(i):
			accent = STAGED_MID
		elif interactive and ready:
			accent = READY_MID
		_frame_mats[i].set_shader_parameter("edge_mid", accent)
		# 升级角标：仅本地玩家行 + 该槽可升级（就绪 + 有 upgrade_to + 能量够）时显示。
		_upgrade_btns[i].visible = interactive and battle.can_upgrade(player, i)


func _dim_color(item: ItemData) -> Color:
	if item == null:
		return SEALED_COL
	return DIM_COLOR.get(item.dimension, Color(0.42, 0.42, 0.47))
