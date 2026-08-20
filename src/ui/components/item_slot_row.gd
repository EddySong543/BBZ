class_name ItemSlotRow
extends Control

## 道具栏组件（2026-07-13 无文字状态语言重做·同日二版按 Eddy 反馈修）：横排 3 格。
## 状态语言=回纹框（全状态统一·有道具=阶框/无道具=暖骨中性框）+ 小配饰 + 动效，状态文字全退役：
##   未解锁=斜贴封条（圆点=剩余回合·到点撕落+框弹亮）；锁中=阶框压暗+角上小封条（单圆点=1回合）；
##   可抽/可补=同语言（锦囊轻浮+框金呼吸=本回合可点）；待抽=锦囊压暗静止；
##   就绪=全彩；可升级=右上金升箭角标（点击/右键=升级）+框向下一阶色呼吸；
##   点选=金晕外环+框身提金+图标下沉（回纹框保留不清除）；空=纯暗格。
## 升级入口=升箭角标点击 / 右键点槽（费用见悬停提示）。
## （挂锁图标/槽顶费用章/卡背/点选换金边框/升条/▲pip 均已退役——Eddy 2026-07-13 三轮反馈：
##  锁多此一举、费用章不合适、卡背与道具无关、点选清框不和谐、升条撞提示框、pip 不明显。）
## 原则「框安静、内容响」。interactive=true（P1）可点击/有 CTA 动效；false（P2·AI 道具-blind）仅显示状态。
## 用法：add_child → interactive/connect（仅 P1）→ 每次 _update_all 调 refresh(battle, player, staged)。

signal slot_clicked(slot: int)
signal slot_upgrade_clicked(slot: int)   # 点击就绪可升级槽右上角「升」角标（C·升级线）
signal slot_hovered(slot: int)           # 鼠标进入槽位（仅 interactive 行·悬停提示用·2026-07-11）
signal slot_unhovered                    # 鼠标离开槽位

const SLOT_W := 68.0   # 道具框（2026-06-28 Eddy：76→缩小一些）
const SLOT_H := 68.0
const GAP := 12.0   # 战斗 HUD 三格之间留出清晰分组；配合 0.92 行缩放，成品净距约 11px。

## 维度 → 芯片底色（与动作按钮 / draft 卡 / 飘字同源的语义色板）。
const DIM_COLOR := {
	"进攻": Color("b8402f"), "防御": Color("3f6fb0"), "能量": Color("d2a32a"),
	"节奏": Color("c47f33"), "状态": Color("4f9d52"), "干扰": Color("6f5bb0"),
	"导出": Color("5f8a9a"), "随机": Color("8a8f98"),
}

