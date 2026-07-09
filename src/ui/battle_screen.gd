extends Control

## 1920x1080. 布局在 battle_screen.tscn 可视化编辑（保留，勿动节点）。
## v4 引擎（BattleCore）+ 同时盲选 vs AI（决策 B1）。
## 你 = P0（下），对手 = P1（上，AI）。玩家选动作 → 确认 → AI 后台选 → 同时结算。
##
## 半点制：HP/护盾内部为半点，显示用 battle.hp_display()。

const A := ActionDef.Action
const ACTIVE := ActionDef.ACTIVE

# 动作按钮"能量消耗"金币（1 能量 1 球）= battle_screen.tscn 内每个按钮下的 CostPips 节点，
# 位置/大小/间距在 Godot 编辑器里可视化调整（可视化设计·任务2）；代码只在运行时填入数量。

const SCREEN_W := 1920.0
const SCREEN_H := 1080.0

## 出战血条低血红闪阈值（HP 占比 ≤ 此值）；闪烁在 IconPipRow 内部实现（任务5：红光改到剩余血量爱心上）。
const LOW_HP_RATIO := 0.5

## 顶部 UI 整体下移量(px)：原布局太贴屏幕顶端 → 下沉一点留呼吸。改这一个数即可整组调整。
## 注：当前为运行时代码统一微调(编辑器里仍是基准位)；下移量定稿后可烘焙进 .tscn 使"所见=所得"。
const TOP_UI_DROP := 26.0   # 顶部 UI 整体下移量（2026-06-28 Eddy：44太多→回调到26）；0=复原原位
const BUBBLE_HEAD_RISE := 127.0  # 出招气泡锚点：角色显示容器「中心」上移此值（越大气泡越高·够高才不压角色·随立绘 2.5x 同步 2026-07-09）
const BUBBLE_SIDE_X := 114.0     # 出招气泡水平偏移：己方(P0)放头「右上」/ 敌方(P1)镜像「左上」（越大越往外侧·够大才不和角色重合·随立绘 2.5x 同步）

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
const BattleDebugPanel := preload("res://src/ui/debug/battle_debug_panel.gd")   # debug 面板（preload 引用·不靠全局 class_name 注册·headless / CLI 可用）

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
# 终结演出背景虚化幕（Stage 之后·WorldGroup 之前 → 只糊背景不糊双雄）。平时 veil 隐藏 +
# grab DISABLED = 零成本；仅 _play_finisher 期间开启。
@onready var finisher_grab: BackBufferCopy = $FinisherGrab
@onready var finisher_veil: ColorRect = $FinisherVeil

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

# ── 任务G（2026-07-09）：AI 异步预想——选招期间后台线程替对手想招·点确认零等待 ──
# 依据：同时盲选 = AI 决策不依赖玩家按了什么 → 回合开始即可在【克隆棋盘】上预想（探针实锤
# 同步想招中期 0.9-1.5s 全压在确认点击上）。玩家中途改状态（道具点选/抽补/升级/调试面板）→
# 作废重想；确认时校验（回合号+道具点选集）不符或没来得及想 → 同步兜底（原路径原样保留）。
# 等价性：决策在克隆+rng 快照副本上跑（与同步完全同序）·命中后真局重放落子+采纳 rng 终态
# → 整局与"当场同步跑一遍"逐位一致（GUT test_ai_async_equivalence 锁此契约）。
var _think_ai: BattleAI                 # 预想专用 AI 实例（配置须与 _ai 一致·rng 每次从 _ai 快照）
var _think_task: int = -1               # WorkerThreadPool 任务 id（-1=无任务在跑）
var _think_mutex := Mutex.new()         # 保护 _think_out（工作线程写·主线程读）
var _think_out: Dictionary = {}         # 预想结果 {turn, items_key, econ_up, choice, rng_end}
var _think_restart: bool = false        # 任务跑着时状态又变了 → 完成回调里重拉（不并行堆积）
var _ai: BattleAI                             # 试玩对手 = 与 sim 统一的同一套搜索 AI（_ready 实例化）
var _overtime := false                        # 本局是否加时赛（Q5·白板 1v1·_ready 从 BattleSetup 读）

# ── 远征 PvE（任务 D·2026-07-06）：对手=怪物驾驶员（明牌概率表）·可脱离·无 PvP 道具经济 ──
const ExpeditionPolicy := preload("res://src/expedition/expedition_monster_policy.gd")
const ExpeditionPixelArt := preload("res://src/expedition/expedition_pixel_art.gd")
const PVE_JELLY_SHADER := preload("res://assets/shaders/canvas_button_jelly.gdshader")
## 怪物系列色（monsters.json "series"·任务 I）：博弈=金 / 考官=靛蓝 / 未知回退暖骨。
const PVE_SERIES_COLORS: Dictionary = {"gamble": Color("e0b54a"), "exam": Color("3f6fb0")}
var _pve := false                             # 本局=远征 PvE（BattleSetup.pve_mode·须在 reset() 前读）
var _pve_policy: ExpeditionPolicy             # 怪物驾驶员（五策略·可支付归一化）
var _pve_choice: Dictionary = {}              # 本拍怪物已定招（回合开始抽样·明牌显示分布·确认时提交）
var _pve_odds_label: Label                    # 明牌概率表（博弈系）/ 循环提示（考官系）
var _pve_flee_btn: Button                     # 脱离按钮（挨一拍·退回地图）
var _pve_ending := false                      # 防重复回程结算

# ---- 选择 / 样式 ----
var action_btn_list: Array[Button] = []
var selected_action: int = -1
var selected_switch: int = -1
var selected_btn: Button = null

# ---- 黑暗卯兔 h16【疾风】：附加同种动作开关（程序化创建·不入 .tscn）----
var btn_jifeng: Button = null
var _double_armed: bool = false   # 本回合是否 armed「附加同种动作」（确认时随动作一起 select_double 提交）

