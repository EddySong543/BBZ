extends Control

## 技能情报双钮（2026-07-17 Eddy 方案 A·取代 SkillCard 大卡）——左钮=己方 / 右钮=敌方。
##
## 形制：底部按钮同款像素果冻框（参数抄图鉴钮）·阵营染色（蓝=己方/红=敌方·压一档饱和
## 区分"可读的档案"与"能按的招式"）·钮面=该英雄专属技能图标·钮底三点 pip=当前第几人。
## 交互：悬停出介绍浮层（本组件只发信号·由 battle_screen 的 _tip_panel 呈现——复用既有
## 悬停提示家族）；左键=本侧下一个英雄·右键=上一个（教学行写在浮层内）；翻页时图标下沉
## 回弹一拍。默认跟随出战英雄：未悬停时每次 refresh 回落到 active_index·悬停中不打断。
## 位置由外部摆（battle_screen 放旧技能卡位·底缘对齐 1024 一线）。
##
## 用法（battle_screen）：
##   _skill_info = SkillInfoBtns.new(); add_child(_skill_info)
##   _skill_info.tip_requested.connect(...) / tip_dismissed.connect(...)
##   每次 _set_buttons_active / debug 改状态后调 refresh(battle)。

signal tip_requested(target: Control, text: String)   # 悬停进入 / 悬停中翻页 → 请求浮层
signal tip_dismissed                                   # 悬停离开

const BTN := 108.0           # 钮边长（2026-07-17 Eddy：与图鉴/结束同档·80 太小）
const GAP := 38.0            # 双钮间距（底部按钮排同律）
const ICON_RECT := Rect2(16.0, 16.0, 76.0, 76.0)   # 图标区=正中（2026-07-17 Eddy：与其他按钮一致）
# pip=三段指示条（2026-07-17 Eddy 二调：果冻框圆角+边缘收蚀→视觉体窄于 108 矩形，
# 总长收 96 居中对齐视觉体：28×3+6×2=96·左右各内缩 6）。
const PIP_W := 28.0
const PIP_H := 6.0
const PIP_GAP := 6.0
const PIP_X0 := 6.0          # 首段起点（(BTN-96)/2·与果冻视觉体对齐）
const PIP_Y := -12.0         # 悬于钮顶上方（pip 移出钮外·动作钮角标同区位）
const POP_DIP := 3.0         # 翻页图标下沉像素（点选下沉同语言）
const FOLLOW_BACK_DELAY := 2.5   # 悬停结束后多久回落跟随出战英雄（s·立即回跳太急——Eddy）

const JELLY_SHADER := preload("res://assets/shaders/canvas_button_jelly.gdshader")
# 阵营染色（比动作钮压一档饱和：档案柜不是糖果钮）；公共参数抄图鉴钮配方。
const FILL_TOP: Array[Color] = [Color(0.30, 0.45, 0.66), Color(0.62, 0.34, 0.28)]
const FILL_BOTTOM: Array[Color] = [Color(0.20, 0.31, 0.48), Color(0.47, 0.24, 0.19)]
const EDGE_INNER: Array[Color] = [Color(0.55, 0.75, 1.0), Color(1.0, 0.62, 0.50)]
const EDGE_OUTER := Color(0.1, 0.09, 0.11)
const PIP_ON := Color("ffd86a")                  # 当前英雄=亮金（就绪金同源）
const PIP_OFF := Color(0.45, 0.41, 0.35, 0.9)    # 其余=暖灰（钮外落在暗夜景上·暗点会隐形）

var _battle: BattleCore = null
var _idx: Array[int] = [0, 0]          # 每侧当前浏览的槽位
var _hover := -1                       # 悬停中的侧（-1=无）
var _btns: Array[Button] = []
var _icons: Array[TextureRect] = []
var _pips: Array = [[], []]            # 每侧 3 个 pip ColorRect
var _pop_tw: Array = [null, null]      # 翻页 pop tween（重翻先 kill）
var _follow_timers: Array = [null, null]   # 每侧回落缓冲计时（重进悬停即作废）
static var _tex_cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(BTN * 2.0 + GAP, BTN)
	for side in 2:
		var btn := Button.new()
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.position = Vector2(side * (BTN + GAP), 0.0)
		btn.size = Vector2(BTN, BTN)
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var bg := ColorRect.new()
		bg.name = "Bg"
		bg.material = _make_jelly(side)
		bg.show_behind_parent = true
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(bg)
		var icon := TextureRect.new()
		icon.position = ICON_RECT.position
		icon.size = ICON_RECT.size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon)
		var pip_row: Array = []
		for k in 3:
			var p := ColorRect.new()
			p.color = PIP_OFF
			p.size = Vector2(PIP_W, PIP_H)
			p.position = Vector2(PIP_X0 + k * (PIP_W + PIP_GAP), PIP_Y)
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(p)
			pip_row.append(p)
		btn.mouse_entered.connect(_on_enter.bind(side))
		btn.mouse_exited.connect(_on_exit.bind(side))
		btn.gui_input.connect(_on_input.bind(side))
		add_child(btn)
		_btns.append(btn)
		_icons.append(icon)
		_pips[side] = pip_row