## 道具框形式（2026-06-28 Eddy：战斗道具栏统一为「道具图鉴」同款形式）：
##   双层 = 暗格底 canvas_ui_item_cell_bg（稀有度暗底 + 中心高亮 + 传说金底图）+ 稀有度像素框 canvas_ui_pixel_frame。
##   与 item_gallery_screen 完全同源（像素框 + 暗格 + 居中图标 + 全圆角）。jelly 仅保留给右上「升」角标。
const FRAME_SHADER := preload("res://assets/shaders/canvas_ui_pixel_frame.gdshader")        # 点选金晕外环用（框本体全走回纹贴图）
const FRAME_PALETTE_SHADER := ItemFrameStyle.FRAME_SHADER
const ITEM_FRAME_TEX := ItemFrameStyle.FRAME_TEXTURE
# 格底内外色（2026-07-13 与图鉴同源定版：四角=深饱和阶色·中心=略浅阶色·传说走 gold_bottom）。
const CELL_FILL_T := ItemFrameStyle.CELL_TOP
const CELL_CENTER_T := ItemFrameStyle.CELL_BOTTOM
const FRAME_SHADOW_T := ItemFrameStyle.FRAME_SHADOW
const FRAME_MID_T := ItemFrameStyle.FRAME_MID
const FRAME_HIGHLIGHT_T := ItemFrameStyle.FRAME_HIGHLIGHT
const CELL_BG_SHADER := ItemFrameStyle.CELL_SHADER
const JELLY_SHADER := preload("res://assets/shaders/canvas_button_jelly.gdshader")          # 仅「升」角标用
const LEGENDARY_BG := ItemFrameStyle.LEGENDARY_TEXTURE
const LEGENDARY_BG_TINT := ItemFrameStyle.LEGENDARY_TINT
const LEGENDARY_TOP_DARKENING := ItemFrameStyle.LEGENDARY_TOP_DARKENING
const FRAME_EDGE_OUTER := Color(0.16, 0.10, 0.06)   # 框外轮廓=深咖（与图鉴同）
const FRAME_ART_SIZE := Vector2.ONE * SLOT_W * ItemFrameStyle.FRAME_ART_SCALE
const FRAME_ART_OFFSET := Vector2(SLOT_W, SLOT_H) * ItemFrameStyle.FRAME_OFFSET_RATIO
const CELL_INSET := SLOT_W * ItemFrameStyle.CELL_INSET_RATIO
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
# 无道具态外框=图鉴 t1 回纹框（2026-07-17 Eddy：道具框外框须与道具图鉴一致——旧 hero_avatar_frame
# 是英雄族素材·道具行里穿错家族衣服；抽卡池 T1-only → 空/可抽格穿 t1 蓝语义也通·各态压暗沿用 frame_mod）。
const SEAL_PAPER := Color("#E8DCC0")            # 封条纸面（米色封印语言·与匾/签同族）
const SEAL_EDGE_INK := Color(0.23, 0.17, 0.12)  # 封条描边
const SEAL_PIP_INK := Color(0.45, 0.34, 0.23)   # 封条圆点（剩余回合数）
# 锦囊（可抽/可补·2026-07-13 Eddy：卡背与道具无关→换"装道具的袋子"）：束口布袋+金绳袋口+绣纹点缀。
const POUCH_EDGE := Color(0.32, 0.24, 0.17)     # 袋描边
const POUCH_CLOTH := Color(0.62, 0.50, 0.36)    # 袋身暖褐布
const POUCH_CLOTH_DK := Color(0.50, 0.40, 0.29) # 袋揪/袋底（暗一档=体积感）
const POUCH_TIE := Color(0.90, 0.76, 0.42)      # 束口金绳（袋口透金光）
const POUCH_MOTIF := Color(0.80, 0.70, 0.54)    # 袋身绣纹菱点
const POUCH_RECTS: Array = [                    # [Rect2, 色]（26×33 画布·双耳束口+鼓身=一眼袋子·后续可换 GPT 贴图）
	[Rect2(6, 0, 5, 6), POUCH_CLOTH],      # 左布耳（束口上方布揪·中间缺口=收拢褶）
	[Rect2(15, 0, 5, 6), POUCH_CLOTH],     # 右布耳
	[Rect2(8, 6, 10, 3), POUCH_TIE],       # 束口金绳（窄于袋身=勒紧·防读成罐盖）
	[Rect2(5, 9, 16, 4), POUCH_CLOTH],     # 肩
	[Rect2(2, 13, 22, 6), POUCH_CLOTH],
	[Rect2(0, 19, 26, 7), POUCH_CLOTH],    # 腹（最宽·鼓袋）
	[Rect2(2, 26, 22, 4), POUCH_CLOTH],
	[Rect2(5, 30, 16, 3), POUCH_CLOTH_DK], # 底
]
const POUCH_W := 26.0
const POUCH_H := 33.0   # = POUCH_ROWS 高度和
# 升级表现（2026-07-13 Eddy 定 A+B）：右上金升箭角标（可点=升级）+ 回纹框向下一阶色呼吸。
const NEXT_TIER_TINT := {   # modulate 乘色：当前阶框主色 → 下一阶主色（8FB8E4→BFA0E8→F0C468 通道比）
	1: Color(1.34, 0.87, 1.02),
	2: Color(1.26, 1.23, 0.45),
}
# 点选表现（2026-07-13 Eddy 定 A）：回纹框保留·外扩金晕环+框身提亮+图标下沉。
const STAGED_TINT := Color(1.18, 1.10, 0.98)    # 点选=框身轻暖提亮（乘色·不动色相防蓝框染绿）
const RING_PAD := 4.0                           # 金晕外环外扩像素（外露部分须是金——外描边也走金）
# 文字层级（2026-07-08 优化点②）：静默态文字退后、可操作态文字响——「框安静、内容响」延伸到字。
const TXT_BRIGHT := Color(0.98, 0.96, 0.9)      # 可抽/可补/就绪/✓用（可操作·亮米白）
const TXT_DIM := Color(0.78, 0.74, 0.66)        # 锁/待抽/锁中（静默电报·暖灰退后）
const TXT_FAINT := Color(0.62, 0.58, 0.50)      # 空格（最弱）