# ---- 主动换人（任务5）：点替补框→框内显「切换」(armed)→再次点=选择(动画)→「结束」提交 ----
var _armed_switch_frame: int = -1   # 当前 armed 的替补框索引（1 / 2），-1=无
var _switch_selected: bool = false  # armed 框是否已进入"选择"态（高亮·待「结束」提交）
var _enemy_targeting: bool = false  # h21 调虎离山：是否处于"选敌方替补揪目标"态（选中该主动技后）
var _enemy_target_pick: int = -1    # 已点选的敌方替补槽（-1=未选→提交时引擎随机揪）

# ---- juice ----
# 受击震屏基幅（实际位移 = 基幅 × 各层 parallax_factor·见 scene1.tscn / battle_stage.gd）。
# 只在受击触发、克制；建筑无 idle 漂移（_ready 关 idle_drift），仅震时才动。F6 调幅在此。
const SHAKE_BIG := 12.0     # 大波命中
const SHAKE_HIT := 7.0      # 普通命中
const PUNCH_RELEASE := 0.35   # P3：大波前推命中后的回弹时长（落在 settle 内）

# ── 终结演出旋钮（Eddy 2026-07-09·Q1A 仅动作直接击杀 / Q2B 压暗+真模糊 / Q3A 全场慢放）──
const FINISHER_SLOW := 0.45          # 慢放倍率（全场 time_scale·参考暗黑地牢判定演出）
const FINISHER_SCALE := 1.35         # 双雄拉出放大倍率（绕脚底锚点）
const FINISHER_SHIFT_KILLER := 90.0  # 击杀方向中错位（px·向前压）
const FINISHER_SHIFT_VICTIM := 34.0  # 受击方退让错位（px·向后让）
const FINISHER_VEIL_IN := 0.18       # 虚化幕淡入时长（s）
const FINISHER_VEIL_OUT := 0.22      # 虚化幕淡出时长（s）
var _confirm_pulse: Tween   # 「结束」按钮的呼吸金光（有待确认动作时召唤点击）
var _cd_home: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]  # 立绘原位（前冲 juice 复位用）
var _shadow_home: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]  # 阴影原位（跟随角色水平位移用）
var _prev_hp_disp: Array[float] = [-1.0, -1.0]   # 上次显示的出战 HP（检测变化 → 心条 flinch 脉冲）
var _hitstop_token: int = 0   # hitstop(c) 防重叠：仅最后一次定格负责恢复 Engine.time_scale
var _time_scale_base: float = 1.0   # hitstop 恢复的目标速度（终结演出慢放期间 = FINISHER_SLOW·平时 1.0）
var _fin_impact_tweens: Array[Tween] = []   # 终结命中的 punch/下沉 tween（慢放中跑不完·归位前必须 kill 防写回放大值）
var _act_focus_active: bool = false   # 执行动作期间镜头是否在偏焦（保留位·当前由 set_focus 直接驱动）
var _world: Control = null    # P2b：立绘+阴影的 dolly 组（运行期归组·与背景同对焦点统一推近）


# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_ai_rng.randomize()   # 任务 B：AI 道具抽取随机种子
	_ai = BattleAI.new(0, 2, 0, {})   # 与 sim 统一：同一套搜索 AI（随机种子·深度 2·基础评估）
	_think_ai = BattleAI.new(0, 2, 0, {})   # 任务G：异步预想副本（配置同 _ai·rng 每次快照覆盖）
	battle = BattleCore.new()
	_overtime = BattleSetup.overtime   # 须在 reset() 前读取
	_pve = BattleSetup.pve_mode        # 远征 PvE（任务 D）·同样须在 reset() 前读取
	var pve_monster: Dictionary = BattleSetup.pve_monster
	var pve_monster_hp: int = BattleSetup.pve_monster_hp
	var pve_team: Array = BattleSetup.pve_team.duplicate(true)
	var pve_equipment: Array = BattleSetup.pve_equipment.duplicate()
	var p0: Array
	var p1: Array
	if _pve:
		# 远征队伍（1-3 人·存活者在前）与单怪都补足 3 槽白板（板凳 0 血·同加时赛零特判）
		p0 = _pve_build_team(pve_team)
		p1 = _pve_build_monster(pve_monster, pve_monster_hp)
	else:
		p0 = _resolve_team(BattleSetup.p1_heroes, DEFAULT_P0)
		p1 = _resolve_team(BattleSetup.p2_heroes, DEFAULT_P1)
	BattleSetup.reset()   # 消费即清空：防止下一局（未经 BP）复用本局阵容
	battle.setup(p0, p1, randi())
	if _overtime:
		# 加时赛（Q5·2026-07-03；2026-07-05 修订）：白板满血 1v1——slot0 出战、其余队友 0 血躺板凳
		# （同归余烬·引擎/UI 全程正常 3 人局零特判）；无道具经济（不 econ_init）、被动能量照常、
		# 上限 30 回合：打满 → 引擎骤死裁决（双方同时扣血·UI 走正常掉血/死亡演出零特判）。
		battle.apply_overtime_bench()
	elif _pve:
		# 远征 PvE：HP 带入（跨战不回满·GDD）·能量每战重置（=setup 默认）·装备直入槽·
		# 无 PvP 道具经济（不 econ_init·pve_equip_init 用 EMPTY 槽防 draft）·怪物无替补。
		# UI 只读铁律：HP 带入走引擎入口 pve_apply_hp（不直写 battle.hp）。
		var team_hp_in: Array = []
		for m in pve_team:
			team_hp_in.append(int(m["hp"]))
		battle.pve_apply_hp(team_hp_in, pve_monster_hp)
		battle.pve_equip_init(pve_equipment)
		_pve_policy = ExpeditionPolicy.new(pve_monster, randi())
		_pve_build_ui()
		p2_char_display.sprite_frames = _pve_monster_frames(pve_monster)   # 任务 I：白板→像素图签占位/MJ art 字段
	else:
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
	_build_settings_button()   # 战斗内设置入口（右上角小钮 + ESC·2026-07-09）

	_build_skill_entries()
	skill_card.advance_requested.connect(_on_skill_card_advance)
	skill_card.back_requested.connect(_on_skill_card_back)   # 右键 → 上一个英雄
	_refresh_skill_card()

	# 低血红闪（任务5）：出战血条剩余爱心在 HP 占比低时红色呼吸（IconPipRow 内部实现）。
	for row in [p1_heart_row, p2_heart_row]:
		row.low_hp_flash = true
		row.low_hp_ratio = LOW_HP_RATIO

	_build_item_rows()
	if _overtime:
		p1_item_row.visible = false   # 加时禁道具 → 道具栏整行隐藏
		p2_item_row.visible = false
		status_label.text = "加时赛 · 巅峰 1v1"
		status_label.add_theme_color_override("font_color", Color("#ffd86a"))
		status_label.visible = true
	_enlarge_frames()
	_update_all()
	_show_turn_intro()


