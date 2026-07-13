class_name ItemSlotRow
extends Control

## 道具栏组件（2026-07-13 无文字状态语言重做·同日二版按 Eddy 反馈修）：横排 3 格。
## 状态语言=回纹框（全状态统一·有道具=阶框/无道具=暖骨中性框）+ 小配饰 + 动效，状态文字全退役：
##   未解锁=斜贴封条（挂锁图标+圆点=剩余回合·到点撕落+框弹亮）；锁中=阶框压暗+角上小封条（带小挂锁）；
##   可抽/可补=同语言（卡背浮动+框金呼吸=本回合可点·补货费走费用章）；待抽=卡背压暗静止；
##   就绪=全彩；点选=金边+图标下沉；空=纯暗格。
## 升级入口=右键点槽（悬停提示说明）；费用展示=槽左上角能量章（IconBadge·与底部按钮 CostPips 同款）。
## （升条/▲pip 方案已撤销：升条与悬停提示框抢槽下空间、pip 不明显——Eddy 2026-07-13。）
## 原则「框安静、内容响」。interactive=true（P1）可点击/有 CTA 动效；false（P2·AI 道具-blind）仅显示状态。
## 用法：add_child → interactive/connect（仅 P1）→ 每次 _update_all 调 refresh(battle, player, staged)。

signal slot_clicked(slot: int)
signal slot_upgrade_clicked(slot: int)   # 点击就绪可升级槽右上角「升」角标（C·升级线）
signal slot_hovered(slot: int)           # 鼠标进入槽位（仅 interactive 行·悬停提示用·2026-07-11）
signal slot_unhovered                    # 鼠标离开槽位

const SLOT_W := 68.0   # 道具框（2026-06-28 Eddy：76→缩小一些）
const SLOT_H := 68.0
const GAP := 9.0

## 维度 → 芯片底色（与动作按钮 / draft 卡 / 飘字同源的语义色板）。
const DIM_COLOR := {
	"进攻": Color("b8402f"), "防御": Color("3f6fb0"), "能量": Color("d2a32a"),
	"节奏": Color("c47f33"), "状态": Color("4f9d52"), "干扰": Color("6f5bb0"),
	"导出": Color("5f8a9a"), "随机": Color("8a8f98"),
}