@export_group("Battle HUD 定向阴影")
@export var bottom_shadow_enabled := false
@export var bottom_shadow_offset := ItemFrameStyle.DROP_SHADOW_OFFSET
@export var bottom_shadow_color := ItemFrameStyle.DROP_SHADOW_COLOR
@export_group("")

## interactive：本地玩家行可点击。hoverable：非交互行也发悬停信号（P2 敌方道具查看·
## 2026-07-17 Eddy）——点击/右键升级仍被 interactive 门控，悬停只读无副作用。
var interactive := false:
	set(v):
		interactive = v
		_apply_mouse_filter()

var hoverable := false:
	set(v):
		hoverable = v
		_apply_mouse_filter()

## 非交互的敌方栏只在“选择敌方道具槽”期间接受左键；不开放升级或经济操作。
var targetable := false:
	set(v):
		targetable = v
		_apply_mouse_filter()


func _apply_mouse_filter() -> void:
	for b in _buttons:
		b.mouse_filter = Control.MOUSE_FILTER_STOP if (interactive or hoverable or targetable) \
				else Control.MOUSE_FILTER_IGNORE

const ICON_INSET := 9.0                          # 图标内缩（露出框·与图鉴 17/138≈12% 同比例·落在内框里不溢出）

var _cells: Array[ColorRect] = []              # 每槽暗格底（cell_bg：稀有度暗底 + 中心高亮 + 传说金底图）
var _cell_mats: Array[ShaderMaterial] = []     # refresh 重设 fill_color / center_glow / use_tex
var _frames: Array[ColorRect] = []             # 每槽点选金晕外环（pixel_frame·外扩金边·仅点选显示）
var _frame_mats: Array[ShaderMaterial] = []    # 金晕材质（金色在 _ready 一次性设定）
var _bottom_shadows: Array[TextureRect] = []   # Battle HUD opt-in：贴合回纹框 alpha 的轻量定向阴影
var _tex_frames: Array[TextureRect] = []       # 每槽回纹阶框贴图（有道具时替换 shader 框·与图鉴同款）
var _tex_frame_mats: Array[ShaderMaterial] = [] # 新框明暗母版按阶级重映射为蓝 / 紫 / 金
var _icon_shadows: Array[TextureRect] = []     # 道具图案 alpha 投影：格底之上、金属框之下
var _icons: Array[TextureRect] = []            # 道具图标层（缺图隐藏 → 回退文字·零回归）
var _icon_cache := {}                          # id → Texture2D / null（避免每帧 load/exists）
var _labels: Array[Label] = []                 # 仅缺图回退道具名（状态文字 2026-07-13 全退役）
var _buttons: Array[Button] = []
# ── 无文字状态语言部件（2026-07-13·同日二版：升条/▲pip 撤销→右键+费用章·Eddy 反馈）──
var _seals: Array[Control] = []                # 未解锁=斜贴封条（挂锁图标+剩余回合圆点）
var _seal_pips: Array[Array] = []              # 每封条 3 圆点
var _mini_seals: Array[Control] = []           # 锁中=角上半张小封条（带小挂锁）
var _pouches: Array[Control] = []              # 可抽/待抽/可补=锦囊（抽补同语言）
var _up_badges: Array[Button] = []             # 右上升箭角标（可点=升级·可升级且未点选时显示）
var _up_chevs: Array[Control] = []             # 角标内双升箭容器（跳动动效对象）
var _can_up: Array[bool] = [false, false, false]
var _anim_keys: Array[String] = ["", "", ""]   # 每槽 ambient 动效键（变更才重建 tween·恢复前必 kill）
var _anim_tweens: Array = [[], [], []]         # 每槽 ambient tween 列表（upN=框呼吸+角标跳双 tween）
var _prev_sealed: Array = [null, null, null]   # 上帧封印态（null=首刷不放撕封条动画）
var _prev_locked: Array = [null, null, null]
var _prev_staged: Array = [null, null, null]   # 上帧点选态（false→true 才放金晕 pop）


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


