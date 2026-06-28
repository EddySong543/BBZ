extends Control

## 1920x1080. 布局在 battle_screen.tscn 可视化编辑（保留，勿动节点）。
## v4 引擎（BattleCore）+ 同时盲选 vs AI（决策 B1）。
## 你 = P0（下），对手 = P1（上，AI）。玩家选动作 → 确认 → AI 后台选 → 同时结算。
##
## 半点制：HP/护盾内部为半点，显示用 battle.hp_display()。

const A := ActionDef.Action
const ACTIVE := ActionDef.ACTIVE
const STORE := ActionDef.STORE   # 一鸣惊人 h22「空过/蓄势」哨兵动作

# 动作按钮"能量消耗"金币（1 能量 1 球）= battle_screen.tscn 内每个按钮下的 CostPips 节点，
# 位置/大小/间距在 Godot 编辑器里可视化调整（可视化设计·任务2）；代码只在运行时填入数量。

const CIRCLE_D := 160.0
const CIRCLE_GAP := 60.0
const CIRCLE_Y := 890.0
const SCREEN_W := 1920.0
const SCREEN_H := 1080.0

## 待选爱心垂直对齐基线带高度（= 自适应 pip 的上限），不同 maxHP 的爱心在其中居中（任务6）。
const HEART_BAND := 16.0
## 出战血条低血红闪阈值（HP 占比 ≤ 此值）；闪烁在 IconPipRow 内部实现（任务5：红光改到剩余血量爱心上）。
const LOW_HP_RATIO := 0.5

## 顶部 UI 整体下移量(px)：原布局太贴屏幕顶端 → 下沉一点留呼吸。改这一个数即可整组调整。
## 注：当前为运行时代码统一微调(编辑器里仍是基准位)；下移量定稿后可烘焙进 .tscn 使"所见=所得"。
const TOP_UI_DROP := 26.0   # 顶部 UI 整体下移量（2026-06-28 Eddy：44太多→回调到26）；0=复原原位
const BUBBLE_HEAD_RISE := 112.0  # 出招气泡锚点：角色显示容器「中心」上移此值（越大气泡越高·够高才不压角色）
const BUBBLE_SIDE_X := 100.0     # 出招气泡水平偏移：己方(P0)放头「右上」/ 敌方(P1)镜像「左上」（越大越往外侧·够大才不和角色重合）

## 顶部头像框尺寸（Eddy 要求整体放大一档·2026-06-20）。出战 / 替补；放大走「底固定向上长」
## （见 _enlarge_frames），不压下方血行/名字。原基准 72 / 68。
const FRAME_ACTIVE_SIZE := 80.0
const FRAME_BENCH_SIZE := 76.0

## 默认阵容 fallback：直接打开 battle_screen.tscn(F6) 测试用，BattleSetup 为空时启用。
const HERO_DATA_DIR := "res://assets/data/heroes/"
const DEFAULT_P0 := ["h01", "h05", "h06"]   # 子鼠 / 辰龙 / 巳蛇（首发 12 生肖）
const DEFAULT_P1 := ["h02", "h09", "h12"]   # 丑牛 / 申猴 / 亥猪（首发 12 生肖）

## 左侧调试测试按钮（满能量/满血/造伤/加盾）。发布或联机前设 false（或删整块）。
## 仅本地调试：直接改 BattleCore 状态后刷新，不走战斗结算管线。
const DEBUG_BUTTONS := true

## 各动画相位等待（秒），可在 Inspector 调。
@export var anim_phase_duration: float = 1.0
@export var action_phase_duration: float = 0.6
@export var turn_time_limit: int = 5   # 每回合思考时限（秒），归零自动结算；可在 Inspector 调

enum State { TURN_INTRO, PLAYER_SELECT, RESOLVING, HERO_SELECT, GAME_OVER }

var battle: BattleCore
var state: int = State.TURN_INTRO
var timer_seconds: int = 0

const PLAYER := 0   # 本地玩家固定 P0
const AI := 1       # 对手 AI

# ---- @onready: battle_screen.tscn 内预置节点（布局保留，路径勿改）----
@onready var timer_label: Label = $TimerLabel
@onready var status_label: Label = $StatusLabel
@onready var event_label: Label = $EventLabel
@onready var big_turn_label: Label = $BigTurnLabel

# 出战角色名(每回合随出战英雄更新) + 玩家伪 id(常驻·占位)。
@onready var p1_active_name: Label = $P1Hud/P1ActiveName
@onready var p2_active_name: Label = $P2Hud/P2ActiveName
@onready var p1_player_id: Label = $P1Hud/P1PlayerId
@onready var p2_player_id: Label = $P2Hud/P2PlayerId

@onready var p1_char_display: CharacterDisplay = $P1CharDisplay
@onready var p2_char_display: CharacterDisplay = $P2CharDisplay
@onready var p1_shadow: TextureRect = $P1Shadow
@onready var p2_shadow: TextureRect = $P2Shadow

# d 排版收纳：每个玩家 HUD(框+❤+名+id+主血条/能量)收进一个 Control 容器 → 整组一处定位。
@onready var p1_hud: Control = $P1Hud
@onready var p2_hud: Control = $P2Hud

@onready var p1_frames: Array[HeroFrame] = [$P1Hud/P1Frame0, $P1Hud/P1Frame1, $P1Hud/P1Frame2]
@onready var p2_frames: Array[HeroFrame] = [$P2Hud/P2Frame0, $P2Hud/P2Frame1, $P2Hud/P2Frame2]
# 待选英雄血量/护甲紧凑居中显示（ReserveHpRow·❤X[+灰❤X]·任务3b/4）。index 0 = 出战位 → null（出战血量看大心条）。
@onready var p1_frame_hp_rows: Array = [null, $P1Hud/P1Frame1HpRow, $P1Hud/P1Frame2HpRow]
@onready var p2_frame_hp_rows: Array = [null, $P2Hud/P2Frame1HpRow, $P2Hud/P2Frame2HpRow]
var p1_frame_slots: Array[int] = [-1, -1, -1]
var p2_frame_slots: Array[int] = [-1, -1, -1]

# ---- 技能展示格：顺序浏览 [己方0,1,2 → 对方0,1,2]，点击翻页 ----
var _skill_entries: Array = []   # [[player, slot], ...]
var _skill_index: int = 0

@onready var buttons_ctrl: Control = $Buttons
@onready var skill_card: SkillCard = $SkillCard
@onready var _death_switch_overlay: DeathSwitchOverlay = $DeathSwitchOverlay
@onready var game_timer: Timer = $GameTimer
@onready var stage: BattleStage = $Stage   # 多层视差舞台：受击震屏走 stage.shake 按 parallax_factor 分层（见 battle_stage.gd）

@onready var btn_charge: Button = $Buttons/BtnCharge
@onready var btn_attack: Button = $Buttons/BtnAttack
@onready var btn_big_attack: Button = $Buttons/BtnBigAttack
@onready var btn_defend: Button = $Buttons/BtnDefend
@onready var btn_big_defend: Button = $Buttons/BtnBigDefend
@onready var btn_special: Button = $Buttons/BtnSpecial
@onready var btn_confirm: Button = $Buttons/BtnConfirm

# 新美术 HUD：心形血珠 + 金币能量点（替换旧 EnergyBar / ArcHealthBar）。
@onready var p1_heart_row: IconPipRow = $P1Hud/P1HeartRow
@onready var p2_heart_row: IconPipRow = $P2Hud/P2HeartRow
@onready var p1_coin_row: IconPipRow = $P1Hud/P1CoinRow
@onready var p2_coin_row: IconPipRow = $P2Hud/P2CoinRow

# 道具栏（M2·占位）：程序化挂在各 HUD 下。P1=贴左(对齐左侧框组·28px 内边距)；
# P2=镜像右贴(右内边距=P1 左内边距)，由 _build_item_rows 随槽宽自动算，修「敌方框偏左」错位。
const ITEM_ROW_POS_P1 := Vector2(28.0, 150.0)   # 2026-06-28 Eddy：道具栏上移一些(168→150)
var p1_item_row: ItemSlotRow
var p2_item_row: ItemSlotRow
## M3：本回合已点选「使用」的道具槽（仅 P1）；确认时统一 use_slot 提交，进新回合清空。
var selected_item_slots: Array[int] = []
var _drafting := false   # draft 弹窗打开中：拦截重入 + 暂停回合计时
var _ai_rng := RandomNumberGenerator.new()   # 任务 B：AI 道具抽取选择用（与游戏 rng 分离）
var _ai: BattleAI                             # 试玩对手 = 与 sim 统一的同一套搜索 AI（_ready 实例化）

# ---- 选择 / 样式 ----
var action_btn_list: Array[Button] = []
var selected_action: int = -1
var selected_switch: int = -1
var selected_btn: Button = null

# ---- 黑暗卯兔 h16【疾风】：附加同种动作开关（程序化创建·不入 .tscn）----
var btn_jifeng: Button = null
var btn_store: Button = null   # 一鸣惊人 h22「蓄势/空过」按钮（在场有 h22 时显示·疾风开关之上）
var _double_armed: bool = false   # 本回合是否 armed「附加同种动作」（确认时随动作一起 select_double 提交）

# ---- 主动换人（任务5）：点替补框→框内显「切换」(armed)→再次点=选择(动画)→「结束」提交 ----
var _armed_switch_frame: int = -1   # 当前 armed 的替补框索引（1 / 2），-1=无
var _switch_selected: bool = false  # armed 框是否已进入"选择"态（高亮·待「结束」提交）

# ---- juice ----
# 受击震屏基幅（实际位移 = 基幅 × 各层 parallax_factor·见 scene1.tscn / battle_stage.gd）。
# 只在受击触发、克制；建筑无 idle 漂移（_ready 关 idle_drift），仅震时才动。F6 调幅在此。
const SHAKE_BIG := 12.0     # 大波命中
const SHAKE_HIT := 7.0      # 普通命中
const PUNCH_RELEASE := 0.35   # P3：大波前推命中后的回弹时长（落在 settle 内）
var _confirm_pulse: Tween   # 「结束」按钮的呼吸金光（有待确认动作时召唤点击）
var _cd_home: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]  # 立绘原位（前冲 juice 复位用）
var _shadow_home: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]  # 阴影原位（跟随角色水平位移用）
var _prev_hp_disp: Array[float] = [-1.0, -1.0]   # 上次显示的出战 HP（检测变化 → 心条 flinch 脉冲）
var _hitstop_token: int = 0   # hitstop(c) 防重叠：仅最后一次定格负责恢复 Engine.time_scale
var _act_focus_active: bool = false   # 执行动作期间镜头是否在偏焦（保留位·当前由 set_focus 直接驱动）
var _world: Control = null    # P2b：立绘+阴影的 dolly 组（运行期归组·与背景同对焦点统一推近）


# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_ai_rng.randomize()   # 任务 B：AI 道具抽取随机种子
	_ai = BattleAI.new(0, 2, 0, {})   # 与 sim 统一：同一套搜索 AI（随机种子·深度 2·基础评估）
	battle = BattleCore.new()
	var p0: Array = _resolve_team(BattleSetup.p1_heroes, DEFAULT_P0)
	var p1: Array = _resolve_team(BattleSetup.p2_heroes, DEFAULT_P1)
	BattleSetup.reset()   # 消费即清空：防止下一局（未经 BP）复用本局阵容
	battle.setup(p0, p1, randi())
	battle.econ_init()   # 启用道具经济（开局带 1 + 槽位状态机·M1）

	_init_buttons()
	_connect_frame_signals()
	game_timer.timeout.connect(_on_timer_tick)

	# P2（对手）立绘 + 头像朝左（面向中间）；记录立绘原位供前冲 juice 复位
	_cd_home[0] = p1_char_display.position
	_cd_home[1] = p2_char_display.position
	_shadow_home[0] = p1_shadow.position
	_shadow_home[1] = p2_shadow.position
	p2_char_display.flip_h = true
	# 建筑保持完全静止（去 idle 呼吸·Eddy 2026-06-21）；纵深感只在受击 shake 时由 stage 分层体现。
	stage.idle_drift = false
	_setup_world_group()   # P2b：立绘+阴影归入 dolly 组，随镜头推近与背景统一移动（须在 home 缓存后）
	for f in p2_frames:
		f.flip_h = true

	_nudge_top_ui_down()
	_build_debug_buttons()

	_build_skill_entries()
	skill_card.advance_requested.connect(_on_skill_card_advance)
	skill_card.back_requested.connect(_on_skill_card_back)   # 右键 → 上一个英雄
	_refresh_skill_card()

	# 低血红闪（任务5）：出战血条剩余爱心在 HP 占比低时红色呼吸（IconPipRow 内部实现）。
	for row in [p1_heart_row, p2_heart_row]:
		row.low_hp_flash = true
		row.low_hp_ratio = LOW_HP_RATIO

	_build_item_rows()
	_enlarge_frames()
	_update_all()
	_show_turn_intro()


## 离场恢复 time_scale=1：hitstop(c) 用全局 Engine.time_scale，若在定格瞬间切场景须复位，防下个场景慢动作。
func _exit_tree() -> void:
	Engine.time_scale = 1.0


## 顶部 UI 整组下移 TOP_UI_DROP 像素（避免太贴屏幕顶端）。
## d 收纳后：每个玩家 HUD 已收进 P1Hud/P2Hud 容器 → 只移动这两个父节点 + 两个中央标签即可，
## 不再逐节点平移（消除"各自独立锚定 → 零星错位"）。
func _nudge_top_ui_down() -> void:
	for n in [p1_hud, p2_hud, timer_label]:
		if n != null:
			(n as Control).position.y += TOP_UI_DROP


## BattleSetup 有阵容就用，否则用默认（直接跑 battle_screen.tscn 测试）。
func _resolve_team(setup_heroes: Array, fallback_ids: Array) -> Array:
	if setup_heroes != null and not setup_heroes.is_empty():
		return setup_heroes
	var t: Array = []
	for id in fallback_ids:
		var path: String = HERO_DATA_DIR + str(id) + ".tres"
		if ResourceLoader.exists(path):
			t.append(load(path))
		else:
			var h := HeroData.new()
			h.hero_id = id
			h.hero_name = id
			h.max_hp = 5
			t.append(h)
	return t


func _init_buttons() -> void:
	btn_charge.pressed.connect(_on_circle_pressed.bind(A.CHARGE, btn_charge))
	btn_attack.pressed.connect(_on_circle_pressed.bind(A.ATTACK, btn_attack))
	btn_big_attack.pressed.connect(_on_circle_pressed.bind(A.BIG_ATTACK, btn_big_attack))
	btn_defend.pressed.connect(_on_circle_pressed.bind(A.DEFEND, btn_defend))
	btn_big_defend.pressed.connect(_on_circle_pressed.bind(A.BIG_DEFEND, btn_big_defend))
	btn_special.pressed.connect(_on_circle_pressed.bind(ACTIVE, btn_special))
	btn_confirm.pressed.connect(_on_confirm_pressed)

	# 攒/波/大波/防/大防 用 HoverIcon 美术图标（节点在 battle_screen.tscn 内，编辑器可见可调）；
	# 技能按钮显示「技能」二字（详细说明仍放 tooltip，见 _layout_circles）。位置/尺寸由 .tscn 决定。
	btn_special.text = "技能"
	btn_confirm.text = "结束"

	for btn in [btn_charge, btn_attack, btn_big_attack, btn_defend, btn_big_defend, btn_special]:
		FontManager.apply_btn(btn, 16)
		btn.clip_text = true
		_attach_button_juice(btn)
	FontManager.apply_btn(btn_confirm, 16)
	btn_confirm.clip_text = true
	_attach_button_juice(btn_confirm)

	# 技能/结束二字放大 + 描边；底已改语义色（技能=紫 / 结束=绿·饱和底）→ 改亮米白字 + 暗描边，任何色底都清晰。
	FontManager.apply_btn(btn_special, 30)
	btn_special.add_theme_color_override("font_color", Color(0.98, 0.96, 0.9))   # 亮米白（压饱和底）
	btn_special.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.85))
	btn_special.add_theme_constant_override("outline_size", 4)

	FontManager.apply_btn(btn_confirm, 30)
	btn_confirm.add_theme_color_override("font_color", Color(0.98, 0.96, 0.9))   # 亮米白（压绿底）
	btn_confirm.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.85))
	btn_confirm.add_theme_constant_override("outline_size", 4)

	action_btn_list = [btn_charge, btn_attack, btn_big_attack, btn_defend, btn_big_defend, btn_special]

	# 疾风开关：程序化创建（不动 .tscn）。节奏=紫底圆角；位置/尺寸运行期跟「结束」键上方（_refresh_jifeng）。
	btn_jifeng = Button.new()
	btn_jifeng.name = "BtnJifeng"
	btn_jifeng.text = "疾风"
	btn_jifeng.focus_mode = Control.FOCUS_NONE
	btn_jifeng.clip_text = true
	btn_jifeng.size = Vector2(120.0, 56.0)
	var _jsb := StyleBoxFlat.new()
	_jsb.bg_color = Color(0.45, 0.38, 0.62)        # 节奏=紫（与技能同维度色系）
	_jsb.set_corner_radius_all(10)
	_jsb.set_border_width_all(2)
	_jsb.border_color = Color(0.85, 0.78, 0.5)     # 暖金边
	for st in ["normal", "hover", "pressed", "disabled"]:
		btn_jifeng.add_theme_stylebox_override(st, _jsb)
	FontManager.apply_btn(btn_jifeng, 22)
	btn_jifeng.add_theme_color_override("font_color", Color(0.98, 0.96, 0.9))
	btn_jifeng.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.85))
	btn_jifeng.add_theme_constant_override("outline_size", 4)
	_attach_button_juice(btn_jifeng)
	btn_jifeng.pressed.connect(_on_jifeng_pressed)
	btn_jifeng.visible = false
	buttons_ctrl.add_child(btn_jifeng)

	# 蓄势键（一鸣惊人 h22）：程序化创建；节奏=紫底圆角（与疾风同维度色系），运行期跟疾风开关上方。
	btn_store = Button.new()
	btn_store.name = "BtnStore"
	btn_store.text = "蓄势"
	btn_store.focus_mode = Control.FOCUS_NONE
	btn_store.clip_text = true
	btn_store.size = Vector2(120.0, 56.0)
	var _ssb := StyleBoxFlat.new()
	_ssb.bg_color = Color(0.45, 0.38, 0.62)        # 节奏=紫
	_ssb.set_corner_radius_all(10)
	_ssb.set_border_width_all(2)
	_ssb.border_color = Color(0.85, 0.78, 0.5)     # 暖金边
	for st in ["normal", "hover", "pressed", "disabled"]:
		btn_store.add_theme_stylebox_override(st, _ssb)
	FontManager.apply_btn(btn_store, 22)
	btn_store.add_theme_color_override("font_color", Color(0.98, 0.96, 0.9))
	btn_store.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.85))
	btn_store.add_theme_constant_override("outline_size", 4)
	_attach_button_juice(btn_store)
	btn_store.pressed.connect(_on_store_pressed)
	btn_store.visible = false
	buttons_ctrl.add_child(btn_store)

	# 镜头偏焦改由「执行动作」触发（见 _play_battle_anims）：波/大波→右聚敌、防/大防→左聚己、其余回正。
	# 旧「hover 底部按钮 → 推近」已取消（2026-06-23 Eddy）。

	# 动作按钮能量消耗金币数量（基础动作 cost 固定；攒/防=0 不显示）。技能键 cost 动态，随刷新更新。
	_set_cost_pips(btn_attack, ActionDef.BASE_ACTION_DEF[A.ATTACK]["cost"])
	_set_cost_pips(btn_big_attack, ActionDef.BASE_ACTION_DEF[A.BIG_ATTACK]["cost"])
	_set_cost_pips(btn_big_defend, ActionDef.BASE_ACTION_DEF[A.BIG_DEFEND]["cost"])

	FontManager.apply(timer_label, 32)   # 顶部常驻回合数(原倒计时位)·紧凑
	timer_label.add_theme_color_override("font_color", Color(0.95, 0.91, 0.8))   # 暖米白（压暗背景）
	FontManager.apply(status_label, 44)
	status_label.add_theme_color_override("font_color", Color(0.95, 0.91, 0.8))   # 暖米白
	FontManager.apply(big_turn_label, 72)   # 中间「回合开始」横幅 + 倒计时（72=12×6 整数倍·清晰）
	big_turn_label.add_theme_color_override("font_color", Color(0.95, 0.91, 0.8))   # 暖米白
	event_label.visible = false
	# 备选血量/护甲：现由 ReserveHpRow（❤X[+灰❤X]·自绘居中·任务3b/4）显示，字体/配色在组件内处理，无需此处设置。

	# 出战角色名 / 玩家 id 的字体·字号·颜色·描边·玩家id文本 全部在 battle_screen.tscn 设置
	# （像素字体 ttf 直接引用·import 已关 AA → 编辑器所见即所得，可在 Inspector 手调位置/大小）。
	# 代码只负责把角色名文本随出战英雄更新（见 _update_hero_frames）。