## 离场恢复 time_scale=1：hitstop(c) 用全局 Engine.time_scale，若在定格瞬间切场景须复位，防下个场景慢动作。
func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if _think_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_think_task)   # 任务G：离场前回收预想线程（防悬垂引用）
		_think_task = -1


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


## 结算"进攻方"判定（镜头冲突落点用·Eddy 2026-07-09 镜头规格）：
## 波/大波恒算进攻（被挡也算——冲突落点仍在受击侧）；主动技按"是否实际造成伤害/击杀"归类
## （无伤主动技=未进攻）；攒/防/大防/切换=未进攻。dmg_to_foe/foe_dead=本次结算对方承受的伤害/死亡。
func _is_offense(action: int, dmg_to_foe: int, foe_dead: bool) -> bool:
	if action == A.ATTACK or action == A.BIG_ATTACK:
		return true
	return action == ActionDef.ACTIVE and (dmg_to_foe > 0 or foe_dead)


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
	# 紧跟 FinisherVeil（终结演出虚化幕只糊 Stage 背景、不糊双雄）、在 dust/后处理/UI 之前。
	move_child(_world, finisher_veil.get_index() + 1)
	for n in [p1_shadow, p2_shadow, p1_char_display, p2_char_display]:
		n.reparent(_world, true)   # keep_global_transform → 静止画面一像素不变


func _connect_frame_signals() -> void:
	# 主动换人：点击己方替补头像（索引 1 / 2）→ 头像下浮现「切换」小按钮（见 _on_reserve_frame_input）。
	# 出战位（索引 0）不可点（不能换成自己）。
	# 敌方替补框（索引 1 / 2）：平时点击无响应（回调内 gate），仅 h21 调虎离山选目标态可点（见 _on_enemy_frame_input）。
	for fi in [1, 2]:
		p1_frames[fi].gui_input.connect(_on_reserve_frame_input.bind(fi))
		p2_frames[fi].gui_input.connect(_on_enemy_frame_input.bind(fi))


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
	var sk: HeroSkill = battle.get_skill(p, slot)
	var is_active: bool = sk != null and (sk.has_active() or sk.has_free_switch())
	# 立绘一律朝右；阵营靠底色区分（己方冷蓝 / 对方暖红）。
	skill_card.populate(h.hero_name, h.skill_description, h.skill_detail, is_active, h.portrait_path, p == PLAYER, h.skill_icon_path)


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
	if _pve:
		_pve_pick_turn()   # 远征：怪物回合开始即定招·明牌概率表先于玩家选择亮出（GDD 明牌博弈系）

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
	_start_ai_think()   # 任务G：选招一开始就让对手在后台想（确认时零等待）


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
	if action == ACTIVE:
		_maybe_arm_enemy_targets()   # 需指定敌方替补的主动技（h21 调虎离山）→ 点亮敌方存活替补框
	_refresh_jifeng()   # 新选的动作是否可双 → 更新疾风开关


func _on_confirm_pressed() -> void:
	if state != State.PLAYER_SELECT:
		return
	game_timer.stop()

	# 玩家提交（未选 → 默认攒）
	if selected_action == ACTIVE:
		battle.select_active(PLAYER, _enemy_target_pick)   # 玩家点选的敌方揪目标（-1=未选→引擎随机）
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

	# AI 选择（远征 PvE：怪物驾驶员已在回合开始定招·明牌承诺=所见即所打）
	if _pve:
		if _pve_choice.is_empty() or not battle.select_action(AI, int(_pve_choice["action"])):
			battle.select_action(AI, A.CHARGE)
	elif not _ai_pick_precomputed():
		_ai_pick(AI)   # 任务G 兜底：预想未命中（状态变过/没来得及想）→ 原同步路径

	selected_action = -1
	selected_switch = -1
	selected_btn = null
	_double_armed = false
	_reset_button_styles()
	_set_confirm_active(false)   # 停止呼吸：已确认提交
	await _resolve()


# ============================================================
# 远征 PvE（任务 D·2026-07-06）
# ============================================================

## 远征队伍 → 3 槽白板 HeroData（存活者在前·不足补 0 血板凳·同加时赛零特判）。
func _pve_build_team(team: Array) -> Array:
	var out: Array = []
	for m in team:
		out.append(_pve_vanilla(String(m["name"]), maxi(1, int(m["hp_max"]) / 2)))
	while out.size() < 3:
		out.append(_pve_vanilla("——", 1))
	return out


func _pve_build_monster(def: Dictionary, hp_half: int) -> Array:
	var out: Array = [_pve_vanilla(String(def.get("name", "怪物")), maxi(1, (hp_half + 1) / 2))]
	while out.size() < 3:
		out.append(_pve_vanilla("——", 1))
	return out


func _pve_vanilla(display_name: String, hp_points: int) -> HeroData:
	var h := HeroData.new()
	h.hero_id = ""      # 空 id = 白板（无技能组件·与校准 sim 同法）
	h.hero_name = display_name
	h.max_hp = hp_points
	return h