## 道具框形式（2026-06-28 Eddy：战斗道具栏统一为「道具图鉴」同款形式）：
##   双层 = 暗格底 canvas_ui_item_cell_bg（稀有度暗底 + 中心高亮 + 传说金底图）+ 稀有度像素框 canvas_ui_pixel_frame。
##   与 item_gallery_screen 完全同源（像素框 + 暗格 + 居中图标 + 全圆角）。jelly 仅保留给右上「升」角标。
const FRAME_SHADER := preload("res://assets/shaders/canvas_ui_pixel_frame.gdshader")        # 状态框（无道具/金边态·有道具改走回纹贴图框）
const ITEM_FRAME_TEX := {   # 三阶回纹框（2026-07-13 与图鉴同源同款贴图）
	1: preload("res://assets/ui/item_frame_t1.png"),
	2: preload("res://assets/ui/item_frame_t2.png"),
	3: preload("res://assets/ui/item_frame_t3.png"),
}
# 格底内外色（2026-07-13 与图鉴同源定版：四角=深饱和阶色·中心=略浅阶色·传说走 gold_bottom）。
const CELL_FILL_T := {1: Color("#6E9BD2"), 2: Color("#9A7FD0")}
const CELL_CENTER_T := {1: Color("#88AEDE"), 2: Color("#B098E0")}
const CELL_BG_SHADER := preload("res://assets/shaders/canvas_ui_item_cell_bg.gdshader")     # 暗格底：圆角 + 稀有度暗底 + 中心高亮 + 传说金底图
const JELLY_SHADER := preload("res://assets/shaders/canvas_button_jelly.gdshader")          # 仅「升」角标用
const LEGENDARY_BG := preload("res://assets/ui/gold_bottom.png")                            # 传说道具金云纹背景（Eddy 美术·与图鉴同源）
const LEGENDARY_BG_TINT := Color(1.0, 1.0, 1.0, 1.0)
const FRAME_EDGE_OUTER := Color(0.16, 0.10, 0.06)   # 框外轮廓=深咖（与图鉴同）
const CELL_CORNER := 0.18                            # 圆角（格底与框一致·与图鉴同·全圆角无方角）
const CELL_GRID := 23.0    # 像素格数（= 图鉴 BOX/6）。用「格数」而非 SLOT_W/6 → 边框按比例随框缩放、不会在小框上变粗（2026-06-28 Eddy：去掉过厚棕边·与图鉴完全一致）
const EDGE_OUTER := Color(0.11, 0.09, 0.075)    # 统一暗轮廓（暖黑·与暖色UI同温·任何色相都干净）
const GOLD_READY := Color("ffd86a")             # 道具本回合可用（interactive）→ 亮金高光边
const GOLD_STAGED := Color("fff0a0")            # 已点选使用 → 更亮金边
const GOLD_OPEN := Color("d8b85a")              # 可开 / 可抽 / 可补 → 提示金边（较暗·次级）
# 中性态填充（锁 / 待操作 / 空格）。2026-06-28：原冷暗灰 → 暖石色 + 整体提亮，与暖色动作按钮同温、不再显暗。
const SEAL_FT := Color(0.51, 0.46, 0.38)        # 锁：暖石灰（上）·2026-06-28 再提亮一档
const SEAL_FB := Color(0.36, 0.32, 0.26)
const SEAL_EI := Color(0.63, 0.57, 0.46)
const NEU_FT := Color(0.54, 0.49, 0.40)         # 待操作：暖石（上）
const NEU_FB := Color(0.39, 0.35, 0.28)
const NEU_EI := Color(0.66, 0.60, 0.48)
const EMP_FT := Color(0.31, 0.28, 0.23)         # 空格：暖石褐（非近黑冷）
const EMP_FB := Color(0.21, 0.19, 0.15)
const EMP_EI := Color(0.44, 0.40, 0.32)
# 无道具态（空/未解锁/不可操作）框色：去饱和中性灰（2026-06-28 Eddy：去掉"木色"边框；有道具一律走稀有度色）。
const EMPTY_EDGE := Color(0.43, 0.42, 0.41)
# ── 无文字状态语言（2026-07-13 重做·Eddy 批 B+A 方案）：状态=回纹框+小配饰+动效·文字全退役 ──
const NEUTRAL_FRAME_TEX := preload("res://assets/ui/hero_avatar_frame.png")   # 无道具态回纹框（暖骨中性·与头像框同源）
const COIN_SHEET := preload("res://assets/ui/icons/energy_idle.png")          # 费用章金币（IconBadge·与底部按钮 CostPips 同款）
const SEAL_PAPER := Color("#E8DCC0")            # 封条纸面（米色封印语言·与匾/签同族）
const SEAL_EDGE_INK := Color(0.23, 0.17, 0.12)  # 封条描边
const SEAL_PIP_INK := Color(0.45, 0.34, 0.23)   # 封条圆点（剩余回合数）
const CARD_EDGE := Color(0.32, 0.24, 0.17)      # 卡背描边（可抽=面朝下的卡）
const CARD_FILL := Color(0.62, 0.50, 0.36)      # 卡背暖褐
const CARD_MOTIF := Color(0.80, 0.70, 0.54)     # 卡背中心菱纹
# 文字层级（2026-07-08 优化点②）：静默态文字退后、可操作态文字响——「框安静、内容响」延伸到字。
const TXT_BRIGHT := Color(0.98, 0.96, 0.9)      # 可抽/可补/就绪/✓用（可操作·亮米白）
const TXT_DIM := Color(0.78, 0.74, 0.66)        # 锁/待抽/锁中（静默电报·暖灰退后）
const TXT_FAINT := Color(0.62, 0.58, 0.50)      # 空格（最弱）

## interactive：本地玩家行可点击。setter 立即把按钮 mouse_filter 设为 STOP；P2（false）→ IGNORE。
var interactive := false:
	set(v):
		interactive = v
		for b in _buttons:
			b.mouse_filter = Control.MOUSE_FILTER_STOP if v else Control.MOUSE_FILTER_IGNORE

const ICON_INSET := 9.0                          # 图标内缩（露出框·与图鉴 17/138≈12% 同比例·落在内框里不溢出）