## 执行动作时的镜头偏焦方向：波/大波→+1(右·聚敌) / 防/大防→−1(左·聚己) / 其余→0(不偏·回正)。
func _focus_dir_for(action: int) -> float:
	match action:
		A.ATTACK, A.BIG_ATTACK:
			return 1.0
		A.DEFEND, A.BIG_DEFEND:
			return -1.0
		_:
			return 0.0


## P2b：把双方立绘 + 阴影归入一个"世界组"容器，整体随镜头推近（与背景舞台同对焦点 → 统一移动）。
## 运行期归组、不改 .tscn（Eddy 编辑器里仍是根节点下的 4 个子节点）；容器置于 Stage 之后、
## dust/后处理/UI 之前 → GodRay/PostFX 仍抓得到角色，UI 仍在最上层不动。
## 容器缩放与角色自身 pop/前冲 juice 在场景图里相乘合成、互不打架（受击 pop 不会被 dolly 吃掉）。
func _setup_world_group() -> void:
	_world = Control.new()
	_world.name = "WorldGroup"
	_world.set_anchors_preset(Control.PRESET_FULL_RECT)
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 显式 position 数学绕 stage.focal() 缩放（与背景同一动态对焦点·焦点随动作偏置）→ pivot 留 0。
	add_child(_world)
	move_child(_world, stage.get_index() + 1)   # 紧跟 Stage、在 dust/后处理/UI 之前
	for n in [p1_shadow, p2_shadow, p1_char_display, p2_char_display]:
		n.reparent(_world, true)   # keep_global_transform → 静止画面一像素不变


func _connect_frame_signals() -> void:
	# 主动换人：点击己方替补头像（索引 1 / 2）→ 头像下浮现「切换」小按钮（见 _on_reserve_frame_input）。
	# 出战位（索引 0）不可点（不能换成自己）。对手框不连接。
	for fi in [1, 2]:
		p1_frames[fi].gui_input.connect(_on_reserve_frame_input.bind(fi))


# ============================================================
# 技能展示格（点击翻页浏览全部英雄技能：己方 → 对方）
# ============================================================

## 构建浏览顺序：先己方 3 个（含替补），再对方 3 个，按阵容槽位顺序。
func _build_skill_entries() -> void:
	_skill_entries.clear()
	for p in [PLAYER, AI]:
		for slot in range(battle.heroes[p].size()):
			_skill_entries.append([p, slot])
	_skill_index = 0


## 把当前选中的英雄填进展示格。主动/被动取自运行时技能组件（h07 当先按主动算）。
func _refresh_skill_card() -> void:
	if _skill_entries.is_empty():
		return
	var e: Array = _skill_entries[_skill_index % _skill_entries.size()]
	var p: int = int(e[0])
	var slot: int = int(e[1])
	var h: HeroData = battle.heroes[p][slot]
	var sk: HeroSkill = battle._skills[p][slot]
	var is_active: bool = sk != null and (sk.has_active() or sk.has_free_switch())
	# 立绘一律朝右；阵营靠底色区分（己方冷蓝 / 对方暖红）。
	skill_card.populate(h.hero_name, h.skill_description, h.skill_detail, is_active, h.portrait_path, p == PLAYER)


## 左键点击展示格 → 翻到下一个英雄，循环。
func _on_skill_card_advance() -> void:
	if _skill_entries.is_empty():
		return
	_skill_index = (_skill_index + 1) % _skill_entries.size()
	_refresh_skill_card()


## 右键点击展示格 → 翻回上一个英雄，循环。
func _on_skill_card_back() -> void:
	if _skill_entries.is_empty():
		return
	_skill_index = (_skill_index - 1 + _skill_entries.size()) % _skill_entries.size()
	_refresh_skill_card()


# ============================================================
# 回合流程（同时盲选）
# ============================================================

func _show_turn_intro() -> void:
	state = State.TURN_INTRO
	_set_buttons_active(false, true)   # 回合介绍：动作栏整体压暗 + 禁用（灰色·防误触；进入选择阶段再亮）
	status_label.visible = false
	event_label.visible = false

	# 顶部中间：持续显示回合数（每回合更新，整局常驻）。「回合」与数字间留一空格，避免拥挤。
	timer_label.text = "回合 %d" % (battle.turn_number + 1)
	timer_label.visible = true

	# 中间：先「回合开始」横幅，随后(进入选择)在同一位置转为倒计时（无底板）
	big_turn_label.text = "回合开始"
	big_turn_label.visible = true
	await get_tree().create_timer(1.0).timeout
	_start_player_select()


func _start_player_select() -> void:
	state = State.PLAYER_SELECT
	selected_action = -1
	selected_switch = -1
	selected_btn = null
	_double_armed = false
	selected_item_slots.clear()   # M3：每回合重置「本回合使用」点选
	status_label.visible = false   # 去除「选择你的动作」提示
	event_label.visible = false
	_set_buttons_active(true)
	_update_all()
	_start_timer()


func _start_timer() -> void:
	timer_seconds = turn_time_limit
	big_turn_label.visible = true   # 中间显示倒计时（接续「回合开始」横幅）
	_update_timer_label()
	game_timer.start(1.0)


func _on_timer_tick() -> void:
	timer_seconds -= 1
	_update_timer_label()
	if timer_seconds <= 0:
		game_timer.stop()
		if state == State.PLAYER_SELECT:
			_on_confirm_pressed()


func _update_timer_label() -> void:
	# 倒计时显示在中间(big_turn_label)；顶部 timer_label 常驻回合数不动。
	big_turn_label.text = "%d" % maxi(timer_seconds, 0)


func _on_circle_pressed(action: int, btn: Button) -> void:
	if state != State.PLAYER_SELECT:
		return
	if action == ACTIVE and not battle.can_use_active(PLAYER):
		return

	# 再点同一个 = 取消
	if selected_btn == btn:
		selected_action = -1
		selected_switch = -1
		selected_btn = null
		_reset_button_styles()
		_update_button_states()
		return

	selected_action = action
	selected_switch = -1
	_reset_button_styles()
	selected_btn = btn
	_set_btn_selected(btn, true)
	_set_confirm_active(true)
	_refresh_jifeng()   # 新选的动作是否可双 → 更新疾风开关


func _on_confirm_pressed() -> void:
	if state != State.PLAYER_SELECT:
		return
	game_timer.stop()

	# 玩家提交（未选 → 默认攒）
	if selected_action == ACTIVE:
		battle.select_active(PLAYER)
	elif selected_action == A.SWITCH and selected_switch >= 0:
		battle.select_switch(PLAYER, selected_switch)
	elif selected_action >= 0:
		battle.select_action(PLAYER, selected_action)
		if _double_armed and battle.can_double(PLAYER):
			battle.select_double(PLAYER, true)   # 疾风：附加同种动作随主动作一起盲选提交
	else:
		battle.select_action(PLAYER, A.CHARGE)

	# M3：提交本回合点选的道具（不占动作槽，与动作一起盲选结算）。
	for s in selected_item_slots:
		battle.use_slot(PLAYER, s)
	selected_item_slots.clear()

	# AI 选择
	_ai_pick(AI)

	selected_action = -1
	selected_switch = -1
	selected_btn = null
	_double_armed = false
	_reset_button_styles()
	_set_confirm_active(false)   # 停止呼吸：已确认提交
	await _resolve()


func _ai_pick(side: int) -> void:
	# 与 sim 统一：同一套 BattleAI 逻辑——价值搜索道具经济(plan_economy·B) + 同时博弈选动作(choose_action)。
	# 取代旧「随机加权出招」占位 AI；试玩与平衡模拟现共用一套决策。AI 不偷看玩家已锁动作（搜索按博弈枚举）。
	_ai.plan_economy(battle, side, _ai_rng)
	var choice: Dictionary = _ai.choose_action(battle, side)
	if not battle.apply_choice(side, choice):
		battle.select_action(side, A.CHARGE)   # 兜底（被禁/付不起→引擎 resolve guard 也兜）


func _resolve() -> void:
	state = State.RESOLVING
	_set_buttons_active(false)
	big_turn_label.visible = false   # 收起中间倒计时（顶部回合数保留）
	status_label.visible = false

	var a0_before: int = battle.active_index[0]
	var a1_before: int = battle.active_index[1]

	var r: Dictionary = battle.resolve()

	# 死亡判定：结算前的出战槽 HP 归零
	var p0_dead: bool = battle.hp[0][a0_before] <= 0
	var p1_dead: bool = battle.hp[1][a1_before] <= 0
	# 受伤量（半点）从 events 累加，准确（不受甲时机换人影响）
	var dmg: Array[int] = [0, 0]
	for ev in r.get("events", []):
		if ev.get("id", "") == "damage_taken":
			dmg[int(ev.get("player", 0))] += int(ev.get("amount", 0))

	# 头顶招式圆圈（揭示双方盲选出招）→ 消失 → 再播打斗动画
	await _show_action_indicators(r.get("p1_action", -1), r.get("p2_action", -1))
	await _play_battle_anims(r.get("p1_action", -1), r.get("p2_action", -1), dmg, [p0_dead, p1_dead])
	_update_all()

	if r.get("game_over", false):
		state = State.GAME_OVER
		var w: int = r.get("winner", BattleCore.WINNER_UNDECIDED)
		var msg := "平局"
		var col := Color("#dddddd")
		if w == BattleCore.WINNER_P1:
			msg = "你胜利！"
			col = Color("#5fd86b")
		elif w != BattleCore.WINNER_DRAW:
			msg = "你失败"
			col = Color("#e0574b")
		status_label.text = msg
		status_label.add_theme_color_override("font_color", col)
		status_label.visible = true
		return

	# AI 死亡换人：与 sim 统一，用搜索 AI 对位选替补（choose_death_switch）；异常兜底首个存活替补。
	if battle.pending_death_switch[AI]:
		var ai_slot: int = _ai.choose_death_switch(battle, AI)
		if ai_slot < 0:
			var ai_reserves: Array[int] = battle.living_reserves(AI)
			ai_slot = ai_reserves[0] if ai_reserves.size() > 0 else -1
		if ai_slot >= 0:
			battle.execute_death_switch(AI, ai_slot)
		_update_all()

	# 玩家死亡换人：弹浮窗
	if battle.pending_death_switch[PLAYER]:
		await _show_death_switch_selection(PLAYER)

	await get_tree().create_timer(maxf(0.1, anim_phase_duration * 0.5)).timeout
	_show_turn_intro()