## 金晕外环材质（pixel_frame·与图鉴/英雄卡同 shader）：点选态金边·edge 色在 _ready 一次性设定。
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


func _make_texture_frame_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FRAME_PALETTE_SHADER
	_set_texture_frame_palette(m, 1)
	return m


func _set_texture_frame_palette(m: ShaderMaterial, tier: int) -> void:
	ItemFrameStyle.apply_frame_palette(m, tier)


func _ready() -> void:
	custom_minimum_size = Vector2(SLOT_W * 3 + GAP * 2, SLOT_H)
	# 根容器不拦截点击：只让每个槽的按钮(STOP)接收（否则上层 HUD 容器会吞点击）。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(3):
		var base := Vector2(i * (SLOT_W + GAP), 0.0)
		# 与回纹框完全同 alpha 轮廓的定向阴影；先于格底和框体加入，不产生矩形黑底。
		var bottom_shadow := ItemFrameStyle.make_frame_shadow(
				base + FRAME_ART_OFFSET, FRAME_ART_SIZE, "BottomShadow%d" % i,
				bottom_shadow_offset, bottom_shadow_color)
		bottom_shadow.visible = bottom_shadow_enabled
		add_child(bottom_shadow)
		# 暗格底（cell_bg）：稀有度暗底 + 中心高亮 + 传说金底图；颜色由 refresh 设。
		var cell := ColorRect.new()
		cell.color = Color.WHITE   # shader 乘 COLOR，须白
		cell.position = base + Vector2(CELL_INSET, CELL_INSET)
		cell.size = Vector2(SLOT_W - CELL_INSET * 2.0, SLOT_H - CELL_INSET * 2.0)
		var cmat := _make_cell_material()
		cell.material = cmat
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cell)
		var icon_position := base + Vector2(ICON_INSET, ICON_INSET)
		var icon_size := Vector2(SLOT_W - ICON_INSET * 2.0, SLOT_H - ICON_INSET * 2.0)
		var icon_shadow := ItemFrameStyle.make_item_art_shadow(
				null, icon_position, icon_size, "ItemArtShadow%d" % i)
		icon_shadow.visible = false
		add_child(icon_shadow)
		# 点选金晕外环（pixel_frame shader·金边·外扩 RING_PAD）：仅点选显示·衬在回纹框后（不再换框）。
		var frame := ColorRect.new()
		frame.color = Color.WHITE
		frame.position = base - Vector2(RING_PAD, RING_PAD)
		frame.size = Vector2(SLOT_W + RING_PAD * 2.0, SLOT_H + RING_PAD * 2.0)
		var fmat := _make_frame_material()
		fmat.set_shader_parameter("edge_outer", GOLD_STAGED.darkened(0.25))   # 外露 4px 必须是金（深咖会读成黑圈）
		fmat.set_shader_parameter("edge_mid", GOLD_STAGED)
		fmat.set_shader_parameter("edge_inner", GOLD_STAGED.darkened(0.5))
		frame.material = fmat
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.visible = false
		add_child(frame)
		# 回纹阶框贴图（有道具时显示·替换 shader 框·与图鉴同款素材）。
		var tframe := TextureRect.new()
		tframe.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tframe.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tframe.position = base + FRAME_ART_OFFSET
		tframe.size = FRAME_ART_SIZE
		var tfmat := _make_texture_frame_material()
		tframe.material = tfmat
		tframe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tframe.visible = false
		add_child(tframe)
		# 道具图标层（铺在框之上、文字之下；缺图隐藏 → 回退文字）。
		var icon := TextureRect.new()
		icon.position = icon_position
		icon.size = icon_size
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
		# ── 无文字状态语言部件（封条/小封条/锦囊·全 IGNORE·refresh 控显）──
		var seal := _make_seal(base)
		add_child(seal)
		var mseal := _make_mini_seal(base)
		add_child(mseal)
		var pouch := _make_pouch(base)
		add_child(pouch)
		var btn := Button.new()
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.position = base
		btn.size = Vector2(SLOT_W, SLOT_H)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP if (interactive or hoverable or targetable) \
				else Control.MOUSE_FILTER_IGNORE
		btn.pressed.connect(_on_slot_pressed.bind(i))
		btn.gui_input.connect(_on_slot_gui_input.bind(i))   # 右键=升级（快捷入口·与角标同信号）
		btn.mouse_entered.connect(_on_slot_hover.bind(i))
		btn.mouse_exited.connect(_on_slot_unhover)
		add_child(btn)
		# 升箭角标（右上·可点=升级）：金色双升箭+深描边·加在点击层之后=接管角标区点击。
		var badge := Button.new()
		badge.flat = true
		badge.focus_mode = Control.FOCUS_NONE
		badge.position = base + Vector2(SLOT_W - 18.0, -4.0)
		badge.size = Vector2(22.0, 22.0)
		badge.visible = false
		badge.pressed.connect(_on_up_badge_pressed.bind(i))
		badge.mouse_entered.connect(_on_slot_hover.bind(i))   # 角标区悬停仍算槽悬停（提示框不闪断）
		badge.mouse_exited.connect(_on_slot_unhover)
		var chev := _make_chevrons()
		badge.add_child(chev)
		add_child(badge)
		_cells.append(cell)
		_cell_mats.append(cmat)
		_frames.append(frame)
		_frame_mats.append(fmat)
		_bottom_shadows.append(bottom_shadow)
		_tex_frames.append(tframe)
		_tex_frame_mats.append(tfmat)
		_icon_shadows.append(icon_shadow)
		_icons.append(icon)
		_labels.append(lbl)
		_buttons.append(btn)
		_seals.append(seal)
		_mini_seals.append(mseal)
		_pouches.append(pouch)
		_up_badges.append(badge)
		_up_chevs.append(chev)