var _cells: Array[ColorRect] = []              # 每槽暗格底（cell_bg：稀有度暗底 + 中心高亮 + 传说金底图）
var _cell_mats: Array[ShaderMaterial] = []     # refresh 重设 fill_color / center_glow / use_tex
var _frames: Array[ColorRect] = []             # 每槽状态像素框（pixel_frame·无道具/金边态用）
var _frame_mats: Array[ShaderMaterial] = []    # refresh 重设 edge_mid / edge_inner（状态色）
var _tex_frames: Array[TextureRect] = []       # 每槽回纹阶框贴图（有道具时替换 shader 框·与图鉴同款）
var _icons: Array[TextureRect] = []            # 道具图标层（缺图隐藏 → 回退文字·零回归）
var _icon_cache := {}                          # id → Texture2D / null（避免每帧 load/exists）
var _labels: Array[Label] = []                 # 仅缺图回退道具名（状态文字 2026-07-13 全退役）
var _buttons: Array[Button] = []
# ── 无文字状态语言部件（2026-07-13·同日二版：升条/▲pip 撤销→右键+费用章·Eddy 反馈）──
var _seals: Array[Control] = []                # 未解锁=斜贴封条（挂锁图标+剩余回合圆点）
var _seal_pips: Array[Array] = []              # 每封条 3 圆点
var _mini_seals: Array[Control] = []           # 锁中=角上半张小封条（带小挂锁）
var _cardbacks: Array[Control] = []            # 可抽/待抽/可补=面朝下小卡背（抽补同语言）
var _cost_chips: Array[IconBadge] = []         # 左上角费用章（能量币+数字·与底部按钮同款·升级/补货费）
var _can_up: Array[bool] = [false, false, false]
var _anim_keys: Array[String] = ["", "", ""]   # 每槽 ambient 动效键（变更才重建 tween·恢复前必 kill）
var _anim_tweens: Array = [null, null, null]
var _prev_sealed: Array = [null, null, null]   # 上帧封印态（null=首刷不放撕封条动画）
var _prev_locked: Array = [null, null, null]


## 暗格底材质（cell_bg·与图鉴同 shader）：稀有度暗底 + 中心高亮 + 传说金底图。颜色/高亮每次 refresh 重设。
func _make_cell_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CELL_BG_SHADER
	m.set_shader_parameter("fill_opaque", 1.0)        # 实底（非叠加）
	m.set_shader_parameter("cloud_on", 0.0)
	m.set_shader_parameter("use_tex", 0.0)
	m.set_shader_parameter("corner_radius", CELL_CORNER)
	m.set_shader_parameter("pixel_grid", CELL_GRID)   # = 图鉴格数·边框/圆角与图鉴等比
	m.set_shader_parameter("center_glow", 0.55)
	m.set_shader_parameter("glow_radius", 0.62)
	return m


## 稀有度像素框材质（pixel_frame·与图鉴/英雄卡同 shader）。edge_mid/inner 每次 refresh 设状态/稀有度色。
func _make_frame_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FRAME_SHADER
	m.set_shader_parameter("edge_outer", FRAME_EDGE_OUTER)
	m.set_shader_parameter("pixel_grid", CELL_GRID)   # = 图鉴格数·边框等比变薄（小框不再粗棕边）
	m.set_shader_parameter("border_px", 2.0)
	m.set_shader_parameter("noise_amt", 0.05)
	m.set_shader_parameter("light_amount", 0.18)     # 方向光浮雕（上/左提亮）
	m.set_shader_parameter("aspect", 1.0)
	m.set_shader_parameter("corner_radius", CELL_CORNER)
	return m