func _show_death_switch_selection(player: int) -> void:
	state = State.HERO_SELECT
	_set_buttons_active(false)
	status_label.visible = false   # 不在屏幕中间显示「英雄阵亡」，只保留换人界面

	var reserves: Array = []
	for slot in battle.living_reserves(player):
		reserves.append([slot, battle.heroes[player][slot], battle.hp_display(battle.hp[player][slot])])

	_death_switch_overlay.show_selection(player, reserves)
	var selected_slot: int = await _death_switch_overlay.selection_made
	battle.execute_death_switch(player, selected_slot)
	_update_all()


# ============================================================
# 英雄框交互（切换 / h07 免费切）
# ============================================================

## 点击己方替补头像（任务5）：
## 第一次点 → 该框立绘变「切换」二字（armed·仅提示）；
## 再次点同框 → 做「选择」动画(弹跳+高亮·与底部按钮一致)，把换人选为本回合动作；
## 第三次点同框 → 取消选择(回 armed)。选定后点「结束」=提交换人并结算回合(可提前结束)。
## h07 当先 = 免费即时换(不占动作·本回合继续)，第二次点即换。
func _on_reserve_frame_input(event: InputEvent, frame_idx: int) -> void:
	if state != State.PLAYER_SELECT:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return

	# 右键 = 回退一步（仅对当前 armed 的框）：选择(发光)→普通切换→角色立绘（任务2）。
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		if _armed_switch_frame == frame_idx:
			if _switch_selected:
				_deselect_switch()            # 发光选中 → 普通「切换」
			else:
				_disarm_switch()              # 「切换」armed → 恢复角色立绘
		return

	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	# 仅存活替补可换；空位 / 阵亡 / 出战位不响应。
	if not _is_switchable_reserve(frame_idx):
		return
	if _armed_switch_frame != frame_idx:
		_arm_switch_frame(frame_idx)          # 第一次左键 → armed（框内显「切换」）
		return
	# 同一框再次左键：
	if battle.is_free_switch_target(PLAYER, p1_frame_slots[frame_idx]):
		_free_switch_now(frame_idx)           # 午马当先：涉及马的切换即时免费（马在场重定位 / 顶马上场）
	elif _switch_selected:
		_deselect_switch()                    # 已选 → 取消（回 armed）
	else:
		_select_switch(frame_idx)             # armed → 选择（动画+高亮·待「结束」提交）


## 该替补框是否可换人（索引 1/2、槽位有效、存活、非出战位；缠绕时全锁）。
func _is_switchable_reserve(frame_idx: int) -> bool:
	if frame_idx < 1 or frame_idx >= p1_frames.size():
		return false
	if not battle._can_switch(PLAYER):
		return false   # 缠绕：对手出战是黑暗巳蛇 → 锁住主动切换
	var slot: int = p1_frame_slots[frame_idx]
	return slot >= 0 and slot != battle.active_index[PLAYER] and battle.hp[PLAYER][slot] > 0


## 进入 armed 态：该框立绘 → 「切换」二字；先取消其它框的 armed + 清掉已选动作高亮（点切换=放弃已选动作）。
func _arm_switch_frame(frame_idx: int) -> void:
	_disarm_switch()
	_clear_action_selection_full()
	_armed_switch_frame = frame_idx
	_switch_selected = false
	p1_frames[frame_idx].set_switch_prompt(true)


## 选择换人：框做选择弹跳动画 + 高亮(与底部按钮一致)，把 switch 设为本回合动作；「结束」呼吸提示提交。
func _select_switch(frame_idx: int) -> void:
	selected_action = A.SWITCH
	selected_switch = p1_frame_slots[frame_idx]
	selected_btn = null
	p1_frames[frame_idx].is_selected = true
	_switch_selected = true
	_set_confirm_active(true)


## 取消换人选择（回 armed：仍显「切换」，去高亮·停结束呼吸）；不退出 armed。
func _deselect_switch() -> void:
	if _armed_switch_frame >= 0 and _armed_switch_frame < p1_frames.size():
		p1_frames[_armed_switch_frame].is_selected = false
	selected_action = -1
	selected_switch = -1
	_switch_selected = false
	_set_confirm_active(false)


## 退出 armed 态：恢复立绘、去选中高亮。
func _disarm_switch() -> void:
	if _armed_switch_frame >= 0 and _armed_switch_frame < p1_frames.size():
		var f: HeroFrame = p1_frames[_armed_switch_frame]
		f.is_selected = false
		f.set_switch_prompt(false)
	_armed_switch_frame = -1
	_switch_selected = false


## h07 当先：免费即时换（不占动作·本回合继续行动）。
func _free_switch_now(frame_idx: int) -> void:
	var slot: int = p1_frame_slots[frame_idx]
	if slot < 0:
		return
	_disarm_switch()
	if battle.free_switch(PLAYER, slot):
		selected_action = -1
		selected_switch = -1
		selected_btn = null
		_reset_button_styles()
		_update_all()


## 清掉底部动作按钮的选中高亮 + 结束呼吸 + 选择状态（点切换或换框时放弃已选动作）。
func _clear_action_selection_full() -> void:
	selected_action = -1
	selected_switch = -1
	selected_btn = null
	for btn in action_btn_list:
		_set_btn_selected(btn, false)
	_set_confirm_active(false)


# ============================================================
# 按钮布局 / 状态
# ============================================================

## active=true：选择阶段，按钮按真实可用性亮/暗 + 可点。
## active=false 时按 dim_inactive 区分：
##   true（结算 / 换人 / 游戏结束）→ 全禁用 + 整体降透明度 0.4（不消失，保留"不可操作"反馈）；
##   false（开局 / 回合介绍）→ 仍按真实可用性显示亮/暗、不整体压暗，仅靠 state 守卫拦截点击
##     → 开局就是"正常"的按钮，不再一上来一片半透明（任务1）。
func _set_buttons_active(active: bool, dim_inactive: bool = true) -> void:
	if not active:
		_disarm_switch()   # 离开选择阶段 → 退出 armed「切换」态
		if btn_jifeng:
			btn_jifeng.visible = false   # 结算/过场：藏疾风开关
		if btn_store:
			btn_store.visible = false    # 结算/过场：藏蓄势键
	# 底部 UI 始终可见。
	for btn in action_btn_list + [btn_confirm]:
		btn.visible = true
	_layout_circles()
	var show_affordance := active or not dim_inactive
	var alpha := 1.0 if show_affordance else 0.4
	buttons_ctrl.modulate = Color(1, 1, 1, alpha)
	if skill_card:
		skill_card.visible = true
		skill_card.modulate = Color(1, 1, 1, alpha)
	if show_affordance:
		_refresh_action_affordance()   # 按能量显示亮/暗（开局与选择阶段一致）
	else:
		for btn in action_btn_list + [btn_confirm]:
			btn.disabled = true        # 结算/过场：全禁用
	_refresh_skill_card()


## 编辑器可摆位：按钮位置/尺寸全部读 .tscn，代码只管显隐与技能 tooltip，不再覆盖坐标。
## 在 Godot 里随意移动/缩放 Buttons 下的按钮即可，运行时不会被弹回。
func _layout_circles() -> void:
	var has_active: bool = _player_has_active()
	btn_special.visible = has_active
	if has_active:
		# 技能按钮无文字，技能说明放 tooltip（悬停可见，信息不丢）。
		btn_special.tooltip_text = battle.active_hero(PLAYER).skill_description
	for btn in [btn_charge, btn_attack, btn_big_attack, btn_defend, btn_big_defend]:
		btn.visible = true
	btn_confirm.visible = true


## 出战英雄是否有主动技（访问 _skills，下划线约定但可读）。
func _player_has_active() -> bool:
	var sk: HeroSkill = battle._skills[PLAYER][battle.active_index[PLAYER]]
	return sk != null and sk.has_active()


func _reset_button_styles() -> void:
	for btn in action_btn_list:
		_set_btn_selected(btn, false)
	if btn_store != null:
		_set_btn_selected(btn_store, false)   # 蓄势键不在 action_btn_list，单独清选中态
	_set_confirm_active(false)
	_disarm_switch()   # 退出 armed「切换」态（换人选中随之消失）


## 给按钮挂 ButtonJuice 交互手感组件（幂等：已挂则跳过）。
func _attach_button_juice(btn: BaseButton) -> void:
	if btn.get_node_or_null("ButtonJuice") == null:
		var bj := ButtonJuice.new()
		bj.name = "ButtonJuice"
		btn.add_child(bj)


## 选中态视觉：果冻底常显，选中按钮整体提亮 + 从中心放大（缩放手感交给 ButtonJuice 弹性处理）。
## （不再用不透明 StyleBox 盖住果冻 —— 那正是"点击后变回老版"的根因）。
func _set_btn_selected(btn: Button, on: bool) -> void:
	# B「典籍朱印」：羊皮按钮选中态镀金箔 —— 暖金提亮 modulate，呼应金箔高亮语言（与 skill_card 同体系）。
	btn.modulate = Color(1.5, 1.32, 0.82) if on else Color.WHITE
	var juice := btn.get_node_or_null("ButtonJuice") as ButtonJuice
	if juice != null:
		juice.set_selected(on)   # 弹性放大/复位（带 overshoot）
	else:
		btn.pivot_offset = btn.size * 0.5
		btn.scale = Vector2.ONE * (1.08 if on else 1.0)
	# 任务7：选中该动作按钮后，让按钮内的美术图标持续播 idle（取消选中则回静止帧）。
	var hi := btn.get_node_or_null("HoverIcon") as HoverIcon
	if hi != null:
		hi.set_selected_play(on)