## 斜贴封条（未解锁）：米色纸条+深褐描边+剩余回合圆点居中（手贴微斜=封印语言·与匾/签同族·挂锁已退役）。
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
	var pips: Array = []
	for k in 3:
		var p := ColorRect.new()
		p.color = SEAL_PIP_INK
		p.size = Vector2(6.0, 6.0)
		p.position = Vector2(-15.0 + k * 12.0, -3.0)   # 三点整组居中（挂锁退役后左移补位）
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(p)
		pips.append(p)
	_seal_pips.append(pips)
	return root


## 角上半张小封条（锁中·冷却 1 回合）：短条斜贴左上角·单圆点=剩 1 回合。
## 斜度与大封条完全同角（-0.30·Eddy 2026-07-13：视觉一致优先——同为横条同角即同斜）。
func _make_mini_seal(base: Vector2) -> Control:
	var root := Control.new()
	root.position = base + Vector2(15.0, 13.0)
	root.rotation = -0.30
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
	var pip := ColorRect.new()
	pip.color = SEAL_PIP_INK
	pip.size = Vector2(6.0, 6.0)
	pip.position = Vector2(-3.0, -3.0)   # 单点居中=剩 1 回合
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pip)
	return root


## 锦囊（可抽/可补同语言·"打开锦囊得道具"）：双耳束口布袋居中·金绳勒口·绣纹菱点·可操作时轻浮动。
## 剪影两遍绘制：先描边层（每块外扩 1px·相邻块叠出整体轮廓）再填充层。
func _make_pouch(base: Vector2) -> Control:
	var root := Control.new()
	root.position = base + Vector2((SLOT_W - POUCH_W) * 0.5, (SLOT_H - POUCH_H) * 0.5)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	for pr: Array in POUCH_RECTS:
		var r: Rect2 = pr[0]
		var e := ColorRect.new()
		e.color = POUCH_EDGE
		e.position = r.position - Vector2.ONE
		e.size = r.size + Vector2.ONE * 2.0
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(e)
	for pr: Array in POUCH_RECTS:
		var f := ColorRect.new()
		f.color = pr[1]
		f.position = (pr[0] as Rect2).position
		f.size = (pr[0] as Rect2).size
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(f)
	var motif := ColorRect.new()   # 绣纹菱点（袋腹中心·与旧卡背菱纹同语言延续）
	motif.color = POUCH_MOTIF
	motif.size = Vector2(7.0, 7.0)
	motif.position = Vector2((POUCH_W - 7.0) * 0.5, 19.0)
	motif.pivot_offset = Vector2(3.5, 3.5)
	motif.rotation = 0.785
	motif.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(motif)
	return root