func _ready() -> void:
	custom_minimum_size = Vector2(SLOT_W * 3 + GAP * 2, SLOT_H)
	# 根容器不拦截点击：只让每个槽的按钮(STOP)接收（否则上层 HUD 容器会吞点击）。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(3):
		var base := Vector2(i * (SLOT_W + GAP), 0.0)
		# 暗格底（cell_bg）：稀有度暗底 + 中心高亮 + 传说金底图；颜色由 refresh 设。
		var cell := ColorRect.new()
		cell.color = Color.WHITE   # shader 乘 COLOR，须白
		cell.position = base
		cell.size = Vector2(SLOT_W, SLOT_H)
		var cmat := _make_cell_material()
		cell.material = cmat
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cell)
		# 稀有度像素框（pixel_frame·中心透明只画边）：覆在格底上、图标之下。
		var frame := ColorRect.new()
		frame.color = Color.WHITE
		frame.position = base
		frame.size = Vector2(SLOT_W, SLOT_H)
		var fmat := _make_frame_material()
		frame.material = fmat
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(frame)
		# 回纹阶框贴图（有道具时显示·替换 shader 框·与图鉴同款素材）。
		var tframe := TextureRect.new()
		tframe.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tframe.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tframe.position = base
		tframe.size = Vector2(SLOT_W, SLOT_H)
		tframe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tframe.visible = false
		add_child(tframe)
		# 道具图标层（铺在框之上、文字之下；缺图隐藏 → 回退文字）。
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
		lbl.add_theme_color_override("font_color", TXT_BRIGHT)
		lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.85))
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lbl)
		# 点击层（透明 flat 按钮，铺满整格）：仅 interactive 时吃点击。
		# ── 无文字状态语言部件（封条/小封条/卡背/金币/▲pip·全 IGNORE·refresh 控显）──
		var seal := _make_seal(base)
		add_child(seal)
		var mseal := _make_mini_seal(base)
		add_child(mseal)
		var cback := _make_cardback(base)
		add_child(cback)
		# 费用章（左上角能量币+数字·与底部按钮 CostPips 同语言）：可升级=升级费·可补=补货费。
		var chip := IconBadge.new()
		chip.position = base + Vector2(-9.0, -10.0)
		chip.size = Vector2(26.0, 26.0)
		chip.set_icon(COIN_SHEET, 4, 4, 0)
		chip.font_size = 12
		chip.outline_size = 4
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.visible = false
		add_child(chip)
		var btn := Button.new()
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.position = base
		btn.size = Vector2(SLOT_W, SLOT_H)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
		btn.pressed.connect(_on_slot_pressed.bind(i))
		btn.gui_input.connect(_on_slot_gui_input.bind(i))   # A 方案：右键=升级
		btn.mouse_entered.connect(_on_slot_hover.bind(i))
		btn.mouse_exited.connect(_on_slot_unhover)
		add_child(btn)
		_cells.append(cell)
		_cell_mats.append(cmat)
		_frames.append(frame)
		_frame_mats.append(fmat)
		_tex_frames.append(tframe)
		_icons.append(icon)
		_labels.append(lbl)
		_buttons.append(btn)
		_seals.append(seal)
		_mini_seals.append(mseal)
		_cardbacks.append(cback)
		_cost_chips.append(chip)


## 斜贴封条（未解锁）：米色纸条+深褐描边+剩余回合圆点（手贴微斜=封印语言·与匾/签同族）。
func _make_seal(base: Vector2) -> Control:
	var root := Control.new()
	root.position = base + Vector2(SLOT_W * 0.5, SLOT_H * 0.5)
	root.rotation = -0.30
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	var w := 72.0   # ≤ 格宽/cos(倾角)——斜贴不探进邻槽（84 实拍越界·2026-07-13）
	var h := 20.0
	var edge := ColorRect.new()
	edge.color = SEAL_EDGE_INK
	edge.position = Vector2(-w * 0.5 - 1.0, -h * 0.5 - 1.0)
	edge.size = Vector2(w + 2.0, h + 2.0)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(edge)
	var paper := ColorRect.new()
	paper.color = SEAL_PAPER
	paper.position = Vector2(-w * 0.5, -h * 0.5)
	paper.size = Vector2(w, h)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(paper)
	_add_padlock(root, Vector2(-24.0, 0.0), 1.0)   # 挂锁图标="封住"一眼知义（Eddy：封条莫名其妙）
	var pips: Array = []
	for k in 3:
		var p := ColorRect.new()
		p.color = SEAL_PIP_INK
		p.size = Vector2(6.0, 6.0)
		p.position = Vector2(-6.0 + k * 12.0, -3.0)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(p)
		pips.append(p)
	_seal_pips.append(pips)
	return root


## 像素挂锁图标（画在封条上）：锁体 + 锁梁三段（顶横+两腿）·全 ColorRect。
func _add_padlock(parent: Control, at: Vector2, s: float = 1.0) -> void:
	for r: Rect2 in [
			Rect2(at + Vector2(-5.0, -1.0) * s, Vector2(10.0, 8.0) * s),   # 锁体
			Rect2(at + Vector2(-3.0, -6.0) * s, Vector2(6.0, 2.0) * s),    # 锁梁顶横
			Rect2(at + Vector2(-3.0, -4.0) * s, Vector2(2.0, 3.0) * s),    # 锁梁左腿
			Rect2(at + Vector2(1.0, -4.0) * s, Vector2(2.0, 3.0) * s)]:    # 锁梁右腿
		var c := ColorRect.new()
		c.color = SEAL_EDGE_INK
		c.position = r.position
		c.size = r.size
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(c)