## 结束按钮"可确认"召唤：有待确认动作时**呼吸金光**，明确区分「已选定」与「已确认」——
## 选了动作只是待提交，必须再点「结束」才出招，呼吸把玩家视线引到这一步（修"选完以为就完了"的错觉）。
func _set_confirm_active(on: bool) -> void:
	if _confirm_pulse and _confirm_pulse.is_valid():
		_confirm_pulse.kill()
	if on:
		_confirm_pulse = create_tween().set_loops()
		_confirm_pulse.tween_property(btn_confirm, "modulate", Color(1.75, 1.6, 1.2), 0.55) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_confirm_pulse.tween_property(btn_confirm, "modulate", Color(1.28, 1.3, 1.12), 0.55) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		btn_confirm.modulate = Color.WHITE


func _update_button_states() -> void:
	if state != State.PLAYER_SELECT:
		return
	_refresh_action_affordance()


## 按真实能量/可用性刷新每个动作按钮的 disabled（= 图标亮/暗 + 能否点）。
## 不依赖 state：开局回合介绍阶段也据此显示正确的亮/暗，能否实际操作交给 state 守卫拦截。
func _refresh_action_affordance() -> void:
	_layout_circles()
	for btn in action_btn_list:
		if not btn.visible:
			continue
		if btn == btn_special:
			btn.disabled = not battle.can_use_active(PLAYER)
		else:
			var act: int = _btn_action(btn)
			btn.disabled = not battle.can_afford(PLAYER, act)
	# 技能键能量消耗随出战英雄主动技动态变化（0 不显示）。
	_set_cost_pips(btn_special, battle._get_cost(PLAYER, ACTIVE))
	btn_confirm.disabled = false
	_refresh_jifeng()
	_refresh_store()


## 疾风开关（点击 = arm/disarm「附加同种动作」）。仅当前已选动作可双时有效。
func _on_jifeng_pressed() -> void:
	if state != State.PLAYER_SELECT:
		return
	if not battle.can_double_action(PLAYER, selected_action):
		return
	_double_armed = not _double_armed
	_refresh_jifeng()


## 蓄势键（一鸣惊人 h22）：点击 = 选「空过/蓄势」动作（再点取消）。空过 0 能、无防御、存行动。
func _on_store_pressed() -> void:
	if state != State.PLAYER_SELECT or not battle.can_store(PLAYER):
		return
	if selected_action == STORE:   # 再点同一个 = 取消
		selected_action = -1
		selected_switch = -1
		selected_btn = null
		_reset_button_styles()
		_update_button_states()
		return
	selected_action = STORE
	selected_switch = -1
	_reset_button_styles()
	selected_btn = null   # 蓄势键不在 action_btn_list，单独高亮（_refresh_store 据 selected_action 刷）
	_set_btn_selected(btn_store, true)
	_set_confirm_active(true)
	_refresh_jifeng()     # 空过不可双 → 疾风开关随之失效


## 刷新疾风开关：在场有疾风英雄 → 显示（结束键正上方）；已选可双动作 → 可点；armed 态高亮 + 剩余次数。
func _refresh_jifeng() -> void:
	if btn_jifeng == null:
		return
	if not battle.has_double(PLAYER):
		_double_armed = false
		btn_jifeng.visible = false
		return
	btn_jifeng.visible = true
	btn_jifeng.size = btn_confirm.size
	btn_jifeng.position = btn_confirm.position + Vector2(0.0, -btn_confirm.size.y - 12.0)
	var ok: bool = battle.can_double_action(PLAYER, selected_action)
	if not ok:
		_double_armed = false
	btn_jifeng.disabled = not ok
	# 标签随来源自适应：在场有疾风(h16) → 「疾风」；否则双动作来自 h22 存储 → 「爆发」(释放蓄势)。
	var is_jifeng: bool = battle._double_grantor(PLAYER) >= 0
	btn_jifeng.text = ("疾风×%d" if is_jifeng else "爆发×%d") % battle.double_uses_left(PLAYER)
	_set_btn_selected(btn_jifeng, _double_armed)


## 刷新蓄势键（一鸣惊人 h22）：在场有 h22 且存储未满 → 显示（疾风开关之上；疾风不显时退到结束键之上）。
## 标签带当前存储数；选中态据 selected_action 高亮。
func _refresh_store() -> void:
	if btn_store == null:
		return
	if not battle.can_store(PLAYER):
		if selected_action == STORE:
			selected_action = -1   # 失去存储能力（h22 全死/存满）→ 撤销已选空过
		btn_store.visible = false
		return
	btn_store.visible = true
	btn_store.size = btn_confirm.size
	var base_y: float = btn_confirm.position.y - btn_confirm.size.y - 12.0
	if btn_jifeng != null and btn_jifeng.visible:
		base_y -= btn_confirm.size.y + 12.0   # 疾风开关也显时，蓄势键再上移一格
	btn_store.position = Vector2(btn_confirm.position.x, base_y)
	btn_store.disabled = false
	var n: int = battle.stored_action[PLAYER]
	btn_store.text = "蓄势×%d" % n if n > 0 else "蓄势"
	_set_btn_selected(btn_store, selected_action == STORE)


func _btn_action(btn: Button) -> int:
	if btn == btn_charge: return A.CHARGE
	if btn == btn_attack: return A.ATTACK
	if btn == btn_big_attack: return A.BIG_ATTACK
	if btn == btn_defend: return A.DEFEND
	if btn == btn_big_defend: return A.BIG_DEFEND
	return -1


## 填入动作按钮的能量消耗 = 一个金币 + 内嵌数字（= bp 血量同款 IconBadge·cost≤0 隐藏）。
## CostPips 节点已在 battle_screen.tscn 内预置（编辑器可视化摆位/调大小·4 按钮统一以 BtnAttack 为准），
## 代码只填数字·不再创建/定位。
func _set_cost_pips(btn: Button, cost: int) -> void:
	var badge := btn.get_node_or_null("CostPips") as IconBadge
	if badge == null:
		return
	badge.visible = cost > 0
	if cost > 0:
		badge.set_number(int(round(cost / float(ActionDef.ENERGY_UNIT))))   # cost 为半能 → 显示整能


# ============================================================
# 刷新显示
# ============================================================

## M2：在各玩家 HUD 下挂道具栏（程序化占位·位置由 ITEM_ROW_POS_* 控制）。
func _build_item_rows() -> void:
	p1_item_row = ItemSlotRow.new()
	p1_item_row.position = ITEM_ROW_POS_P1
	p1_item_row.interactive = true   # M3：本地玩家行可点击
	p1_item_row.slot_clicked.connect(_on_p1_slot_clicked)
	p1_item_row.slot_upgrade_clicked.connect(_on_p1_slot_upgrade)   # C：升级角标
	p1_hud.add_child(p1_item_row)
	p2_item_row = ItemSlotRow.new()   # P2 = AI·道具-blind（ADR D9）→ 仅显示
	# 右贴镜像 P1：P2 右内边距 = P1 左内边距(28) → 与右侧 P2 框组对齐(修敌方道具行偏左)。
	var row_w := ItemSlotRow.SLOT_W * 3.0 + ItemSlotRow.GAP * 2.0
	p2_item_row.position = Vector2(SCREEN_W - ITEM_ROW_POS_P1.x - row_w, ITEM_ROW_POS_P1.y)
	p2_hud.add_child(p2_item_row)


## 顶部头像框整体放大一档（Eddy·2026-06-20）：尺寸在 _update_single_frame 设（FRAME_*_SIZE），
## 这里只把每框位置按增量「左移半量 + 上移全量」→ 横向居中变宽、纵向底固定向上长，
## 不压下方血行/名字、保持顶部 UI 和谐。仅运行一次（_ready）。frame[0]=出战 / 1,2=替补。
func _enlarge_frames() -> void:
	for frames in [p1_frames, p2_frames]:
		for i in range(frames.size()):
			var f: HeroFrame = frames[i]
			var d: float = (FRAME_ACTIVE_SIZE - 72.0) if i == 0 else (FRAME_BENCH_SIZE - 68.0)
			f.position -= Vector2(d * 0.5, d)


## M3：P1 道具槽点击分派（按槽态）。开格/抽/补 = 立即生效（公开电报）；
## 使用 = 暂存点选（金边），确认时与动作一起盲选提交。
func _on_p1_slot_clicked(s: int) -> void:
	if state != State.PLAYER_SELECT or _drafting:
		return
	match battle.slot_state(PLAYER, s):
		BattleCore.SlotState.SEALED:
			if battle.can_open_slot(PLAYER, s):
				battle.open_slot(PLAYER, s)   # 付 1 能·SEALED→OPENED·锁本回合
				_update_all()
		BattleCore.SlotState.OPENED:
			if battle.can_draw_slot(PLAYER, s):
				var c: int = await _show_draft(s, battle.begin_draft(PLAYER, s))
				if c >= 0:
					battle.pick_draft(PLAYER, s, c)
				_update_all()
		BattleCore.SlotState.CHARGING:
			if battle.slot_ready(PLAYER, s):
				if selected_item_slots.has(s):   # 可取消点选（toggle）
					selected_item_slots.erase(s)
				else:
					selected_item_slots.append(s)
				_update_all()
		BattleCore.SlotState.EMPTY:
			if battle.can_refill(PLAYER, s):
				var opts: Array = battle.start_refill(PLAYER, s)   # 付 1 能→OPENED·本回合可抽
				_update_all()                                      # 先反映扣能量
				var c2: int = await _show_draft(s, opts)
				if c2 >= 0:                                        # 取消则留 OPENED·本回合可再抽（draft 已缓存）
					battle.pick_draft(PLAYER, s, c2)
				_update_all()