## 金色双升箭（∧∧·全 ColorRect 两遍=深描边底+金身·装进角标钮内）。
func _make_chevrons() -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rects: Array = []
	for cy: float in [3.0, 10.0]:   # 上下两道箭·每道 5 段阶梯
		rects.append(Rect2(9.0, cy, 4.0, 3.0))          # 箭尖
		rects.append(Rect2(6.0, cy + 2.0, 4.0, 3.0))    # 中段左右
		rects.append(Rect2(12.0, cy + 2.0, 4.0, 3.0))
		rects.append(Rect2(3.0, cy + 4.0, 4.0, 3.0))    # 外段左右
		rects.append(Rect2(15.0, cy + 4.0, 4.0, 3.0))
	for r: Rect2 in rects:
		var e := ColorRect.new()
		e.color = SEAL_EDGE_INK
		e.position = r.position - Vector2.ONE
		e.size = r.size + Vector2.ONE * 2.0
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(e)
	for r: Rect2 in rects:
		var c := ColorRect.new()
		c.color = GOLD_READY
		c.position = r.position
		c.size = r.size
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(c)
	return root


func _on_slot_pressed(slot: int) -> void:
	if interactive or targetable:
		slot_clicked.emit(slot)


## 升级快捷入口=右键点槽（主入口=升箭角标点击·两者同信号·费用见悬停提示）。
func _on_slot_gui_input(event: InputEvent, slot: int) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT \
			and interactive and _can_up[slot]:
		slot_upgrade_clicked.emit(slot)


## 升箭角标点击=升级（入口从纯右键改为可见可点——Eddy 2026-07-13：悬停文字讲解完全看不出来）。
func _on_up_badge_pressed(slot: int) -> void:
	if interactive and _can_up[slot]:
		slot_upgrade_clicked.emit(slot)


func _on_slot_hover(slot: int) -> void:
	if interactive or hoverable:
		slot_hovered.emit(slot)


func _on_slot_unhover() -> void:
	slot_unhovered.emit()