## PvE 怪物立绘（任务 I·白板→程序化像素图签占位）。
## 🎨 美术挂点：MJ 素材到位后在 monsters.json 该怪条目加可选字段 "art": "res://...（SpriteFrames .tres 或单图）"
## 即自动替换·零改码（字段缺省=程序占位·见 design/expedition-monsters.md）。
func _pve_monster_frames(def: Dictionary) -> SpriteFrames:
	var art_path: String = String(def.get("art", ""))
	if art_path != "" and ResourceLoader.exists(art_path):
		var res: Resource = load(art_path)
		if res is SpriteFrames:
			return res
		if res is Texture2D:
			var sf_art := SpriteFrames.new()
			sf_art.add_animation("idle")
			sf_art.add_frame("idle", res)
			return sf_art
	var tier: int = int(def.get("tier", 1))
	var icon: String = "paw" if tier == 1 else ("fang" if tier == 2 else "horns")
	var col: Color = PVE_SERIES_COLORS.get(String(def.get("series", "")), Color("b3a386"))
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.add_frame("idle", ExpeditionPixelArt.get_texture(icon, col, 256))
	return sf


## PvE 专属 UI：明牌概率表（敌方区下缘·暖底芯片）+ 脱离按钮（左下·jelly 节奏橙）。运行时代码建·不动 PvP .tscn。
func _pve_build_ui() -> void:
	_pve_odds_label = Label.new()
	_pve_odds_label.position = Vector2(660, 168)
	_pve_odds_label.size = Vector2(600, 36)
	_pve_odds_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pve_odds_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pve_odds_label.modulate = Color(0.95, 0.91, 0.80)
	_pve_odds_label.pivot_offset = Vector2(300, 18)   # 中心轴=明牌亮出 pop 用
	var chip := StyleBoxFlat.new()   # 暖色深底芯片（J 任务·对齐远征弹窗语言）
	chip.bg_color = Color(0.14, 0.11, 0.07, 0.85)
	chip.border_color = Color("b3a386")
	chip.set_border_width_all(1)
	chip.set_corner_radius_all(6)
	chip.set_content_margin_all(6)
	_pve_odds_label.add_theme_stylebox_override("normal", chip)
	FontManager.apply(_pve_odds_label, 16)
	add_child(_pve_odds_label)
	_pve_flee_btn = Button.new()
	_pve_flee_btn.text = "脱离战斗（挨一拍·退回）"
	_pve_flee_btn.position = Vector2(56, 700)
	_pve_flee_btn.size = Vector2(250, 44)
	FontManager.apply_btn(_pve_flee_btn, 16)
	for st: String in ["normal", "hover", "pressed", "focus"]:
		_pve_flee_btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_pve_flee_btn.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88))
	_pve_flee_btn.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.9))
	_pve_flee_btn.add_theme_constant_override("outline_size", 4)
	var jelly := ColorRect.new()   # 果冻底（节奏橙=撤退语义·show_behind_parent 垫在文字下）
	jelly.color = Color.WHITE
	jelly.set_anchors_preset(Control.PRESET_FULL_RECT)
	jelly.show_behind_parent = true
	jelly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = PVE_JELLY_SHADER
	var base := Color("c47f33")
	m.set_shader_parameter("fill_top", base.lightened(0.12))
	m.set_shader_parameter("fill_bottom", base.darkened(0.32))
	m.set_shader_parameter("edge_inner", base.lightened(0.38))
	m.set_shader_parameter("edge_outer", Color(0.05, 0.045, 0.04))
	m.set_shader_parameter("fill_alpha", 1.0)
	m.set_shader_parameter("pixel_grid", 44.0)
	m.set_shader_parameter("corner", 0.16)
	m.set_shader_parameter("edge_px", 2.0)
	m.set_shader_parameter("aspect", 250.0 / 44.0)
	m.set_shader_parameter("noise_amt", 0.06)
	m.set_shader_parameter("wear", 0.18)
	jelly.material = m
	_pve_flee_btn.add_child(jelly)
	_pve_flee_btn.pressed.connect(_on_pve_flee)
	add_child(_pve_flee_btn)