## C：升级就绪槽内道具（花能量 → 下一级池 3 选 1 → 换件并重新锁 1 回合·公开电报）。
func _on_p1_slot_upgrade(s: int) -> void:
	if state != State.PLAYER_SELECT or _drafting:
		return
	if battle.can_upgrade(PLAYER, s):
		var c: int = await _show_draft(s, battle.begin_upgrade_draft(PLAYER, s), "升级道具（3 选 1）")
		if c >= 0:
			battle.pick_upgrade(PLAYER, s, c)   # 付能量 → 换升级件 → 锁本回合
			selected_item_slots.erase(s)        # 升级后该槽不再就绪 → 撤销本回合「使用」点选
		_update_all()


## 弹出 3 选 1 抽取弹窗，await 返回选中 index（-1 = 取消）。抽取期间暂停回合计时 + 拦重入。
func _show_draft(_s: int, options: Array, title: String = "抽取道具（3 选 1）") -> int:
	_drafting = true
	game_timer.stop()
	var popup := ItemDraftPopup.new()
	add_child(popup)
	popup.setup(options, true, title)
	var choice: int = await popup.resolved
	popup.queue_free()
	_drafting = false
	if state == State.PLAYER_SELECT and not battle.game_over:
		game_timer.start(1.0)   # 恢复计时（沿用剩余 timer_seconds）
	return choice


func _update_all() -> void:
	_update_hero_frames()
	if p1_item_row != null:
		p1_item_row.refresh(battle, 0, selected_item_slots)
	if p2_item_row != null:
		p2_item_row.refresh(battle, 1)
	_update_character_displays()
	_update_energy_labels()
	_update_hp_labels()
	if state == State.PLAYER_SELECT:
		_update_button_states()


func _update_character_displays() -> void:
	for p in [0, 1]:
		var cd: CharacterDisplay = p1_char_display if p == 0 else p2_char_display
		cd.modulate = Color.WHITE  # 复位（死亡变暗 / 防御蓝闪 / 攒黄闪）
		var h: HeroData = battle.active_hero(p)
		if h.sprite_frames_path != "":
			cd.sprite_frames_path = h.sprite_frames_path
		elif h.spritesheet_path != "":
			cd.spritesheet_path = h.spritesheet_path
		# A 方案：v4 数据无 attack/hit/defeat 帧，攻击靠 juice；仍喂（多为空，组件 fallback）。
		cd.attack_spritesheet_path = h.attack_spritesheet_path
		cd.hit_spritesheet_path = h.hit_spritesheet_path
		cd.defend_spritesheet_path = h.defend_spritesheet_path
		cd.defeat_spritesheet_path = h.defeat_spritesheet_path


func _get_reserve_slots(player: int) -> Array[int]:
	var result: Array[int] = []
	for i in range(battle.heroes[player].size()):
		if i != battle.active_index[player]:
			result.append(i)
	return result


func _update_hero_frames() -> void:
	for p in [0, 1]:
		var frames := p1_frames if p == 0 else p2_frames
		var hp_rows: Array = p1_frame_hp_rows if p == 0 else p2_frame_hp_rows
		var frame_slots: Array[int] = p1_frame_slots if p == 0 else p2_frame_slots
		var active_idx: int = battle.active_index[p]
		# 出战头像框下方的角色名（随换人/回合更新）。
		var name_lbl: Label = p1_active_name if p == 0 else p2_active_name
		name_lbl.text = "%s" % battle.heroes[p][active_idx].hero_name
		var reserves := _get_reserve_slots(p)
		var pcolor := Color("#3f86c8") if p == 0 else Color("#d24a44")  # 四角阵营宝石：我方蓝 / 敌方红(边框统一中性板岩)

		frame_slots[0] = active_idx
		_update_single_frame(frames[0], hp_rows[0], p, active_idx, true, pcolor)

		for j in range(2):
			var fi := j + 1
			if j < reserves.size():
				var slot: int = reserves[j]
				frame_slots[fi] = slot
				_update_single_frame(frames[fi], hp_rows[fi], p, slot, false, pcolor)
			else:
				frame_slots[fi] = -1
				frames[fi].visible = false
				if hp_rows[fi] != null:
					hp_rows[fi].visible = false


## 出战位(is_active)：只画头像，血量/护盾由上方大心条显示 → 替补血量行隐藏。
## 待选位：头像 + ReserveHpRow（❤X[+灰❤X]·自绘居中·小数也居中·任务3b/4）。
## hp_row 在 index 0(出战位) 为 null；摆位/大小在 battle_screen.tscn 调，代码只填值。
func _update_single_frame(frame: HeroFrame, hp_row, player: int, slot: int, is_active: bool, pcolor: Color) -> void:
	if slot < 0 or slot >= battle.heroes[player].size():
		frame.visible = false
		if hp_row != null:
			hp_row.visible = false
		return

	frame.visible = true

	var h: HeroData = battle.heroes[player][slot]
	var dead: bool = battle.hp[player][slot] <= 0

	frame.hero_name = h.hero_name
	frame.portrait_path = h.portrait_path
	frame.is_active = is_active
	frame.is_dead = dead
	frame.player_color = pcolor
	frame.frame_size = Vector2(FRAME_ACTIVE_SIZE, FRAME_ACTIVE_SIZE) if is_active else Vector2(FRAME_BENCH_SIZE, FRAME_BENCH_SIZE)

	# 出战位 / 阵亡位：替补血量行隐藏（出战血量看上方大心条；阵亡不显示 0hp/护盾）。
	if is_active or dead:
		if hp_row != null:
			hp_row.visible = false
		return

	# 待选位：❤X[+灰❤X]，按内容测宽居中（整数/小数一致·护甲灰心）。
	if hp_row != null:
		hp_row.visible = true
		var hp_now := battle.hp_display(battle.hp[player][slot])
		var sh := battle.hp_display(battle.shield[player][slot])
		hp_row.set_values(hp_now, sh)


func _update_energy_labels() -> void:
	# 金币能量点：energy 内部为半能(×2)，显示除以 ENERGY_UNIT → 整能（0.5 能可显半枚·allow_half）。
	var e0 := battle.energy[0] / float(ActionDef.ENERGY_UNIT)
	var e1 := battle.energy[1] / float(ActionDef.ENERGY_UNIT)
	p1_coin_row.set_value(e0, e0)
	p2_coin_row.set_value(e1, e1)


func _update_hp_labels() -> void:
	p1_char_display.visible = true
	p2_char_display.visible = true
	for p in [0, 1]:
		var hp_now := battle.hp_display(battle.current_hp(p))
		var hp_max := battle.hp_display(battle.current_max_hp(p))
		var sh := battle.hp_display(battle.shield[p][battle.active_index[p]])
		# 心形血珠：满+半+暗色空心到 max；护盾作青色额外心追加。
		var row: IconPipRow = p1_heart_row if p == 0 else p2_heart_row
		row.set_value(hp_now, hp_max, sh)
		# 数字重量(b)：HP 变化时心条 flinch 脉冲（掉血偏红 / 回血偏绿）。
		if _prev_hp_disp[p] >= 0.0 and not is_equal_approx(hp_now, _prev_hp_disp[p]):
			_flinch_heart_row(row, hp_now < _prev_hp_disp[p])
		_prev_hp_disp[p] = hp_now


func _fmt_hp(v: float) -> String:
	v = maxf(v, 0.0)
	if is_equal_approx(v, roundf(v)):
		return "%d" % int(roundf(v))
	return "%.1f" % v


func _hp_color(ratio: float) -> Color:
	if ratio > 0.6:
		return Color("#44cc44")
	elif ratio > 0.3:
		return Color("#ffaa00")
	return Color("#ff4444")


# ============================================================
# 调试测试按钮（左侧）—— DEBUG_BUTTONS 开关
# ============================================================

## 左侧竖排测试按钮：满能量 / 满血 / 敌我造伤 / 加盾。直接改 battle 状态 → _update_all() 刷新。
## ⚠ 不走正常结算管线：debug 致死不会触发强制换人浮窗（要测死亡流程请打真实战斗）。
func _build_debug_buttons() -> void:
	if not DEBUG_BUTTONS:
		return
	var vb := VBoxContainer.new()
	vb.name = "DebugButtons"
	vb.position = Vector2(12.0, 300.0)
	vb.add_theme_constant_override("separation", 6)
	add_child(vb)

	var defs: Array = [
		["满能量", _dbg_full_energy],
		["满血", _dbg_full_hp],
		["敌 -10", _dbg_damage_enemy],
		["我 -10", _dbg_damage_self],
		["敌 +盾2", _dbg_shield_enemy],
		["我 下个英雄", _dbg_next_hero_self],
		["敌 下个英雄", _dbg_next_hero_enemy],
	]
	for d in defs:
		var b := Button.new()
		b.text = d[0] as String
		b.custom_minimum_size = Vector2(92.0, 30.0)
		b.focus_mode = Control.FOCUS_NONE
		b.modulate = Color(1, 1, 1, 0.82)
		FontManager.apply_btn(b, 14)
		b.pressed.connect(d[1] as Callable)
		vb.add_child(b)


func _dbg_full_energy() -> void:
	battle.energy[PLAYER] = ActionDef.MAX_ENERGY
	battle.energy[AI] = ActionDef.MAX_ENERGY
	_update_all()


func _dbg_full_hp() -> void:
	for p in [0, 1]:
		for s in range(battle.hp[p].size()):
			battle.hp[p][s] = battle.max_hp[p][s]
			battle.shield[p][s] = 0
	_update_all()


func _dbg_damage_enemy() -> void:
	_dbg_damage_active(AI, 10)


func _dbg_damage_self() -> void:
	_dbg_damage_active(PLAYER, 10)


## 给 player 的出战英雄扣 amount HP（debug，不走结算/不触发死亡换人）。
## 一并触发命中 juice（飘字+斩击+白闪+心条 flinch+震屏）→ 方便 F6 测试质感。
func _dbg_damage_active(player: int, amount: int) -> void:
	var s: int = battle.active_index[player]
	battle.hp[player][s] = maxi(battle.hp[player][s] - amount * BattleCore.HP_UNIT, 0)
	_update_all()                              # 含心条 flinch（HP 变化检测）
	_impact(player, amount * BattleCore.HP_UNIT)   # 飘字 + 斩击 + 白闪
	stage.shake(SHAKE_HIT)


