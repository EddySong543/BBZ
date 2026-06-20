class_name ItemSlotRow
extends Control

## 道具栏组件（M2 显示 + M3 交互 + C 升级 + 配色重审 2026-06-20）：横排 3 个圆角 jelly 芯片。
## 芯片 = 复用动作按钮同款 canvas_button_jelly（圆角果冻·像素质感），按【状态/维度】分色、与按钮同色语言：
##   安静默认（锁=灰 / 空=暗格）→ 就绪点亮（维度色满铺：进攻红/防御蓝… + 金色高光边 + 升角标）。
##   原则「框安静、内容响」。interactive=true（P1）每槽可点击发 slot_clicked；false（P2·AI 道具-blind）仅显示、不点亮。
## ⚠ 行位置由 battle_screen 控（P1 贴左 / P2 镜像右贴）；道具名为占位文字，待换图标。
## 用法：add_child → interactive/connect（仅 P1）→ 每次 _update_all 调 refresh(battle, player, staged)。

signal slot_clicked(slot: int)
signal slot_upgrade_clicked(slot: int)   # 点击就绪可升级槽右上角「升」角标（C·升级线）

const SLOT_W := 64.0   # 道具芯片：略小于头像框（出战80/替补76）→ 仍从属于英雄（2026-06-20 整体放大一档）
const SLOT_H := 64.0
const GAP := 8.0

## 维度 → 芯片底色（与动作按钮 / draft 卡 / 飘字同源的语义色板）。
const DIM_COLOR := {
	"进攻": Color("b8402f"), "防御": Color("3f6fb0"), "能量": Color("d2a32a"),
	"节奏": Color("c47f33"), "状态": Color("4f9d52"), "干扰": Color("6f5bb0"),
	"导出": Color("5f8a9a"), "随机": Color("8a8f98"),
}

## jelly 芯片（与 battle_screen 动作按钮同款 shader → 统一 UI 语言）。
const JELLY_SHADER := preload("res://assets/shaders/canvas_button_jelly.gdshader")
const CHIP_CORNER := 0.22                       # 圆角（同动作按钮·非锐角）
const EDGE_OUTER := Color(0.10, 0.09, 0.11)     # 统一暗轮廓（中性·任何色相都干净·场景无关）
const GOLD_READY := Color("ffd86a")             # 道具本回合可用（interactive）→ 亮金高光边
const GOLD_STAGED := Color("fff0a0")            # 已点选使用 → 更亮金边
const GOLD_OPEN := Color("d8b85a")              # 可开 / 可抽 / 可补 → 提示金边（较暗·次级）
# 中性态填充（锁 / 待操作 / 空格）：
const SEAL_FT := Color(0.31, 0.31, 0.34)
const SEAL_FB := Color(0.20, 0.20, 0.23)
const SEAL_EI := Color(0.37, 0.37, 0.40)
const NEU_FT := Color(0.34, 0.32, 0.29)
const NEU_FB := Color(0.23, 0.21, 0.18)
const NEU_EI := Color(0.42, 0.40, 0.34)
const EMP_FT := Color(0.14, 0.14, 0.16)
const EMP_FB := Color(0.09, 0.09, 0.11)
const EMP_EI := Color(0.23, 0.23, 0.26)

## interactive：本地玩家行可点击。setter 立即把按钮 mouse_filter 设为 STOP；P2（false）→ IGNORE。
var interactive := false:
	set(v):
		interactive = v
		for b in _buttons:
			b.mouse_filter = Control.MOUSE_FILTER_STOP if v else Control.MOUSE_FILTER_IGNORE

const ICON_INSET := 6.0                          # 图标内缩（露出芯片边框/状态色）

var _chips: Array[ColorRect] = []
var _chip_mats: Array[ShaderMaterial] = []   # 每槽 jelly 材质（refresh 重设 fill/edge 做状态/维度色）
var _icons: Array[TextureRect] = []            # 道具图标层（缺图隐藏 → 回退文字·零回归）
var _icon_cache := {}                          # id → Texture2D / null（避免每帧 load/exists）
var _labels: Array[Label] = []
var _buttons: Array[Button] = []
var _upgrade_btns: Array[Button] = []          # 每槽右上角「升」金角标，仅就绪可升级时显示（C）