## 角上半张小封条（锁中·冷却 1 回合）：短条斜贴右上角。
func _make_mini_seal(base: Vector2) -> Control:
	var root := Control.new()
	root.position = base + Vector2(SLOT_W - 16.0, 14.0)
	root.rotation = 0.62
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	var w := 44.0
	var h := 13.0
	var edge := ColorRect.new()
	edge.color = SEAL_EDGE_INK
	edge.position = Vector2(-w * 0.5 - 1.0, -h * 0.5 - 1.0)
	edge.size = Vector2(w + 2.0, h + 2.0)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(edge)
	var paper := ColorRect.new()
	paper.color = SEAL_PAPER
	paper.position = Vector2(-w * 0.5, -h * 0.5)
	paper.size = Vector2(w, h)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(paper)
	_add_padlock(root, Vector2(0.0, 0.5), 0.9)   # 小挂锁居中（锁中一眼知义）
	return root


## 面朝下小卡背（可抽/可补同语言·Eddy：两者保持一致）：暖褐卡+中心菱纹·可操作时轻浮动。
func _make_cardback(base: Vector2) -> Control:
	var root := Control.new()
	root.position = base + Vector2((SLOT_W - 24.0) * 0.5, (SLOT_H - 32.0) * 0.5)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	var edge := ColorRect.new()
	edge.color = CARD_EDGE
	edge.size = Vector2(24.0, 32.0)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(edge)
	var fill := ColorRect.new()
	fill.color = CARD_FILL
	fill.position = Vector2(2.0, 2.0)
	fill.size = Vector2(20.0, 28.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fill)
	var motif := ColorRect.new()
	motif.color = CARD_MOTIF
	motif.size = Vector2(8.0, 8.0)
	motif.position = Vector2(8.0, 12.0)
	motif.pivot_offset = Vector2(4.0, 4.0)
	motif.rotation = 0.785
	motif.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(motif)
	return root


func _on_slot_pressed(slot: int) -> void:
	if interactive:
		slot_clicked.emit(slot)


## 升级入口=右键点槽（悬停提示有说明·费用见槽左上角能量章。升条/▲pip 方案已撤销：与提示框抢位+不明显）。
func _on_slot_gui_input(event: InputEvent, slot: int) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT \
			and interactive and _can_up[slot]:
		slot_upgrade_clicked.emit(slot)


func _on_slot_hover(slot: int) -> void:
	if interactive:
		slot_hovered.emit(slot)


func _on_slot_unhover() -> void:
	slot_unhovered.emit()