func _dbg_shield_enemy() -> void:
	var s: int = battle.active_index[AI]
	battle.shield[AI][s] += 2 * BattleCore.HP_UNIT
	_update_all()


func _dbg_next_hero_self() -> void:
	_dbg_next_hero(PLAYER)


func _dbg_next_hero_enemy() -> void:
	_dbg_next_hero(AI)


## 美术资产巡检池：全英雄池中有 idle 动画资产的（不限本局阵容）。首次点击时构建。
var _dbg_art_pool: Array[HeroData] = []


## 把 player 的出战英雄换成英雄池里的下一个（h01→h02→...→h12→h01，跳过无美术的）。
## 仅替换 HeroData + 重置该槽位 HP/护盾为新英雄满血 → 立绘/头像/名字/技能卡/爱心数全套联动刷新。
## ⚠ 纯美术巡检用：不走结算管线，被动/技能状态不迁移。
func _dbg_next_hero(player: int) -> void:
	if _dbg_art_pool.is_empty():
		for h in HeroData.create_pool_heroes():
			var has_art: bool = h.sprite_frames_path != "" and ResourceLoader.exists(h.sprite_frames_path)
			if not has_art:
				has_art = h.spritesheet_path != "" and ResourceLoader.exists(h.spritesheet_path)
			if has_art:
				_dbg_art_pool.append(h)
		if _dbg_art_pool.is_empty():
			push_warning("debug: 英雄池中没有任何带美术资产的英雄")
			return

	var slot: int = battle.active_index[player]
	var cur_id: String = battle.heroes[player][slot].hero_id
	var idx: int = -1
	for i in range(_dbg_art_pool.size()):
		if _dbg_art_pool[i].hero_id == cur_id:
			idx = i
			break
	var next_hero: HeroData = _dbg_art_pool[(idx + 1) % _dbg_art_pool.size()]

	battle.heroes[player][slot] = next_hero
	battle.max_hp[player][slot] = int(next_hero.max_hp) * BattleCore.HP_UNIT
	battle.hp[player][slot] = battle.max_hp[player][slot]
	battle.shield[player][slot] = 0

	_update_all()
	_refresh_skill_card()
	print("debug: P%d 出战英雄 → %s (%s)" % [player + 1, next_hero.hero_id, next_hero.hero_name])


# ============================================================
# 动画 / juice
# ============================================================

## A 方案 juice：出招（攻击前冲 / 防御蓝闪沉身 / 攒上浮黄闪）→ 命中（白闪 + 斩击光
## + 伤害数字 + 震屏）。dmg/dead 为 [p0, p1]。无逐帧 attack/hit 动画，全靠代码表现。
func _play_battle_anims(a0: int, a1: int, dmg: Array, dead: Array) -> void:
	# 执行动作 → 镜头按玩家(P1)动作偏焦：波/大波 右聚敌、防/大防 左聚己、其余回正（取代旧 hover 触发）。
	var fdir: float = _focus_dir_for(a0)
	stage.set_focus(fdir != 0.0, fdir)
	_act_juice(0, a0)
	_act_juice(1, a1)
	# P3：仅"大波且确实打中（伤害/击杀）"时镜头前推蓄势，峰值正好落在 0.45*phase 后的命中瞬间，
	# 与 stage.shake() + _hitstop 合拍（被挡的大波无 impact → 不触发，避免推近落空）。
	var big_lands := (a0 == A.BIG_ATTACK and (int(dmg[1]) > 0 or bool(dead[1]))) \
		or (a1 == A.BIG_ATTACK and (int(dmg[0]) > 0 or bool(dead[0])))
	if big_lands:
		_big_attack_punch()
	await get_tree().create_timer(action_phase_duration * 0.45).timeout

	var any := false
	if int(dmg[1]) > 0 or bool(dead[1]):
		_impact(1, int(dmg[1]))
		any = true
	if int(dmg[0]) > 0 or bool(dead[0]):
		_impact(0, int(dmg[0]))
		any = true
	if any:
		stage.shake(SHAKE_BIG if (a0 == A.BIG_ATTACK or a1 == A.BIG_ATTACK) else SHAKE_HIT)
	if bool(dead[0]):
		p1_char_display.modulate = Color(0.35, 0.35, 0.35)
	if bool(dead[1]):
		p2_char_display.modulate = Color(0.35, 0.35, 0.35)

	await get_tree().create_timer(action_phase_duration).timeout
	stage.set_focus(false)   # 动作结束 → 镜头回正中