## 造 jelly 芯片材质（颜色每次 refresh 重设 fill_top/fill_bottom/edge_inner）。
func _make_chip_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = JELLY_SHADER
	m.set_shader_parameter("edge_outer", EDGE_OUTER)
	m.set_shader_parameter("fill_alpha", 1.0)
	m.set_shader_parameter("pixel_grid", 30.0)
	m.set_shader_parameter("corner", CHIP_CORNER)
	m.set_shader_parameter("edge_px", 2.0)
	m.set_shader_parameter("aspect", 1.0)
	m.set_shader_parameter("noise_amt", 0.07)
	m.set_shader_parameter("wear", 0.20)
	return m


func _ready() -> void:
	custom_minimum_size = Vector2(SLOT_W * 3 + GAP * 2, SLOT_H)
	# 根容器不拦截点击：只让每个槽的按钮(STOP)接收（否则上层 HUD 容器会吞点击）。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(3):
		var base := Vector2(i * (SLOT_W + GAP), 0.0)
		# jelly 芯片（一层搞定底色 + 立体边 + 圆角；颜色由 refresh 设）。
		var chip := ColorRect.new()
		chip.color = Color.WHITE   # jelly shader 乘 COLOR，须白
		chip.position = base
		chip.size = Vector2(SLOT_W, SLOT_H)
		var mat := _make_chip_material()
		chip.material = mat
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(chip)
		# 道具图标层（铺在芯片之上、文字之下；缺图隐藏 → 回退文字）。
		var icon := TextureRect.new()
		icon.position = base + Vector2(ICON_INSET, ICON_INSET)
		icon.size = Vector2(SLOT_W - ICON_INSET * 2.0, SLOT_H - ICON_INSET * 2.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # 小尺寸须 IGNORE_SIZE 否则被纹理顶大
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 像素清晰
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		add_child(icon)
		var lbl := Label.new()
		lbl.position = base
		lbl.size = Vector2(SLOT_W, SLOT_H)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.clip_text = true   # 长道具名（占位文字）夹在芯片内·勿溢出（待换图标）
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.98, 0.96, 0.9))
		lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.85))
		lbl.add_theme_constant_override("outline_size", 4)
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
		# 升级金角标（右上角·铺在点击层之上 → 角落点击=升级、槽身=使用）。默认隐藏，refresh 控显。
		var up := _make_upgrade_badge(base, i)
		add_child(up)
		_chips.append(chip)
		_chip_mats.append(mat)
		_icons.append(icon)
		_labels.append(lbl)
		_buttons.append(btn)
		_upgrade_btns.append(up)


## 右上角「升」金色角标（jelly 金底 + 墨字·点角=升级·点槽身=使用）。
func _make_upgrade_badge(base: Vector2, i: int) -> Button:
	var up := Button.new()
	up.text = "升"
	up.flat = true
	up.focus_mode = Control.FOCUS_NONE
	up.position = base + Vector2(SLOT_W - 20.0, 1.0)
	up.size = Vector2(19.0, 17.0)
	up.add_theme_font_size_override("font_size", 10)
	up.add_theme_color_override("font_color", Color(0.25, 0.16, 0.04))   # 墨字压金
	up.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	up.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	up.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	var bg := ColorRect.new()
	bg.color = Color.WHITE
	bg.size = Vector2(19.0, 17.0)
	bg.show_behind_parent = true
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bm := ShaderMaterial.new()
	bm.shader = JELLY_SHADER
	bm.set_shader_parameter("fill_top", Color("ffd86a"))
	bm.set_shader_parameter("fill_bottom", Color("c89a30"))
	bm.set_shader_parameter("edge_inner", Color("fff0b0"))
	bm.set_shader_parameter("edge_outer", EDGE_OUTER)
	bm.set_shader_parameter("fill_alpha", 1.0)
	bm.set_shader_parameter("pixel_grid", 18.0)
	bm.set_shader_parameter("corner", 0.2)
	bm.set_shader_parameter("edge_px", 1.5)
	bm.set_shader_parameter("aspect", 19.0 / 17.0)
	bm.set_shader_parameter("noise_amt", 0.05)
	bm.set_shader_parameter("wear", 0.15)
	bg.material = bm
	up.add_child(bg)
	up.visible = false
	up.pressed.connect(_on_upgrade_pressed.bind(i))
	return up


func _on_slot_pressed(slot: int) -> void:
	if interactive:
		slot_clicked.emit(slot)


func _on_upgrade_pressed(slot: int) -> void:
	if interactive:
		slot_upgrade_clicked.emit(slot)