## 按经济状态刷新 3 个芯片（2026-07-13 重做：无文字状态语言——回纹框+封条/卡背/金币+动效）。
## staged：本回合已点选「使用」的槽位（仅 P1 传入；金边+图标下沉）。
func refresh(battle: BattleCore, player: int, staged: Array = [], concealed: bool = false) -> void:
	if battle == null or player < 0 or player >= battle.slots.size():
		return
	if battle.slots[player].size() < 3 or _cells.size() < 3:
		return
	for i in range(3):
		var st: int = battle.slot_state(player, i)
		var lbl: Label = _labels[i]
		var icon: TextureRect = _icons[i]
		var icon_shadow: TextureRect = _icon_shadows[i]
		icon.visible = false
		icon_shadow.visible = false
		lbl.text = ""                      # 状态文字全退役——label 只留缺图回退道具名
		var ft := SEAL_FT
		var fb := SEAL_FB                   # = 格底四角色（fill_color）
		var glow := 0.0
		var cell_inner := Color.WHITE
		var legend := false
		var has_item := false
		var sealed := st == BattleCore.SlotState.SEALED
		var locked_item := false           # 有道具但冷却锁中
		var anim := ""                     # ambient 动效键：cta（锦囊浮+框金呼吸）/ upN（升箭跳+升阶呼吸）/ 空
		var cur_tier := 1                  # 当前道具阶（upN 动效键用）
		var frame_tex: Texture2D = ITEM_FRAME_TEX   # 全状态统一框母版；无道具=暖骨中性
		var frame_mod := Color.WHITE
		_seals[i].visible = false
		_mini_seals[i].visible = false
		_pouches[i].visible = false
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
				# 可抽 = 锦囊轻浮动 + 框金呼吸（直接的"可点"信号）；本回合不能抽 = 锦囊静止压暗。
				ft = NEU_FT; fb = NEU_FB
				_pouches[i].visible = true
				if battle.can_draw_slot(player, i):
					_pouches[i].modulate = Color.WHITE
					if interactive:
						anim = "cta"
				else:
					frame_mod = Color(0.74, 0.72, 0.69)
					_pouches[i].modulate = Color(0.72, 0.72, 0.72)
			BattleCore.SlotState.CHARGING:
				var item: ItemData = null if concealed else battle.slot_item(player, i)
				has_item = item != null
				legend = has_item and item.tier >= 3        # 传说 → 格底用 gold_bottom 金底图
				if has_item:
					glow = 0.0 if legend else 1.0
				var tier_key: int = item.tier if item != null else 1
				cur_tier = tier_key
				var c_out: Color = CELL_FILL_T.get(tier_key, CELL_FILL_T[1])
				var c_in: Color = CELL_CENTER_T.get(tier_key, CELL_CENTER_T[1])
				var tex: Texture2D = _icon_for(item.item_id) if item != null else null
				if tex != null:
					icon.texture = tex
					icon_shadow.texture = tex
					icon.visible = true
					icon_shadow.visible = true
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
				# 可补 = 与可抽同语言（Eddy 定）：锦囊浮动+框金呼吸，补货费见悬停提示；不可补 = 纯空暗格。
				if battle.can_refill(player, i):
					ft = NEU_FT; fb = NEU_FB
					_pouches[i].visible = true
					_pouches[i].modulate = Color.WHITE
					if interactive:
						anim = "cta"
				else:
					ft = EMP_FT; fb = EMP_FB
					frame_mod = Color(0.60, 0.58, 0.55)
		# 无道具格：连续内渐变代替死平底（中心 ft 微亮·幅度克制）。
		if not has_item:
			glow = 0.45
			cell_inner = ft
		# 点选使用 = 金晕外环 + 框身提金 + 图标下沉 3px（回纹框保留不清除——Eddy 2026-07-13 五改）。
		var staged_now: bool = staged.has(i)
		icon.position.y = ICON_INSET + (3.0 if staged_now else 0.0)
		icon_shadow.position = icon.position + ItemFrameStyle.item_art_shadow_offset(icon.size)
		icon_shadow.self_modulate = Color(
				ItemFrameStyle.ITEM_ART_SHADOW_COLOR.r,
				ItemFrameStyle.ITEM_ART_SHADOW_COLOR.g,
				ItemFrameStyle.ITEM_ART_SHADOW_COLOR.b,
				ItemFrameStyle.ITEM_ART_SHADOW_COLOR.a * (0.65 if locked_item else 1.0))
		# 格底应用
		var cmat: ShaderMaterial = _cell_mats[i]
		if has_item:
			# 统一样式负责阶色、纵向渐变与传说贴图；战斗状态只附加锁定压暗。
			var state_tint := Color(0.68, 0.68, 0.68, 1.0) if locked_item else Color.WHITE
			ItemFrameStyle.apply_cell_palette(cmat, cur_tier, state_tint)
		else:
			# 空槽保留战斗 HUD 原有的柔和中心高光，避免改变状态语言。
			cmat.set_shader_parameter("fill_color", fb)
			cmat.set_shader_parameter("inner_color", cell_inner)
			cmat.set_shader_parameter("center_glow", glow)
			cmat.set_shader_parameter("vertical_gradient", 0.0)
			cmat.set_shader_parameter("material_lighting", 0.0)
			cmat.set_shader_parameter("use_tex", 0.0)
			cmat.set_shader_parameter("tex_top_darkening", 0.0)
		# 框应用：全状态=回纹贴图框（有道具=阶框/无道具=暖骨中性框）；点选叠金晕外环+框身提金（入场 pop 一次）。
		_tex_frames[i].visible = true
		_tex_frames[i].texture = frame_tex
		_set_texture_frame_palette(_tex_frame_mats[i], cur_tier)
		_tex_frames[i].modulate = STAGED_TINT if staged_now else frame_mod
		_frames[i].visible = staged_now
		if staged_now and _prev_staged[i] != true:
			_play_stage_pop(i)
		_prev_staged[i] = staged_now
		# 解锁演出：封条撕落（未解锁→解锁）/ 小封条飘走（锁中→就绪）+ 框弹亮（有 cta 呼吸时略过闪·防抢属性）。首刷不放。
		if _prev_sealed[i] == true and not sealed:
			_play_seal_tear(i, false, frame_mod, anim == "")
		if _prev_locked[i] == true and has_item and not locked_item:
			_play_seal_tear(i, true, frame_mod, anim == "")
		_prev_sealed[i] = sealed
		_prev_locked[i] = locked_item
		# 可升级（角标点击/右键·费用见悬停提示）：升箭角标显隐 + upN 升阶呼吸（点选时让位金晕）。
		_can_up[i] = interactive and battle.can_upgrade(player, i)
		_up_badges[i].visible = _can_up[i] and not staged_now
		if _up_badges[i].visible:
			anim = "up%d" % cur_tier
		_set_ambient(i, anim, STAGED_TINT if staged_now else frame_mod)