## 按经济状态刷新 3 个芯片（2026-07-13 重做：无文字状态语言——回纹框+封条/卡背/金币+动效）。
## staged：本回合已点选「使用」的槽位（仅 P1 传入；金边+图标下沉）。
func refresh(battle: BattleCore, player: int, staged: Array = []) -> void:
	if battle == null or player < 0 or player >= battle.slots.size():
		return
	if battle.slots[player].size() < 3 or _cells.size() < 3:
		return
	for i in range(3):
		var st: int = battle.slot_state(player, i)
		var lbl: Label = _labels[i]
		var icon: TextureRect = _icons[i]
		icon.visible = false
		lbl.text = ""                      # 状态文字全退役——label 只留缺图回退道具名
		var ft := SEAL_FT
		var fb := SEAL_FB                   # = 格底四角色（fill_color）
		var glow := 0.0
		var cell_inner := Color.WHITE
		var legend := false
		var has_item := false
		var sealed := st == BattleCore.SlotState.SEALED
		var locked_item := false           # 有道具但冷却锁中
		var anim := ""                     # ambient 动效键：cta（卡背浮+框金呼吸=本回合可点）/ 空
		var frame_tex: Texture2D = NEUTRAL_FRAME_TEX   # 全状态统一回纹框：无道具=暖骨中性
		var frame_mod := Color.WHITE
		_seals[i].visible = false
		_mini_seals[i].visible = false
		_cardbacks[i].visible = false
		match st:
			BattleCore.SlotState.SEALED:
				# 未解锁 = 压暗中性回纹框 + 斜贴封条·剩余回合=封条圆点（每回合掉一点）。
				ft = EMP_FT; fb = EMP_FB
				frame_mod = Color(0.58, 0.56, 0.53)
				_seals[i].visible = true
				var remain: int = clampi(int(BattleCore.SLOT_UNLOCK_TURN[i]) - battle.turn_number, 0, 3)
				for k in 3:
					(_seal_pips[i][k] as ColorRect).visible = k < remain
			BattleCore.SlotState.OPENED:
				# 可抽 = 卡背轻浮动 + 框金呼吸（直接的"可点"信号）；本回合不能抽 = 卡背静止压暗。
				ft = NEU_FT; fb = NEU_FB
				_cardbacks[i].visible = true
				if battle.can_draw_slot(player, i):
					_cardbacks[i].modulate = Color.WHITE
					if interactive:
						anim = "cta"
				else:
					frame_mod = Color(0.74, 0.72, 0.69)
					_cardbacks[i].modulate = Color(0.72, 0.72, 0.72)
			BattleCore.SlotState.CHARGING:
				var item: ItemData = battle.slot_item(player, i)
				has_item = item != null
				legend = has_item and item.tier >= 3        # 传说 → 格底用 gold_bottom 金底图
				if has_item:
					glow = 0.0 if legend else 1.0
					frame_tex = ITEM_FRAME_TEX.get(item.tier, ITEM_FRAME_TEX[1])
				var tier_key: int = item.tier if item != null else 1
				var c_out: Color = CELL_FILL_T.get(tier_key, CELL_FILL_T[1])
				var c_in: Color = CELL_CENTER_T.get(tier_key, CELL_CENTER_T[1])
				var tex: Texture2D = _icon_for(item.item_id) if item != null else null
				if tex != null:
					icon.texture = tex
					icon.visible = true
				else:
					lbl.text = tr(item.item_name) if item != null else ""   # 缺图回退（唯一残留文字）
				if battle.slot_ready(player, i):
					fb = c_out
					cell_inner = c_in
					icon.modulate = Color.WHITE
				else:
					# 锁中 = 阶色压暗 + 图标去饱和 + 角上半张小封条。
					locked_item = true
					fb = c_out.darkened(0.32)
					cell_inner = c_in.darkened(0.32)
					frame_mod = Color(0.65, 0.65, 0.68)
					icon.modulate = Color(0.62, 0.62, 0.66)
					_mini_seals[i].visible = true
			BattleCore.SlotState.EMPTY:
				# 可补 = 与可抽同语言（Eddy 定）：卡背浮动+框金呼吸，费用差异走左上角能量章；不可补 = 纯空暗格。
				if battle.can_refill(player, i):
					ft = NEU_FT; fb = NEU_FB
					_cardbacks[i].visible = true
					_cardbacks[i].modulate = Color.WHITE
					if interactive:
						anim = "cta"
				else:
					ft = EMP_FT; fb = EMP_FB
					frame_mod = Color(0.60, 0.58, 0.55)
		# 无道具格：连续内渐变代替死平底（中心 ft 微亮·幅度克制）。
		if not has_item:
			glow = 0.45
			cell_inner = ft
		# 点选使用 = 金边 shader 框 + 图标下沉 3px（按下感·「✓用」文字退役）。
		var staged_now: bool = staged.has(i)
		icon.position.y = ICON_INSET + (3.0 if staged_now else 0.0)
		# 格底应用
		var cmat: ShaderMaterial = _cell_mats[i]
		cmat.set_shader_parameter("fill_color", fb)
		cmat.set_shader_parameter("inner_color", cell_inner)
		cmat.set_shader_parameter("center_glow", glow)
		cmat.set_shader_parameter("use_tex", 1.0 if legend else 0.0)
		if legend:
			cmat.set_shader_parameter("bg_tex", LEGENDARY_BG)
			cmat.set_shader_parameter("tex_tint", LEGENDARY_BG_TINT)
		# 框应用：点选=shader 金边框；其余全状态=回纹贴图框（有道具=阶框/无道具=暖骨中性框）。
		_tex_frames[i].visible = not staged_now
		_frames[i].visible = staged_now
		if staged_now:
			var fmat: ShaderMaterial = _frame_mats[i]
			fmat.set_shader_parameter("edge_mid", GOLD_STAGED)
			fmat.set_shader_parameter("edge_inner", GOLD_STAGED.darkened(0.5))
		else:
			_tex_frames[i].texture = frame_tex
			_tex_frames[i].modulate = frame_mod
		# 解锁演出：封条撕落（未解锁→解锁）/ 小封条飘走（锁中→就绪）+ 框弹亮（有 cta 呼吸时略过闪·防抢属性）。首刷不放。
		if _prev_sealed[i] == true and not sealed:
			_play_seal_tear(i, false, frame_mod, anim == "")
		if _prev_locked[i] == true and has_item and not locked_item:
			_play_seal_tear(i, true, frame_mod, anim == "")
		_prev_sealed[i] = sealed
		_prev_locked[i] = locked_item
		# 可升级判据（右键入口）+ 费用章 + ambient 动效
		_can_up[i] = interactive and battle.can_upgrade(player, i)
		var chip: IconBadge = _cost_chips[i]
		if _can_up[i]:
			chip.set_number(int(round(BattleCore.UPGRADE_COST / float(ActionDef.ENERGY_UNIT))))
			chip.visible = true
		elif interactive and st == BattleCore.SlotState.EMPTY and battle.can_refill(player, i):
			chip.set_number(int(round(BattleCore.ITEM_REFILL_COST / float(ActionDef.ENERGY_UNIT))))
			chip.visible = true
		else:
			chip.visible = false
		_set_ambient(i, anim, frame_mod)