## 回合开始：怪物定招（引擎从显示表直接采样=明牌诚实性结构保证）+ 更新明牌面板。
func _pve_pick_turn() -> void:
	_pve_choice = _pve_policy.pick(battle, AI)
	var odds: Dictionary = _pve_choice.get("odds", {})
	if odds.is_empty():
		_pve_odds_label.text = "明牌：无（此怪出招有循环·可观察学习）"
	else:
		var names := {"attack": "波", "defend": "防", "charge": "攒", "bigAttack": "大波", "bigDefend": "大防"}
		var parts: Array = []
		for k in odds:
			parts.append("%s %.0f%%" % [String(names.get(k, k)), float(odds[k])])
		_pve_odds_label.text = "明牌 ｜ " + "  ·  ".join(parts)
	# 明牌亮出 pop（J 任务·中心轴回弹·提示"新一拍的牌翻开了"）
	_pve_odds_label.scale = Vector2(1.14, 1.14)
	var tw := create_tween()
	tw.tween_property(_pve_odds_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 脱离战斗（子文档 B §5）：占当拍·敌方本拍动作免费命中一次（无防御结算）·退回进入前格子。
func _on_pve_flee() -> void:
	if state != State.PLAYER_SELECT or battle.game_over or _pve_ending:
		return
	var act: int = int(_pve_choice.get("action", A.CHARGE))
	var dmg: int = 0
	if act == A.ATTACK:
		dmg = 2
	elif act == A.BIG_ATTACK:
		dmg = 4
	if dmg > 0:
		battle.strike(PLAYER, dmg, AI, ActionDef.Pen.NORMAL)   # 无防御动作在场=直落（护盾仍吸收）
	await _pve_finish("flee", 1)


## 回程结算：写 BattleSetup.pve_result → 波幕转场回远征地图（expedition_screen 消费并回写地图状态）。
func _pve_finish(outcome: String, extra_beats: int = 0) -> void:
	if _pve_ending:
		return
	_pve_ending = true
	state = State.GAME_OVER
	_set_buttons_active(false)
	var team_hp: Array = []
	for i in range(battle.hp[PLAYER].size()):
		team_hp.append(maxi(0, battle.hp[PLAYER][i]))
	BattleSetup.pve_result = {outcome = outcome, beats = battle.turn_number + extra_beats,
		team_hp = team_hp, monster_hp = maxi(0, battle.hp[AI][0])}
	var texts := {"win": "怪物被击败！", "lose": "全灭……", "flee": "脱离战斗"}
	status_label.text = String(texts[outcome])
	status_label.add_theme_color_override("font_color", Color("#5fd86b") if outcome == "win" else Color("#dddddd"))
	status_label.visible = true
	await get_tree().create_timer(1.0).timeout
	TransitionManager.transition_to("res://src/expedition/expedition_screen.tscn")


# ============================================================
# 任务G：AI 异步预想（选招期后台想·确认时重放·详见 _think_* 变量注释）
# ============================================================

## 玩家本回合点选道具集的指纹（排序后字符串·预想结果的有效性校验键之一）。
func _items_key() -> String:
	var a: Array[int] = selected_item_slots.duplicate()
	a.sort()
	return str(a)


## 拉起/重启后台预想。仅 PvP 选招阶段（PvE 怪物驾驶员回合开始已定招·不经此路径）。
func _start_ai_think() -> void:
	if _pve or state != State.PLAYER_SELECT or battle == null or battle.game_over:
		return
	if _think_task >= 0:
		_think_restart = true   # 正在想：标记重拉（旧结果会因 items_key/turn 校验不符被弃）
		return
	_think_restart = false
	_think_mutex.lock()
	_think_out = {}
	_think_mutex.unlock()
	var clone: BattleCore = battle.clone()
	for s in selected_item_slots:
		clone.use_slot(PLAYER, s)   # 纳入玩家已点选道具（同步路径确认时同序提交·输入才逐位一致）
	_think_task = WorkerThreadPool.add_task(
		_think_job.bind(clone, battle.turn_number, _items_key(), _ai.rng_snapshot(), _ai_rng.state))


## 工作线程：在克隆上跑与同步 _ai_pick 完全相同的决策序列。只碰克隆与 _think_ai（rng=快照副本）
## → 真局/真 AI/场景树零接触（线程安全）。结果经 mutex 交回。
func _think_job(clone: BattleCore, turn: int, items_key: String, rng_snap: Dictionary, econ_state: int) -> void:
	_think_ai.rng_restore(rng_snap)
	var econ_rng := RandomNumberGenerator.new()
	econ_rng.state = econ_state
	var up: int = _think_ai.plan_economy_decide(clone, AI)
	_think_ai.plan_economy_apply(clone, AI, econ_rng, up)
	var choice: Dictionary = _think_ai.choose_action(clone, AI)
	_think_mutex.lock()
	_think_out = {"turn": turn, "items_key": items_key, "econ_up": up,
			"choice": choice, "rng_end": _think_ai.rng_snapshot()}
	_think_mutex.unlock()
	call_deferred("_on_think_done")


## 主线程回调：回收任务位；期间被要求重想（玩家改了道具/调试改了状态）→ 立即重拉。
func _on_think_done() -> void:
	if _think_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_think_task)   # 任务已结束·立即返回（回收句柄）
		_think_task = -1
	if _think_restart:
		_think_restart = false
		_start_ai_think()


## 确认时消费预想。命中 → 真局重放（经济落子同 rng 起点=逐位一致·选招直接采用·_ai 采纳
## 预想 rng 终态=后续随机流与同步世界一致）并返回 true；未命中/校验不符 → false（调用方走同步兜底）。
func _ai_pick_precomputed() -> bool:
	if _think_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_think_task)   # 还在想 → 等剩余部分（远短于全量）
		_think_task = -1
	_think_mutex.lock()
	var out: Dictionary = _think_out
	_think_out = {}
	_think_mutex.unlock()
	if out.is_empty() or _think_restart:
		return false
	if int(out["turn"]) != battle.turn_number or String(out["items_key"]) != _items_key():
		return false   # 预想期间状态变过（保护网·正常应已被重想覆盖）
	_ai.rng_restore(out["rng_end"])
	_ai.plan_economy_apply(battle, AI, _ai_rng, int(out["econ_up"]))
	var choice: Dictionary = out["choice"]
	BattleAI.commit_attack_items(battle, AI, int(choice["action"]))
	if not battle.apply_choice(AI, choice):
		battle.select_action(AI, A.CHARGE)   # 兜底（与同步路径同款保险）
	return true


func _ai_pick(side: int) -> void:
	# 与 sim 统一：同一套 BattleAI 逻辑——价值搜索道具经济(plan_economy·B) + 同时博弈选动作(choose_action)
	# + 进攻向道具随攻击动作一并甩出(commit_attack_items·2026-07-03)。
	# 取代旧「随机加权出招」占位 AI；试玩与平衡模拟现共用一套决策。AI 不偷看玩家已锁动作（搜索按博弈枚举）。
	_ai.plan_economy(battle, side, _ai_rng)
	var choice: Dictionary = _ai.choose_action(battle, side)
	BattleAI.commit_attack_items(battle, side, int(choice["action"]))
	if not battle.apply_choice(side, choice):
		battle.select_action(side, A.CHARGE)   # 兜底（被禁/付不起→引擎 resolve guard 也兜）