## ambient 动效：cta=锦囊浮动+框金呼吸（"本回合可点"）；upN=升箭轻跳+框向下一阶色呼吸（可升级）。
## 键变更才重建；恢复前必 kill 全部旧 tween（慢放 tween 教训）。
func _set_ambient(i: int, key: String, base_mod: Color) -> void:
	if _anim_keys[i] == key:
		return
	_anim_keys[i] = key
	for old: Tween in _anim_tweens[i]:
		if old != null and old.is_valid():
			old.kill()
	_anim_tweens[i] = []
	var cy := (SLOT_H - POUCH_H) * 0.5
	_pouches[i].position.y = cy
	_up_chevs[i].position.y = 0.0
	_tex_frames[i].modulate = base_mod   # 杀掉旧 tween 后必须复位（tween 残值会盖掉刚 apply 的状态色）
	if key == "cta":
		var tw := create_tween().set_loops()
		tw.set_parallel(true)
		tw.tween_property(_pouches[i], "position:y", cy - 2.0, 0.6)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_tex_frames[i], "modulate", Color(1.22, 1.14, 0.88), 0.6)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.chain().tween_property(_pouches[i], "position:y", cy + 1.0, 0.6)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(_tex_frames[i], "modulate", Color.WHITE, 0.6)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_anim_tweens[i].append(tw)
	elif key.begins_with("up"):
		# 升阶呼吸：回纹框 modulate 周期透向下一阶主色再回（"框想变成下一阶的颜色"）。
		var tint: Color = NEXT_TIER_TINT.get(int(key.substr(2)), Color.WHITE)
		var breath := create_tween().set_loops()
		breath.tween_property(_tex_frames[i], "modulate", tint, 1.2)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		breath.tween_property(_tex_frames[i], "modulate", Color.WHITE, 1.2)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_anim_tweens[i].append(breath)
		# 升箭轻跳：每 ~2s 上跳 2px 弹回（提醒入口·幅度克制不抢戏）。
		var hop := create_tween().set_loops()
		hop.tween_interval(1.7)
		hop.tween_property(_up_chevs[i], "position:y", -2.0, 0.10)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		hop.tween_property(_up_chevs[i], "position:y", 0.0, 0.18)\
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		_anim_tweens[i].append(hop)


## 点选入场 pop（一次性）：金晕外环从外扩 3px/全透明 收拢到位+淡入（0.14s·轻快不黏）。
func _play_stage_pop(i: int) -> void:
	var ring: ColorRect = _frames[i]
	var base := Vector2(float(i) * (SLOT_W + GAP), 0.0)
	var end_pos := base - Vector2(RING_PAD, RING_PAD)
	var end_size := Vector2(SLOT_W + RING_PAD * 2.0, SLOT_H + RING_PAD * 2.0)
	ring.position = end_pos - Vector2(3.0, 3.0)
	ring.size = end_size + Vector2(6.0, 6.0)
	ring.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ring, "position", end_pos, 0.14)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "size", end_size, 0.14)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 1.0, 0.14)


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