## P3：大波命中"前推顿帧"。上升时长 = 命中前的 await（0.45×phase）→ 峰值正好落在命中瞬间，
## 与 stage.shake() + _hitstop 合拍（顿帧期 scaled-time tween 自然冻结 → 推近 hold 在峰值），随后快速回弹。
## 缩放叠加在 hover 对焦之上，立绘/阴影经 ground_dolly 同步推 → 整场景一起"凑近"那一击。
func _big_attack_punch() -> void:
	var rise: float = action_phase_duration * 0.45
	var tw := create_tween()
	tw.tween_method(stage.set_punch, 0.0, 1.0, rise).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_method(stage.set_punch, 1.0, 0.0, PUNCH_RELEASE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _cd(player: int) -> CharacterDisplay:
	return p1_char_display if player == 0 else p2_char_display


## 出招 juice。攻击=蓄力前冲复位；防御=蓝闪沉身；攒=上浮黄闪。
func _act_juice(player: int, action: int) -> void:
	var cd := _cd(player)
	var home: Vector2 = _cd_home[player]
	var dir := 1.0 if player == 0 else -1.0
	match action:
		A.ATTACK, A.BIG_ATTACK:
			var reach := 190.0 if action == A.BIG_ATTACK else 140.0
			var tw := create_tween()
			tw.tween_property(cd, "position", home + Vector2(-28.0 * dir, 0), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(cd, "position", home + Vector2(reach * dir, 0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(cd, "position", home, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			# A3：出招瞬间被自己的招式照亮（月光描边增强）。
			cd.pulse_rim(1.4 if action == A.BIG_ATTACK else 0.9, 0.3)
		A.DEFEND, A.BIG_DEFEND:
			var glow := Color(0.55, 0.8, 1.4) if action == A.BIG_DEFEND else Color(0.7, 0.85, 1.2)
			var tw := create_tween()
			tw.tween_property(cd, "modulate", glow, 0.1)
			tw.tween_property(cd, "modulate", Color.WHITE, 0.35)
			var tw2 := create_tween()
			tw2.tween_property(cd, "position", home + Vector2(0, 10), 0.1)
			tw2.tween_property(cd, "position", home, 0.3).set_trans(Tween.TRANS_SINE)
		A.CHARGE:
			var tw := create_tween()
			tw.tween_property(cd, "position", home + Vector2(0, -16), 0.15).set_trans(Tween.TRANS_SINE)
			tw.tween_property(cd, "position", home, 0.28).set_trans(Tween.TRANS_SINE)
			var tw2 := create_tween()
			tw2.tween_property(cd, "modulate", Color(1.35, 1.25, 0.6), 0.12)
			tw2.tween_property(cd, "modulate", Color.WHITE, 0.32)


## 命中表现：白闪 + 斩击弧光 + 伤害数字。
func _impact(target_player: int, dmg_half: int) -> void:
	var cd := _cd(target_player)
	var big := dmg_half >= 4   # ≥2HP=重击：更强退弹/火花/定格
	cd.flash_white(0.18)
	cd.pulse_rim(0.7, 0.22)   # A3：被弧光照亮
	_char_pop(target_player, 0.12 if big else 0.08)   # 受击退弹（scale 弹一下）
	_spawn_slash(target_player)
	_spawn_spark(target_player, big)                  # c：命中火花
	if dmg_half > 0:
		_pop_damage(target_player, float(dmg_half) / 2.0)
	_hitstop(0.075 if big else 0.045)                 # c：命中定格（不 await，自管恢复）


## A3：受击 scale-pop（绕立绘中心快速放大再回弹）。pivot 每次按当前尺寸取中心，稳健。
func _char_pop(player: int, amount: float) -> void:
	var cd := _cd(player)
	cd.pivot_offset = cd.size * 0.5
	var tw := create_tween()
	tw.tween_property(cd, "scale", Vector2(1.0 + amount, 1.0 + amount), 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(cd, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 命中定格 hitstop(c)：极短时间把 Engine.time_scale 压到极低 → 整个画面"顿"一下，
## 把出招/受击张力咬住几帧再放开，是打击脆度的核心。token 防多发重叠误恢复；
## 计时器用 ignore_time_scale 按真实时长恢复；_exit_tree 兜底复位。
func _hitstop(real_dur: float, ts: float = 0.04) -> void:
	_hitstop_token += 1
	var my := _hitstop_token
	Engine.time_scale = ts
	await get_tree().create_timer(real_dur, true, false, true).timeout
	if my == _hitstop_token:
		Engine.time_scale = 1.0


## 命中火花(c)：受击点爆一簇短命粒子（径向飞溅 + 重力下坠），重击更多更快。
## 一次性 explosive 爆发 → "一帧火花"的脆感。无贴图=小方块火星，足够。
func _spawn_spark(target_player: int, big: bool) -> void:
	var cd := _cd(target_player)
	var p := CPUParticles2D.new()
	p.global_position = cd.global_position + cd.size * Vector2(0.5, 0.42)
	p.z_index = 95
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 16 if big else 10
	p.lifetime = 0.38
	p.spread = 180.0                       # 径向全向飞溅
	p.initial_velocity_min = 160.0
	p.initial_velocity_max = 460.0 if big else 300.0
	p.gravity = Vector2(0, 700)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5 if big else 3.0
	p.color = Color(1.0, 0.92, 0.62)       # 暖白火星
	add_child(p)
	p.emitting = true
	get_tree().create_timer(0.9).timeout.connect(p.queue_free)


func _spawn_slash(target_player: int) -> void:
	var cd := _cd(target_player)
	var slash := SlashVFX.new()
	var s := 2.0
	slash.scale = Vector2(-s, s) if target_player == 0 else Vector2(s, s)  # 打左侧的镜像
	slash.global_position = cd.global_position + cd.size * 0.5
	slash.z_index = 60
	add_child(slash)
	slash.play()


## 伤害飘字（数字重量 b）：受击处弹 -N，按伤害量缩放大小/配色 → punch-in 过冲 → 抛物上浮淡出。
## 大伤(≥2HP)更大更炽、描边更粗；起点偏击退方向 + 小随机，防多发叠死。
func _pop_damage(player: int, amount: float) -> void:
	var cd: CharacterDisplay = p1_char_display if player == 0 else p2_char_display
	var big := amount >= 2.0
	var lbl := Label.new()
	lbl.text = "-%s" % _fmt_hp(amount)
	FontManager.apply(lbl, 60 if big else 44)
	# 重击=炽黄白更醒目 / 轻击=橙红；粗黑描边 = 投影/重量。
	lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.5) if big else Color(1.0, 0.55, 0.42))
	lbl.add_theme_color_override("font_outline_color", Color(0.12, 0.02, 0.02, 0.95))
	lbl.add_theme_constant_override("outline_size", 9 if big else 6)
	lbl.z_index = 100
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	lbl.reset_size()
	lbl.pivot_offset = lbl.size * 0.5   # 绕中心缩放
	var dir := 1.0 if player == 0 else -1.0   # 击退方向（P0 打右侧敌→数字往右）
	var start: Vector2 = cd.global_position + cd.size * Vector2(0.5, 0.30) - lbl.size * 0.5 \
		+ Vector2(dir * 16.0 + randf_range(-10.0, 10.0), randf_range(-6.0, 6.0))
	lbl.global_position = start
	# punch-in：0.45 → 过冲 → 落定
	var peak := 1.28 if big else 1.12
	lbl.scale = Vector2(0.45, 0.45)
	var st := create_tween()
	st.tween_property(lbl, "scale", Vector2(peak, peak), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	st.tween_property(lbl, "scale", Vector2(peak, peak) * 0.86, 0.10).set_trans(Tween.TRANS_SINE)
	# 抛物上浮（横向带一点击退漂移）+ 末段淡出
	var rise := 104.0 if big else 78.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position", start + Vector2(dir * 26.0, -rise), 0.66).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.40).set_delay(0.52)
	get_tree().create_timer(1.05).timeout.connect(lbl.queue_free)


## 数字重量(b)：HP 变化时给出战心条一个 modulate flinch（掉血偏红 / 回血偏绿），
## 用 modulate 而非 scale → 不受 RTL 心条(右起左排)的布局影响、稳健。
func _flinch_heart_row(row: IconPipRow, is_loss: bool) -> void:
	var peak := Color(1.7, 1.35, 1.35) if is_loss else Color(1.35, 1.7, 1.4)
	var tw := create_tween()
	tw.tween_property(row, "modulate", peak, 0.06).set_trans(Tween.TRANS_SINE)
	tw.tween_property(row, "modulate", Color.WHITE, 0.30).set_trans(Tween.TRANS_SINE)


func _process(_delta: float) -> void:
	# 受击震屏已移交舞台分层 stage.shake()（见 battle_stage.gd 按 parallax_factor 分摊衰减）——
	# 根节点不再整体抖，故 UI 始终不动；震感与纵深由舞台层负责。
	# 阴影对角色动作反应：水平位移跟随 + 离地缩小淡出 + 冲刺拉长（接地/重量感）。
	_update_shadow(0)
	_update_shadow(1)
	# P2b：立绘+阴影组随镜头推近整体缩放 + 绕同一动态对焦点位移（与地面屋顶层 factor 1.0 同步 →
	# 统一移动·焦点随动作左右偏置）。组缩放 × 角色自身 juice 由场景图相乘，pop/前冲不受影响。
	if _world:
		var gd: float = stage.ground_dolly()
		_world.scale = Vector2.ONE * gd
		_world.position = stage.focal() * (1.0 - gd)


## A3：阴影随角色动作变形。
## - 水平位移：前冲时影子跟着横移；
## - 离地（攒上浮 / 前冲腾身，position.y < home.y）：影子缩小 + 变淡（角色离地）；
## - 横向冲刺：影子沿地面拉长（速度感）。
func _update_shadow(p: int) -> void:
	var cd: CharacterDisplay = p1_char_display if p == 0 else p2_char_display
	var sh: TextureRect = p1_shadow if p == 0 else p2_shadow
	var home: Vector2 = _cd_home[p]
	var dx: float = cd.position.x - home.x
	var lift: float = maxf(home.y - cd.position.y, 0.0)          # 上抬量（离地）
	sh.position.x = _shadow_home[p].x + dx
	var k: float = clampf(1.0 - lift / 140.0, 0.5, 1.0)          # 离地越多越小
	var stretch: float = 1.0 + clampf(absf(dx) / 190.0, 0.0, 1.0) * 0.4
	sh.scale = Vector2(k * stretch, k)
	sh.modulate.a = lerpf(0.4, 1.0, k)


# ============================================================
# 头顶招式圆圈（揭示盲选出招，占位待美术）/ 动作名
# ============================================================

## 双方各在角色头顶弹出一个气泡（揭示盲选出招）：有美术图标用图标、否则用文字。
## 进场带 pop 动画（缩放回弹 + 淡入），显示 1.2s 后收起淡出，告别"直接冒出来"的僵硬。
func _show_action_indicators(a0: int, a1: int) -> void:
	status_label.visible = false
	event_label.visible = false
	var c0 := _spawn_action_circle(0, a0)
	var c1 := _spawn_action_circle(1, a1)
	await get_tree().create_timer(1.2).timeout
	for c in [c0, c1]:
		if is_instance_valid(c):
			var tw := create_tween()
			tw.tween_property(c, "scale", Vector2(0.5, 0.5), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(c, "modulate:a", 0.0, 0.14)
			tw.tween_callback(c.queue_free)


## 找动作对应的动作按钮（攒/波/大波/防/大防 有；技能/切换 无 → null）。
func _btn_for_action(action: int) -> Button:
	match action:
		A.CHARGE: return btn_charge
		A.ATTACK: return btn_attack
		A.BIG_ATTACK: return btn_big_attack
		A.DEFEND: return btn_defend
		A.BIG_DEFEND: return btn_big_defend
		ACTIVE: return btn_special
	return null


## 取动作按钮上的 HoverIcon（图标/帧/缩放的单一来源，在 .tscn 配置）；无则 null。
func _hover_icon_for(action: int) -> HoverIcon:
	var btn := _btn_for_action(action)
	if btn == null:
		return null
	return btn.get_node_or_null("HoverIcon") as HoverIcon


## 在 player 角色头顶生成揭示气泡（圆底 + 美术图标 / 文字回退）。
func _spawn_action_circle(player: int, action: int) -> Control:
	var cd := _cd(player)
	var sz := 92.0
	var circ := Control.new()
	circ.size = Vector2(sz, sz)
	# 气泡位置：己方(P0)=人物头「右上方」/ 敌方(P1)=镜像「左上方」+ pop 小动画（_animate_bubble_pop）。
	# 锚用容器「中心」(不随 viewport 放大飞走)：中心上移 BUBBLE_HEAD_RISE 到头顶、再按阵营左右偏 BUBBLE_SIDE_X。
	var cd_center := cd.position + cd.size * 0.5
	var side := 1.0 if player == PLAYER else -1.0   # 己方右 / 敌方左·镜像
	circ.position = Vector2(
		cd_center.x + side * BUBBLE_SIDE_X - sz * 0.5,
		cd_center.y - BUBBLE_HEAD_RISE - sz)
	circ.pivot_offset = Vector2(sz, sz) * 0.5   # 从中心 pop
	circ.z_index = 80
	circ.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 果冻底：复用对应动作按钮的 jelly 材质 → 颜色/像素风格/Inspector 微调全与按钮一致。
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var btn := _btn_for_action(action)
	var btn_bg: ColorRect = null
	if btn != null:
		btn_bg = btn.get_node_or_null("Bg") as ColorRect
	if btn_bg != null and btn_bg.material != null:
		bg.material = btn_bg.material
		bg.color = Color.WHITE              # shader 输出 × COLOR；白 = 全强度
	else:
		bg.color = Color(0.09, 0.085, 0.075)   # 无对应按钮(如切换)→ 近黑暖底（B 典籍）
	circ.add_child(bg)

	var hi := _hover_icon_for(action)
	if hi != null and hi.sheet != null:
		# 气泡内放一个自动循环播放的 HoverIcon → 复用按钮图标的 sheet/帧/缩放，观感与按钮一致，
		# 且持续播放 idle 动画（动态，不再是静止帧0）。填满气泡，inset/content_scale 同按钮。
		var anim := HoverIcon.new()
		anim.sheet = hi.sheet
		anim.hframes = hi.hframes
		anim.vframes = hi.vframes
		anim.frame_count = hi.frame_count
		anim.fps = hi.fps
		# 比例与按钮一致：取按钮里图标的「显示占比」直接当 content_scale + inset 归零 →
		# 气泡内图标占气泡的比例 = 图标占按钮的比例（修复气泡图标偏大/比例不一致）。
		anim.inset_ratio = 0.0
		anim.content_scale = hi.display_ratio()
		anim.auto_play = true
		anim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		anim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		circ.add_child(anim)
	else:
		var lbl := Label.new()
		lbl.text = _action_name(action)
		FontManager.apply(lbl, 28)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 3)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		circ.add_child(lbl)

	add_child(circ)
	_animate_bubble_pop(circ)
	return circ


## 气泡 pop 进场：从小放大（回弹）+ 淡入。
func _animate_bubble_pop(node: Control) -> void:
	node.scale = Vector2(0.2, 0.2)
	node.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(1.14, 1.14), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE)
	var tw2 := create_tween()
	tw2.tween_property(node, "modulate:a", 1.0, 0.14).set_ease(Tween.EASE_OUT)


func _action_name(act: int) -> String:
	match act:
		A.CHARGE: return "攒"
		A.ATTACK: return "波"
		A.DEFEND: return "防"
		A.BIG_ATTACK: return "大波"
		A.BIG_DEFEND: return "大防"
		A.SWITCH: return "切换"
		ACTIVE: return "技能"
	return "?"