func _resolve() -> void:
	state = State.RESOLVING
	_set_buttons_active(false)
	big_turn_label.visible = false   # 收起中间倒计时（顶部回合数保留）
	status_label.visible = false

	# 结算前的出战槽（= UI 已知的"谁在场上"·上一帧就渲染着·非引擎完整状态·联机客户端同样持有）。
	# 仅用它判定"出战英雄本回合是否阵亡"（配 hero_died 事件），不读结算后的 battle.hp。
	var active_before: Array[int] = [battle.active_index[0], battle.active_index[1]]

	var r: Dictionary = battle.resolve()

	# 动画所需信息全部【从事件流派生】——不再 diff 结算后的引擎完整状态，
	# 联机（服务器权威·客户端只收 events）下同样可行。A3a（2026-07-02）：死亡判定由血量 diff 改吃 hero_died。
	#   damage_taken 累加受伤量；hero_died（槽 == 结算前出战槽）= 该方出战英雄阵亡。
	var dmg: Array[int] = [0, 0]
	var dead: Array[bool] = [false, false]
	for ev in r.get("events", []):
		var p: int = int(ev.get("player", 0))
		match ev.get("id", ""):
			"damage_taken":
				dmg[p] += int(ev.get("amount", 0))
			"hero_died":
				if int(ev.get("slot", -1)) == active_before[p]:
					dead[p] = true

	# 头顶招式圆圈（揭示双方盲选出招）→ 消失 → 再播打斗动画
	await _show_action_indicators(r.get("p1_action", -1), r.get("p2_action", -1))
	await _play_battle_anims(r.get("p1_action", -1), r.get("p2_action", -1), dmg, dead)
	_update_all()

	if r.get("game_over", false):
		var w: int = r.get("winner", BattleCore.WINNER_UNDECIDED)
		# 远征 PvE：胜=怪死·其余（含同拍双死）=全灭 → 回地图结算·不走加时赛。
		if _pve:
			await _pve_finish("win" if w == BattleCore.WINNER_P1 else "lose")
			return
		# 加时赛触发（Q5）：主局双方同归 → 各自 3 选 1 白板满血 1v1；加时局再平 = 真平局（走下方正常结束）。
		if w == BattleCore.WINNER_DRAW and not _overtime:
			await _start_overtime()
			return
		state = State.GAME_OVER
		var msg := "平局"
		var col := Color("#dddddd")
		if w == BattleCore.WINNER_P1:
			msg = "胜利！"
			col = Color("#5fd86b")
		elif w != BattleCore.WINNER_DRAW:
			msg = "失败"
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


## 加时赛（Q5·2026-07-03）：主局同归 → 玩家复用换人浮窗从全队 3 人里选 1（含阵亡者·满血复活），
## AI 选血量上限最大者；组白板 3 人组（板凳 0 血）→ BattleSetup 带旗标整场景重载 = UI 干净重建。
func _start_overtime() -> void:
	state = State.HERO_SELECT
	_set_buttons_active(false)
	status_label.text = "平局 → 加时赛！"
	status_label.add_theme_color_override("font_color", Color("#ffd86a"))
	status_label.visible = true

	var entries: Array = []
	for s in range(battle.heroes[PLAYER].size()):
		var h: HeroData = battle.heroes[PLAYER][s]
		entries.append([s, h, float(h.max_hp)])   # 满血复活展示
	_death_switch_overlay.show_selection(PLAYER, entries, "加时赛：选一人出战（满血·无技能无道具）")
	var pick: int = await _death_switch_overlay.selection_made
	var ai_pick: int = BattleAI.choose_overtime_pick(battle, AI)

	BattleSetup.p1_heroes = BattleCore.overtime_roster(battle.heroes[PLAYER], pick)
	BattleSetup.p2_heroes = BattleCore.overtime_roster(battle.heroes[AI], ai_pick)
	BattleSetup.overtime = true
	get_tree().reload_current_scene()


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
	if not battle.can_switch(PLAYER):
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
	_clear_enemy_targets()   # 放弃已选动作 → 一并退出 h21 敌方目标选择态


# ============================================================
# h21 枭阳【调虎离山】：选敌方替补揪目标（方案1·敌方替补框亮）
# ============================================================

## 选中"需指定敌方替补"的主动技（h21）后：点亮敌方存活替补框、进入选目标态。
func _maybe_arm_enemy_targets() -> void:
	var sk: HeroSkill = battle.get_skill(PLAYER, battle.active_index[PLAYER])
	if sk == null or not sk.active_needs_enemy_target():
		return
	_enemy_targeting = true
	_enemy_target_pick = -1
	for fi in [1, 2]:
		var slot: int = p2_frame_slots[fi]
		if slot >= 0 and slot != battle.active_index[AI] and battle.hp[AI][slot] > 0:
			p2_frames[fi].set_switch_prompt(true, "揪")   # 敌方存活替补：盖「揪」提示（文字/样式待 F6 调）


## 敌方替补框点击（仅 h21 选目标态响应；平时 gate 掉 → 无副作用）：点存活敌方替补 → 设/换/取消揪目标。
func _on_enemy_frame_input(event: InputEvent, frame_idx: int) -> void:
	if state != State.PLAYER_SELECT or not _enemy_targeting:
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var slot: int = p2_frame_slots[frame_idx]
	if slot < 0 or slot == battle.active_index[AI] or battle.hp[AI][slot] <= 0:
		return   # 出战位 / 空位 / 阵亡 → 不可揪
	if _enemy_target_pick == slot:
		_enemy_target_pick = -1                    # 点已选 = 取消（回未选 → 提交走随机）
		p2_frames[frame_idx].is_selected = false
	else:
		for fj in [1, 2]:
			p2_frames[fj].is_selected = false      # 单选：先清旧选中
		_enemy_target_pick = slot
		p2_frames[frame_idx].is_selected = true


## 退出敌方目标选择态：清高亮 + 提示 + 记录（幂等·非 h21 态调用是 no-op）。
func _clear_enemy_targets() -> void:
	if not _enemy_targeting and _enemy_target_pick < 0:
		return
	for fi in [1, 2]:
		p2_frames[fi].is_selected = false
		p2_frames[fi].set_switch_prompt(false)
	_enemy_targeting = false
	_enemy_target_pick = -1


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
		_clear_enemy_targets()   # 离开选择阶段 → 退出 h21 敌方目标选择态
		if btn_jifeng:
			btn_jifeng.visible = false   # 结算/过场：藏疾风开关
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
	var sk: HeroSkill = battle.get_skill(PLAYER, battle.active_index[PLAYER])
	return sk != null and sk.has_active()


func _reset_button_styles() -> void:
	for btn in action_btn_list:
		_set_btn_selected(btn, false)
	_set_confirm_active(false)
	_disarm_switch()   # 退出 armed「切换」态（换人选中随之消失）
	_clear_enemy_targets()   # 退出 h21 敌方目标选择态


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
	_set_cost_pips(btn_special, battle.action_cost(PLAYER, ACTIVE))
	btn_confirm.disabled = false
	_refresh_jifeng()