## 按经济状态刷新 3 个芯片（颜色 + 文字）。battle 未启用经济（槽空）时安全跳过。
## staged：本回合已点选「使用」的槽位（仅 P1 传入；用于亮金高亮）。
func refresh(battle: BattleCore, player: int, staged: Array = []) -> void:
	if battle == null or player < 0 or player >= battle.slots.size():
		return
	if battle.slots[player].size() < 3 or _chips.size() < 3:
		return
	for i in range(3):
		var st: int = battle.slot_state(player, i)
		var lbl: Label = _labels[i]
		var icon: TextureRect = _icons[i]
		icon.visible = false               # 默认隐藏 → 非 CHARGING / 缺图均回退文字（零回归）
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var ready := false                 # 本回合是否「有可操作动作」（决定金边）
		var cta := GOLD_OPEN               # 召唤操作用的金（经济操作=暗金；道具就绪=亮金）
		var ft := SEAL_FT
		var fb := SEAL_FB
		var ei := SEAL_EI
		match st:
			BattleCore.SlotState.SEALED:
				if battle.turn_number >= int(BattleCore.SLOT_UNLOCK_TURN[i]):
					lbl.text = "可开"
					ready = battle.can_open_slot(player, i)
					ft = NEU_FT; fb = NEU_FB; ei = NEU_EI
				else:
					lbl.text = "—"   # 仍是 SEAL 灰（未到解锁回合）
			BattleCore.SlotState.OPENED:
				ft = NEU_FT; fb = NEU_FB; ei = NEU_EI
				if battle.can_draw_slot(player, i):
					lbl.text = "可抽"
					ready = true
				else:
					lbl.text = "开格\n(锁)"
			BattleCore.SlotState.CHARGING:
				var item: ItemData = battle.slot_item(player, i)
				var nm: String = item.item_name if item != null else ""
				var dim: Color = _dim_color(item)
				var tex: Texture2D = _icon_for(item.item_id) if item != null else null
				if tex != null:
					icon.texture = tex
					icon.visible = true
					lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM   # 状态标签落底·不挡图标
				if battle.slot_ready(player, i):
					ready = true
					cta = GOLD_READY          # 道具就绪可用 = 主操作 → 亮金
					ft = dim.lightened(0.10)
					fb = dim.darkened(0.30)
					ei = dim.lightened(0.28)
					icon.modulate = Color.WHITE
					if tex != null:
						lbl.text = "✓用" if staged.has(i) else ""   # 有图 → 只留状态标签
					else:
						lbl.text = nm + "\n✓用" if staged.has(i) else nm   # 缺图回退名
				else:
					ft = dim.darkened(0.18)   # 锁中 = 维度色压暗（仍认得出归属）
					fb = dim.darkened(0.48)
					ei = NEU_EI
					icon.modulate = Color(0.62, 0.62, 0.66)   # 图标压暗 = 读作锁中
					lbl.text = "(锁)" if tex != null else nm + "\n(锁)"
			BattleCore.SlotState.EMPTY:
				if battle.can_refill(player, i):
					lbl.text = "可补"
					ready = true
					ft = NEU_FT; fb = NEU_FB; ei = NEU_EI
				else:
					lbl.text = "空"
					ft = EMP_FT; fb = EMP_FB; ei = EMP_EI
		lbl.modulate = Color.WHITE
		# 金色「召唤操作」高光边：已点选=最亮金 / 本回合可操作(仅 interactive)=召唤金 / 否则=状态本色边（P2 不点亮）。
		if staged.has(i):
			ei = GOLD_STAGED
		elif interactive and ready:
			ei = cta
		var mat: ShaderMaterial = _chip_mats[i]
		mat.set_shader_parameter("fill_top", ft)
		mat.set_shader_parameter("fill_bottom", fb)
		mat.set_shader_parameter("edge_inner", ei)
		# 升级角标：仅本地玩家行 + 该槽可升级（就绪 + tier<3 + 能量够）时显示。
		_upgrade_btns[i].visible = interactive and battle.can_upgrade(player, i)


func _dim_color(item: ItemData) -> Color:
	if item == null:
		return SEAL_FT
	return DIM_COLOR.get(item.dimension, Color(0.42, 0.42, 0.47))


## 取道具图标（带缓存）；缺图 / 未导入返回 null → 回退占位文字。
func _icon_for(id: String) -> Texture2D:
	if not _icon_cache.has(id):
		_icon_cache[id] = ItemCatalog.load_icon(id)   # 可能为 null，缓存避免每帧 exists/load
	return _icon_cache[id]