func _make_jelly(side: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = JELLY_SHADER
	m.set_shader_parameter("fill_top", FILL_TOP[side])
	m.set_shader_parameter("fill_bottom", FILL_BOTTOM[side])
	m.set_shader_parameter("edge_inner", EDGE_INNER[side])
	m.set_shader_parameter("edge_outer", EDGE_OUTER)
	m.set_shader_parameter("fill_alpha", 1.0)
	m.set_shader_parameter("pixel_grid", 38.0)
	m.set_shader_parameter("corner", 0.22)
	m.set_shader_parameter("edge_px", 2.0)
	m.set_shader_parameter("aspect", 1.0)
	m.set_shader_parameter("noise_amt", 0.08)
	m.set_shader_parameter("wear", 0.24)
	m.set_shader_parameter("solid_rim", true)
	m.set_shader_parameter("rim_px", 1.5)
	return m


## 每次战斗状态刷新调用：未悬停且无回落缓冲的侧跟随出战英雄；
## 悬停中 / 缓冲期内（刚浏览完 2.5s 内）不打断浏览位。
func refresh(battle: BattleCore) -> void:
	if battle == null:
		return
	_battle = battle
	for side in 2:
		if _hover != side and _follow_timers[side] == null:
			_idx[side] = battle.active_index[side]
		_update_side(side)


func _hero(side: int) -> HeroData:
	var team: Array = _battle.heroes[side]
	if team.is_empty():
		return null
	_idx[side] = clampi(_idx[side], 0, team.size() - 1)
	return team[_idx[side]]


func _update_side(side: int) -> void:
	if _battle == null:
		return
	var h: HeroData = _hero(side)
	if h == null:
		return
	var icon: TextureRect = _icons[side]
	var path := h.skill_icon_path
	if path != "" and ResourceLoader.exists(path):
		if not _tex_cache.has(path):
			_tex_cache[path] = load(path)
		icon.texture = _tex_cache[path]
		icon.visible = true
	else:
		icon.visible = false
	var count: int = _battle.heroes[side].size()
	for k in 3:
		var p: ColorRect = _pips[side][k]
		p.visible = k < count
		p.color = PIP_ON if k == _idx[side] else PIP_OFF


## 浮层文案：英雄名·技能名（主动/被动）→ 技能描述 → 教学行。
## 换行交给 battle_screen 的 _wrap_fixed（保留手动 \n）。
func _tip_text(side: int) -> String:
	var h: HeroData = _hero(side)
	if h == null:
		return ""
	var sk: HeroSkill = _battle.get_skill(side, _idx[side])
	var is_active: bool = sk != null and (sk.has_active() or sk.has_free_switch())
	var kind: String = tr("主动") if is_active else tr("被动")
	var who: String = tr("己方") if side == 0 else tr("敌方")
	return "%s %s·%s（%s）\n%s\n%s" % [
		who, tr(h.hero_name), tr(h.skill_description), kind,
		tr(h.skill_detail), tr("左键下一个·右键上一个")]


func _on_enter(side: int) -> void:
	_hover = side
	_follow_timers[side] = null   # 重进悬停 → 作废未决的回落缓冲
	_btns[side].modulate = Color(1.08, 1.06, 1.0)
	tip_requested.emit(_btns[side], _tip_text(side))


func _on_exit(side: int) -> void:
	_btns[side].modulate = Color.WHITE
	if _hover == side:
		_hover = -1
		tip_dismissed.emit()
		_schedule_follow_back(side)


## 回落缓冲（2026-07-17 Eddy：移开立即跳回太急）：悬停结束 2.5s 后才回落跟随出战英雄；
## 期间重新悬停 / 再次调度即作废旧计时（比对 timer 引用·无需显式取消）。
func _schedule_follow_back(side: int) -> void:
	var t := get_tree().create_timer(FOLLOW_BACK_DELAY)
	_follow_timers[side] = t
	t.timeout.connect(func() -> void:
		if _follow_timers[side] != t:
			return   # 已被重进悬停/新缓冲作废
		_follow_timers[side] = null
		if _hover != side and _battle != null:
			_idx[side] = _battle.active_index[side]
			_update_side(side))


func _on_input(event: InputEvent, side: int) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		_cycle(side, 1)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		_cycle(side, -1)


## 翻页：本侧循环 + 图标下沉回弹一拍（点击有回应）；悬停中同步刷新浮层。
func _cycle(side: int, dir: int) -> void:
	if _battle == null:
		return
	var count: int = _battle.heroes[side].size()
	if count <= 0:
		return
	_idx[side] = (_idx[side] + dir + count) % count
	_update_side(side)
	var icon: TextureRect = _icons[side]
	if _pop_tw[side] != null and (_pop_tw[side] as Tween).is_valid():
		(_pop_tw[side] as Tween).kill()
	icon.position.y = ICON_RECT.position.y + POP_DIP
	var tw := create_tween()
	tw.tween_property(icon, "position:y", ICON_RECT.position.y, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pop_tw[side] = tw
	if _hover == side:
		tip_requested.emit(_btns[side], _tip_text(side))