## 疾风开关（点击 = arm/disarm「附加同种动作」）。仅当前已选动作可双时有效。
func _on_jifeng_pressed() -> void:
	if state != State.PLAYER_SELECT:
		return
	if not battle.can_double_action(PLAYER, selected_action):
		return
	_double_armed = not _double_armed
	_refresh_jifeng()


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
	btn_jifeng.text = "疾风×%d" % battle.double_uses_left(PLAYER)
	_set_btn_selected(btn_jifeng, _double_armed)


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


## M3：P1 道具槽点击分派（按槽态）。抽/补 = 立即生效（公开电报）；
## 使用 = 暂存点选（金边），确认时与动作一起盲选提交。
## 格解锁自动（第 3/4/5 回合·无开格步骤/费用·2026-07-03）→ SEALED（未到解锁回合）点击无操作。
func _on_p1_slot_clicked(s: int) -> void:
	if state != State.PLAYER_SELECT or _drafting:
		return
	match battle.slot_state(PLAYER, s):
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
	_start_ai_think()   # 任务G：道具点选/抽/补都改变 AI 该看到的棋盘 → 重想


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
		_start_ai_think()   # 任务G：升级改变棋盘 → 重想


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


# ============================================================
# 战斗内设置入口（右上角小钮 + ESC）
# ============================================================