## ambient 动效（cta=卡背浮动+框金呼吸="本回合可点"）：键变更才重建；恢复前必 kill（慢放 tween 教训）。
func _set_ambient(i: int, key: String, base_mod: Color) -> void:
	if _anim_keys[i] == key:
		return
	_anim_keys[i] = key
	var old: Tween = _anim_tweens[i]
	if old != null and old.is_valid():
		old.kill()
	_anim_tweens[i] = null
	var cy := (SLOT_H - 32.0) * 0.5
	_cardbacks[i].position.y = cy
	_tex_frames[i].modulate = base_mod   # 杀掉旧 tween 后必须复位（tween 残值会盖掉刚 apply 的状态色）
	if key == "cta":
		var tw := create_tween().set_loops()
		tw.set_parallel(true)
		tw.tween_property(_cardbacks[i], "position:y", cy - 2.0, 0.6)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_tex_frames[i], "modulate", Color(1.22, 1.14, 0.88), 0.6)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.chain().tween_property(_cardbacks[i], "position:y", cy + 1.0, 0.6)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(_tex_frames[i], "modulate", Color.WHITE, 0.6)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_anim_tweens[i] = tw


## 解锁演出：封条幽灵副本撕落飘出（位移+旋转+淡出）+ 回纹框弹亮回落（flash=false 时只撕不闪）。
func _play_seal_tear(i: int, mini: bool, end_mod: Color, flash: bool = true) -> void:
	var src: Control = _mini_seals[i] if mini else _seals[i]
	var ghost := src.duplicate() as Control
	ghost.visible = true
	add_child(ghost)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ghost, "position", ghost.position + Vector2(16.0, 34.0), 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(ghost, "rotation", ghost.rotation + 0.55, 0.45)
	tw.tween_property(ghost, "modulate:a", 0.0, 0.45)
	tw.chain().tween_callback(ghost.queue_free)
	if flash:
		_tex_frames[i].modulate = Color(1.65, 1.55, 1.25)
		create_tween().tween_property(_tex_frames[i], "modulate", end_mod, 0.35)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 芯片底色（2026-06-26 Eddy：改按【稀有度】而非维度——普通灰/稀有蓝/传说金·与图鉴/抽卡同源）。
func _rarity_color(item: ItemData) -> Color:
	if item == null:
		return SEAL_FT
	return ItemCatalog.rarity_color(item.tier)


## 取道具图标（带缓存）；缺图 / 未导入返回 null → 回退占位文字。
func _icon_for(id: String) -> Texture2D:
	if not _icon_cache.has(id):
		_icon_cache[id] = ItemCatalog.load_icon(id)   # 可能为 null，缓存避免每帧 exists/load
	return _icon_cache[id]