## 右上角"设置"小钮（P2 道具槽行下方空区·暗色低调工具件·不与战斗 UI 抢眼）。
func _build_settings_button() -> void:
	var b := Button.new()
	b.name = "SettingsButton"
	b.text = "设置"
	FontManager.apply_btn(b, 16)
	b.add_theme_color_override("font_color", Color(0.70, 0.64, 0.53))       # 暖骨降级字色（工具件·非主操作）
	b.add_theme_color_override("font_hover_color", Color(0.95, 0.91, 0.8))  # hover 暖米白
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.06, 0.72)
	sb.border_color = Color(0.42, 0.36, 0.26, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	b.position = Vector2(1826.0, 254.0)   # P2 道具槽行正下方右缘（空天区·不压任何 HUD）
	b.size = Vector2(64.0, 30.0)
	b.pressed.connect(_open_settings)
	add_child(b)


## 打开设置浮层（复用主菜单 SettingsPanel·加为末子节点=盖住全部战斗 UI）。
## 打开期间暂停出招倒计时（防止面板里改设置时被自动确认），关闭恢复。
func _open_settings() -> void:
	if has_node("SettingsPanel"):
		return
	var panel := SettingsPanel.new()
	panel.name = "SettingsPanel"
	add_child(panel)
	game_timer.paused = true
	panel.closed.connect(func() -> void: game_timer.paused = false)


## ESC 打开设置（面板开着时其自身 _input 先拦下 ESC 用于关闭，不会走到这里）。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not has_node("SettingsPanel"):
		_open_settings()


# ============================================================
# 调试测试按钮（左侧）—— DEBUG_BUTTONS 开关
# ============================================================

## 左侧竖排测试按钮拆入独立组件 BattleDebugPanel（src/ui/debug/·全项目唯一改写引擎状态处·防作弊隔离）。
## battle_screen 只负责创建 + 接其信号（刷新 / 打击 juice），本身不再直写 battle 状态（见 test 里的 grep 断言）。
func _build_debug_buttons() -> void:
	if not DEBUG_BUTTONS:
		return
	var panel := BattleDebugPanel.new()
	panel.name = "DebugButtons"
	add_child(panel)
	panel.setup(battle)
	panel.state_changed.connect(_on_debug_state_changed)
	panel.hit_fx.connect(_on_debug_hit_fx)


## debug 面板改了 battle 状态 → 刷新全套显示（含换英雄需刷技能卡·多刷无害）。
func _on_debug_state_changed() -> void:
	_update_all()
	_refresh_skill_card()
	_start_ai_think()   # 任务G：调试面板直改引擎状态 → 预想作废重想


## debug 造伤按钮 → 播打击表现（飘字 / 斩击 / 白闪 / 震屏）。
func _on_debug_hit_fx(player: int, dmg_half: int) -> void:
	_impact(player, dmg_half)
	stage.shake(SHAKE_HIT)


# ============================================================
# 动画 / juice
# ============================================================

## A 方案 juice：出招（攻击前冲 / 防御蓝闪沉身 / 攒上浮黄闪）→ 命中（白闪 + 斩击光
## + 伤害数字 + 震屏）。dmg/dead 为 [p0, p1]。无逐帧 attack/hit 动画，全靠代码表现。
func _play_battle_anims(a0: int, a1: int, dmg: Array, dead: Array) -> void:
	# 执行动作 → 镜头聚焦"冲突落点"（Eddy 2026-07-09 镜头规格）：双方都进攻=居中放大对撞（配震屏）；
	# 仅对方进攻=偏左聚受击的己方；仅己方进攻=偏右聚受击的敌方；双方都未进攻=不推近。
	var p1_off := _is_offense(a0, int(dmg[1]), bool(dead[1]))
	var p2_off := _is_offense(a1, int(dmg[0]), bool(dead[0]))
	# 终结演出（Q1A）：本拍"动作直接击杀出战英雄"→ 专用慢放演出取代普通结算演出。
	# 毒引爆随攻击结算=攻击致死会触发；反弹死/纯道具死（击杀侧非进攻动作）不触发；
	# 天狗御凶拦下致命伤=没死=自然不触发。
	var fin_kill_p2 := bool(dead[1]) and p1_off
	var fin_kill_p1 := bool(dead[0]) and p2_off
	if fin_kill_p1 or fin_kill_p2:
		await _play_finisher(dmg, fin_kill_p2, fin_kill_p1)
		return
	var fdir := 0.0
	if p1_off != p2_off:
		fdir = 1.0 if p1_off else -1.0
	stage.set_focus(p1_off or p2_off, fdir)
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


## 终结演出（Eddy 2026-07-09 批·参考暗黑地牢判定演出）：斩杀拍的专用结算演出，取代普通路径。
## 流程=背景虚化退场（FinisherVeil 压暗+模糊·只糊背景不糊双雄）→ 双雄放大错位拉出（击杀方
## 向前压/受击方向后让·绕脚底锚缩放）→ 全场慢放出招（帧动画英雄播 attack）→ 强化命中
## （白闪/弧光/火花/飘字慢速展开+强震+强顿帧）→ 恢复。总时长 ≈1.9s（普通结算 ≈0.9s·延长约 1s）。
## 双死=居中对撞构图。后置条件与普通路径一致（阵亡变灰·镜头回正·time_scale=1）→ 换人流程照旧。
## 编排时钟全用 ignore_time_scale 真实时长（慢放期间 await 不被拉长）；视觉 tween 随 time_scale
## 自然慢放=演出本体。
func _play_finisher(dmg: Array, kill_p2: bool, kill_p1: bool) -> void:
	var killer := 0 if kill_p2 else 1
	var both := kill_p2 and kill_p1
	var fdir := 0.0 if both else (1.0 if killer == 0 else -1.0)
	# ── 拉出（正常速度·0.22s）：虚化幕淡入 + 双雄放大错位 + 镜头推近受击侧 ──
	finisher_grab.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	finisher_veil.visible = true
	var vmat := finisher_veil.material as ShaderMaterial
	vmat.set_shader_parameter("strength", 0.0)
	var vt := create_tween()
	vt.tween_method(func(v: float) -> void: vmat.set_shader_parameter("strength", v),
			0.0, 1.0, FINISHER_VEIL_IN)
	stage.set_focus(true, fdir)
	for p in 2:
		var cd := _cd(p)
		cd.pivot_offset = Vector2(cd.size.x * 0.5, cd.size.y * 0.67)   # 脚底锚：放大不离地
		var toward := 1.0 if p == 0 else -1.0   # 朝对方方向
		var shift := FINISHER_SHIFT_KILLER if (both or p == killer) else -FINISHER_SHIFT_VICTIM
		var tw := create_tween().set_parallel(true)
		tw.tween_property(cd, "scale", Vector2.ONE * FINISHER_SCALE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(cd, "position", _cd_home[p] + Vector2(shift * toward, 0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.22, true, false, true).timeout
	# ── 慢放出招（全场 0.45×·帧动画约 0.6s 真实展开·同步小前刺）──
	_time_scale_base = FINISHER_SLOW
	Engine.time_scale = FINISHER_SLOW
	for p in 2:
		if both or p == killer:
			var cd := _cd(p)
			cd.play_animation("attack")
			var dirn := 1.0 if p == 0 else -1.0
			var tw := create_tween()
			tw.tween_property(cd, "position", _cd_home[p] + Vector2((FINISHER_SHIFT_KILLER + 120.0) * dirn, 0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(0.65, true, false, true).timeout
	# ── 命中（慢放中·特效慢速展开）──
	if kill_p2:
		_finisher_impact(1, int(dmg[1]))
	if kill_p1:
		_finisher_impact(0, int(dmg[0]))
	stage.shake(SHAKE_BIG * 1.3)
	_hitstop(0.1)
	await get_tree().create_timer(0.45, true, false, true).timeout
	# ── 恢复：时间回正 → 杀掉命中残留 tween（慢放里跑不完·晚于归位结束会把 scale 写回放大值）
	#    → 幕淡出关停 → 双雄归位（阵亡者保持灰·换人流程接手）──
	_time_scale_base = 1.0
	Engine.time_scale = 1.0
	for ft in _fin_impact_tweens:
		if ft.is_valid():
			ft.kill()
	_fin_impact_tweens.clear()
	var vt2 := create_tween()
	vt2.tween_method(func(v: float) -> void: vmat.set_shader_parameter("strength", v),
			1.0, 0.0, FINISHER_VEIL_OUT)
	vt2.tween_callback(func() -> void:
		finisher_veil.visible = false
		finisher_grab.copy_mode = BackBufferCopy.COPY_MODE_DISABLED)
	for p in 2:
		var cd := _cd(p)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(cd, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE)
		tw.tween_property(cd, "position", _cd_home[p], 0.22).set_trans(Tween.TRANS_SINE)
	stage.set_focus(false)
	await get_tree().create_timer(0.3, true, false, true).timeout


## 终结版命中表现：不用 _impact——其 _char_pop 会把拉出的 1.35 放大拽回 1.0、自带顿帧也与
## 终结统一顿帧冲突。改为放大基础上的小 punch + 阵亡变灰下沉。
func _finisher_impact(target_player: int, dmg_half: int) -> void:
	var cd := _cd(target_player)
	cd.flash_white(0.3)
	cd.pulse_rim(1.0, 0.3)
	_spawn_slash(target_player)
	_spawn_spark(target_player, true)
	if dmg_half > 0:
		_pop_damage(target_player, float(dmg_half) / 2.0)
	var tw := create_tween()
	tw.tween_property(cd, "scale", Vector2.ONE * (FINISHER_SCALE * 1.08), 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(cd, "scale", Vector2.ONE * FINISHER_SCALE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	cd.modulate = Color(0.35, 0.35, 0.35)   # 阵亡变灰（与普通路径一致）
	var tw2 := create_tween()
	tw2.tween_property(cd, "position:y", cd.position.y + 14.0, 0.3).set_trans(Tween.TRANS_SINE)
	_fin_impact_tweens.append(tw)
	_fin_impact_tweens.append(tw2)


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
			if cd.has_action_anim("attack"):
				# 帧动画英雄（h01 起）：挥刀帧信息量大会盖掉常规前冲——省去容器后撤
				# （动画自带蓄势）、前冲加大 1.3× 并顶在前段贯穿命中拍（0.27s），平移才读得出来。
				cd.play_animation("attack")
				tw.tween_property(cd, "position", home + Vector2(reach * 1.3 * dir, 0), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw.tween_interval(0.14)
				tw.tween_property(cd, "position", home, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			else:
				# 静态图英雄：后撤蓄势 → 前冲 → 回位（平移=唯一攻击运动信号·原配方不动）。
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
		Engine.time_scale = _time_scale_base   # 恢复到基准（终结演出慢放期间=FINISHER_SLOW）


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
		# 鼠标视差：角色组加上地面层同款平移（stage.pointer_ground_offset）→ 与脚下屋脊零滑动。
		_world.position = stage.focal() * (1.0 - gd) + stage.pointer_ground_offset()


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
