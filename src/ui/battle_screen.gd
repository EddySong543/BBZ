extends Control

## 1920x1080. 共用布局在 battle_screen_base.tscn 可视化编辑；
## battle_screen1.tscn / battle_screen2.tscn 只组合各自舞台与环境参数。
## v4 引擎（BattleCore）+ 同时盲选 vs AI（决策 B1）。
## 你 = P0（下），对手 = P1（上，AI）。玩家选动作 → 确认 → AI 后台选 → 同时结算。
##
## 半点制：HP/护盾内部为半点，显示用 battle.hp_display()。

const A := ActionDef.Action
const ACTIVE := ActionDef.ACTIVE
const FURNACE_ITEM_ID := "t1_ronglu"
const POINTSTONE_ITEM_ID := "t2_dianjinshi"
const DEPOSIT_ITEM_ID := "t1_jicun_pai"
const INSURANCE_ITEM_ID := "t2_baojia_feng"
const EXCHANGE_ITEM_ID := "t2_huanqian_tong"
const REPURCHASE_ITEM_ID := "t2_huigou_quan"
const ENERGY_COST_SHEET := preload("res://assets/ui/icons/energy_idle.png")
const HEART_COST_SHEET := preload("res://assets/ui/icons/heart_idle.png")
const LONGYUJI_SKILL_ICON := preload("res://assets/sprites/heroes/h05/h05_skill.png")
const ANCHAO_SKILL_ICON := preload("res://assets/sprites/heroes/h13/h13_skill.png")
const H24_SKILL_ICON := preload("res://assets/sprites/heroes/h24/h24_skill.png")
const HERO_FRAME_SCENE := preload("res://src/ui/components/hero_frame.tscn")
const BACKPACK_OVERLAY_SCENE := preload("res://src/ui/backpack_screen.tscn")
const BACKPACK_ICON := preload("res://assets/ui/icons/backpack.png")

# 动作按钮"能量消耗"金币（1 能量 1 球）= battle_screen_base.tscn 内每个按钮下的 CostPips 节点，
# 位置/大小/间距在 Godot 编辑器里可视化调整（可视化设计·任务2）；代码只在运行时填入数量。

const SCREEN_W := 1920.0
const SCREEN_H := 1080.0

## 出战血条低血红闪阈值（HP 占比 ≤ 此值）；闪烁在 IconPipRow 内部实现（任务5：红光改到剩余血量爱心上）。
const LOW_HP_RATIO := 0.5

## 顶部 UI 整体下移量(px)：原布局太贴屏幕顶端 → 下沉一点留呼吸。改这一个数即可整组调整。
## 注：当前为运行时代码统一微调(编辑器里仍是基准位)；下移量定稿后可烘焙进 .tscn 使"所见=所得"。
const TOP_UI_DROP := 26.0   # 顶部 UI 整体下移量（2026-06-28 Eddy：44太多→回调到26）；0=复原原位
const BUBBLE_HEAD_RISE := 102.0  # 出招气泡锚点：角色显示容器「中心」上移此值（越大气泡越高·够高才不压角色·随立绘 2.0x 同步 2026-07-11）
const BUBBLE_SIDE_X := 91.0      # 出招气泡水平偏移：己方(P0)放头「右上」/ 敌方(P1)镜像「左上」（越大越往外侧·够大才不和角色重合·随立绘 2.0x 同步）

## 顶部头像框尺寸。出战 / 替补。**摆位一律在 battle_screen_base.tscn 里定**（offset_* 已按本尺寸摆好），
## 代码只负责把尺寸喂给 HeroFrame —— 旧 _enlarge_frames「按基准差量偏移」的代偿已退役。
## 尺寸线：72/68（2026-07-17 缩小批）→ **80/76（2026-07-18 Eddy「只要微微放大」·92/84 一版判过大回调）**。
const FRAME_ACTIVE_SIZE := 80.0
const FRAME_BENCH_SIZE := 76.0

## 菱形头像的**绝对**高度（成品像素）——与框尺寸解耦：框放大时头像原地不动
## （Eddy 2026-07-18：「只放大头像框，不放大内部头像」）。取值 = 放大前的视觉大小
## （旧 72×1.15 / 68×1.15），所以这批只有框变大、头像一像素没动。
const PORTRAIT_ACTIVE_PX := 82.8
const PORTRAIT_BENCH_PX := 78.2

## 菱形头像在框内的上抬量（像素）。**这才是"脸被斜边切到"的唯一有效旋钮**：
## 下巴处允许的横向宽度 = 下巴离框底的高度，与框边长无关 → 放大框不解决遮挡，抬头才解决
## （一轮靠放大"顺带"顶上去，被 Eddy 判为没真修）。12/11 = 实拍逐档（tools/diamond_probe 扫 rise）
## 挑出的分水岭：脸完全脱离斜边、只切衣领，框底露出的暗底楔形也还不难看。
const PORTRAIT_ACTIVE_RISE := 12.0
const PORTRAIT_BENCH_RISE := 11.0

## battle_screen 顶部菱形头像框专用描边；HeroFrame 默认值仍供其他界面沿用。
## 亮边 4px → 6px，近黑外压边保持 2px，增强小尺寸 HUD 上的轮廓辨识度。
const BATTLE_DIAMOND_STROKE_PX := 6.0
## UI 与中央「回合开始」同方向的定向下投影：横向只偏 3px，纵向落 6px。
## 只增加层级分离，不扩大点击区域，也不参与按钮配色。
const UI_BOTTOM_SHADOW_OFFSET := Vector2(3.0, 6.0)
const UI_BOTTOM_SHADOW_COLOR := Color(0.02, 0.012, 0.008, 0.52)

## 这 8 位英雄的旧 portrait 是从头部中段截出的截图，头饰/耳朵已在源文件里被裁掉。
## 战斗顶部单独改用手动裁好的 battle portrait；图鉴、BP 等其他构图不受影响。
const BATTLE_PORTRAIT_OVERRIDES := {
	"h04": "res://assets/sprites/heroes/h04/h04_battle_portrait.png",
	"h05": "res://assets/sprites/heroes/h05/h05_battle_portrait.png",
	"h08": "res://assets/sprites/heroes/h08/h08_battle_portrait.png",
	"h10": "res://assets/sprites/heroes/h10/h10_battle_portrait.png",
	"h12": "res://assets/sprites/heroes/h12/h12_battle_portrait.png",
	"h19": "res://assets/sprites/heroes/h19/h19_battle_portrait.png",
	"h20": "res://assets/sprites/heroes/h20/h20_battle_portrait.png",
	"h22": "res://assets/sprites/heroes/h22/h22_battle_portrait.png",
}

## 手裁 battle portrait 保留原始像素，因此画布尺寸并不统一；统一压成 82.8/78.2px 会让
## 大画布英雄的脸缩小。这里按人物实际占比逐个校准显示倍率与水平中心，不修改手裁资产本身。
## scale：相对常规 portrait 显示高度；x/y：出战框成品像素偏移（替补按框比例同步缩放）。
## x 只以未翻转原图的脸部中心为准；P2 水平翻转时 HeroFrame 会自动反号，保证两边都居中。
const BATTLE_PORTRAIT_TUNING := {
	"h03": {"scale": 1.00, "x": 0.0, "y": -2.0},  # 轻微下移
	"h04": {"scale": 1.30, "x": -7.0, "y": -2.0}, # 与 h03 同幅下移
	"h05": {"scale": 1.22, "x": 0.0, "y": -4.0},  # 再向左下各微调 2px
	"h08": {"scale": 1.10, "x": 0.0, "y": 0.0},   # 已验收，保持不动
	"h10": {"scale": 1.04, "x": 2.0, "y": 2.0},   # 水平不动，仅轻微上提脸部
	"h07": {"scale": 1.00, "x": -5.0, "y": -3.0}, # 再向左微调 2px
	"h12": {"scale": 0.98, "x": 0.0, "y": 0.0},   # 再向右移动 3px
	"h19": {"scale": 1.05, "x": -4.0, "y": 0.0},  # 再向右移动 3px
	"h20": {"scale": 1.22, "x": -5.0, "y": 0.0},  # 再向右微调 2px
	"h21": {"scale": 1.00, "x": 0.0, "y": -6.0},  # 再向下移动 3px
	"h22": {"scale": 1.02, "x": 0.0, "y": 2.0},   # 水平不动，仅轻微上提脸部
}

## 默认阵容 fallback：直接打开 battle_screen1.tscn(F6) 测试用，BattleSetup 为空时启用。
const HERO_DATA_DIR := "res://assets/data/heroes/"
const DEFAULT_P0 := ["h01", "h05", "h06"]   # 子鼠 / 辰龙 / 巳蛇（首发 12 生肖）
const DEFAULT_P1 := ["h02", "h09", "h12"]   # 丑牛 / 申猴 / 亥猪（首发 12 生肖）

## 左侧调试测试按钮（满能量/满血/造伤/加盾）。仅本地调试：直改 BattleCore 状态后刷新。
## 运行时双门在 _build_debug_buttons：联机局禁用 + release 模板不建（OS.is_debug_build()）——
## 本常量=开发期手动总开关无须动。⚠脚本文件仍会进 release 包：发布时导出过滤须排除
## src/ui/debug/**（已列入 docs/pck-encryption-guide.md 发布清单·2026-07-17 审计）。
const DEBUG_BUTTONS := true
# debug 面板改运行时 load（2026-07-17 发行审计②）：preload=硬编译引用——发行导出按
# export_presets.example.cfg 排除 src/ui/debug/** 后会让本文件编译失败；load 在
# _build_debug_buttons 双门（联机禁用+is_debug_build）之后才执行=开发期照常·发行包可剥离。
const ProfileStore := preload("res://src/core/player_profile.gd")   # 个人资料战绩计数（同上·preload 引用）
const RoundLabelOrnamentsComponent := preload("res://src/ui/components/round_label_ornaments.gd")
const CentralTurnCueComponent := preload("res://src/ui/components/central_turn_cue.gd")
## 出战血条＝斜切分段条（2026-07-18 取代心形 IconPipRow）。走 preload 常量当类型：
## 新 class_name 在 headless/GUT 首跑可能尚未注册（踩过·见 memory godot-headless-classname-preload）。
const HpSlantBarScript := preload("res://src/ui/components/hp_slant_bar.gd")

## 各动画相位等待（秒），可在 Inspector 调。
@export var anim_phase_duration: float = 1.0
@export var action_phase_duration: float = 0.6
## 独立场景变体可把现有角色 SubViewport 送入指定水面；默认关闭，Scene1 不改变。
@export var character_reflections_enabled: bool = false
@export var character_reflection_receiver_path: NodePath = ^"River"
## 当前角色素材的脚底在 768px SubViewport 中约为 63.5%；作为镜像与水线相接的锚点。
@export_range(0.0, 1.0, 0.001) var character_reflection_foot_ratio: float = 0.635
## 死亡五拍：短定格 → 受力衔接 → 倒地帧真实结束 → 末帧停留 → 四周侵蚀式像素瓦解。
## 所有节拍均以事件为锚，不再假定每名英雄的 defeat 都固定为 0.7 秒。
@export var kill_hitstop_duration: float = 0.11
@export var death_recoil_duration: float = 0.07
@export var death_recoil_distance: float = 8.0
@export var death_final_frame_hold_duration: float = 0.26
@export var death_dissolve_duration: float = 0.60
@export_range(4, 24, 1) var death_dissolve_steps: int = 12
@export var death_entry_duration: float = 0.24
@export var death_entry_drop: float = 18.0
const DEATH_DISSOLVE_OPEN_PROGRESS: float = 0.25
const DEATH_DISSOLVE_MIDDLE_PROGRESS: float = 0.83
const DEATH_DISSOLVE_OPEN_SHARE: float = 0.30
const DEATH_DISSOLVE_MIDDLE_SHARE: float = 0.42
const DEATH_DISSOLVE_CLOSE_SHARE: float = 0.28
# 回合时限阶梯（2026-07-11 Eddy 定·由少到多·台阶绑道具解锁节奏）：回合 1-2 纯动作选择 10s →
# 回合 3 起道具经济开动（3/4/5 逐格解锁）15s → 回合 6 起组合决策期（看描述/算对方）20s 封顶。
const TURN_TIME_STEPS: Array = [[5, 20], [2, 15], [0, 10]]   # [起始回合(0-based), 秒]·降序查表
const COUNTDOWN_WARNING_3_COLOR := Color("#f1c21b")   # IBM Carbon Yellow 30
const COUNTDOWN_WARNING_2_COLOR := Color("#ff832b")   # IBM Carbon Orange 40
const COUNTDOWN_WARNING_1_COLOR := Color("#da1e28")   # IBM Carbon Red 60
const COUNTDOWN_ALERT_OUTLINE_COLOR := Color(0.07, 0.04, 0.02, 0.86)

@export_group("Top Countdown Theme")
@export var countdown_normal_color: Color = Color("#f2e8cc")
@export var countdown_outline_color: Color = Color(0.0, 0.0, 0.0, 0.8)
@export_range(0, 8, 1) var countdown_outline_size: int = 4
@export var countdown_shadow_color: Color = Color(0.0, 0.0, 0.0, 0.60)
@export_range(-8, 8, 1) var countdown_shadow_offset_x: int = 3
@export_range(-8, 8, 1) var countdown_shadow_offset_y: int = 3
@export var countdown_ornament_color: Color = Color("#f2e8cc")
@export var countdown_ornament_underlay_color: Color = Color(0.07, 0.04, 0.02, 0.88)
@export_range(0.0, 6.0, 0.5) var countdown_ornament_underlay_width: float = 3.0

enum State { TURN_INTRO, PLAYER_SELECT, RESOLVING, HERO_SELECT, GAME_OVER }
enum ItemSlotTargetMode { NONE, CONSUMES, TRANSFORMS, PRESERVES }

var battle: BattleCore
var state: int = State.TURN_INTRO
var timer_seconds: int = 0

const PLAYER := 0   # 本地玩家固定 P0
const AI := 1       # 对手 AI

# ---- @onready: battle_screen_base.tscn 内预置节点（布局保留，路径勿改）----
@onready var timer_label: Label = $TimerLabel
@onready var status_label: Label = $StatusLabel
@onready var event_label: Label = $EventLabel
@onready var big_turn_label: Label = $BigTurnLabel
var _round_ornaments
var _central_turn_cue

# 出战角色名(每回合随出战英雄更新) + 玩家名(我方=资料档案真名·对手=场景占位值·联机对手名待协议捎带)。
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
# 待选英雄血量/护甲=单个平行四边形符号+数字（英雄图鉴「图标+数字」版式）。index 0 = 出战位 → null。
@onready var p1_frame_hp_rows: Array = [null, $P1Hud/P1Frame1HpRow, $P1Hud/P1Frame2HpRow]
@onready var p2_frame_hp_rows: Array = [null, $P2Hud/P2Frame1HpRow, $P2Hud/P2Frame2HpRow]
var p1_frame_slots: Array[int] = [-1, -1, -1]
var p2_frame_slots: Array[int] = [-1, -1, -1]

var btn_backpack: Button = null       # 右下「背包」入口（程序化创建）
var btn_switch: Button = null         # 左下切换入口；候选头像从它向右展开
var _switch_button_icon: HoverIcon = null
var _switch_tray: Control = null
var _switch_candidate_frames: Array[HeroFrame] = []
var _switch_tray_open := false
var _switch_tray_tween: Tween = null
const SWITCH_MAIN_POS := Vector2(30.0, 46.0)
const SWITCH_MAIN_SIZE := Vector2(108.0, 108.0)
const SWITCH_FRAME_SIZE := 76.0
const SWITCH_FRAME_STEP := 94.0
var _special_icon: TextureRect = null # 技能钮内的英雄专属技能图标（2026-07-17 Eddy 点单·懒创建）
var _backpack_overlay: Control = null # 战斗内背包浮层（懒创建·关闭仅隐藏）

@onready var buttons_ctrl: Control = $Buttons
@onready var _death_switch_overlay: DeathSwitchOverlay = $DeathSwitchOverlay
@onready var game_timer: Timer = $GameTimer
@onready var stage: BattleStage = get_node_or_null("StageSlot/Stage") as BattleStage
# 终结演出背景虚化幕（Stage 之后·WorldGroup 之前 → 只糊背景不糊双雄）。平时 veil 隐藏 +
# grab DISABLED = 零成本；仅 _play_finisher 期间开启。
@onready var finisher_grab: BackBufferCopy = $FinisherGrab
@onready var finisher_veil: ColorRect = $FinisherVeil
@onready var post_fx: ColorRect = $PostFX           # 全屏调色（黑白闪借它的 saturation 参数·零新 pass）

@onready var btn_charge: Button = $Buttons/BtnCharge
@onready var btn_attack: Button = $Buttons/BtnAttack
@onready var btn_big_attack: Button = $Buttons/BtnBigAttack
@onready var btn_defend: Button = $Buttons/BtnDefend
@onready var btn_big_defend: Button = $Buttons/BtnBigDefend
@onready var btn_special: Button = $Buttons/BtnSpecial
@onready var btn_confirm: Button = $Buttons/BtnConfirm

# 新美术 HUD：心形血珠 + 金币能量点（替换旧 EnergyBar / ArcHealthBar）。
@onready var p1_heart_row: HpSlantBarScript = $P1Hud/P1HeartRow
@onready var p2_heart_row: HpSlantBarScript = $P2Hud/P2HeartRow
@onready var p1_coin_row: IconPipRow = $P1Hud/P1CoinRow
@onready var p2_coin_row: IconPipRow = $P2Hud/P2CoinRow
@onready var p1_energy_cap_label: Label = $P1Hud/P1EnergyCapLabel
@onready var p2_energy_cap_label: Label = $P2Hud/P2EnergyCapLabel

# 道具栏（M2·占位）：程序化挂在各 HUD 下。P1=贴左(对齐左侧框组·28px 内边距)；
# P2=镜像右贴(右内边距=P1 左内边距)，由 _build_item_rows 随槽宽自动算，修「敌方框偏左」错位。
const ITEM_ROW_POS_P1 := Vector2(28.0, 150.0)   # 2026-06-28 Eddy：道具栏上移一些(168→150)
const ITEM_ROW_SCALE := 0.92   # 小于 76px 替补头像一个层级，仍比旧 0.85 档清楚。
var p1_item_row: ItemSlotRow
var p2_item_row: ItemSlotRow
## M3：本回合已点选「使用」的道具槽（仅 P1）；确认时统一 use_slot 提交，进新回合清空。
var selected_item_slots: Array[int] = []
## 需要另选槽位的道具参数：使用槽 -> 目标道具槽。熔炉消耗目标，点金石变换目标。
var selected_item_targets: Dictionary = {}
## 需要明确选择己方英雄的道具参数：使用槽 -> 己方英雄槽（移甲环、护阵钉）。
var selected_item_hero_targets: Dictionary = {}
## 道具私有候选下标：使用槽 -> 候选下标。其余道具缺省为 -1。
var selected_item_choices: Dictionary = {}
## 联机端仅在本人内存保留私有候选 id，便于显示与取消后复核，不写入公共视图。
var selected_item_choice_options: Dictionary = {}
## 首次点需要槽目标的道具后暂存；只有再点合法目标完成配对，来源才进入 selected_item_slots。
var _pending_item_target_slot: int = -1
## 正在等待玩家点击己方头像的道具来源槽。
var _pending_item_hero_target_slot: int = -1
## 正在等待玩家点击敌方锁定道具槽的来源槽（时滞枷锁）。
var _pending_enemy_item_target_slot: int = -1
var _item_target_prompt_frames: Array[int] = []
## 联机请求带选择的道具候选后等待权威私发的 {source,target,item_id}；期间不允许改动配对。
var _pending_pointstone_offer: Dictionary = {}
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

# ── 远征 PvE：公共战斗核心 + 跨战生命/回程适配 ──
const BattlePveScript := preload("res://src/ui/components/battle_pve.gd")   # PvE 跨战状态/回程适配层（仅 PvE 局创建）
const NAV_PLATE_TEX := preload("res://assets/ui/ui_nav_button.png")   # 导航钮贴图（米金纸面+角折·与主菜单同源）
const SWITCH_ICON_TEX := preload("res://assets/ui/icons/switch_hover_sheet.png")
## 4×2 图集按左上到右下编号 0..7：排除第一行第四帧(3)、第二行第一帧(4)，
## 新版第二行其余格也为空，因此只播放三个实际有内容的帧。
const SWITCH_ICON_PLAYBACK_FRAMES: Array[int] = [0, 1, 2]
var _pve := false                             # 本局=远征 PvE（BattleSetup.pve_mode·须在 reset() 前读）
var _pved: Node = null                        # PvE 只保留真 HeroData、跨战 HP 与回程结果适配
var _net := false                             # 本局=联机局（BattleSetup.net_session 非空·M1）
var _net_last_turn := 0                       # 已进入选招的回合号（检测服务器 turn_begin）
var _net_busy := false                        # 联机结算演出进行中（pump 串行防重入）
var _net_snap_rev := 0                        # 已上镜的快照版本号（client.snap_rev 对账）
var _net_link_lost := false                   # 对端断线提示态（M2b·重连自动恢复）
const MatchClientScript := preload("res://src/net/match_client.gd")   # 视角翻转静态工具（M1）

# ---- 选择 / 样式 ----
var action_btn_list: Array[Button] = []
var selected_action: int = -1
var selected_second_action: int = -1
var _second_enemy_target_pick: int = -1
var _second_action_btn: Button = null
var selected_switch: int = -1
var selected_btn: Button = null

# ---- 攻击变体（程序化创建·不入 .tscn）----
var longyuji_picker: Control = null
var btn_longyuji_branch: Button = null
var split_big_wave_picker: Control = null
var btn_split_big_wave: Button = null
var h24_discount_picker: Control = null
var btn_h24_discount: Button = null
var _empowered_wave_armed: bool = false   # 本回合是否为已选「波」追加龙御极的 1 能 / 1 伤
var _split_big_wave_armed: bool = false   # 本回合是否把玄冥的「大波」改为连续两次「波」
var _blood_payment_armed: bool = false    # 本回合是否由出战蚩尤以等量生命支付行动费用
var _energy_cap_discount_armed: bool = false # 本回合是否降低 1 点能量上限，换取行动费用 -1
var _free_switch_sequence: Array[int] = [] # 联机提交时重放本回合千里自在风的逻辑预览序列
var _blood_payment_activation_step: int = -1 # 在第几次免费切换前由蚩尤发动（-1=未发动）

# ---- 主动换人（任务5）：点替补框→框内显「切换」(armed)→再次点=选择(动画)→「结束」提交 ----
var _armed_switch_frame: int = -1   # 当前 armed 的替补框索引（1 / 2），-1=无
var _switch_selected: bool = false  # armed 框是否已进入"选择"态（高亮·待「结束」提交）
var _enemy_targeting: bool = false  # 是否处于敌方英雄目标选择态（h21 主动技 / h04 基础攻击）
var _enemy_target_action: int = -1  # 触发目标选择的动作；ACTIVE=h21，波/大波=h04
var _enemy_target_pick: int = -1    # 已点选的敌方英雄槽（h21 未选=-1；h04 默认当前出战位）

# ---- juice ----
# 受击震屏基幅（实际位移 = 基幅 × 各层 parallax_factor·见 scene1.tscn / battle_stage.gd）。
# 只在受击触发、克制；建筑无 idle 漂移（_ready 关 idle_drift），仅震时才动。F6 调幅在此。
const SHAKE_BIG := 12.0     # 大波命中
const SHAKE_HIT := 7.0      # 普通命中
const SHAKE_BLOCK := 3.5    # ② 被挡（无命中时的接触感·比普通命中轻一半以上）
const PUNCH_RELEASE := 0.35   # P3：大波前推命中后的回弹时长（落在 settle 内）

# ── 终结演出旋钮（Eddy 2026-07-09·Q1A 仅动作直接击杀 / Q2B 压暗+真模糊 / Q3A 全场慢放）──
const FINISHER_SLOW := 0.45          # 慢放倍率（全场 time_scale·参考暗黑地牢判定演出）
const FINISHER_SCALE := 1.35         # 双雄拉出放大倍率（绕脚底锚点）
const FINISHER_SHIFT_KILLER := 90.0  # 击杀方向中错位（px·向前压）
const FINISHER_SHIFT_VICTIM := 34.0  # 受击方退让错位（px·向后让）
const FINISHER_VEIL_IN := 0.18       # 虚化幕淡入时长（s）
const FINISHER_VEIL_OUT := 0.22      # 虚化幕淡出时长（s）
# ── 冲击帧（Eddy 2026-07-10 定 A/A/A：二值化+受击点锯齿炸开+正负反转·终结命中拍专属·⚠待 F6；
#    边缘速度线已试装后删除=方向否；纯降饱和灰度版=方向否"只是变灰没有黑白暴力感"）──
const FINISHER_BW_POS := 0.08        # 正片段时长（真实秒·墨黑纸白）
const FINISHER_BW_NEG := 0.055       # 负片段时长（真实秒·黑白互换一闪·0.07→0.055 压刺眼）·形态旋钮在 PostFX 材质 impact_* 组
var _confirm_pulse: Tween   # 「结束」按钮的呼吸金光（有待确认动作时召唤点击）
var _cd_home: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]  # 立绘原位（前冲 juice 复位用）
var _shadow_home: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]  # 阴影原位（跟随角色水平位移用）
var _prev_hp_disp: Array[float] = [-1.0, -1.0]   # 上次显示的出战 HP（检测变化 → 心条 flinch 脉冲）
var _hitstop_token: int = 0   # hitstop(c) 防重叠：仅最后一次定格负责恢复 Engine.time_scale
var _time_scale_base: float = 1.0   # hitstop 恢复的目标速度（终结演出慢放期间 = FINISHER_SLOW·平时 1.0）
var _fin_impact_tweens: Array[Tween] = []   # 终结命中的 punch/下沉 tween（慢放中跑不完·归位前必须 kill 防写回放大值）
var _act_focus_active: bool = false   # 执行动作期间镜头是否在偏焦（保留位·当前由 set_focus 直接驱动）
var _world: Control = null    # P2b：立绘+阴影的 dolly 组（运行期归组·与背景同对焦点统一推近）
var _world_foreground_occluder: Control = null
var _world_foreground_source: Control = null
var _character_reflection_receiver: Control = null
var _character_reflection_material: ShaderMaterial = null


# ---- 演出原语库（2026-07-17 拆分批①）：飘字/斩击/火花/尘/能量粒/冲击帧+对象池 全家
#      迁入 src/ui/components/battle_fx.gd（_ready 挂载·经 _fx. 调用·配色常量随迁）----
const BattleFxScript := preload("res://src/ui/components/battle_fx.gd")
var _fx: Node = null   # BattleFx 实例（演出原语库·池在组件内）

# A3b 事件注解飘字配色（伤害数字解释不了的时刻·沿用战斗已有色族不添新色相）
const COL_TAG_POISON := Color(0.55, 0.88, 0.35)   # 毒爆=酸绿（比治疗绿偏黄·毒感）
const COL_TAG_AMP := Color(1.0, 0.72, 0.35)       # 印记/脆弱=暖橙（"这下更疼"的加伤注解）
const COL_TAG_ABSORB := Color(0.62, 0.78, 1.0)    # 护盾/替身=钢蓝（与格挡火花同族·"被垫掉"）
const COL_TAG_SAVE := Color(1.0, 0.86, 0.42)      # 还魂/免疫=救场金（最该被看见的时刻）
const COL_TAG_BREAK := Color(1.0, 0.45, 0.35)     # 破甲/能量上限受损=赤红（坏消息）
const COL_DMG_BURN := Color(1.0, 0.58, 0.22)      # 延迟伤害到期（妖火/藤蔓）=余烬橙（动作前结算的旧账）


# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_ensure_stage_for_standalone_base()
	_ai_rng.randomize()   # 任务 B：AI 道具抽取随机种子
	_ai = BattleAI.new(0, 2, 0, {})   # 与 sim 统一：同一套搜索 AI（随机种子·深度 2·基础评估）
	_think_ai = BattleAI.new(0, 2, 0, {})   # 任务G：异步预想副本（配置同 _ai·rng 每次快照覆盖）
	battle = BattleCore.new()
	_overtime = BattleSetup.overtime   # 须在 reset() 前读取
	_pve = BattleSetup.pve_mode        # 远征 PvE（任务 D）·同样须在 reset() 前读取
	_net = BattleSetup.net_session != null   # 联机局（M1）·net_session 不被 reset() 清（生命周期独立）
	var pve_player_hp: Array = BattleSetup.pve_player_hp.duplicate()
	var pve_opponent_hp: Array = BattleSetup.pve_opponent_hp.duplicate()
	var pve_seed: int = BattleSetup.pve_seed
	var p1_item_backpack: Array[String] = BattleSetup.p1_item_backpack.duplicate()
	var p2_item_backpack: Array[String] = BattleSetup.p2_item_backpack.duplicate()
	var p0: Array
	var p1: Array
	if _net:
		# 联机局（M1）：本地不建局——镜像=服务器权威快照（阵容/经济/随机流全在内·加入方视角已翻转）
		BattleSetup.reset()
		# 重连令牌转存（2026-07-17 身份门）：match_start 下发·跨场景留底——断线后大厅重连
		# 用新 client 报到时凭它取回席位（没有它=任何过口令门的连接都能顶号）。
		BattleSetup.net_rtk = String(BattleSetup.net_session.client.rtk)
		_net_sync_latest()
		_net_last_turn = battle.turn_number
	elif _pve:
		# 远征只适配跨战状态；双方仍使用完整 HeroData 与当前公共战斗核心。
		_pved = BattlePveScript.new()
		_pved.name = "BattlePve"
		add_child(_pved)
		_pved.setup(self)
		p0 = _pved.build_team(BattleSetup.p1_heroes)
		p1 = _pved.build_team(BattleSetup.p2_heroes)
	else:
		p0 = _resolve_team(BattleSetup.p1_heroes, DEFAULT_P0)
		p1 = _resolve_team(BattleSetup.p2_heroes, DEFAULT_P1)
	if not _net:
		BattleSetup.reset()   # 消费即清空：防止下一局（未经 BP）复用本局阵容
		battle.setup(p0, p1, pve_seed if _pve and pve_seed != 0 else randi())
		if not p1_item_backpack.is_empty() or not p2_item_backpack.is_empty():
			battle.configure_battle_backpacks(p1_item_backpack, p2_item_backpack)
	if _overtime:
		# 加时赛（Q5·2026-07-03；2026-07-05 修订）：白板满血 1v1——slot0 出战、其余队友 0 血躺板凳
		# （同归余烬·引擎/UI 全程正常 3 人局零特判）；无道具经济（不 econ_init）、被动能量照常、
		# 上限 30 回合：打满 → 引擎骤死裁决（双方同时扣血·UI 走正常掉血/死亡演出零特判）。
		battle.apply_overtime_bench()
	elif _pve:
		# 跨战 HP 是唯一的局内初始状态差异；道具经济与本地 PvP 使用同一入口。
		_pved.apply_initial_hp(pve_player_hp, pve_opponent_hp)
		battle.econ_init()
	elif not _net:
		battle.econ_init()   # 启用道具经济（开局带 1 + 槽位状态机·M1）——联机局经济在服务器快照里

	_init_buttons()
	_connect_frame_signals()
	game_timer.timeout.connect(_on_timer_tick)
	# 我方玩家名=资料档案真名（技术债#3·2026-07-17）。对手名保持场景占位值——
	# 本地对手=AI 无名可言；联机对手名待协议捎带（hello 加字段·另批）。
	p1_player_id.text = ProfileStore.get_player_name()

	# P2（对手）立绘 + 头像朝左（面向中间）；记录立绘原位供前冲 juice 复位
	_cd_home[0] = p1_char_display.position
	_cd_home[1] = p2_char_display.position
	_shadow_home[0] = p1_shadow.position
	_shadow_home[1] = p2_shadow.position
	p2_char_display.flip_h = true
	# 建筑保持完全静止（去 idle 呼吸·Eddy 2026-06-21）；纵深感只在受击 shake 时由 stage 分层体现。
	stage.idle_drift = false
	_setup_world_group()   # P2b：立绘+阴影归入 dolly 组，随镜头推近与背景统一移动（须在 home 缓存后）
	_setup_character_reflections()
	for f in p2_frames:
		f.flip_h = true

	_nudge_top_ui_down()
	_build_debug_buttons()
	_fx = BattleFxScript.new()   # 演出原语库（拆分批①·池在组件内预分配）
	_fx.name = "BattleFx"
	add_child(_fx)
	_fx.setup(self)

	# 低血红闪（任务5）：出战血条剩余爱心在 HP 占比低时红色呼吸（IconPipRow 内部实现）。
	for row in [p1_heart_row, p2_heart_row]:
		row.low_hp_flash = true
		row.low_hp_ratio = LOW_HP_RATIO
	for cap_label in [p1_energy_cap_label, p2_energy_cap_label]:
		FontManager.apply(cap_label, 16)

	_build_item_rows()
	_build_hover_tips()        # 悬停提示（底部按钮+我方道具槽·2026-07-11）
	_connect_hero_skill_tips()
	if _overtime:
		p1_item_row.visible = false   # 加时禁道具 → 道具栏整行隐藏
		p2_item_row.visible = false
		status_label.text = tr("加时赛 · 巅峰 1v1")
		status_label.add_theme_color_override("font_color", Color("#ffd86a"))
		status_label.visible = true
	_update_all()
	_show_turn_intro()
	if _overtime:
		_play_eclipse_intro()   # 「烛阴之眼」开场演出（非阻塞·与选招并行）


## battle_screen_base.tscn 是各场景共用的 UI 母版，本身不挂具体背景舞台。
## 直接 F6 母版时补一个透明空舞台；正式 Scene1–7 的既有 Stage 不受影响。
func _ensure_stage_for_standalone_base() -> void:
	if stage != null:
		return
	var stage_slot := get_node_or_null("StageSlot") as Control
	if stage_slot == null:
		push_error("BattleScreen: missing StageSlot")
		return
	stage = BattleStage.new()
	stage.name = "Stage"
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.demo_click_shake = false
	stage_slot.add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## 离场恢复 time_scale=1：hitstop(c) 用全局 Engine.time_scale，若在定格瞬间切场景须复位，防下个场景慢动作。
## 冲击帧同理兜底关闭——PostFX 材质是跨实例共享资源，闪的瞬间切场景会把黑白带进下一局。
func _exit_tree() -> void:
	Engine.time_scale = 1.0
	(post_fx.material as ShaderMaterial).set_shader_parameter("impact_strength", 0.0)
	if _think_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_think_task)   # 任务G：离场前回收预想线程（防悬垂引用）
		_think_task = -1
	# 联机（M1）：离开战斗即结束会话（断链+释放·中途退场=断线·重连=M2b）
	if _net and BattleSetup.net_session != null:
		BattleSetup.net_session.close()
		BattleSetup.net_session = null


## 顶部 UI 整组下移 TOP_UI_DROP 像素（避免太贴屏幕顶端）。
## d 收纳后：每个玩家 HUD 已收进 P1Hud/P2Hud 容器 → 只移动这两个父节点 + 两个中央标签即可，
## 不再逐节点平移（消除"各自独立锚定 → 零星错位"）。
func _nudge_top_ui_down() -> void:
	for n in [p1_hud, p2_hud, timer_label]:
		if n != null:
			(n as Control).position.y += TOP_UI_DROP


## BattleSetup 有阵容就用，否则用默认（直接跑 battle_screen1.tscn 测试）。
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

	# 攒/波/大波/防/大防 用 HoverIcon 美术图标（节点在 battle_screen_base.tscn 内，编辑器可见可调）；
	# 技能按钮显示「技能」二字（详细说明仍放 tooltip，见 _layout_circles）。位置/尺寸由 .tscn 决定。
	btn_special.text = tr("技能")
	btn_confirm.text = tr("结束")

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

	# 龙御极：底部「波」就是普通分支；选择后只在正上方追加一个技能 icon 分支。
	# 两个按钮各自显示 1 能角标，直观表达基础 1 能 + 强化额外 1 能。
	longyuji_picker = Control.new()
	longyuji_picker.name = "LongyujiPicker"
	longyuji_picker.mouse_filter = Control.MOUSE_FILTER_PASS
	longyuji_picker.size = btn_attack.size
	longyuji_picker.visible = false
	buttons_ctrl.add_child(longyuji_picker)
	btn_longyuji_branch = _make_longyuji_branch_button()
	btn_longyuji_branch.position = Vector2.ZERO
	btn_longyuji_branch.pressed.connect(_on_longyuji_branch_pressed)
	longyuji_picker.add_child(btn_longyuji_branch)

	# 并封：选择正费用行动后，在该动作正上方提供技能 icon 分支；与龙御极并存时向上叠一层。
	h24_discount_picker = Control.new()
	h24_discount_picker.name = "H24DiscountPicker"
	h24_discount_picker.mouse_filter = Control.MOUSE_FILTER_PASS
	h24_discount_picker.size = btn_attack.size
	h24_discount_picker.visible = false
	buttons_ctrl.add_child(h24_discount_picker)
	btn_h24_discount = _make_h24_discount_button()
	btn_h24_discount.position = Vector2.ZERO
	btn_h24_discount.pressed.connect(_on_h24_discount_pressed)
	h24_discount_picker.add_child(btn_h24_discount)

	# 暗潮：底部「大波」保持原动作；选择后只在正上方追加技能 icon 分支。
	split_big_wave_picker = Control.new()
	split_big_wave_picker.name = "SplitBigWavePicker"
	split_big_wave_picker.mouse_filter = Control.MOUSE_FILTER_PASS
	split_big_wave_picker.size = btn_big_attack.size
	split_big_wave_picker.visible = false
	buttons_ctrl.add_child(split_big_wave_picker)
	btn_split_big_wave = _make_split_big_wave_branch_button()
	btn_split_big_wave.position = Vector2.ZERO
	btn_split_big_wave.pressed.connect(_on_split_big_wave_pressed)
	split_big_wave_picker.add_child(btn_split_big_wave)

	# 战斗中只保留背包工具入口；图鉴入口从战斗 HUD 移除，结束按钮回到右下角。
	btn_backpack = _make_backpack_utility_button()
	buttons_ctrl.add_child(btn_backpack)
	_build_switch_module()

	# 顶部倒计时/回合开始已有右下定向阴影；底部按钮同步这套层级语言。
	# 阴影是按钮子节点，会跟随现有 hover/selected 缩放，但不改变点击矩形。
	for button: Button in action_btn_list + [
			btn_confirm, btn_backpack, btn_switch, btn_longyuji_branch,
			btn_split_big_wave, btn_h24_discount]:
		_attach_button_bottom_shadow(button)

	# 镜头偏焦改由「执行动作」触发（见 _play_battle_anims）：波/大波→右聚敌、防/大防→左聚己、其余回正。
	# 旧「hover 底部按钮 → 推近」已取消（2026-06-23 Eddy）。

	# 动作按钮能量消耗金币数量（基础动作 cost 固定；攒=获取不显示）。技能键 cost 动态，随刷新更新。
	_set_cost_pips(btn_attack, ActionDef.BASE_ACTION_DEF[A.ATTACK]["cost"])
	_set_cost_pips(btn_big_attack, ActionDef.BASE_ACTION_DEF[A.BIG_ATTACK]["cost"])
	_set_cost_pips(btn_big_defend, ActionDef.BASE_ACTION_DEF[A.BIG_DEFEND]["cost"])
	_set_cost_pips(btn_defend, ActionDef.BASE_ACTION_DEF[A.DEFEND]["cost"], true)   # 防=0 费也显示（Eddy 2026-07-13·与其他按钮一致）

	# 顶部中央仅承担倒计时：沿用原回合标的加粗米色字形与两侧极简装饰。
	var turn_bold := FontVariation.new()
	turn_bold.base_font = FontManager.f16
	turn_bold.variation_embolden = 0.6
	timer_label.add_theme_font_override("font", turn_bold)
	timer_label.add_theme_font_size_override("font_size", 44)
	timer_label.add_theme_color_override("font_color", countdown_normal_color)
	timer_label.add_theme_color_override("font_outline_color", countdown_outline_color)
	timer_label.add_theme_constant_override("outline_size", countdown_outline_size)
	timer_label.add_theme_color_override("font_shadow_color", countdown_shadow_color)
	timer_label.add_theme_constant_override("shadow_offset_x", countdown_shadow_offset_x)
	timer_label.add_theme_constant_override("shadow_offset_y", countdown_shadow_offset_y)
	# 仅在文字两侧补：近文字金色菱形 → 小间隔 → 向外水平金线。无底板、无折角、无动态。
	_round_ornaments = RoundLabelOrnamentsComponent.new()
	_round_ornaments.name = "RoundLabelOrnaments"
	timer_label.add_child(_round_ornaments)
	_round_ornaments.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_round_ornaments.configure(
		countdown_ornament_color,
		countdown_ornament_underlay_color,
		countdown_ornament_underlay_width)
	FontManager.apply(status_label, 44)
	status_label.add_theme_color_override("font_color", Color(0.95, 0.91, 0.8))   # 暖米白
	status_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	status_label.add_theme_constant_override("outline_size", 5)
	# 中央只显示一秒「回合开始」宣告；倒计时统一移到顶部。
	big_turn_label.text = ""
	_central_turn_cue = CentralTurnCueComponent.new()
	_central_turn_cue.name = "CentralTurnCue"
	big_turn_label.add_child(_central_turn_cue)
	_central_turn_cue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	event_label.visible = false
	# 备选血量/护甲：ReserveHpRow 自绘单个斜切符号 + 数字，配色/居中均由组件处理。

	# 出战角色名 / 玩家 id 的字体·字号·颜色·描边·玩家id文本 全部在 battle_screen_base.tscn 设置
	# （像素字体 ttf 直接引用·import 已关 AA → 编辑器所见即所得，可在 Inspector 手调位置/大小）。
	# 代码只负责把角色名文本随出战英雄更新（见 _update_hero_frames）。


func _make_backpack_utility_button() -> Button:
	var button := Button.new()
	button.name = "BtnBackpack"
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.position = Vector2(1652.0, 46.0)
	button.size = Vector2(108.0, 108.0)
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state_name, StyleBoxEmpty.new())

	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.show_behind_parent = true
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/canvas_button_jelly.gdshader")
	material.set_shader_parameter("fill_top", Color(0.92, 0.87, 0.70))
	material.set_shader_parameter("fill_bottom", Color(0.76, 0.68, 0.50))
	material.set_shader_parameter("edge_inner", Color(1.0, 0.95, 0.80))
	material.set_shader_parameter("edge_outer", Color(0.1, 0.09, 0.11))
	material.set_shader_parameter("fill_alpha", 1.0)
	material.set_shader_parameter("pixel_grid", 38.0)
	material.set_shader_parameter("corner", 0.22)
	material.set_shader_parameter("edge_px", 2.0)
	material.set_shader_parameter("aspect", 1.0)
	material.set_shader_parameter("noise_amt", 0.08)
	material.set_shader_parameter("wear", 0.24)
	material.set_shader_parameter("solid_rim", true)
	material.set_shader_parameter("rim_px", 1.5)
	bg.material = material
	button.add_child(bg)

	var icon := TextureRect.new()
	icon.name = "BackpackIcon"
	icon.texture = BACKPACK_ICON
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 22.0
	icon.offset_top = 22.0
	icon.offset_right = -22.0
	icon.offset_bottom = -22.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	_attach_button_juice(button)
	button.pressed.connect(_on_backpack_pressed)
	return button


func _make_longyuji_branch_button() -> Button:
	var choice := Button.new()
	choice.name = "BtnLongyujiBranch"
	choice.focus_mode = Control.FOCUS_NONE
	choice.size = btn_attack.size
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		choice.add_theme_stylebox_override(state_name, StyleBoxEmpty.new())

	var source_bg := btn_attack.get_node_or_null("Bg") as ColorRect
	if source_bg != null and source_bg.material is ShaderMaterial:
		var bg := ColorRect.new()
		bg.name = "Bg"
		bg.show_behind_parent = true
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var material := (source_bg.material as ShaderMaterial).duplicate() as ShaderMaterial
		material.set_shader_parameter("aspect", choice.size.x / choice.size.y)
		bg.material = material
		choice.add_child(bg)
		choice.move_child(bg, 0)

	# 技能 icon 保持原生 64×64 像素，不做非整数缩放。
	var icon := TextureRect.new()
	icon.name = "SkillIcon"
	icon.texture = LONGYUJI_SKILL_ICON
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = (choice.size - Vector2(64.0, 64.0)) * 0.5
	icon.size = Vector2(64.0, 64.0)
	choice.add_child(icon)

	# 与底部动作按钮同款左上角费用徽记；此处只表示龙御极额外支付的 1 能。
	var cost_badge := IconBadge.new()
	cost_badge.name = "CostPips"
	cost_badge.position = Vector2(-22.0, -24.0)
	cost_badge.size = Vector2(70.0, 70.0)
	cost_badge.set_icon(ENERGY_COST_SHEET, 4, 4, 0)
	cost_badge.set_number(1)
	cost_badge.font_size = 16
	cost_badge.embolden = 0.7
	choice.add_child(cost_badge)
	_attach_button_juice(choice)
	return choice


func _make_split_big_wave_branch_button() -> Button:
	var choice := Button.new()
	choice.name = "BtnSplitBigWave"
	choice.focus_mode = Control.FOCUS_NONE
	choice.size = btn_big_attack.size
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		choice.add_theme_stylebox_override(state_name, StyleBoxEmpty.new())

	var source_bg := btn_big_attack.get_node_or_null("Bg") as ColorRect
	if source_bg != null and source_bg.material is ShaderMaterial:
		var bg := ColorRect.new()
		bg.name = "Bg"
		bg.show_behind_parent = true
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var material := (source_bg.material as ShaderMaterial).duplicate() as ShaderMaterial
		material.set_shader_parameter("aspect", choice.size.x / choice.size.y)
		bg.material = material
		choice.add_child(bg)
		choice.move_child(bg, 0)

	var icon := TextureRect.new()
	icon.name = "SkillIcon"
	icon.texture = ANCHAO_SKILL_ICON
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = (choice.size - Vector2(64.0, 64.0)) * 0.5
	icon.size = Vector2(64.0, 64.0)
	choice.add_child(icon)
	_attach_button_juice(choice)
	return choice


func _make_h24_discount_button() -> Button:
	var choice := Button.new()
	choice.name = "BtnH24Discount"
	choice.focus_mode = Control.FOCUS_NONE
	choice.size = btn_attack.size
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		choice.add_theme_stylebox_override(state_name, StyleBoxEmpty.new())

	var source_bg := btn_attack.get_node_or_null("Bg") as ColorRect
	if source_bg != null and source_bg.material is ShaderMaterial:
		var bg := ColorRect.new()
		bg.name = "Bg"
		bg.show_behind_parent = true
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var material := (source_bg.material as ShaderMaterial).duplicate() as ShaderMaterial
		material.set_shader_parameter("aspect", choice.size.x / choice.size.y)
		bg.material = material
		choice.add_child(bg)
		choice.move_child(bg, 0)

	var icon := TextureRect.new()
	icon.name = "SkillIcon"
	icon.texture = H24_SKILL_ICON
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = (choice.size - Vector2(64.0, 64.0)) * 0.5
	icon.size = Vector2(64.0, 64.0)
	choice.add_child(icon)

	# 沿用行动费用徽记的视觉语法；-1 表示永久支付 1 点能量上限。
	var cap_badge := IconBadge.new()
	cap_badge.name = "CapCost"
	cap_badge.position = Vector2(-22.0, -24.0)
	cap_badge.size = Vector2(70.0, 70.0)
	cap_badge.set_icon(ENERGY_COST_SHEET, 4, 4, 0)
	cap_badge.set_number(-1)
	cap_badge.font_size = 16
	cap_badge.embolden = 0.7
	choice.add_child(cap_badge)
	_attach_button_juice(choice)
	return choice


## 结算"进攻方"判定（镜头冲突落点用·Eddy 2026-07-09 镜头规格）：
## 波/大波恒算进攻（被挡也算——冲突落点仍在受击侧）；主动技按"是否实际造成伤害/击杀"归类
## （无伤主动技=未进攻）；攒/防/大防/切换=未进攻。dmg_to_foe/foe_dead=本次结算对方承受的伤害/死亡。
func _is_offense(action: int, dmg_to_foe: int, foe_dead: bool) -> bool:
	if action == A.ATTACK or action == A.BIG_ATTACK:
		return true
	return action == ActionDef.ACTIVE and (dmg_to_foe > 0 or foe_dead)


## Basic wave clashes carry their own readable direction independent of hero
## skills and damage values. Other action pairs keep the resolved hit fallback.
func _base_attack_response_direction(a0: int, a1: int) -> float:
	if not ActionDef.ATTACK_ACTIONS.has(a0) \
			or not ActionDef.ATTACK_ACTIONS.has(a1):
		return NAN
	var p1_rank := 1 if a0 == A.BIG_ATTACK else 0
	var p2_rank := 1 if a1 == A.BIG_ATTACK else 0
	return float(signi(p1_rank - p2_rank))


## P2b：把双方立绘 + 阴影归入一个"世界组"容器，整体随镜头推近（与背景舞台同对焦点 → 统一移动）。
## 运行期归组、不改 .tscn（Eddy 编辑器里仍是根节点下的 4 个子节点）；容器置于 Stage 之后、
## dust/后处理/UI 之前 → PostFX 仍抓得到角色，UI 仍在最上层不动。
## 容器缩放与角色自身 pop/前冲 juice 在场景图里相乘合成、互不打架（受击 pop 不会被 dolly 吃掉）。
func _setup_world_group() -> void:
	_world_foreground_occluder = get_node_or_null(
			"WorldForegroundOccluder") as Control
	if _world_foreground_occluder:
		var source_path := NodePath(str(_world_foreground_occluder.get_meta(
				"source_stage_layer", "")))
		_world_foreground_source = stage.get_node_or_null(source_path) as Control
	_world = Control.new()
	_world.name = "WorldGroup"
	_world.set_anchors_preset(Control.PRESET_FULL_RECT)
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 显式 position 数学绕 stage.focal() 缩放（与背景同一动态对焦点·焦点随动作偏置）→ pivot 留 0。
	add_child(_world)
	# 紧跟 FinisherVeil（终结演出虚化幕只糊 Stage 背景、不糊双雄）、在 dust/后处理/UI 之前。
	move_child(_world, finisher_veil.get_index() + 1)
	var world_items: Array[Control] = [
		p1_shadow,
		p2_shadow,
		p1_char_display,
		p2_char_display,
	]
	if _world_foreground_occluder:
		world_items.append(_world_foreground_occluder)
	for n: Control in world_items:
		n.reparent(_world, true)   # keep_global_transform → 静止画面一像素不变
	_sync_world_foreground_occluder()
	var wind_field := stage.get_node_or_null("WindField")
	if wind_field and _world_foreground_occluder \
			and wind_field.has_method("register_external_material"):
		wind_field.call(
				"register_external_material",
				_world_foreground_occluder.material)


## Scene variants may provide an opaque lower foreground band. It remains in
## WorldGroup after both fighters, but copies the source stage layer transform
## so pointer parallax and camera focus never create a duplicate-texture seam.
func _sync_world_foreground_occluder() -> void:
	if _world_foreground_occluder == null \
			or _world_foreground_source == null:
		return
	var parent_xform := (
			_world_foreground_occluder.get_parent() as CanvasItem
			).get_global_transform()
	var local_xform := (
			parent_xform.affine_inverse()
			* _world_foreground_source.get_global_transform())
	_world_foreground_occluder.position = local_xform.origin
	_world_foreground_occluder.rotation = local_xform.get_rotation()
	_world_foreground_occluder.scale = local_xform.get_scale()
	_world_foreground_occluder.size = _world_foreground_source.size


## 为启用该功能的场景变体创建独享河面材质，并绑定现有角色的实时 SubViewportTexture。
## 材质必须逐实例复制，否则同时存在两个 BattleScreen 时会互相覆盖纹理句柄。
func _setup_character_reflections() -> void:
	_character_reflection_receiver = null
	_character_reflection_material = null
	if not character_reflections_enabled:
		return

	var receiver := stage.get_node_or_null(character_reflection_receiver_path) as Control
	if receiver == null:
		push_warning("BattleScreen: character reflection receiver not found: %s" % character_reflection_receiver_path)
		return
	var source_material := receiver.material as ShaderMaterial
	if source_material == null:
		push_warning("BattleScreen: character reflection receiver requires a ShaderMaterial")
		return

	var instance_material := source_material.duplicate() as ShaderMaterial
	receiver.material = instance_material
	_character_reflection_receiver = receiver
	_character_reflection_material = instance_material
	instance_material.set_shader_parameter("p1_reflection_tex", p1_char_display.get_render_texture())
	instance_material.set_shader_parameter("p2_reflection_tex", p2_char_display.get_render_texture())
	instance_material.set_shader_parameter("screen_px", get_viewport_rect().size)
	_update_character_reflections()


func _control_screen_rect(control: Control) -> Rect2:
	var xform := control.get_global_transform_with_canvas()
	var corners: Array[Vector2] = [
		xform * Vector2.ZERO,
		xform * Vector2(control.size.x, 0.0),
		xform * control.size,
		xform * Vector2(0.0, control.size.y),
	]
	var min_point := corners[0]
	var max_point := corners[0]
	for point in corners:
		min_point = min_point.min(point)
		max_point = max_point.max(point)
	return Rect2(min_point, max_point - min_point)


## 角色和 WorldGroup 会在动作、镜头推近与鼠标视差中移动，因此每帧只同步少量屏幕空间参数。
## 倒影本身仍由河面 shader 裁切、切片和衰减，不参与角色交互或战斗状态。
func _update_character_reflections() -> void:
	if _character_reflection_material == null or _character_reflection_receiver == null:
		return

	var p1_rect := _control_screen_rect(p1_char_display)
	var p2_rect := _control_screen_rect(p2_char_display)
	var p1_xform := p1_char_display.get_global_transform_with_canvas()
	var p2_xform := p2_char_display.get_global_transform_with_canvas()
	var p1_foot := p1_xform * Vector2(
		p1_char_display.size.x * 0.5,
		p1_char_display.size.y * character_reflection_foot_ratio)
	var p2_foot := p2_xform * Vector2(
		p2_char_display.size.x * 0.5,
		p2_char_display.size.y * character_reflection_foot_ratio)
	var river_xform := _character_reflection_receiver.get_global_transform_with_canvas()
	var river_left := river_xform * Vector2.ZERO
	var river_right := river_xform * Vector2(_character_reflection_receiver.size.x, 0.0)

	_character_reflection_material.set_shader_parameter(
		"p1_reflection_rect", Vector4(p1_rect.position.x, p1_rect.position.y, p1_rect.size.x, p1_rect.size.y))
	_character_reflection_material.set_shader_parameter(
		"p2_reflection_rect", Vector4(p2_rect.position.x, p2_rect.position.y, p2_rect.size.x, p2_rect.size.y))
	_character_reflection_material.set_shader_parameter("p1_reflection_foot_y", p1_foot.y)
	_character_reflection_material.set_shader_parameter("p2_reflection_foot_y", p2_foot.y)
	_character_reflection_material.set_shader_parameter("character_waterline_y", minf(river_left.y, river_right.y))


func _connect_frame_signals() -> void:
	# 己方头像的普通换人入口已迁移到左下切换模块；这里仍保留道具选择己方英雄目标的成熟语义。
	# 敌方三个头像框：平时点击无响应（回调内 gate）；h21 只接替补，h04 波/大波可接任一存活英雄。
	for fi in [0, 1, 2]:
		# 头像框换皮只能改绘制，不能拿走成熟的主动换人入口；在调用侧显式锁住输入属性，
		# 避免组件/场景重制时把 Panel 的 mouse_filter 一并改掉后出现“看得见但点不到”。
		p1_frames[fi].mouse_filter = Control.MOUSE_FILTER_STOP
		p1_frames[fi].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		p1_frames[fi].gui_input.connect(_on_reserve_frame_input.bind(fi))
	for fi in [0, 1, 2]:
		p2_frames[fi].mouse_filter = Control.MOUSE_FILTER_STOP
		p2_frames[fi].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		p2_frames[fi].gui_input.connect(_on_enemy_frame_input.bind(fi))


## 左下切换模块：主按钮占用原图鉴位置，两个替补头像从按钮右侧展开。
## 候选只呈现头像与可用性，不复制生命/护盾信息；完整状态仍由顶部 HUD 承担。
func _build_switch_module() -> void:
	btn_switch = Button.new()
	btn_switch.name = "BtnSwitch"
	btn_switch.text = ""
	btn_switch.focus_mode = Control.FOCUS_NONE
	btn_switch.position = SWITCH_MAIN_POS
	btn_switch.size = SWITCH_MAIN_SIZE
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		btn_switch.add_theme_stylebox_override(st, StyleBoxEmpty.new())

	var bg := ColorRect.new()
	bg.name = "Bg"
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/canvas_button_jelly.gdshader")
	mat.set_shader_parameter("fill_top", Color(0.52, 0.72, 0.70))
	mat.set_shader_parameter("fill_bottom", Color(0.24, 0.43, 0.45))
	mat.set_shader_parameter("edge_inner", Color(0.80, 0.90, 0.82))
	mat.set_shader_parameter("edge_outer", Color(0.07, 0.09, 0.10))
	mat.set_shader_parameter("fill_alpha", 1.0)
	mat.set_shader_parameter("pixel_grid", 38.0)
	mat.set_shader_parameter("corner", 0.22)
	mat.set_shader_parameter("edge_px", 2.0)
	mat.set_shader_parameter("aspect", 1.0)
	mat.set_shader_parameter("noise_amt", 0.08)
	mat.set_shader_parameter("wear", 0.20)
	mat.set_shader_parameter("solid_rim", true)
	mat.set_shader_parameter("rim_px", 1.5)
	bg.material = mat
	bg.show_behind_parent = true
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_switch.add_child(bg)
	_switch_button_icon = HoverIcon.new()
	_switch_button_icon.name = "SwitchIcon"
	_switch_button_icon.sheet = SWITCH_ICON_TEX
	_switch_button_icon.hframes = 4
	_switch_button_icon.vframes = 2
	_switch_button_icon.playback_frames = PackedInt32Array(SWITCH_ICON_PLAYBACK_FRAMES)
	_switch_button_icon.fps = 4.0
	_switch_button_icon.loop_on_hover = true
	_switch_button_icon.rest_frame = 0
	_switch_button_icon.inset_ratio = 0.0
	_switch_button_icon.content_scale = 1.0
	_switch_button_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_switch_button_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_switch_button_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_switch.add_child(_switch_button_icon)
	_attach_button_juice(btn_switch)
	btn_switch.pressed.connect(_on_switch_main_pressed)
	buttons_ctrl.add_child(btn_switch)

	_switch_tray = Control.new()
	_switch_tray.name = "SwitchTray"
	_switch_tray.position = Vector2(
		SWITCH_MAIN_POS.x + SWITCH_MAIN_SIZE.x + 20.0,
		SWITCH_MAIN_POS.y + (SWITCH_MAIN_SIZE.y - SWITCH_FRAME_SIZE) * 0.5)
	_switch_tray.size = Vector2(SWITCH_FRAME_STEP + SWITCH_FRAME_SIZE, SWITCH_FRAME_SIZE)
	_switch_tray.mouse_filter = Control.MOUSE_FILTER_PASS
	_switch_tray.visible = false
	buttons_ctrl.add_child(_switch_tray)

	for candidate_index: int in range(2):
		# 必须实例化正式场景：HeroFrame.new() 只有脚本空壳，没有 Portrait/Bg 等可视子节点。
		var frame := HERO_FRAME_SCENE.instantiate() as HeroFrame
		frame.name = "Candidate%d" % (candidate_index + 1)
		frame.position = Vector2(SWITCH_FRAME_STEP * candidate_index, 0.0)
		frame.frame_size = Vector2.ONE * SWITCH_FRAME_SIZE
		frame.diamond_mode = true
		frame.bottom_shadow_enabled = true
		frame.mouse_filter = Control.MOUSE_FILTER_STOP
		frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		frame.gui_input.connect(_on_switch_candidate_input.bind(candidate_index + 1))
		_switch_tray.add_child(frame)
		_switch_candidate_frames.append(frame)


func _on_switch_main_pressed() -> void:
	if state != State.PLAYER_SELECT or not _has_switchable_reserve():
		return
	_set_switch_tray_open(not _switch_tray_open)


func _on_switch_candidate_input(event: InputEvent, frame_idx: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_on_switch_candidate_pressed(frame_idx)


func _on_switch_candidate_pressed(frame_idx: int) -> void:
	if state != State.PLAYER_SELECT or not _is_switchable_reserve(frame_idx):
		return
	if _switch_selected and _armed_switch_frame == frame_idx:
		_deselect_switch()
		_disarm_switch()
		_refresh_switch_module()
		return

	_disarm_switch()
	var keep_blood_payment := _blood_payment_armed \
		and battle.is_free_switch_target(PLAYER, p1_frame_slots[frame_idx])
	_clear_action_selection_full(keep_blood_payment)
	_armed_switch_frame = frame_idx
	_switch_selected = false
	if battle.is_free_switch_target(PLAYER, p1_frame_slots[frame_idx]):
		_free_switch_now(frame_idx)
	else:
		_select_switch(frame_idx)
	# 普通切换选定后保持候选层展开：头像高亮 + 主按钮“已选” + 结束按钮呼吸共同反馈待提交态。
	_refresh_switch_module()


func _has_switchable_reserve() -> bool:
	for frame_idx: int in [1, 2]:
		if _is_switchable_reserve(frame_idx):
			return true
	return false


func _set_switch_tray_open(open: bool) -> void:
	if _switch_tray == null:
		return
	if _switch_tray_tween != null and _switch_tray_tween.is_valid():
		_switch_tray_tween.kill()
	_switch_tray_open = open
	if not open:
		_switch_tray.visible = false
		return
	_refresh_switch_module()
	_switch_tray.visible = true
	_switch_tray_tween = create_tween().set_parallel(true)
	_switch_tray_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for index: int in range(_switch_candidate_frames.size()):
		var frame := _switch_candidate_frames[index]
		var final_position := Vector2(SWITCH_FRAME_STEP * index, 0.0)
		# 点击矩形从第一帧起就按最终顺序分离，不能让第二候选在动画起点覆盖第一候选。
		# 第二格只从第一格右缘滑出 18px，既保留“向右展开”，又全程零重叠。
		frame.position = final_position - Vector2(minf(18.0 * index, 18.0), 0.0)
		_switch_tray_tween.tween_property(frame, "position", final_position, 0.14)


func _refresh_switch_module() -> void:
	if btn_switch == null or _switch_tray == null or battle == null:
		return
	var can_operate := state == State.PLAYER_SELECT and _has_switchable_reserve()
	btn_switch.disabled = not can_operate
	_set_switch_button_feedback(_switch_selected and selected_action == A.SWITCH)
	if not can_operate:
		_set_switch_tray_open(false)
	var pcolor := Color("#3f86c8")
	for index: int in range(_switch_candidate_frames.size()):
		var frame_idx := index + 1
		var frame := _switch_candidate_frames[index]
		var slot: int = p1_frame_slots[frame_idx] if frame_idx < p1_frame_slots.size() else -1
		if slot < 0 or slot >= battle.heroes[PLAYER].size():
			frame.visible = false
			continue
		_update_single_frame(frame, null, PLAYER, slot, false, pcolor)
		var available := _is_switchable_reserve(frame_idx)
		var candidate_selected := _switch_selected and _armed_switch_frame == frame_idx
		if frame.is_selected != candidate_selected:
			frame.is_selected = candidate_selected
		if not frame.is_selected:
			frame.modulate = Color.WHITE if available else Color(0.52, 0.52, 0.52, 0.72)
		frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if available \
			else Control.CURSOR_ARROW
	_switch_tray.visible = _switch_tray_open


func _set_switch_button_feedback(selected: bool) -> void:
	if btn_switch == null:
		return
	btn_switch.text = ""
	if _switch_button_icon != null:
		_switch_button_icon.self_modulate = Color(1.16, 1.10, 0.82) if selected \
			else (Color(0.62, 0.65, 0.62) if btn_switch.disabled else Color.WHITE)
	var previous := bool(btn_switch.get_meta("switch_selected", false))
	if previous == selected:
		return
	btn_switch.set_meta("switch_selected", selected)
	_set_btn_selected(btn_switch, selected)


## 背包与图鉴使用相同的场景内浮层生命周期；按入口呼出，浮层内 X / ESC 关闭。
func _on_backpack_pressed() -> void:
	if _backpack_overlay == null:
		_backpack_overlay = BACKPACK_OVERLAY_SCENE.instantiate() as Control
		_backpack_overlay.name = "BackpackOverlay"
		add_child(_backpack_overlay)
		_backpack_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _backpack_overlay.visible:
		_backpack_overlay.call("close")
	else:
		_backpack_overlay.call("open")


# ============================================================
# 回合流程（同时盲选）
# ============================================================

func _show_turn_intro() -> void:
	state = State.TURN_INTRO
	_set_buttons_active(false, true)   # 回合介绍：动作栏整体压暗 + 禁用（灰色·防误触；进入选择阶段再亮）
	status_label.visible = false
	event_label.visible = false
	# 新回合是倒计时唯一的刷新点；此前结算/换人阶段保持的 0 在这里恢复为完整时限。
	timer_seconds = _turn_time_limit()
	_update_timer_label()
	timer_label.visible = true

	# 中间只做回合开场宣告，不再承载倒计时。
	_central_turn_cue.show_turn_start(tr("回合开始"))
	big_turn_label.visible = true
	await get_tree().create_timer(1.4).timeout
	_start_player_select()


func _start_player_select() -> void:
	state = State.PLAYER_SELECT
	selected_action = -1
	selected_second_action = -1
	_second_enemy_target_pick = -1
	_second_action_btn = null
	selected_switch = -1
	selected_btn = null
	_empowered_wave_armed = false
	_split_big_wave_armed = false
	_blood_payment_armed = false
	_energy_cap_discount_armed = false
	_free_switch_sequence.clear()
	_blood_payment_activation_step = -1
	_clear_selected_items()   # M3：每回合重置使用件、槽目标与待选来源
	status_label.visible = false   # 去除「选择你的动作」提示
	event_label.visible = false
	_set_buttons_active(true)
	_update_all()
	_start_timer()
	_start_ai_think()   # 任务G：选招一开始就让对手在后台想（确认时零等待）


## 当前回合思考时限（秒）：由少到多阶梯（TURN_TIME_STEPS 降序查表）。
func _turn_time_limit() -> int:
	for step in TURN_TIME_STEPS:
		if battle.turn_number >= int(step[0]):
			return int(step[1])
	return int(TURN_TIME_STEPS[-1][1])


func _start_timer() -> void:
	timer_seconds = _turn_time_limit()
	big_turn_label.visible = false
	timer_label.visible = true
	_update_timer_label()
	game_timer.start(1.0)


func _on_timer_tick() -> void:
	timer_seconds -= 1
	_update_timer_label()
	if timer_seconds <= 0:
		game_timer.stop()
		if state == State.PLAYER_SELECT:
			_on_confirm_pressed()
		elif state == State.HERO_SELECT and _death_switch_overlay.visible:
			_death_switch_overlay.select_default()


func _countdown_color_for_seconds(seconds_left: int) -> Color:
	match seconds_left:
		3:
			return COUNTDOWN_WARNING_3_COLOR
		2:
			return COUNTDOWN_WARNING_2_COLOR
		1, 0:
			return COUNTDOWN_WARNING_1_COLOR
		_:
			return COUNTDOWN_WARNING_1_COLOR if seconds_left < 0 else countdown_normal_color


func _update_timer_label() -> void:
	# 倒计时只显示在顶部；末 3 秒按黄→橙→红推进，装饰同步从中央向外染色。
	timer_label.text = str(maxi(timer_seconds, 0))
	var countdown_color := _countdown_color_for_seconds(timer_seconds)
	var is_alert := timer_seconds <= 3
	timer_label.add_theme_color_override("font_color", countdown_color)
	timer_label.add_theme_color_override(
		"font_outline_color",
		COUNTDOWN_ALERT_OUTLINE_COLOR if is_alert else countdown_outline_color)
	timer_label.add_theme_constant_override(
		"outline_size", max(countdown_outline_size, 3) if is_alert else countdown_outline_size)
	if _round_ornaments != null:
		_round_ornaments.set_warning_state(timer_seconds, countdown_color)


func _hold_timer_at_zero() -> void:
	# 结算、死亡换人等非选招阶段仍保留顶部信息位，统一停在红色 0，直到新回合刷新。
	timer_seconds = 0
	_update_timer_label()
	timer_label.visible = true


func _on_circle_pressed(action: int, btn: Button) -> void:
	if state != State.PLAYER_SELECT:
		return
	var preview: BattleCore = _battle_after_selected_items()
	if action == ACTIVE:
		if battle.has_blood_payment(PLAYER):
			var next_blood_payment := not _blood_payment_armed
			# 已选行动若只能靠蚩尤付款，必须先取消行动，不能把界面留在
			# “看似已选、提交后却被核心静默回退为攒”的无效状态。
			if not next_blood_payment and selected_action >= 0 \
					and not _selected_action_can_pay(false, _energy_cap_discount_armed):
				return
			if not battle.set_blood_payment_active(PLAYER, next_blood_payment):
				return
			_blood_payment_armed = next_blood_payment
			_blood_payment_activation_step = _free_switch_sequence.size() \
				if next_blood_payment else -1
			_refresh_action_affordance()
			return
		if not preview.can_use_active(PLAYER, _blood_payment_armed) \
				and not preview.can_use_active(PLAYER, _blood_payment_armed, true):
			return

	# 连环鼓：第一行动已经选定后，再点另一个公共动作即选择第二行动。
	# 第二行动不承载切换、主动技或英雄技能分支，按钮双高亮直接表达先后序列。
	if action >= A.CHARGE and action <= A.BIG_DEFEND and selected_action >= A.CHARGE \
			and selected_action <= A.BIG_DEFEND and preview.has_lianhuan_gu_queued(PLAYER):
		if selected_second_action == action:
			selected_second_action = -1
			_second_enemy_target_pick = -1
			_second_action_btn = null
			_reset_button_styles()
			if selected_btn != null:
				_set_btn_selected(selected_btn, true)
			return
		if action != selected_action:
			var first_ok: bool = preview.select_action(PLAYER, selected_action,
				_enemy_target_pick if ActionDef.is_attack(selected_action) else -1,
				_empowered_wave_armed, _split_big_wave_armed, _blood_payment_armed,
				_energy_cap_discount_armed)
			var second_target: int = preview.active_index[AI] \
				if preview.can_target_any_enemy_with_base_attack(PLAYER, action) else -1
			if first_ok and preview.select_second_action(PLAYER, action, second_target):
				selected_second_action = action
				_second_enemy_target_pick = second_target
				_second_action_btn = btn
				_reset_button_styles()
				_set_btn_selected(selected_btn, true)
				_set_btn_selected(btn, true)
				_set_confirm_active(true)
				return

	if selected_btn == btn:
		# 再点同一动作仍为取消；龙御极由「波」上方临时出现的技能 icon 分支切换。
		_clear_enemy_targets()
		selected_action = -1
		selected_second_action = -1
		_second_enemy_target_pick = -1
		_second_action_btn = null
		selected_switch = -1
		selected_btn = null
		_empowered_wave_armed = false
		_split_big_wave_armed = false
		_energy_cap_discount_armed = false
		_reset_button_styles()
		_update_button_states()
		return

	selected_action = action
	selected_second_action = -1
	_second_enemy_target_pick = -1
	_second_action_btn = null
	selected_switch = -1
	_empowered_wave_armed = false
	_split_big_wave_armed = false
	_energy_cap_discount_armed = false
	_reset_button_styles()
	selected_btn = btn
	if not _current_action_can_pay_without_h24() and preview.can_use_energy_cap_discount(
			PLAYER, selected_action, _empowered_wave_armed, _blood_payment_armed):
		_energy_cap_discount_armed = true
	_set_btn_selected(btn, true)
	_set_confirm_active(true)
	_clear_enemy_targets()
	if action == ACTIVE or ActionDef.is_attack(action):
		_maybe_arm_enemy_targets(action)
	_refresh_action_modifiers()
	_refresh_action_cost_badges()


func _on_confirm_pressed() -> void:
	if state != State.PLAYER_SELECT or not _pending_pointstone_offer.is_empty():
		return
	_ensure_lianhuan_choice(_battle_after_selected_items())
	game_timer.stop()
	_hold_timer_at_zero()

	# 联机（M1）：本地不落子——payload 交服务器权威结算·镜像等 resolve 快照上镜
	if _net:
		_net_submit_turn()
		return

	# M3：道具先提交。槽依赖来源必须先于目标；即时产能/减费随后才能支付本回合动作。
	for s in _ordered_selected_item_slots():
		battle.use_slot(PLAYER, s, int(selected_item_hero_targets.get(s, -1)),
			int(selected_item_targets.get(s, -1)),
			int(selected_item_choices.get(s, -1)))

	# 玩家提交（未选 → 默认攒）
	if selected_action == ACTIVE:
		battle.select_active(
			PLAYER, _enemy_target_pick, _blood_payment_armed,
			_energy_cap_discount_armed)   # 玩家点选的敌方揪目标（-1=未选→引擎随机）
	elif selected_action == A.SWITCH and selected_switch >= 0:
		battle.select_switch(PLAYER, selected_switch)
	elif selected_action >= 0:
		battle.select_action(PLAYER, selected_action,
			_enemy_target_pick if ActionDef.is_attack(selected_action) else -1,
			_empowered_wave_armed, _split_big_wave_armed, _blood_payment_armed,
			_energy_cap_discount_armed)
	else:
		battle.select_action(PLAYER, A.CHARGE)
	if selected_second_action >= 0:
		battle.select_second_action(PLAYER, selected_second_action, _second_enemy_target_pick)

	# PvE 与本地 PvP 共用当前 BattleAI：合法行动、道具决策和提交入口全部同源。
	if not _ai_pick_precomputed():
		_ai_pick(AI)   # 任务G 兜底：预想未命中（状态变过/没来得及想）→ 原同步路径
	_clear_selected_items()

	selected_action = -1
	selected_second_action = -1
	_second_enemy_target_pick = -1
	_second_action_btn = null
	selected_switch = -1
	selected_btn = null
	_empowered_wave_armed = false
	_split_big_wave_armed = false
	_energy_cap_discount_armed = false
	_blood_payment_armed = false
	_reset_button_styles()
	_set_confirm_active(false)   # 停止呼吸：已确认提交
	await _resolve()


func _ensure_lianhuan_choice(preview: BattleCore) -> void:
	if not preview.has_lianhuan_gu_queued(PLAYER):
		selected_second_action = -1
		_second_enemy_target_pick = -1
		_second_action_btn = null
		return
	if selected_action < A.CHARGE or selected_action > A.BIG_DEFEND:
		selected_action = A.CHARGE
		selected_switch = -1
		selected_btn = btn_charge
		_empowered_wave_armed = false
		_split_big_wave_armed = false
		_blood_payment_armed = false
		_energy_cap_discount_armed = false
	if not preview.select_action(PLAYER, selected_action,
			_enemy_target_pick if ActionDef.is_attack(selected_action) else -1,
			_empowered_wave_armed, _split_big_wave_armed, _blood_payment_armed,
			_energy_cap_discount_armed):
		return
	if selected_second_action >= 0 and preview.select_second_action(
			PLAYER, selected_second_action, _second_enemy_target_pick):
		return
	for choice_variant in preview.legal_second_actions(PLAYER):
		var choice: Dictionary = choice_variant
		selected_second_action = int(choice["action"])
		_second_enemy_target_pick = int(choice.get("target", -1))
		_second_action_btn = _action_button_for(selected_second_action)
		return


func _action_button_for(action: int) -> Button:
	match action:
		A.CHARGE: return btn_charge
		A.ATTACK: return btn_attack
		A.BIG_ATTACK: return btn_big_attack
		A.DEFEND: return btn_defend
		A.BIG_DEFEND: return btn_big_defend
	return null


# ============================================================
# 联机局（M1·2026-07-12·ADR-004）：镜像 + 协议驱动
# 本地 battle = 服务器权威快照的只读镜像（唯一写入口 _net_apply_snap）；
# 加入方（you=1）快照/事件/动作/pending 全部经 MatchClientScript.flip_* 翻转 →
# UI 恒以「玩家0=自己」渲染，两端各看各的视角。
# ============================================================

## 每帧网络泵 + 消息状态机（严格串行：结算动画期间不消化新消息）。
func _net_pump() -> void:
	var ses: Variant = BattleSetup.net_session
	if ses == null or battle == null:
		return
	ses.pump()
	# M2b 断线感知：断链亮提示（房主等重连·加入方指路回大厅重连续战）·链路恢复自动消提示
	var linked: bool = ses.enet.is_ready()
	if not linked and not _net_link_lost and state != State.GAME_OVER:
		_net_link_lost = true
		status_label.text = tr("对方断线·等待重连…（计时已暂停）") if String(ses.role) == "host" \
			else tr("与主机断开：回大厅→加入同一 IP 可续战")
		status_label.add_theme_color_override("font_color", Color("#e0a84b"))
		status_label.visible = true
	elif linked and _net_link_lost:
		_net_link_lost = false
		if state == State.PLAYER_SELECT or state == State.RESOLVING:
			status_label.visible = false
	if _net_busy or _drafting:
		return
	var c: Variant = ses.client
	if not c.resolves.is_empty():
		_net_play_resolution(c.resolves.pop_front())   # async·_net_busy 自守
		return
	if not c.draft_offer.is_empty() and state == State.PLAYER_SELECT:
		var offer: Dictionary = c.draft_offer
		c.draft_offer = {}
		_net_open_offer(offer)   # async·_drafting 自守
		return
	if int(c.snap_rev) != _net_snap_rev:
		_net_sync_latest()   # 对手抽/补/升级或换人 → 镜像跟进（明牌电报实时可见）
		if state == State.PLAYER_SELECT:
			_update_all()
	if String(c.phase) == "over" and state != State.GAME_OVER:
		var w: int = int(c.winner)
		_net_game_over(MatchClientScript.flip_winner(w) if _net_flipped() else w)
		return
	# 重连恢复死亡换人（2026-07-17 审计修复）：DEATH_SWITCH 期重连没有 resolve/turn_begin
	# 可跟——凭快照恢复的 client.phase 直接弹换人浮窗（否则只能干等服务器 20s 代选）。
	# 正常路径的换人在 _net_play_resolution 内（_net_busy 期）不经此口=不双弹。
	if String(c.phase) == "death_switch" and state != State.HERO_SELECT \
			and bool(battle.pending_death_switch[PLAYER]):
		_net_resume_death_switch()   # async·_net_busy 自守
		return
	if String(c.phase) == "select" and int(c.turn) != _net_last_turn \
			and state != State.PLAYER_SELECT and state != State.TURN_INTRO:
		_net_last_turn = int(c.turn)
		_show_turn_intro()   # 服务器 turn_begin → 正常回合开场（选招流程与本地共用）


## 终局 winner → 个人资料战绩键（本地直读 / 联机须先翻转为本端视角再传入）。
func _profile_outcome(w: int) -> String:
	if w == BattleCore.WINNER_P1:
		return "win"
	if w == BattleCore.WINNER_DRAW:
		return "draw"
	return "lose"


func _net_flipped() -> bool:
	return int(BattleSetup.net_session.client.you) == 1


## 权威快照上镜（联机镜像唯一写入口）。恢复失败=保留旧镜像并报警（2026-07-17 终审修复：
## 原先不查返回值——畸形快照会让客户端揣着半新不旧的状态继续渲染）。
func _net_apply_snap(snap: Dictionary) -> void:
	if not battle.from_snapshot(MatchClientScript.flip_snapshot(snap) if _net_flipped() else snap):
		push_error("battle_screen: 权威快照恢复失败（schema/版本不符）——保留旧镜像·等下一份快照")


func _net_sync_latest() -> void:
	var c: Variant = BattleSetup.net_session.client
	_net_apply_snap(c.snap)
	_net_snap_rev = int(c.snap_rev)


## 确认提交（联机版）：UI 选择打包成 payload 上行·锁输入等服务器结算。
func _net_submit_turn() -> void:
	var preview: BattleCore = _battle_after_selected_items()
	var action := A.CHARGE
	var target := -1
	if selected_action == ACTIVE:
		action = ACTIVE
		target = _enemy_target_pick
		if target < 0:
			# 需显式目标的主动技未点选：从镜像合法集代选（联机协议要求 target 精确匹配·不留引擎随机）
			for la in preview.legal_actions(PLAYER):
				if int(la["action"]) == ACTIVE:
					target = int(la["target"])
					break
	elif selected_action == A.SWITCH and selected_switch >= 0:
		action = A.SWITCH
		target = selected_switch
	elif selected_action >= 0:
		action = selected_action
		if ActionDef.is_attack(action) \
				and preview.can_target_any_enemy_with_base_attack(PLAYER, action):
			target = _enemy_target_pick
			if target < 0:
				target = preview.active_index[AI]
	var energy_cap_discount: bool = _energy_cap_discount_armed and \
		preview.can_use_energy_cap_discount(
			PLAYER, action, _empowered_wave_armed, _blood_payment_armed)
	var blood_payment: bool = _blood_payment_armed and (
		preview.can_use_active(PLAYER, true, energy_cap_discount) if action == ACTIVE
		else preview.can_pay_action_with_blood(
			PLAYER, action, _empowered_wave_armed, energy_cap_discount))
	var empowered: bool = _empowered_wave_armed \
		and preview.can_empower_wave_action(PLAYER, action, blood_payment, energy_cap_discount)
	var split_big_wave: bool = _split_big_wave_armed \
		and preview.can_split_big_wave_action(PLAYER, action, blood_payment, energy_cap_discount)
	var ordered_item_slots: Array[int] = _ordered_selected_item_slots()
	var item_slot_targets: Array[int] = []
	var item_slot_choices: Array[int] = []
	for s in ordered_item_slots:
		item_slot_targets.append(int(selected_item_hero_targets.get(
			s, selected_item_targets.get(s, -1))))
		item_slot_choices.append(int(selected_item_choices.get(s, -1)))
	BattleSetup.net_session.client.submit(
		action, target, ordered_item_slots, false, empowered, split_big_wave, blood_payment,
		_free_switch_sequence.duplicate(), _blood_payment_activation_step, energy_cap_discount,
		item_slot_targets, item_slot_choices, selected_second_action,
		_second_enemy_target_pick)
	_clear_selected_items()
	selected_action = -1
	selected_second_action = -1
	_second_enemy_target_pick = -1
	_second_action_btn = null
	selected_switch = -1
	selected_btn = null
	_empowered_wave_armed = false
	_split_big_wave_armed = false
	_energy_cap_discount_armed = false
	_blood_payment_armed = false
	_free_switch_sequence.clear()
	_blood_payment_activation_step = -1
	_reset_button_styles()
	_set_confirm_active(false)
	_set_buttons_active(false)
	state = State.RESOLVING   # 锁输入·resolve 快照到达后播动画
	status_label.text = tr("等待对方出招…")
	status_label.add_theme_color_override("font_color", Color("#c9c2b4"))
	status_label.visible = true


## 联机结算演出：镜像前置基线 → 权威快照上镜 → 与本地共用 _animate_resolution 播事件流。
func _net_play_resolution(msg: Dictionary) -> void:
	_net_busy = true
	state = State.RESOLVING
	game_timer.stop()
	_set_buttons_active(false)
	big_turn_label.visible = false
	_hold_timer_at_zero()
	status_label.visible = false
	var active_before: Array[int] = [battle.active_index[0], battle.active_index[1]]
	var hp_before: Array[float] = [
		battle.hp_display(battle.hp[0][active_before[0]]),
		battle.hp_display(battle.hp[1][active_before[1]])]
	_net_apply_snap(msg["snap"])
	var events: Array = msg.get("events", [])
	var actions: Array = msg.get("actions", [-1, -1])
	var pending: Array = (msg.get("pending", [false, false]) as Array).duplicate()
	if _net_flipped():
		events = MatchClientScript.flip_events(events)
		actions = [actions[1], actions[0]]
		pending = [pending[1], pending[0]]
	await _animate_resolution(
		{events = events, p1_action = int(actions[0]), p2_action = int(actions[1])},
		active_before, hp_before)
	if battle.game_over:
		await _wait_for_active_death_dissolves()
		_net_game_over(battle.winner)   # 镜像已按本端视角翻转 → winner 直接可读
		_net_busy = false
		return
	if bool(pending[0]):
		await _net_death_switch()
	elif bool(pending[1]):
		status_label.text = tr("对方选择替补中…")
		status_label.add_theme_color_override("font_color", Color("#c9c2b4"))
		status_label.visible = true
	_net_busy = false   # 新回合由 turn_begin → _net_pump 检测 turn 变化接手


## 重连恢复死亡换人（_net_pump 检测 client.phase 触发·_net_busy 挡住期间的重复泵）。
func _net_resume_death_switch() -> void:
	_net_busy = true
	await _net_death_switch()
	_net_busy = false


## 联机死亡换人：本端选替补 → 上行·服务器执行后 view/turn_begin 快照跟进。
func _net_death_switch() -> void:
	# 正常结算必须先看完倒地末帧的四周瓦解；重连恢复没有本地 defeat 事件时直接进选择。
	await _wait_for_death_dissolve(PLAYER)
	state = State.HERO_SELECT
	_set_buttons_active(false)
	_start_death_switch_timer()
	status_label.visible = false
	var reserves: Array = []
	for slot in battle.living_reserves(PLAYER):
		reserves.append([slot, battle.heroes[PLAYER][slot], battle.hp_display(battle.hp[PLAYER][slot])])
	_death_switch_overlay.show_selection(PLAYER, reserves)
	var pick: int = await _death_switch_overlay.selection_made
	game_timer.stop()
	BattleSetup.net_session.client.death_switch(pick)
	state = State.RESOLVING   # 等服务器广播（对方可能也在换）


## 联机 3 选 1（服务器私发的选项 → 复用本地弹窗 → 选择上行）。
func _net_open_offer(offer: Dictionary) -> void:
	var options: Array = []
	for id in offer.get("options", []):
		options.append(ItemCatalog.make(String(id)))
	if String(offer.get("kind", "")) in ["pointstone_offer", "item_choice_offer"]:
		var source: int = int(offer.get("slot", -1))
		var target: int = int(offer.get("target", -1))
		var item_id: String = String(offer.get("item_id", POINTSTONE_ITEM_ID))
		if _pending_pointstone_offer.get("source", -1) != source \
				or _pending_pointstone_offer.get("target", -1) != target \
				or String(_pending_pointstone_offer.get("item_id", "")) != item_id:
			_pending_pointstone_offer.clear()
			_update_all()
			return
		var pointstone_choice: int = await _show_draft(
			source, options, _item_choice_title(item_id, options.size()))
		_pending_pointstone_offer.clear()
		if pointstone_choice >= 0:
			_complete_item_choice(source, target, pointstone_choice,
				offer.get("options", []))
		elif target >= 0:
			_pending_item_target_slot = source
		_update_all()
		return
	var upgrade: bool = bool(offer.get("upgrade", false))
	var slot: int = int(offer.get("slot", 0))
	var c: int = await _show_draft(slot, options, tr("升级道具（3 选 1）") if upgrade else tr("抽取道具（3 选 1）"))
	if c >= 0:
		BattleSetup.net_session.client.pick(slot, c, upgrade)
	# 服务器回 view+snap → _net_pump 同步镜像并刷新 UI


func _net_game_over(w: int) -> void:
	# 幂等：终局可能双路到达（镜像结算演出末尾 + 服务器 over 相位消息）——战绩只记一次。
	if state == State.GAME_OVER:
		return
	state = State.GAME_OVER
	ProfileStore.record_result("net", _profile_outcome(w))   # 个人资料战绩（联机·w 已翻转为本端视角）
	game_timer.stop()
	_hold_timer_at_zero()
	_set_buttons_active(false)
	var msg := tr("平局")
	var col := Color("#dddddd")
	if w == BattleCore.WINNER_P1:
		msg = tr("胜利！")
		col = Color("#5fd86b")
	elif w != BattleCore.WINNER_DRAW:
		msg = tr("失败")
		col = Color("#e0574b")
	status_label.text = msg
	status_label.add_theme_color_override("font_color", col)
	status_label.visible = true


# ============================================================
# 任务G：AI 异步预想（选招期后台想·确认时重放·详见 _think_* 变量注释）
# ============================================================

## 把本回合已完成配对的道具按依赖顺序提交到克隆；用于动作可支付预览与 AI 预想。
## 熔炉/魔晶即时产能、爆裂即时减费与点金石原位升级都由 use_slot 统一反映。
func _battle_after_selected_items() -> BattleCore:
	var preview: BattleCore = battle.clone()
	for s in _ordered_selected_item_slots():
		preview.use_slot(PLAYER, s, int(selected_item_hero_targets.get(s, -1)),
			int(selected_item_targets.get(s, -1)),
			int(selected_item_choices.get(s, -1)))
	return preview


## 道具栏专用投影：只呈现点金石选定后的“锁定 T3”，不把其他暂存使用件误画成锁定。
func _battle_for_item_row() -> BattleCore:
	if selected_item_choices.is_empty():
		return battle
	var preview: BattleCore = battle.clone()
	for owner_variant in selected_item_choices:
		var owner: int = int(owner_variant)
		var target: int = int(selected_item_targets.get(owner, -1))
		var choice: int = int(selected_item_choices[owner])
		if target < 0 or target >= preview.slots[PLAYER].size():
			continue
		var option_ids: Array = selected_item_choice_options.get(owner, [])
		if option_ids.is_empty() and owner >= 0 and owner < battle.slots[PLAYER].size():
			for item_variant in (battle.slots[PLAYER][owner]["upg_draft"] as Array):
				option_ids.append((item_variant as ItemData).item_id)
		if choice < 0 or choice >= option_ids.size():
			continue
		var legendary: ItemData = ItemCatalog.make(String(option_ids[choice]))
		if legendary == null or legendary.tier != 3:
			continue
		var target_slot: Dictionary = preview.slots[PLAYER][target]
		target_slot["item"] = legendary
		target_slot["state"] = BattleCore.SlotState.CHARGING
		target_slot["since"] = preview.turn_number
		target_slot["used"] = false
		target_slot["draft"] = []
		target_slot["upg_draft"] = []
	return preview


## 玩家本回合点选道具集的指纹（槽位+目标槽排序后字符串·预想结果的有效性校验键之一）。
func _items_key() -> String:
	var a: Array[int] = selected_item_slots.duplicate()
	a.sort()
	var keyed: Array[String] = []
	for s in a:
		keyed.append("%d:%d:%d:%d" % [s, int(selected_item_targets.get(s, -1)),
			int(selected_item_hero_targets.get(s, -1)),
			int(selected_item_choices.get(s, -1))])
	return str(keyed)


## 拉起/重启本地 AI 后台预想。PvE 与本地 PvP 共用；联机局由对端玩家决策。
func _start_ai_think() -> void:
	if _net or state != State.PLAYER_SELECT or battle == null or battle.game_over:
		return   # 联机局无本地 AI（对手=真人·M1）
	if _think_task >= 0:
		_think_restart = true   # 正在想：标记重拉（旧结果会因 items_key/turn 校验不符被弃）
		return
	_think_restart = false
	_think_mutex.lock()
	_think_out = {}
	_think_mutex.unlock()
	var clone: BattleCore = battle.clone()
	for s in _ordered_selected_item_slots():
		clone.use_slot(PLAYER, s, int(selected_item_hero_targets.get(s, -1)),
			int(selected_item_targets.get(s, -1)),
			int(selected_item_choices.get(s, -1)))
		# 纳入玩家已点选道具及槽目标（同步路径确认时同序提交·输入才逐位一致）。
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
	BattleAI.commit_attack_items(battle, AI, int(choice["action"]),
		int(choice.get("second_action", -1)))
	if not battle.apply_choice(AI, choice):
		battle.select_action(AI, A.CHARGE)   # 兜底（与同步路径同款保险）
	return true


func _ai_pick(side: int) -> void:
	# 与 sim 统一：同一套 BattleAI 逻辑——价值搜索道具经济(plan_economy·B) + 同时博弈选动作(choose_action)
	# + 进攻向道具随攻击动作一并甩出(commit_attack_items·2026-07-03)。
	# 取代旧「随机加权出招」占位 AI；试玩与平衡模拟现共用一套决策。AI 不偷看玩家已锁动作（搜索按博弈枚举）。
	_ai.plan_economy(battle, side, _ai_rng)
	var choice: Dictionary = _ai.choose_action(battle, side)
	BattleAI.commit_attack_items(battle, side, int(choice["action"]),
		int(choice.get("second_action", -1)))
	if not battle.apply_choice(side, choice):
		battle.select_action(side, A.CHARGE)   # 兜底（被禁/付不起→引擎 resolve guard 也兜）


func _resolve() -> void:
	state = State.RESOLVING
	_set_buttons_active(false)
	big_turn_label.visible = false
	_hold_timer_at_zero()
	status_label.visible = false

	# 结算前的出战槽（= UI 已知的"谁在场上"·上一帧就渲染着·非引擎完整状态·联机客户端同样持有）。
	# 仅用它判定"出战英雄本回合是否阵亡"（配 hero_died 事件），不读结算后的 battle.hp。
	var active_before: Array[int] = [battle.active_index[0], battle.active_index[1]]
	# ③ 治疗检测基线：结算前出战英雄的显示 HP（=屏幕上正渲染着的值·联机客户端同样持有）。
	# 结算后同槽位 HP 上升 = 本拍被治疗 → 绿 +N 飘字。走前后快照对比而非枚举治疗事件 id：
	# 引擎零改动、未来新增治疗来源（道具/技能）自动覆盖；槽位变了（切换/换人）不算治疗。
	var hp_before: Array[float] = [
		battle.hp_display(battle.hp[0][active_before[0]]),
		battle.hp_display(battle.hp[1][active_before[1]])]

	var r: Dictionary = battle.resolve()
	await _animate_resolution(r, active_before, hp_before)
	await _post_resolution(r)


## 免费切换在选择期只改逻辑预览。若天罗于揭示后取消它，核心快照已经恢复原出战槽；
## 在动作演出开始前只同步角色与头像布局，避免仍由预览英雄代演本回合动作。
func _sync_cancelled_free_switch_preview(events: Array) -> void:
	for event_variant in events:
		var event: Dictionary = event_variant
		if String(event.get("id", "")) != "free_switch_cancelled":
			continue
		_update_hero_frames()
		_update_character_displays()
		return


## resolve 前 UI 正显示免费切换的预览英雄，因此本地与联机都会先抓到 preview 槽的
## active_before / hp_before。取消事件携带原槽与裁定时原槽血量，用它修正纯演出基线；
## 否则原槽的到期伤害注解会漏，原槽同拍治疗也会因槽位不等而不显示。
func _correct_cancelled_free_switch_baselines(events: Array, active_before: Array[int],
		hp_before: Array[float]) -> Dictionary:
	var corrected_active: Array[int] = active_before.duplicate()
	var corrected_hp: Array[float] = hp_before.duplicate()
	for event_variant in events:
		var event: Dictionary = event_variant
		if String(event.get("id", "")) != "free_switch_cancelled":
			continue
		var player: int = int(event.get("player", -1))
		if player < 0 or player >= corrected_active.size():
			continue
		corrected_active[player] = int(event.get("from", corrected_active[player]))
		if event.has("hp_before"):
			corrected_hp[player] = float(event["hp_before"]) / float(BattleCore.HP_UNIT)
	return {active = corrected_active, hp = corrected_hp}


## 结算演出（本地/联机共用·M1 抽取）：一切动画从事件流 + 前置基线派生，零依赖"谁 resolve 的"。
## r 需含 events / p1_action / p2_action；active_before / hp_before = 结算前出战槽与其显示 HP
## （本地=resolve 前捕获·联机=镜像上快照前捕获——两者同源=屏幕上正渲染的值）。
func _animate_resolution(r: Dictionary, active_before: Array[int], hp_before: Array[float]) -> void:
	# 动画所需信息全部【从事件流派生】——不再 diff 结算后的引擎完整状态，
	# 联机（服务器权威·客户端只收 events）下同样可行。A3a（2026-07-02）：死亡判定由血量 diff 改吃 hero_died。
	#   damage_taken 按目标槽累加；当前出战位走中央角色演出，替补位走对应头像框演出。
	var resolution_events: Array = r.get("events", [])
	_sync_cancelled_free_switch_preview(resolution_events)
	var corrected_baselines: Dictionary = _correct_cancelled_free_switch_baselines(
		resolution_events, active_before, hp_before)
	var corrected_active_before: Array[int] = corrected_baselines["active"]
	var corrected_hp_before: Array[float] = corrected_baselines["hp"]
	var display_slots: Array[int] = [battle.active_index[0], battle.active_index[1]]
	var dmg: Array[int] = [0, 0]
	var reserve_hits: Array[Dictionary] = [{}, {}]   # slot → {amount, pen}，防替补受击误打中央角色
	var reserve_blocks: Array[Dictionary] = [{}, {}] # slot → 是否挡下大波，防替补格挡误播到中央角色
	var dead: Array[bool] = [false, false]
	var pen_max: Array[int] = [0, 0]        # ⑧ 本拍最高穿透档（damage_taken.pen·Pen 枚举有序 → 取最高档配色）
	var blocked: Array[bool] = [false, false]     # ② 该方本拍挡下过攻击（player=防守方）
	var block_big_atk: Array[bool] = [false, false]  # ② 挡下的是不是大波（演出隆重度）
	var egain: Array[int] = [0, 0]          # ③ 本拍能量获得（半能单位）
	# A3b 事件注解飘字：伤害数字解释不了的时刻逐条标出（每项={text,col,可选 size/y/outline/pr}）。
	#   tags=命中拍弹出；pre_tags=出招拍弹出（力竭/定身/到期延迟伤害——都发生在动作揭示时刻）。
	#   替补席事件（牧羊/饕餮回血、替补位延迟伤害）不在角色身位飘字——replay 到 HUD 替补行=后续候选。
	var tags: Array = [[], []]
	var pre_tags: Array = [[], []]
	var cancelled_attacks: Array[bool] = [false, false]
	# 力量的代价属于回合末自我处决，而非对方动作击杀。保留死亡演出，
	# 但不能误触发对方终结技或“大波命中”的镜头判断。
	var strength_price_executed: Array[bool] = [false, false]
	for ev in resolution_events:
		var p: int = int(ev.get("player", 0))
		var event_slot: int = int(ev.get("slot", display_slots[p]))
		var on_display: bool = event_slot == display_slots[p]
		match ev.get("id", ""):
			"item_countered":
				var counter_player: int = int(ev.get("source_player", 1 - p))
				if counter_player >= 0 and counter_player < pre_tags.size():
					pre_tags[counter_player].append({text = tr("反制"), col = COL_TAG_BREAK})
			"damage_taken":
				if on_display:
					dmg[p] += int(ev.get("amount", 0))
					pen_max[p] = maxi(pen_max[p], int(ev.get("pen", 0)))
				else:
					var reserve_hit: Dictionary = reserve_hits[p].get(event_slot, {amount = 0, pen = 0})
					reserve_hit["amount"] = int(reserve_hit["amount"]) + int(ev.get("amount", 0))
					reserve_hit["pen"] = maxi(int(reserve_hit["pen"]), int(ev.get("pen", 0)))
					reserve_hits[p][event_slot] = reserve_hit
			"life_lost", "yaohuo_loss":
				# 失去生命绕过伤害管线，但仍必须进入受击演出，避免血量无提示跳变。
				var loss_amount: int = int(ev.get("amount", 0))
				if on_display:
					dmg[p] += loss_amount
					tags[p].append({
						text = tr("妖火") if String(ev.get("id", "")) == "yaohuo_loss" else tr("反噬"),
						col = COL_DMG_BURN if String(ev.get("id", "")) == "yaohuo_loss" else COL_TAG_BREAK,
					})
				else:
					var reserve_loss: Dictionary = reserve_hits[p].get(event_slot, {amount = 0, pen = 0})
					reserve_loss["amount"] = int(reserve_loss["amount"]) + loss_amount
					reserve_hits[p][event_slot] = reserve_loss
			"hero_died":
				if event_slot == display_slots[p]:
					dead[p] = true
			"defend_block", "big_defend_block":
				var blocked_big: bool = int(ev.get("kind", -1)) == A.BIG_ATTACK
				if on_display:
					blocked[p] = true
					if blocked_big:
						block_big_atk[p] = true
				else:
					reserve_blocks[p][event_slot] = bool(reserve_blocks[p].get(event_slot, false)) or blocked_big
			"charge_gain":
				egain[p] += int(ev.get("amount", 0))
			"poison_detonate":
				if on_display:
					tags[p].append({text = tr("毒爆"), col = COL_TAG_POISON})
			"marked_hit":
				if on_display:
					tags[p].append({text = tr("印记"), col = COL_TAG_AMP})
			"vuln_hit":
				if on_display:
					tags[p].append({text = tr("脆弱"), col = COL_TAG_AMP})
			"shield_absorb":
				if on_display:
					tags[p].append({text = tr("护盾-%s") % _fmt_hp(float(ev.get("amount", 0)) / 2.0), col = COL_TAG_ABSORB})
			"decoy_absorb":
				if on_display:
					tags[p].append({text = tr("替身-%s") % _fmt_hp(float(ev.get("amount", 0)) / 2.0), col = COL_TAG_ABSORB})
			"damage_immune":
				if on_display:
					tags[p].append({text = tr("免疫"), col = COL_TAG_SAVE, pr = 0})
			"armor_broken":
				if on_display:
					tags[p].append({text = tr("破甲"), col = COL_TAG_BREAK})
			"longyuji_empowered":
				tags[p].append({text = tr("龙御极"), col = COL_TAG_AMP})
			"h13_split_big_wave":
				tags[p].append({text = tr("双波"), col = COL_TAG_AMP})
			"h14_blood_payment":
				tags[p].append({
					text = tr("生命-%s") % _fmt_hp(float(ev.get("amount", 0)) / 2.0),
					col = COL_TAG_BREAK,
				})
			"h24_energy_cap_discount":
				tags[p].append({text = tr("上限-1 / 费用-1"), col = COL_TAG_AMP})
			"h16_reserve_pursuit":
				tags[p].append({text = tr("追击"), col = COL_TAG_AMP})
			"h17_transform":
				pre_tags[p].append({text = tr("转变"), col = COL_TAG_AMP})
			"h22_energy_burn":
				tags[0].append({text = tr("能量归零"), col = COL_TAG_BREAK})
				tags[1].append({text = tr("能量归零"), col = COL_TAG_BREAK})
			"energy_max_reduced":
				tags[p].append({
					text = tr("能量上限-%s") % _fmt_hp(float(ev.get("amount", 0)) / float(ActionDef.ENERGY_UNIT)),
					col = COL_TAG_BREAK,
				})
			"huanhun_revive", "huanhun_fatal_immunity":
				if on_display:
					tags[p].append({text = tr("还魂"), col = COL_TAG_SAVE, pr = 0})
			"strength_price_execution":
				if on_display:
					strength_price_executed[p] = true
					tags[p].append({text = tr("代价"), col = COL_TAG_BREAK, pr = 0})
			"base_attack_cancelled":
				cancelled_attacks[p] = true
				tags[p].append({text = tr("断招"), col = COL_TAG_BREAK, pr = 0})
			"exhausted":
				pre_tags[p].append({text = tr("力竭"), col = BattleFxScript.COL_BLOCK_TEXT})
			"switch_locked":
				pre_tags[p].append({text = tr("定身"), col = BattleFxScript.COL_BLOCK_TEXT})
			"free_switch_cancelled":
				pre_tags[p].append({text = tr("天罗·切换无效"), col = BattleFxScript.COL_BLOCK_TEXT})
			"deferred_damage":
				# 旧延迟伤害不走 damage_taken；保留其动作前余烬提示。
				if int(ev.get("slot", -1)) == corrected_active_before[p]:
					pre_tags[p].append({text = "-%s" % _fmt_hp(float(ev.get("amount", 0)) / 2.0),
						col = COL_DMG_BURN, size = 44, y = 0.30, outline = Color(0.22, 0.08, 0.02, 0.95)})
	# ③ 治疗量：同槽位显示 HP 前后差（阵亡/换槽不算）
	var healed: Array[float] = [0.0, 0.0]
	for p in 2:
		if not dead[p] and battle.active_index[p] == corrected_active_before[p]:
			var hp_now := battle.hp_display(battle.hp[p][corrected_active_before[p]])
			if hp_now > corrected_hp_before[p]:
				healed[p] = hp_now - corrected_hp_before[p]

	# 头顶招式圆圈（揭示双方盲选出招）→ 消失 → 再播打斗动画
	await _show_action_indicators(r.get("p1_action", -1), r.get("p2_action", -1))
	var anim_actions: Array[int] = [int(r.get("p1_action", -1)), int(r.get("p2_action", -1))]
	for p in 2:
		if cancelled_attacks[p]:
			anim_actions[p] = -1
	await _play_battle_anims(anim_actions[0], anim_actions[1], dmg, dead,
		{pen = pen_max, blocked = blocked, block_big = block_big_atk, egain = egain, healed = healed,
			tags = tags, pre_tags = pre_tags, reserve_hits = reserve_hits, reserve_blocks = reserve_blocks,
			strength_price_executed = strength_price_executed})
	_update_all()


## 结算后续（本地流程尾）：终局/加时/AI 换人/玩家换人/下一回合。联机不走此路（服务器驱动相位）。
func _post_resolution(r: Dictionary) -> void:
	if r.get("game_over", false):
		# 终局/同归/远征都先完成角色本体瓦解，结果 UI 不再抢跑。
		await _wait_for_active_death_dissolves()
		var w: int = r.get("winner", BattleCore.WINNER_UNDECIDED)
		# 远征 PvE：胜=对手全灭·其余（含同拍双死）=队伍全灭 → 回地图结算·不走加时赛。
		if _pve:
			await _pved.finish("win" if w == BattleCore.WINNER_P1 else "lose")
			return
		# 加时赛触发（Q5）：主局双方同归 → 各自 3 选 1 白板满血 1v1；加时局再平 = 真平局（走下方正常结束）。
		if w == BattleCore.WINNER_DRAW and not _overtime:
			await _start_overtime()
			return
		state = State.GAME_OVER
		ProfileStore.record_result("match", _profile_outcome(w))   # 个人资料战绩（本地匹配·终局仅此一处）
		var msg := tr("平局")
		var col := Color("#dddddd")
		if w == BattleCore.WINNER_P1:
			msg = tr("胜利！")
			col = Color("#5fd86b")
		elif w != BattleCore.WINNER_DRAW:
			msg = tr("失败")
			col = Color("#e0574b")
		status_label.text = msg
		status_label.add_theme_color_override("font_color", col)
		status_label.visible = true
		return

	# AI 死亡换人：与 sim 统一，用搜索 AI 对位选替补（choose_death_switch）；异常兜底首个存活替补。
	if battle.pending_death_switch[AI]:
		await _wait_for_death_dissolve(AI)
		var ai_slot: int = _ai.choose_death_switch(battle, AI)
		if ai_slot < 0:
			var ai_reserves: Array[int] = battle.living_reserves(AI)
			ai_slot = ai_reserves[0] if ai_reserves.size() > 0 else -1
		if ai_slot >= 0:
			battle.execute_death_switch(AI, ai_slot)
			await _death_switch_transition(AI)   # 遗体消散→新人入场（秒切退役）
		else:
			_update_all()

	# 玩家死亡换人：倒地末帧停留 + 12 阶瓦解全部完成后才弹出选择。
	if battle.pending_death_switch[PLAYER]:
		await _wait_for_death_dissolve(PLAYER)
		await _show_death_switch_selection(PLAYER)

	await get_tree().create_timer(maxf(0.1, anim_phase_duration * 0.5)).timeout
	_show_turn_intro()


## 加时赛（Q5·2026-07-03）：主局同归 → 玩家复用换人浮窗从全队 3 人里选 1（含阵亡者·满血复活），
## AI 选血量上限最大者；组白板 3 人组（板凳 0 血）→ BattleSetup 带旗标整场景重载 = UI 干净重建。
func _start_overtime() -> void:
	state = State.HERO_SELECT
	_set_buttons_active(false)
	_start_death_switch_timer()
	status_label.text = tr("平局 → 加时赛！")
	status_label.add_theme_color_override("font_color", Color("#ffd86a"))
	status_label.visible = true

	var entries: Array = []
	for s in range(battle.heroes[PLAYER].size()):
		var h: HeroData = battle.heroes[PLAYER][s]
		entries.append([s, h, float(h.max_hp)])   # 满血复活展示
	_death_switch_overlay.show_selection(PLAYER, entries, tr("加时赛：选一人出战（满血·无技能无道具）"))
	var pick: int = await _death_switch_overlay.selection_made
	game_timer.stop()
	var ai_pick: int = BattleAI.choose_overtime_pick(battle, AI)

	BattleSetup.p1_heroes = BattleCore.overtime_roster(battle.heroes[PLAYER], pick)
	BattleSetup.p2_heroes = BattleCore.overtime_roster(battle.heroes[AI], ai_pick)
	BattleSetup.overtime = true
	get_tree().reload_current_scene()


# 加时日食「烛阴之眼」演出旋钮（2026-07-11 五版·Eddy 定形：裂缝闪现+小震 → 挂住 → 咔嚓吞尽接大震）
const ECLIPSE_EAT_DELAY := 0.3       # 开场静置(s)
const ECLIPSE_CRACK_TIME := 0.22     # 裂缝自缘向心伸展时长(s·"一下")
const ECLIPSE_CRACK_SHAKE := 2.5     # 裂缝瞬间小震幅度
const ECLIPSE_CRACK_HOLD := 0.55     # 裂缝挂住时长(s·裂纹微微蠕动)
const ECLIPSE_SNAP_TIME := 0.2       # 咔嚓吞尽时长(s·黑暗一口盖满)
const ECLIPSE_COMMIT_SHAKE := 5.0    # 成相震屏幅度
const ECLIPSE_RIM_BURST := 2.4       # 环光小炸峰值(rim_intensity 短冲)
const ECLIPSE_RIM_SETTLE := 0.45     # 小炸回落时长(s)
const ECLIPSE_HALO_CORE := Color(0.85, 0.7, 1.0)   # 日食态月晕芯色(紫白)
const ECLIPSE_HALO_GLOW := Color(0.5, 0.32, 0.9)   # 日食态月晕外晕(紫)


## 加时赛开场演出「烛阴之眼」（2026-07-11 五版·Eddy 定形·⛔眼球晃动已去/⛔白闪已否）：
## 巨月原地不动 → 黑色裂纹自月缘向心一下伸展（小震）→ 挂住微微蠕动 → 咔嚓：黑暗一口吞尽
## （指状前沿·⛔正圆收缩环）→ 紧接成相大震+环光小炸 → 紫日食+月晕转紫定格。
## 非阻塞：与选招流程并行·不碰 UI/不锁输入。日食本体=程序化 shader（scene1 Eclipse 节点）。
## ⚠ Eclipse/MoonHalo 材质均先 duplicate 再改（.tscn 子资源跨场景实例共享·防污染下一局）。
func _play_eclipse_intro() -> void:
	var moon := stage.get_node_or_null("Moon") as CanvasItem
	var eclipse := stage.get_node_or_null("Eclipse") as CanvasItem
	if moon == null or eclipse == null:
		return
	eclipse.material = eclipse.material.duplicate()
	var emat := eclipse.material as ShaderMaterial
	var halo_mat: ShaderMaterial = null
	var halo := stage.get_node_or_null("MoonHalo") as CanvasItem
	if halo != null and halo.material is ShaderMaterial:
		halo.material = halo.material.duplicate()
		halo_mat = halo.material as ShaderMaterial
	emat.set_shader_parameter("crack", 0.0)
	emat.set_shader_parameter("eat", 0.0)
	emat.set_shader_parameter("final_mix", 0.0)
	eclipse.modulate = Color.WHITE
	eclipse.visible = true
	var tw := create_tween()
	tw.tween_interval(ECLIPSE_EAT_DELAY)
	tw.tween_callback(stage.shake.bind(ECLIPSE_CRACK_SHAKE, 0.0))
	tw.tween_property(emat, "shader_parameter/crack", 1.0, ECLIPSE_CRACK_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(ECLIPSE_CRACK_HOLD)
	tw.tween_property(emat, "shader_parameter/eat", 1.0, ECLIPSE_SNAP_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_eclipse_commit.bind(moon, emat, halo_mat))


## 成相瞬间（⛔白闪已否·Eddy 2026-07-11）：月面隐藏、环+冕点亮并小炸回落、震屏、月晕转紫。
func _eclipse_commit(moon: CanvasItem, emat: ShaderMaterial, halo_mat: ShaderMaterial) -> void:
	moon.visible = false
	emat.set_shader_parameter("final_mix", 1.0)
	emat.set_shader_parameter("rim_intensity", ECLIPSE_RIM_BURST)
	emat.set_shader_parameter("corona_intensity", 0.9)
	stage.shake(ECLIPSE_COMMIT_SHAKE)
	var tw := create_tween()
	tw.tween_property(emat, "shader_parameter/rim_intensity", 1.0, ECLIPSE_RIM_SETTLE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(emat, "shader_parameter/corona_intensity", 0.5, ECLIPSE_RIM_SETTLE)
	if halo_mat != null:
		halo_mat.set_shader_parameter("core_color", ECLIPSE_HALO_CORE)
		halo_mat.set_shader_parameter("glow_color", ECLIPSE_HALO_GLOW)
		halo_mat.set_shader_parameter("core_intensity", 0.35)
		halo_mat.set_shader_parameter("glow_intensity", 0.16)


func _show_death_switch_selection(player: int) -> void:
	state = State.HERO_SELECT
	_set_buttons_active(false)
	_start_death_switch_timer()
	status_label.visible = false   # 不在屏幕中间显示「英雄阵亡」，只保留换人界面

	var reserves: Array = []
	for slot in battle.living_reserves(player):
		reserves.append([slot, battle.heroes[player][slot], battle.hp_display(battle.hp[player][slot])])

	_death_switch_overlay.show_selection(player, reserves)
	var selected_slot: int = await _death_switch_overlay.selection_made
	game_timer.stop()
	battle.execute_death_switch(player, selected_slot)
	await _death_switch_transition(player)   # 遗体已瓦解 → 透明期换装 → 新人入场


func _start_death_switch_timer() -> void:
	# 死亡补位继续使用顶部唯一回合倒计时；浮层不再拥有第二套 Label/Timer。
	timer_seconds = _turn_time_limit()
	timer_label.visible = true
	_update_timer_label()
	game_timer.start(1.0)


# ============================================================
# 英雄框交互（切换 / h07 免费切）
# ============================================================

## 顶部己方头像只处理道具选择英雄目标；普通切换统一由左下模块承接。
func _on_reserve_frame_input(event: InputEvent, frame_idx: int) -> void:
	if state != State.PLAYER_SELECT:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	if _pending_item_hero_target_slot >= 0:
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_pending_item_hero_target_slot = -1
			_clear_friendly_item_target_prompts()
			_update_all()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_select_friendly_item_target(frame_idx)
		return
	# 非道具选人状态下，顶部头像只提供悬停说明，不再产生切换动作。
	return


## 该替补框是否可换人（索引 1/2、槽位有效、存活、非出战位，并通过战斗核心动作门）。
func _is_switchable_reserve(frame_idx: int) -> bool:
	if frame_idx < 1 or frame_idx >= p1_frames.size():
		return false
	if not battle.can_switch(PLAYER):
		return false
	var slot: int = p1_frame_slots[frame_idx]
	return slot >= 0 and slot != battle.active_index[PLAYER] and battle.hp[PLAYER][slot] > 0


## 进入 armed 态：该框立绘 → 「切换」二字；先取消其它框的 armed + 清掉已选动作高亮（点切换=放弃已选动作）。
func _arm_switch_frame(frame_idx: int) -> void:
	_disarm_switch()
	var keep_blood_payment := _blood_payment_armed \
		and battle.is_free_switch_target(PLAYER, p1_frame_slots[frame_idx])
	_clear_action_selection_full(keep_blood_payment)
	_armed_switch_frame = frame_idx
	_switch_selected = false
	p1_frames[frame_idx].set_switch_prompt(true)


## 选择换人：框做选择弹跳动画 + 高亮(与底部按钮一致)，把 switch 设为本回合动作；「结束」呼吸提示提交。
func _select_switch(frame_idx: int) -> void:
	selected_action = A.SWITCH
	selected_second_action = -1
	_second_enemy_target_pick = -1
	_second_action_btn = null
	selected_switch = p1_frame_slots[frame_idx]
	selected_btn = null
	_empowered_wave_armed = false
	_split_big_wave_armed = false
	_energy_cap_discount_armed = false
	_blood_payment_armed = false
	battle.set_blood_payment_active(PLAYER, false)
	_blood_payment_activation_step = -1
	p1_frames[frame_idx].is_selected = true
	_switch_selected = true
	_set_switch_button_feedback(true)
	_set_confirm_active(true)


## 取消换人选择（回 armed：仍显「切换」，去高亮·停结束呼吸）；不退出 armed。
func _deselect_switch() -> void:
	if _armed_switch_frame >= 0 and _armed_switch_frame < p1_frames.size():
		p1_frames[_armed_switch_frame].is_selected = false
	selected_action = -1
	selected_second_action = -1
	_second_enemy_target_pick = -1
	_second_action_btn = null
	selected_switch = -1
	_empowered_wave_armed = false
	_split_big_wave_armed = false
	_energy_cap_discount_armed = false
	_blood_payment_armed = false
	battle.set_blood_payment_active(PLAYER, false)
	_blood_payment_activation_step = -1
	_switch_selected = false
	_set_switch_button_feedback(false)
	_set_confirm_active(false)


## 退出 armed 态：恢复立绘、去选中高亮。
func _disarm_switch() -> void:
	if _armed_switch_frame >= 0 and _armed_switch_frame < p1_frames.size():
		var f: HeroFrame = p1_frames[_armed_switch_frame]
		f.is_selected = false
		f.set_switch_prompt(false)
	_armed_switch_frame = -1
	_switch_selected = false
	_set_switch_button_feedback(false)


## h07 千里自在风：每回合一次免费切换逻辑预览（不占动作·本回合继续行动）。
## 核心只暂存 from/to 并让 active_index 指向预览英雄；出入场、冲撞与夜明珠均等到
## 同回合天罗裁定后才原子兑现，故此处可以直接复用成熟角色/按钮刷新而不复制战局。
func _free_switch_now(frame_idx: int) -> void:
	var slot: int = p1_frame_slots[frame_idx]
	if slot < 0:
		return
	_disarm_switch()
	if battle.free_switch(PLAYER, slot):
		if _net:
			_free_switch_sequence.append(slot)
		selected_action = -1
		selected_second_action = -1
		_second_enemy_target_pick = -1
		_second_action_btn = null
		selected_switch = -1
		selected_btn = null
		_empowered_wave_armed = false
		_split_big_wave_armed = false
		_energy_cap_discount_armed = false
		_reset_button_styles()
		_update_all()


## 清掉底部动作按钮的选中高亮 + 结束呼吸 + 选择状态。
## 免费切换可保留蚩尤已发动的血量支付；普通换人会一并取消。
func _clear_action_selection_full(preserve_blood_payment: bool = false) -> void:
	selected_action = -1
	selected_second_action = -1
	_second_enemy_target_pick = -1
	_second_action_btn = null
	selected_switch = -1
	selected_btn = null
	_empowered_wave_armed = false
	_split_big_wave_armed = false
	_energy_cap_discount_armed = false
	if not preserve_blood_payment:
		_blood_payment_armed = false
		battle.set_blood_payment_active(PLAYER, false)
		_blood_payment_activation_step = -1
	for btn in action_btn_list:
		_set_btn_selected(btn, false)
	_set_confirm_active(false)
	_clear_enemy_targets()   # 放弃已选动作 → 一并退出 h21 敌方目标选择态


# ============================================================
# 敌方英雄目标选择：h21【调虎离山】、h04【十方无次第】与寻星坠共用头像框入口
# ============================================================

## h21：只点敌方存活替补，未选时保留技能默认；h04：波/大波可点任一存活敌方；
## 寻星坠：只授权原选招为「波」的本回合攻击。两者都默认锁当前敌方出战位。
func _can_choose_enemy_attack_target(action: int) -> bool:
	if not ActionDef.is_attack(action):
		return false
	var preview: BattleCore = _battle_after_selected_items()
	return preview.can_target_any_enemy_with_base_attack(PLAYER, action)


func _maybe_arm_enemy_targets(action: int) -> void:
	var sk: HeroSkill = battle.get_skill(PLAYER, battle.active_index[PLAYER])
	var include_active := false
	var prompt := ""
	if action == ACTIVE and sk != null and sk.active_needs_enemy_target():
		prompt = tr("揪")
	elif _can_choose_enemy_attack_target(action):
		include_active = true
		prompt = tr("攻")
	else:
		return
	_enemy_targeting = true
	_enemy_target_action = action
	_enemy_target_pick = battle.active_index[AI] if include_active else -1
	for fi in [0, 1, 2]:
		var slot: int = p2_frame_slots[fi]
		if slot >= 0 and battle.hp[AI][slot] > 0 \
				and (include_active or slot != battle.active_index[AI]):
			p2_frames[fi].set_switch_prompt(true, prompt)
			p2_frames[fi].is_selected = slot == _enemy_target_pick


## 道具点选可以在选招前或选招后发生；每次变更都从已选道具预览重算临时选敌权。
## 不新增界面：仍复用 h04 的敌方头像单选；若授权仍存在，保留玩家已选的存活目标。
func _refresh_enemy_targets_after_item_change() -> void:
	if selected_action < 0:
		return
	# 轻量脚本测试/非战斗预览可能尚未装配英雄框；权限仍由预览核心查询，不触碰空 UI。
	if p2_frames.size() < 3 or p2_frame_slots.size() < 3:
		return
	var previous_pick: int = _enemy_target_pick
	var should_target: bool = selected_action == ACTIVE \
		or _can_choose_enemy_attack_target(selected_action)
	_clear_enemy_targets()
	if not should_target:
		return
	_maybe_arm_enemy_targets(selected_action)
	if not ActionDef.is_attack(selected_action) or previous_pick < 0 \
			or previous_pick >= battle.hp[AI].size() or battle.hp[AI][previous_pick] <= 0:
		return
	_enemy_target_pick = previous_pick
	for fi in [0, 1, 2]:
		var slot: int = p2_frame_slots[fi]
		p2_frames[fi].is_selected = slot == previous_pick


## 敌方头像框点击：h21 排除出战位且允许取消；h04 包含出战位并始终保持一个明确目标。
func _on_enemy_frame_input(event: InputEvent, frame_idx: int) -> void:
	if state != State.PLAYER_SELECT or not _enemy_targeting:
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var slot: int = p2_frame_slots[frame_idx]
	var is_attack_targeting := ActionDef.is_attack(_enemy_target_action)
	if slot < 0 or battle.hp[AI][slot] <= 0 \
			or (not is_attack_targeting and slot == battle.active_index[AI]):
		return
	if _enemy_target_pick == slot:
		if not is_attack_targeting:
			_enemy_target_pick = -1                # h21 点已选 = 取消（提交走技能默认）
			p2_frames[frame_idx].is_selected = false
	else:
		for fj in [0, 1, 2]:
			p2_frames[fj].is_selected = false      # 单选：先清旧选中
		_enemy_target_pick = slot
		p2_frames[frame_idx].is_selected = true


## 退出敌方目标选择态：清高亮 + 提示 + 记录（幂等）。
func _clear_enemy_targets() -> void:
	if not _enemy_targeting and _enemy_target_pick < 0:
		return
	for fi in [0, 1, 2]:
		p2_frames[fi].is_selected = false
		p2_frames[fi].set_switch_prompt(false)
	_enemy_targeting = false
	_enemy_target_action = -1
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
		_set_switch_tray_open(false)
		_clear_enemy_targets()   # 离开选择阶段 → 退出敌方英雄目标选择态
		if longyuji_picker:
			longyuji_picker.visible = false
		if split_big_wave_picker:
			split_big_wave_picker.visible = false
		if h24_discount_picker:
			h24_discount_picker.visible = false
	# 底部 UI 始终可见。
	for btn in action_btn_list + [btn_confirm]:
		btn.visible = true
	_layout_circles()
	var show_affordance := active or not dim_inactive
	var alpha := 1.0 if show_affordance else 0.4
	buttons_ctrl.modulate = Color(1, 1, 1, alpha)
	if show_affordance:
		_refresh_action_affordance()   # 按能量显示亮/暗（开局与选择阶段一致）
	else:
		for btn in action_btn_list + [btn_confirm]:
			btn.disabled = true        # 结算/过场：全禁用（图鉴钮不禁——随时可查阅）
	_refresh_switch_module()


## 编辑器可摆位：按钮位置/尺寸全部读 .tscn，代码只管显隐与技能 tooltip，不再覆盖坐标。
## 在 Godot 里随意移动/缩放 Buttons 下的按钮即可，运行时不会被弹回。
func _layout_circles() -> void:
	var has_active: bool = _player_has_active()
	btn_special.visible = has_active
	if has_active:
		_refresh_special_icon()   # 图标=出战英雄专属技能图标（换人/翻面后跟随刷新）
	# 技能说明改走自绘悬停提示（_build_hover_tips 像素框）；原生 tooltip_text 灰框不合语言已弃（2026-07-11）。
	for btn in [btn_charge, btn_attack, btn_big_attack, btn_defend, btn_big_defend]:
		btn.visible = true
	btn_confirm.visible = true


## 出战英雄是否有占行动主动技，或不占行动的主动强化。
func _player_has_active() -> bool:
	var sk: HeroSkill = battle.get_skill(PLAYER, battle.active_index[PLAYER])
	return sk != null and (sk.has_active() or sk.enables_blood_payment())


## 技能钮图标 = 出战英雄专属技能图标（h*_skill.png·2026-07-17 Eddy 点单）；无图回退「技能」二字。
func _refresh_special_icon() -> void:
	if _special_icon == null:
		_special_icon = TextureRect.new()
		_special_icon.name = "SkillIcon"
		_special_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_special_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_special_icon.offset_left = 18.0
		_special_icon.offset_top = 16.0
		_special_icon.offset_right = -18.0
		_special_icon.offset_bottom = -20.0
		_special_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # 小尺寸 TextureRect 必 IGNORE_SIZE
		_special_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_special_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn_special.add_child(_special_icon)
	var h: HeroData = battle.heroes[PLAYER][battle.active_index[PLAYER]]
	var icon_path: String = h.skill_icon_path
	if String(_special_icon.get_meta("icon_path", "")) == icon_path:
		return   # 同图跳过（affordance 每刷都会经过这里·防重复 load）
	_special_icon.set_meta("icon_path", icon_path)
	if icon_path != "" and ResourceLoader.exists(icon_path):
		_special_icon.texture = load(icon_path)
		_special_icon.visible = true
		btn_special.text = ""
	else:
		_special_icon.texture = null
		_special_icon.visible = false
		btn_special.text = tr("技能")


func _reset_button_styles() -> void:
	for btn in action_btn_list:
		_set_btn_selected(btn, false)
	_set_confirm_active(false)
	_disarm_switch()   # 退出 armed「切换」态（换人选中随之消失）
	_clear_enemy_targets()   # 退出 h21 敌方目标选择态


## 为果冻按钮复制同一轮廓作为深色下投影；没有果冻 Bg 的按钮使用同尺寸圆角面。
## 阴影位于按钮内部树序最底且 mouse_filter=IGNORE，不改变原点击、hover、disabled 行为。
func _attach_button_bottom_shadow(btn: Button) -> void:
	if btn == null or btn.get_node_or_null("BottomShadow") != null:
		return

	var source_bg := btn.get_node_or_null("Bg") as ColorRect
	var shadow: Control
	if source_bg != null and source_bg.material is ShaderMaterial:
		var shadow_rect := ColorRect.new()
		shadow_rect.color = Color.WHITE
		var material := (source_bg.material as ShaderMaterial).duplicate() as ShaderMaterial
		var opaque_shadow := Color(
				UI_BOTTOM_SHADOW_COLOR.r,
				UI_BOTTOM_SHADOW_COLOR.g,
				UI_BOTTOM_SHADOW_COLOR.b,
				1.0)
		for parameter in ["fill_top", "fill_bottom", "edge_inner", "edge_outer"]:
			material.set_shader_parameter(parameter, opaque_shadow)
		material.set_shader_parameter("fill_alpha", 1.0)
		material.set_shader_parameter("noise_amt", 0.0)
		material.set_shader_parameter("wear", 0.0)
		shadow_rect.material = material
		shadow = shadow_rect
	else:
		var shadow_panel := Panel.new()
		var box := StyleBoxFlat.new()
		box.bg_color = Color(
				UI_BOTTOM_SHADOW_COLOR.r,
				UI_BOTTOM_SHADOW_COLOR.g,
				UI_BOTTOM_SHADOW_COLOR.b,
				1.0)
		box.set_corner_radius_all(10)
		shadow_panel.add_theme_stylebox_override("panel", box)
		shadow = shadow_panel

	shadow.name = "BottomShadow"
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.show_behind_parent = true
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shadow.offset_left = UI_BOTTOM_SHADOW_OFFSET.x
	shadow.offset_top = UI_BOTTOM_SHADOW_OFFSET.y
	shadow.offset_right = UI_BOTTOM_SHADOW_OFFSET.x
	shadow.offset_bottom = UI_BOTTOM_SHADOW_OFFSET.y
	shadow.self_modulate = Color(1.0, 1.0, 1.0, UI_BOTTOM_SHADOW_COLOR.a)
	btn.add_child(shadow)
	btn.move_child(shadow, 0)


## 给按钮挂 ButtonJuice 交互手感组件（幂等：已挂则跳过）。
func _attach_button_juice(btn: BaseButton) -> void:
	if btn.get_node_or_null("ButtonJuice") == null:
		var bj := ButtonJuice.new()
		bj.name = "ButtonJuice"
		btn.add_child(bj)


## 选中态视觉：果冻底常显，选中按钮整体提亮 + 从中心放大（缩放手感交给 ButtonJuice 弹性处理）。
## （不再用不透明 StyleBox 盖住果冻 —— 那正是"点击后变回老版"的根因）。
func _set_btn_selected(btn: Button, on: bool) -> void:
	# B「典籍朱印」：羊皮按钮选中态镀金箔 —— 暖金提亮 modulate，呼应金箔高亮语言（源自原技能卡体系·卡已退役）。
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
	var preview: BattleCore = _battle_after_selected_items()
	if not preview.has_lianhuan_gu_queued(PLAYER):
		selected_second_action = -1
		_second_enemy_target_pick = -1
		_second_action_btn = null
	_layout_circles()
	for btn in action_btn_list:
		if not btn.visible:
			continue
		if btn == btn_special:
			btn.disabled = not preview.has_blood_payment(PLAYER) \
				and not preview.can_use_active(PLAYER, _blood_payment_armed) \
				and not preview.can_use_active(PLAYER, _blood_payment_armed, true)
		else:
			var act: int = _btn_action(btn)
			var normally_available: bool = preview.can_pay_action_with_blood(PLAYER, act) \
				if _blood_payment_armed else preview.can_afford(PLAYER, act)
			btn.disabled = not normally_available and not preview.can_use_energy_cap_discount(
				PLAYER, act, false, _blood_payment_armed)
	# 技能键能量消耗随出战英雄主动技动态变化（0 不显示）。
	_refresh_action_modifiers()
	_refresh_action_cost_badges()
	btn_confirm.disabled = false


## 上方技能 icon 是「波」的额外强化层；再次点击可撤销，退回普通波。
func _on_longyuji_branch_pressed() -> void:
	if state != State.PLAYER_SELECT:
		return
	if selected_action != A.ATTACK or selected_btn != btn_attack:
		return
	var preview: BattleCore = _battle_after_selected_items()
	var empower: bool = not _empowered_wave_armed
	if empower and not preview.can_empower_wave_action(
			PLAYER, selected_action, _blood_payment_armed, _energy_cap_discount_armed):
		return
	_empowered_wave_armed = empower
	_split_big_wave_armed = false
	_refresh_action_affordance()


## 暗潮使用「大波」上方的技能 icon 分支；再次点击可撤销，退回普通大波。
func _on_split_big_wave_pressed() -> void:
	if state != State.PLAYER_SELECT:
		return
	var preview: BattleCore = _battle_after_selected_items()
	if not preview.can_split_big_wave_action(
			PLAYER, selected_action, _blood_payment_armed, _energy_cap_discount_armed):
		return
	_split_big_wave_armed = not _split_big_wave_armed
	_empowered_wave_armed = false
	_refresh_action_modifiers()


func _selected_action_can_pay(blood_payment: bool, energy_cap_discount: bool) -> bool:
	var preview: BattleCore = _battle_after_selected_items()
	if selected_action == ACTIVE:
		return preview.can_use_active(PLAYER, blood_payment, energy_cap_discount)
	if selected_action < 0 or selected_action == A.SWITCH:
		return true
	if _empowered_wave_armed:
		return preview.can_empower_wave_action(
			PLAYER, selected_action, blood_payment, energy_cap_discount)
	if _split_big_wave_armed:
		return preview.can_split_big_wave_action(
			PLAYER, selected_action, blood_payment, energy_cap_discount)
	if energy_cap_discount:
		return preview.can_use_energy_cap_discount(
			PLAYER, selected_action, false, blood_payment)
	return preview.can_pay_action_with_blood(PLAYER, selected_action) \
		if blood_payment else preview.can_afford(PLAYER, selected_action)


func _current_action_can_pay_without_h24() -> bool:
	return _selected_action_can_pay(_blood_payment_armed, false)


func _on_h24_discount_pressed() -> void:
	if state != State.PLAYER_SELECT or selected_action < 0:
		return
	if _energy_cap_discount_armed:
		# 若当前行动只有借助并封才付得起，则不能留下一个必定回退为「攒」的无效提交。
		if not _current_action_can_pay_without_h24():
			return
		_energy_cap_discount_armed = false
	elif _battle_after_selected_items().can_use_energy_cap_discount(
			PLAYER, selected_action, _empowered_wave_armed, _blood_payment_armed):
		_energy_cap_discount_armed = true
	_refresh_action_affordance()


func _refresh_action_modifiers() -> void:
	_refresh_longyuji()
	_refresh_h24_discount()
	_set_btn_selected(btn_special, _blood_payment_armed and battle.has_blood_payment(PLAYER))


## 刷新攻击变体：龙御极位于「波」上方，暗潮位于「大波」上方。
func _refresh_longyuji() -> void:
	if longyuji_picker == null or split_big_wave_picker == null or btn_split_big_wave == null:
		return
	var preview: BattleCore = _battle_after_selected_items()
	var has_empowered: bool = preview.has_empowered_wave(PLAYER)
	var has_split: bool = preview.has_split_big_wave(PLAYER)
	if not has_empowered:
		_empowered_wave_armed = false
	elif _empowered_wave_armed and not preview.can_empower_wave_action(
			PLAYER, selected_action, _blood_payment_armed, _energy_cap_discount_armed):
		_empowered_wave_armed = false
	_set_btn_selected(btn_attack, selected_btn == btn_attack)
	var show_picker: bool = state == State.PLAYER_SELECT and has_empowered \
		and selected_action == A.ATTACK and selected_btn == btn_attack
	longyuji_picker.visible = show_picker
	if show_picker:
		longyuji_picker.position = Vector2(
			btn_attack.position.x + (btn_attack.size.x - longyuji_picker.size.x) * 0.5,
			btn_attack.position.y - longyuji_picker.size.y - 14.0)
		btn_longyuji_branch.disabled = not preview.can_empower_wave_action(
			PLAYER, selected_action, _blood_payment_armed, _energy_cap_discount_armed)
		_set_btn_selected(btn_longyuji_branch, _empowered_wave_armed)
		if btn_longyuji_branch.disabled:
			btn_longyuji_branch.modulate = Color(0.52, 0.50, 0.47)

	if not has_split:
		_split_big_wave_armed = false
	var show_split_picker: bool = state == State.PLAYER_SELECT and has_split \
		and selected_action == A.BIG_ATTACK and selected_btn == btn_big_attack
	split_big_wave_picker.visible = show_split_picker
	if show_split_picker:
		split_big_wave_picker.position = Vector2(
			btn_big_attack.position.x + (btn_big_attack.size.x - split_big_wave_picker.size.x) * 0.5,
			btn_big_attack.position.y - split_big_wave_picker.size.y - 14.0)
		var can_split: bool = preview.can_split_big_wave_action(
			PLAYER, selected_action, _blood_payment_armed, _energy_cap_discount_armed)
		if not can_split:
			_split_big_wave_armed = false
		btn_split_big_wave.disabled = not can_split
		_set_btn_selected(btn_split_big_wave, _split_big_wave_armed)


func _refresh_h24_discount() -> void:
	if h24_discount_picker == null or btn_h24_discount == null:
		return
	var preview: BattleCore = _battle_after_selected_items()
	var can_discount: bool = selected_action >= 0 and preview.can_use_energy_cap_discount(
		PLAYER, selected_action, _empowered_wave_armed, _blood_payment_armed)
	if not can_discount:
		_energy_cap_discount_armed = false
	var show_picker: bool = state == State.PLAYER_SELECT and selected_btn != null and can_discount
	h24_discount_picker.visible = show_picker
	if not show_picker:
		return
	var stack_offset := 0.0
	if selected_btn == btn_attack and longyuji_picker != null and longyuji_picker.visible:
		stack_offset = longyuji_picker.size.y + 14.0
	elif selected_btn == btn_big_attack and split_big_wave_picker != null \
			and split_big_wave_picker.visible:
		stack_offset = split_big_wave_picker.size.y + 14.0
	h24_discount_picker.position = Vector2(
		selected_btn.position.x + (selected_btn.size.x - h24_discount_picker.size.x) * 0.5,
		selected_btn.position.y - h24_discount_picker.size.y - 14.0 - stack_offset)
	btn_h24_discount.disabled = false
	_set_btn_selected(btn_h24_discount, _energy_cap_discount_armed)
func _btn_action(btn: Button) -> int:
	if btn == btn_charge: return A.CHARGE
	if btn == btn_attack: return A.ATTACK
	if btn == btn_big_attack: return A.BIG_ATTACK
	if btn == btn_defend: return A.DEFEND
	if btn == btn_big_defend: return A.BIG_DEFEND
	return -1


## 填入动作按钮的能量消耗 = 一个金币 + 内嵌数字（= bp 血量同款 IconBadge）。
## CostPips 节点已在 battle_screen_base.tscn 内预置（编辑器可视化摆位/调大小·统一以 BtnAttack 为准），
## 代码只填数字·不再创建/定位。show_zero=0 费也显示（防按钮·Eddy 2026-07-13：与其他按钮一致）。
func _set_cost_pips(btn: Button, cost: int, show_zero: bool = false) -> void:
	var badge := btn.get_node_or_null("CostPips") as IconBadge
	if badge == null:
		return
	badge.visible = cost > 0 or show_zero
	if badge.visible:
		var pay_with_hp: bool = _blood_payment_armed and cost > 0
		if pay_with_hp:
			badge.set_icon(HEART_COST_SHEET, 4, 1, 0)
		else:
			badge.set_icon(ENERGY_COST_SHEET, 4, 4, 0)
		badge.set_number(int(round(cost / float(ActionDef.ENERGY_UNIT))))   # cost 为半能 → 显示整能


func _refresh_action_cost_badges() -> void:
	# 「波」按钮始终标基础 1 能；龙御极分支另标额外 1 能，避免同一费用被重复显示为“2 + 1”。
	var attack_cost: int = int(ActionDef.BASE_ACTION_DEF[A.ATTACK]["cost"])
	var big_attack_cost: int = int(ActionDef.BASE_ACTION_DEF[A.BIG_ATTACK]["cost"])
	var big_defend_cost: int = int(ActionDef.BASE_ACTION_DEF[A.BIG_DEFEND]["cost"])
	var active_cost: int = battle.action_cost(PLAYER, ACTIVE)
	if _energy_cap_discount_armed:
		match selected_action:
			A.ATTACK:
				attack_cost = maxi(0, attack_cost - BattleCore.ENERGY_CAP_DISCOUNT_AMOUNT)
			A.BIG_ATTACK:
				big_attack_cost = maxi(0, big_attack_cost - BattleCore.ENERGY_CAP_DISCOUNT_AMOUNT)
			A.BIG_DEFEND:
				big_defend_cost = maxi(0, big_defend_cost - BattleCore.ENERGY_CAP_DISCOUNT_AMOUNT)
			ACTIVE:
				active_cost = maxi(0, active_cost - BattleCore.ENERGY_CAP_DISCOUNT_AMOUNT)
	_set_cost_pips(btn_attack, attack_cost,
		_energy_cap_discount_armed and selected_action == A.ATTACK)
	if btn_longyuji_branch != null:
		_set_cost_pips(btn_longyuji_branch, BattleCore.EMPOWERED_WAVE_COST)
	_set_cost_pips(btn_big_attack, big_attack_cost)
	_set_cost_pips(btn_big_defend, big_defend_cost)
	_set_cost_pips(btn_defend, ActionDef.BASE_ACTION_DEF[A.DEFEND]["cost"], true)
	_set_cost_pips(btn_special, active_cost,
		_energy_cap_discount_armed and selected_action == ACTIVE)


# ============================================================
# 刷新显示
# ============================================================

## M2：在各玩家 HUD 下挂道具栏（程序化占位·位置由 ITEM_ROW_POS_* 控制）。
func _build_item_rows() -> void:
	p1_item_row = ItemSlotRow.new()
	p1_item_row.position = ITEM_ROW_POS_P1
	p1_item_row.scale = Vector2.ONE * ITEM_ROW_SCALE
	p1_item_row.bottom_shadow_enabled = true
	p1_item_row.interactive = true   # M3：本地玩家行可点击
	p1_item_row.slot_clicked.connect(_on_p1_slot_clicked)
	p1_item_row.slot_upgrade_clicked.connect(_on_p1_slot_upgrade)   # C：升级角标
	p1_hud.add_child(p1_item_row)
	p2_item_row = ItemSlotRow.new()   # P2 = AI·道具-blind（ADR D9）→ 仅显示
	p2_item_row.scale = Vector2.ONE * ITEM_ROW_SCALE
	p2_item_row.bottom_shadow_enabled = true
	# 右贴镜像 P1：P2 右内边距 = P1 左内边距(28) → 与右侧 P2 框组对齐(修敌方道具行偏左)。
	# 镜像宽度按缩放后的实显宽算（否则 P2 行会向内缩进一截）。
	var row_w := (ItemSlotRow.SLOT_W * 3.0 + ItemSlotRow.GAP * 2.0) * ITEM_ROW_SCALE
	p2_item_row.position = Vector2(SCREEN_W - ITEM_ROW_POS_P1.x - row_w, ITEM_ROW_POS_P1.y)
	p2_item_row.slot_clicked.connect(_on_p2_item_target_clicked)
	p2_hud.add_child(p2_item_row)


# ============================================================
# 悬停提示（2026-07-11 Eddy 点单·外部 UI 件到位前的程序化像素框版）
# ============================================================

enum TipFormat { S, L }
enum TipContentKind { PLAIN, SKILL, ITEM, AVATAR_SKILL }

@export_group("悬停说明框")
@export var tip_size_s := Vector2(320.0, 96.0)    # 基础动作、技能分支
@export var tip_size_l := Vector2(480.0, 144.0)   # 主动技能、技能说明、道具说明
@export var tip_size_item := Vector2(222.0, 128.0)   # 具名道具：紧凑标题行 + 最多三行正文
@export var tip_size_avatar_skill := Vector2(340.0, 116.0)   # 去掉标题后收短高度：技能图标 + 单段说明
@export_range(0.5, 2.0, 0.01) var tip_texture_brightness := 1.28
@export_subgroup("字距")
@export_range(-4, 8, 1) var tip_glyph_spacing: int = 0
@export_subgroup("S 框文字与留白")
@export_range(8, 32, 1) var tip_font_size_s: int = 17
@export_range(-4, 12, 1) var tip_line_spacing_s: int = 1
@export_range(0.0, 32.0, 1.0) var tip_padding_horizontal_s := 12.0
@export_range(0.0, 32.0, 1.0) var tip_padding_vertical_s := 8.0
@export_subgroup("L 框文字与留白")
@export_range(8, 32, 1) var tip_font_size_l: int = 16
@export_range(-4, 12, 1) var tip_line_spacing_l: int = 1
@export_range(0.0, 32.0, 1.0) var tip_padding_horizontal_l := 12.0
@export_range(0.0, 32.0, 1.0) var tip_padding_vertical_l := 8.0
@export_subgroup("分框视觉轴")
## 正值向右；每类提示独立保存，禁止再用一个全局值同时推动 S/L。
@export_range(-8.0, 8.0, 1.0) var tip_optical_center_shift_s := 0.0
@export_range(-8.0, 8.0, 1.0) var tip_optical_center_shift_l := 0.0
@export_range(-8.0, 8.0, 1.0) var tip_optical_center_shift_item := 3.0
@export_range(-8.0, 8.0, 1.0) var tip_optical_center_shift_avatar_skill := 0.0
@export_subgroup("道具说明排版")
## 正值越大，道具名称与正文组成的整块越向上移动；常规布局保持 0。
@export_range(0.0, 12.0, 1.0) var item_tip_vertical_lift := 0.0
## 名称行与正文的真实像素间距；默认只留一个短呼吸位。
@export_range(1, 64, 1) var item_tip_title_body_gap: int = 8
const ITEM_TIP_ICON_SIZE := 32.0
const ITEM_TIP_ICON_TITLE_GAP := 6.0
const ITEM_TIP_COLUMN_INSET := 8.0
const ITEM_TIP_BASE_TOP := 2.0
@export_group("")

const TIP_GAP := 12.0                # 提示框与目标控件的间距(px)
const AVATAR_SKILL_TIP_EXTRA_DROP := 30.0   # 越过替补头像下方 28px 血量行
const TIP_ATOMIC_TERMS: Array[String] = [
	"0.5点", "1点", "2点", "3点", "4点", "大波", "大防", "能量", "生命", "护盾",
	"伤害", "回合", "出战", "英雄", "敌方", "我方",
]

var _tip_panel: PanelContainer
var _tip_content: Control
var _tip_label: Label
var _tip_rich: RichTextLabel
var _tip_skill_icon: TextureRect
var _tip_item_header: Control
var _tip_item_icon: TextureRect
var _tip_item_title: Label
var _tip_stylebox: StyleBoxTexture


## 建悬停提示（中性书页像素框 9-slice）+ 挂满底部动作按钮与我方道具槽。
## 动作/道具数值全部从 ActionDef / BattleCore 常量推导（禁硬编码游戏数值）。
func _build_hover_tips() -> void:
	_tip_panel = PanelContainer.new()
	_tip_panel.name = "HoverTip"
	_tip_stylebox = StyleBoxTexture.new()
	_tip_stylebox.texture = preload("res://assets/ui/ui_tooltip_book_pixel.png")   # 192×57·黑色角套+低对比书页纹理
	_tip_stylebox.modulate_color = Color(
		tip_texture_brightness,
		tip_texture_brightness,
		tip_texture_brightness,
		1.0
	)
	_tip_stylebox.set_texture_margin_all(20.0)                          # 9-slice：保留像素切角、实心角套与投影
	# 中央纸面直接拉伸，避免纹理在宽/高方向周期性平铺成明显点阵；20px 九宫格仍锁定边框与四角。
	_tip_stylebox.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	_tip_stylebox.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	_set_tip_content_margins(TipFormat.S, TipContentKind.PLAIN)
	_tip_panel.add_theme_stylebox_override("panel", _tip_stylebox)
	_tip_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 像素贴图必须点采样（默认线性会糊）
	_tip_panel.visible = false
	_tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.clip_contents = true
	_tip_panel.z_index = 90
	_tip_content = Control.new()
	_tip_content.name = "Content"
	_tip_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_content.clip_contents = true
	_tip_panel.add_child(_tip_content)
	_tip_label = Label.new()
	_tip_label.name = "Text"
	_tip_label.add_theme_font_override("font", _make_tip_font(tip_font_size_s))
	_tip_label.add_theme_font_size_override("font_size", tip_font_size_s)
	_tip_label.add_theme_constant_override("line_spacing", tip_line_spacing_s)
	_tip_label.add_theme_color_override("font_color", Color(0.24, 0.19, 0.12))   # 墨字压纸面（描边退役——亮底不需要）
	_tip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.clip_text = true
	_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_content.add_child(_tip_label)
	_tip_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tip_skill_icon = TextureRect.new()
	_tip_skill_icon.name = "SkillIcon"
	_tip_skill_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tip_skill_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tip_skill_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tip_skill_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_skill_icon.visible = false
	_tip_content.add_child(_tip_skill_icon)
	_tip_skill_icon.anchor_top = 0.5
	_tip_skill_icon.anchor_bottom = 0.5
	_tip_skill_icon.offset_left = 0.0
	_tip_skill_icon.offset_top = -32.0
	_tip_skill_icon.offset_right = 64.0
	_tip_skill_icon.offset_bottom = 32.0
	_build_item_tip_header()
	_tip_rich = RichTextLabel.new()
	_tip_rich.name = "RichText"
	_tip_rich.add_theme_font_override("normal_font", _make_tip_font(tip_font_size_l))
	_tip_rich.add_theme_font_size_override("normal_font_size", tip_font_size_l)
	_tip_rich.add_theme_constant_override("line_separation", tip_line_spacing_l)
	_tip_rich.add_theme_color_override("default_color", Color(0.24, 0.19, 0.12))
	_tip_rich.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_tip_rich.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_tip_rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_rich.fit_content = false
	_tip_rich.scroll_active = false
	_tip_rich.selection_enabled = false
	_tip_rich.context_menu_enabled = false
	_tip_rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_rich.visible = false
	_tip_content.add_child(_tip_rich)
	_tip_rich.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_tip_panel)
	_register_tip(btn_charge, _action_tip.bind(A.CHARGE), TipFormat.S, true)
	_register_tip(btn_attack, _action_tip.bind(A.ATTACK), TipFormat.S, true)
	_register_tip(btn_big_attack, _action_tip.bind(A.BIG_ATTACK), TipFormat.S, true)
	_register_tip(btn_defend, _action_tip.bind(A.DEFEND), TipFormat.S, true)
	_register_tip(btn_big_defend, _action_tip.bind(A.BIG_DEFEND), TipFormat.S, true)
	_register_tip(btn_special, _special_tip, TipFormat.L, false, TipContentKind.SKILL)
	_register_tip(btn_longyuji_branch, _longyuji_tip, TipFormat.L, false,
		TipContentKind.SKILL)
	_register_tip(btn_split_big_wave, _split_big_wave_tip, TipFormat.L, false,
		TipContentKind.SKILL)
	_register_tip(btn_h24_discount, _h24_discount_tip, TipFormat.L, false,
		TipContentKind.SKILL)
	p1_item_row.slot_hovered.connect(_on_item_slot_hovered)
	p1_item_row.slot_unhovered.connect(_hide_tip)
	# 敌方道具同享悬停查看（2026-07-17 Eddy）：只读提示·无点击 CTA（hoverable 不解锁点击）。
	p2_item_row.hoverable = true
	p2_item_row.slot_hovered.connect(_on_item_slot_hovered_p2)
	p2_item_row.slot_unhovered.connect(_hide_tip)


## 具名道具说明的独立顶部行：原尺寸像素图标 + 名称，不再缩放正式道具框。
## 正文仍由 RichTextLabel 承担，因此换行规则与原子词保护逻辑保持不变。
func _build_item_tip_header() -> void:
	_tip_item_header = Control.new()
	_tip_item_header.name = "ItemHeader"
	_tip_item_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_item_header.visible = false
	_tip_content.add_child(_tip_item_header)
	_tip_item_header.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_tip_item_header.size = Vector2.ZERO

	_tip_item_icon = TextureRect.new()
	_tip_item_icon.name = "ItemIcon"
	_tip_item_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tip_item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tip_item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tip_item_icon.position = Vector2.ZERO
	_tip_item_icon.size = Vector2.ONE * ITEM_TIP_ICON_SIZE
	_tip_item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_item_header.add_child(_tip_item_icon)

	_tip_item_title = Label.new()
	_tip_item_title.name = "ItemTitle"
	_tip_item_title.anchor_right = 1.0
	_tip_item_title.offset_left = ITEM_TIP_ICON_SIZE + ITEM_TIP_ICON_TITLE_GAP
	_tip_item_title.offset_right = 0.0
	_tip_item_title.offset_bottom = ITEM_TIP_ICON_SIZE
	_tip_item_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tip_item_title.clip_text = true
	_tip_item_title.add_theme_font_override("font", _make_tip_font(tip_font_size_l + 1))
	_tip_item_title.add_theme_font_size_override("font_size", tip_font_size_l + 1)
	_tip_item_title.add_theme_color_override("font_color", Color(0.22, 0.16, 0.10))
	_tip_item_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_item_header.add_child(_tip_item_title)


func _register_tip(c: Control, provider: Callable, format: int, centered: bool = false,
		content_kind: int = TipContentKind.PLAIN) -> void:
	c.mouse_entered.connect(_on_tip_enter.bind(c, provider, format, centered, content_kind))
	c.mouse_exited.connect(_hide_tip)


func _on_tip_enter(c: Control, provider: Callable, format: int, centered: bool = false,
		content_kind: int = TipContentKind.PLAIN) -> void:
	_show_tip_at(c.get_global_rect(), str(provider.call()), format, centered, content_kind)


## 取消左下技能翻页钮后，六个头像框直接承担各自的技能说明入口。
## 悬停只读，不改变己方头像现有点击换人/道具选人语义。
func _connect_hero_skill_tips() -> void:
	for frame_idx: int in range(p1_frames.size()):
		p1_frames[frame_idx].mouse_entered.connect(
			_on_hero_skill_tip.bind(PLAYER, frame_idx))
		p1_frames[frame_idx].mouse_exited.connect(_hide_tip)
	for frame_idx: int in range(p2_frames.size()):
		p2_frames[frame_idx].mouse_entered.connect(
			_on_hero_skill_tip.bind(AI, frame_idx))
		p2_frames[frame_idx].mouse_exited.connect(_hide_tip)


func _on_hero_skill_tip(player: int, frame_idx: int) -> void:
	if battle == null:
		return
	var frame_slots: Array[int] = p1_frame_slots if player == PLAYER else p2_frame_slots
	var frames: Array[HeroFrame] = p1_frames if player == PLAYER else p2_frames
	if frame_idx < 0 or frame_idx >= frame_slots.size() or frame_idx >= frames.size():
		return
	var slot: int = frame_slots[frame_idx]
	if slot < 0 or slot >= battle.heroes[player].size():
		return
	var hero: HeroData = battle.heroes[player][slot]
	if hero == null:
		return
	var detail: String = tr(hero.skill_detail)
	# 头像说明只保留效果正文；旧 skill_description 是技能名，不再占据顶部一行。
	var text: String = detail
	if text == "":
		text = tr("暂无技能说明")
	var icon: Texture2D = null
	if hero.skill_icon_path != "" and ResourceLoader.exists(hero.skill_icon_path):
		icon = load(hero.skill_icon_path) as Texture2D
	_show_tip_at(frames[frame_idx].get_global_rect(), text, TipFormat.L, true,
		TipContentKind.AVATAR_SKILL, icon)


func _on_item_slot_hovered(slot: int) -> void:
	var sc: Vector2 = p1_item_row.scale
	var base: Vector2 = p1_item_row.global_position \
		+ Vector2(slot * (ItemSlotRow.SLOT_W + ItemSlotRow.GAP) * sc.x, 0.0)
	_show_tip_at(Rect2(base, Vector2(ItemSlotRow.SLOT_W * sc.x, ItemSlotRow.SLOT_H * sc.y)),
		_item_slot_tip(slot), TipFormat.L, false, TipContentKind.ITEM, null,
		_item_slot_tip_data(slot, PLAYER))


## 敌方道具悬停：槽矩形始终按道具行的实际缩放计算。
func _on_item_slot_hovered_p2(slot: int) -> void:
	var sc: Vector2 = p2_item_row.scale
	var base: Vector2 = p2_item_row.global_position \
		+ Vector2(slot * (ItemSlotRow.SLOT_W + ItemSlotRow.GAP) * sc.x, 0.0)
	_show_tip_at(Rect2(base, Vector2(ItemSlotRow.SLOT_W * sc.x, ItemSlotRow.SLOT_H * sc.y)),
		_item_slot_tip(slot, AI), TipFormat.L, false, TipContentKind.ITEM, null,
		_item_slot_tip_data(slot, AI))


## 顶部英雄头像悬停：英雄槽状态跟随对应头像；团队级待命/控制/遗物状态只列在出战头像，
## 避免让“下一次攻击真伤”“全队禁切”或遗物次数看起来像绑定某一名替补。
func _hero_status_tip(player: int, frame_idx: int) -> String:
	var frame_slots: Array[int] = p1_frame_slots if player == PLAYER else p2_frame_slots
	if frame_idx < 0 or frame_idx >= frame_slots.size():
		return ""
	var slot: int = frame_slots[frame_idx]
	if slot < 0 or slot >= battle.heroes[player].size():
		return ""

	var lines: Array[String] = []
	var immunity_charges: int = int(battle.get_status(
		player, slot, "fatal_damage_immunity", 0))
	if immunity_charges > 0:
		lines.append(tr("还魂丹：可免疫1次致命伤害"))
	elif int(battle.get_status(player, slot, "huanhun_used", 0)) > 0:
		lines.append(tr("还魂丹：本局已使用"))

	if slot == battle.active_index[player]:
		var lock_until: int = int(battle.item_buffs[player].get("switch_lock_until_turn", -1))
		if lock_until >= battle.turn_number:
			var remaining_turns: int = lock_until - battle.turn_number + 1
			lines.append(tr("定身：切换无效（剩余%d回合）") % remaining_turns)
		var energy_lock_turn: int = int(battle.item_buffs[player].get(
			"energy_gain_lock_turn", -1))
		if energy_lock_turn == battle.turn_number:
			lines.append(tr("锁泉塞：本回合无法获得能量"))
		elif energy_lock_turn == battle.turn_number + 1:
			lines.append(tr("锁泉塞：下回合无法获得能量"))
		var return_camp_heal: int = int(battle.item_buffs[player].get(
			"return_camp_heal", 0))
		if return_camp_heal > 0:
			lines.append(tr("归营牌：下次切换时换下英雄回复%s点生命") %
				_fmt_hp(float(return_camp_heal) / 2.0))
		if bool(battle.info_distortion[player].get("hide_item_bar", false)):
			lines.append(tr("迷雾斗篷：道具栏对敌方隐藏"))
		var free_big_until: int = int(battle.item_buffs[player].get(
			"free_big_attack_until_turn", -1))
		if free_big_until == battle.turn_number:
			lines.append(tr("至臻剑意：本回合第一次「大波」不消耗能量"))
		var exhausted_turn: int = int(battle.item_buffs[player].get("exhausted_turn", -1))
		if exhausted_turn == battle.turn_number:
			lines.append(tr("赊命券：本回合无法行动"))
		elif exhausted_turn == battle.turn_number + 1:
			lines.append(tr("赊命券：下回合无法行动"))
		_append_relic_status_lines(player, lines)

	var tip := ""
	for line in lines:
		if tip != "":
			tip += "\n"
		tip += line
	return tip


## 团队级遗物只挂在实时出战头像，避免三张头像重复同一公开状态。
## 次数/回合完全读取权威 relic state；UI 不自行倒计时，也不持有第二份状态。
func _append_relic_status_lines(player: int, lines: Array[String]) -> void:
	for relic_variant in battle.relics[player]:
		var relic: Dictionary = relic_variant
		var data: ItemData = relic.get("data", null)
		if data == null or data.tier != 3:
			continue
		var state: Dictionary = relic.get("state", {})
		var charges: int = maxi(int(state.get("charges", 0)), 0)
		var remaining_turns: int = maxi(int(state.get("remaining_turns", 0)), 0)
		match data.item_id:
			"t3_budongmingwang":
				lines.append(tr("不动明王甲：剩余%d次防御转甲") % charges)
			"t3_hedinghong":
				lines.append(tr("鹤顶红：下次毒爆每层+1伤害（剩余%d次）") % charges)
			"t3_judingsanhua":
				lines.append(tr("聚鼎三花：剩余%d次攻击附效") % charges)
			"t3_jubao_pen":
				lines.append(tr("聚宝盆：每回合结束时为空槽补入普通道具"))
			"t3_morihuozhong":
				if battle.alive_count(player) == 1:
					lines.append(tr("末日火种：残局攻击与防御强化已生效"))
				else:
					lines.append(tr("末日火种：等待我方仅剩1名英雄"))
			"t3_qingyuanbaolian":
				lines.append(tr("青元宝莲：剩余%d回合获得能量") % remaining_turns)
			"t3_shixinding":
				lines.append(tr("噬心钉：本回合必须攻击，否则失去3点生命"))
			"t3_xumingxiang":
				lines.append(tr("续命香：剩余%d回合回复生命") % remaining_turns)
			"t3_yemingzhu":
				lines.append(tr("夜明珠：剩余%d次切换触发") % charges)


## 目标矩形上方居中放提示；上方放不下（道具行在屏幕上部）→ 落到下方。
func _show_tip_at(target: Rect2, text: String, format: int, centered: bool = false,
		content_kind: int = TipContentKind.PLAIN, skill_icon: Texture2D = null,
		item_data: ItemData = null) -> void:
	if text == "":
		_hide_tip()
		return
	var is_avatar_skill := content_kind == TipContentKind.AVATAR_SKILL
	var is_named_item := content_kind == TipContentKind.ITEM and item_data != null
	var tip_size: Vector2 = tip_size_avatar_skill if is_avatar_skill else (
		tip_size_item if is_named_item else (tip_size_s if format == TipFormat.S else tip_size_l))
	_set_tip_content_margins(format, content_kind)
	var is_short := format == TipFormat.S
	_tip_label.visible = is_short
	_tip_rich.visible = not is_short
	_tip_skill_icon.texture = skill_icon
	_tip_skill_icon.visible = is_avatar_skill and skill_icon != null
	_tip_item_header.visible = false
	_tip_rich.offset_left = 76.0 if _tip_skill_icon.visible else 0.0
	_tip_rich.offset_top = 0.0
	_tip_rich.offset_right = 0.0
	_tip_rich.offset_bottom = 0.0
	if is_short:
		_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered \
			else HORIZONTAL_ALIGNMENT_LEFT
		_tip_label.text = _keep_tip_terms_together(text)
	elif is_avatar_skill:
		_set_avatar_skill_tip_text(text)
	else:
		_set_l_tip_text(text, content_kind, item_data)
	# PanelContainer 只直接管理零最小尺寸的中间层，文字自身不会再把固定框撑大。
	_tip_panel.custom_minimum_size = Vector2.ZERO
	_tip_panel.size = tip_size
	var sz: Vector2 = tip_size
	var x: float = clampf(target.position.x + target.size.x * 0.5 - sz.x * 0.5, 8.0, SCREEN_W - sz.x - 8.0)
	# 目标在上半屏（道具行）→ 提示放下方（防压顶部头像/血行）；下半屏（底部按钮）→ 放上方。
	var y: float = target.end.y + TIP_GAP if target.get_center().y < SCREEN_H * 0.4 \
		else target.position.y - sz.y - TIP_GAP
	if is_avatar_skill and target.get_center().y < SCREEN_H * 0.4:
		y += AVATAR_SKILL_TIP_EXTRA_DROP
	if y < 8.0 or y + sz.y > SCREEN_H - 8.0:
		y = clampf(y, 8.0, SCREEN_H - sz.y - 8.0)
	_tip_panel.global_position = Vector2(x, y)
	_tip_panel.visible = true


## 头像技能说明使用独立的「图标 + 文案」布局，不与道具文本解析共用状态。
func _set_avatar_skill_tip_text(text: String) -> void:
	_tip_rich.clear()
	_tip_rich.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tip_rich.push_paragraph(HORIZONTAL_ALIGNMENT_LEFT)
	_tip_rich.push_font_size(tip_font_size_l)
	_tip_rich.push_color(Color(0.27, 0.21, 0.14))
	_tip_rich.add_text(_keep_tip_terms_together(text.strip_edges()))
	_tip_rich.pop_all()


func _make_tip_font(font_size: int) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = FontManager._best_font(font_size)
	variation.spacing_glyph = tip_glyph_spacing
	return variation


func _tip_optical_center_shift(format: int, content_kind: int) -> float:
	match content_kind:
		TipContentKind.ITEM:
			return tip_optical_center_shift_item
		TipContentKind.AVATAR_SKILL:
			return tip_optical_center_shift_avatar_skill
	return tip_optical_center_shift_s if format == TipFormat.S \
		else tip_optical_center_shift_l


func _set_tip_content_margins(format: int,
		content_kind: int = TipContentKind.PLAIN) -> void:
	var horizontal := tip_padding_horizontal_s if format == TipFormat.S \
		else tip_padding_horizontal_l
	var vertical := tip_padding_vertical_s if format == TipFormat.S \
		else tip_padding_vertical_l
	var optical_shift := _tip_optical_center_shift(format, content_kind)
	# 回归记录：第三次对齐复发的根因是把道具 L 的 +3px 补偿错误提升为全局轴，
	# 导致原本居中的底部 S 与头像技能一起右移。只允许在此按内容类型分流。
	_tip_stylebox.content_margin_left = horizontal + optical_shift
	_tip_stylebox.content_margin_right = horizontal - optical_shift
	_tip_stylebox.content_margin_top = vertical
	_tip_stylebox.content_margin_bottom = vertical


## 具名道具使用「左上图标+紧随名称 / 下方正文」；空槽状态仍整体居中。
func _set_l_tip_text(text: String, content_kind: int, item_data: ItemData = null) -> void:
	_tip_rich.clear()
	_tip_rich.vertical_alignment = VERTICAL_ALIGNMENT_CENTER \
		if content_kind == TipContentKind.SKILL else VERTICAL_ALIGNMENT_TOP
	if content_kind != TipContentKind.ITEM:
		if content_kind == TipContentKind.SKILL:
			_tip_rich.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
		_tip_rich.push_font_size(tip_font_size_l)
		_tip_rich.push_color(Color(0.24, 0.19, 0.12))
		_tip_rich.add_text(_keep_tip_terms_together(text))
		_tip_rich.pop_all()
		return

	var title := ""
	var body_lines: Array[String] = []
	var has_named_item := text.contains("\n")
	for line_variant in text.split("\n"):
		var line := String(line_variant).strip_edges()
		if line == "":
			continue
		if has_named_item and title == "":
			title = line
		else:
			body_lines.append(line)
	# 没有「道具名 + 换行」的 ITEM 文案都是空槽/未解锁/待抽取等槽位状态：
	# 不再模仿说明段落顶端左排，而是在整张提示纸内水平+垂直居中。
	if title == "":
		_tip_item_header.visible = false
		_tip_rich.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_tip_rich.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
		_tip_rich.push_font_size(tip_font_size_l)
		_tip_rich.push_color(Color(0.27, 0.21, 0.14))
		_tip_rich.add_text(_keep_tip_terms_together(text.strip_edges()))
		_tip_rich.pop_all()
		return
	var body_text := "\n".join(body_lines)
	var group_top := ITEM_TIP_BASE_TOP - item_tip_vertical_lift
	var content_width := tip_size_item.x - tip_padding_horizontal_l * 2.0
	# 固定左右对称内容轴：不再根据每件道具的标题/正文长度改变列宽，彻底消除视觉漂移。
	var column_left := ITEM_TIP_COLUMN_INSET
	var column_width := content_width - ITEM_TIP_COLUMN_INSET * 2.0
	_configure_item_tip_header(title, item_data, group_top, content_width)
	# 正文维持左右对称内容列；顶部图标+名称则按实际组合宽度独立居中。
	_tip_rich.offset_left = column_left
	_tip_rich.offset_right = -column_left
	_tip_rich.offset_top = group_top + ITEM_TIP_ICON_SIZE + item_tip_title_body_gap
	_tip_rich.offset_bottom = 0.0
	_tip_rich.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if not body_lines.is_empty():
		_tip_rich.push_paragraph(HORIZONTAL_ALIGNMENT_LEFT)
		_tip_rich.push_font_size(tip_font_size_l)
		_tip_rich.push_color(Color(0.27, 0.21, 0.14))
		_tip_rich.add_text(_keep_tip_terms_together(body_text))
		_tip_rich.pop_all()
func _configure_item_tip_header(title: String, item_data: ItemData, top: float,
		content_width: float) -> void:
	var protected_title := _keep_tip_terms_together(title)
	_tip_item_title.text = protected_title
	_tip_item_icon.texture = ItemCatalog.load_icon(item_data.item_id) if item_data != null else null
	_tip_item_icon.visible = _tip_item_icon.texture != null
	var icon_width := ITEM_TIP_ICON_SIZE if _tip_item_icon.visible else 0.0
	var icon_gap := ITEM_TIP_ICON_TITLE_GAP if _tip_item_icon.visible else 0.0
	var title_font := _tip_item_title.get_theme_font("font")
	var title_font_size := _tip_item_title.get_theme_font_size("font_size")
	var measured_title_width := ceilf(title_font.get_string_size(
			protected_title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_font_size).x)
	var title_width := minf(measured_title_width,
			maxf(content_width - icon_width - icon_gap, 0.0))
	var group_width := icon_width + icon_gap + title_width
	var group_left := floorf((content_width - group_width) * 0.5)
	_tip_item_header.position = Vector2(group_left, top)
	_tip_item_header.size = Vector2(group_width, ITEM_TIP_ICON_SIZE)
	_tip_item_title.offset_left = icon_width + icon_gap
	_tip_item_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_tip_item_header.visible = true


## U+2060 只影响断行、不绘制；保护高频规则词，避免“能/量”“大/防”被拆到两行。
func _keep_tip_terms_together(text: String) -> String:
	var protected_text := text
	for term in TIP_ATOMIC_TERMS:
		var joined_term := ""
		for glyph in term:
			if joined_term != "":
				joined_term += "\u2060"
			joined_term += glyph
		protected_text = protected_text.replace(term, joined_term)
	return protected_text


func _hide_tip() -> void:
	if _tip_panel != null:
		_tip_panel.visible = false


## 基础动作提示只解释按钮功能；费用已由按钮角标表达，不在浮层重复。
func _action_tip(action: int) -> String:
	match action:
		A.CHARGE:
			return tr("获得1点能量")
		A.ATTACK:
			return tr("造成1点伤害")
		A.BIG_ATTACK:
			return tr("造成2点伤害")
		A.DEFEND:
			return tr("抵挡「波」")
		A.BIG_DEFEND:
			return tr("抵挡「波」、「大波」")
	return ""


## 主动技能按钮只显示功能正文；完整技能说明由技能情报按钮的 L 框承担。
func _special_tip() -> String:
	var h: HeroData = battle.active_hero(PLAYER)
	if h == null:
		return ""
	match h.hero_id:
		"h10":
			return tr("消耗全部剑气发动攻击；剑气越多，伤害与穿透越强")
		"h14":
			return tr("将本回合行动的能量消耗改为消耗生命")
		"h17":
			return tr("转变为敌方当前出战英雄")
		"h18":
			return tr("平均分配我方所有存活英雄的当前生命")
		"h21":
			return tr("指定敌方一名未出战英雄登场，替换其当前出战英雄")
		"h22":
			return tr("下一回合结束时，双方失去全部能量")
		_:
			return tr(h.skill_detail)


func _longyuji_tip() -> String:
	return tr("使「波」额外造成1点伤害")


func _split_big_wave_tip() -> String:
	return tr("将本次「大波」改为连续两次「波」")


func _h24_discount_tip() -> String:
	return tr("降低1点能量上限，使本回合行动少消耗1点能量（上限最低3点）")


## 我方道具槽提示（按槽状态）：空槽显示解锁/抽取/补充提示；
## 已有道具只显示道具名与效果，不再在说明底部重复操作 CTA 或就绪/锁定状态。
func _item_slot_tip(slot: int, p: int = PLAYER) -> String:
	var mine := p == PLAYER
	if not mine and bool(battle.info_distortion[p].get("hide_item_bar", false)):
		return tr("道具栏被迷雾遮蔽")
	var shown_battle: BattleCore = _battle_for_item_row() if mine else battle
	match shown_battle.slot_state(p, slot):
		BattleCore.SlotState.SEALED:
			return tr("第%d回合自动解锁") % (int(BattleCore.SLOT_UNLOCK_TURN[slot]) + 1)
		BattleCore.SlotState.OPENED:
			if not mine:
				return tr("待抽取道具")
			if shown_battle.can_draw_slot(p, slot):
				return tr("点击抽取道具（3选1·免费）")
			return tr("下回合可抽取道具")
		BattleCore.SlotState.CHARGING:
			var item: ItemData = shown_battle.slot_item(p, slot)
			if item == null:
				return ""
			return tr("%s\n%s") % [tr(item.item_name), tr(item.description)]
		BattleCore.SlotState.EMPTY:
			if not mine:
				return tr("空槽")
			if shown_battle.can_refill(p, slot):
				return tr("点击补充道具（3选1·消耗%s点能量）") % _fmt_hp(BattleCore.ITEM_REFILL_COST / 2.0)
			return tr("空槽（补充需%s点能量）") % _fmt_hp(BattleCore.ITEM_REFILL_COST / 2.0)
	return ""


## 与提示文字读取同一份预览战斗，保证顶部图标/阶框不会和本回合暂存后的槽状态错位。
func _item_slot_tip_data(slot: int, p: int = PLAYER) -> ItemData:
	if p != PLAYER and bool(battle.info_distortion[p].get("hide_item_bar", false)):
		return null
	var shown_battle: BattleCore = _battle_for_item_row() if p == PLAYER else battle
	if shown_battle.slot_state(p, slot) != BattleCore.SlotState.CHARGING:
		return null
	return shown_battle.slot_item(p, slot)


func _is_furnace_slot(s: int) -> bool:
	if battle == null or s < 0 or s >= battle.slots[PLAYER].size():
		return false
	var item: ItemData = battle.slot_item(PLAYER, s)
	return item != null and item.item_id == FURNACE_ITEM_ID


## 已配对关系中，以 s 为目标的来源槽；互斥规则依来源道具的 consumes/transforms 语义决定。
func _target_owner_for_slot(s: int) -> int:
	for owner_variant in selected_item_targets:
		var owner: int = int(owner_variant)
		if BattleCore.item_requires_enemy_item_slot_target(_effective_slot_item(owner)):
			continue
		if _slot_target_mode(owner) == ItemSlotTargetMode.PRESERVES:
			continue
		if int(selected_item_targets[owner_variant]) == s:
			return owner
	return -1


## 保留玩家点选顺序。带槽目标的道具只提交来源槽；熔炉燃料会被一并消耗，点金石目标会锁定一回合。
func _ordered_selected_item_slots() -> Array[int]:
	return selected_item_slots.duplicate()


## 槽目标规则只看本回合开始时真正就绪的道具。点金石产出的 T3 本回合锁定，不形成链式入口。
func _effective_slot_item(s: int) -> ItemData:
	if battle == null or s < 0 or s >= battle.slots[PLAYER].size():
		return null
	return battle.slot_item(PLAYER, s)


func _slot_target_mode(s: int) -> int:
	var item: ItemData = _effective_slot_item(s)
	if item == null:
		return ItemSlotTargetMode.NONE
	match item.item_id:
		FURNACE_ITEM_ID, DEPOSIT_ITEM_ID:
			return ItemSlotTargetMode.CONSUMES
		POINTSTONE_ITEM_ID, EXCHANGE_ITEM_ID:
			return ItemSlotTargetMode.TRANSFORMS
		INSURANCE_ITEM_ID:
			return ItemSlotTargetMode.PRESERVES
		_:
			return ItemSlotTargetMode.NONE


func _is_valid_item_slot_target(owner: int, target: int) -> bool:
	if battle == null or owner == target or target < 0 or target >= battle.slots[PLAYER].size():
		return false
	var preview: BattleCore = _battle_after_selected_items()
	if not preview.slot_ready(PLAYER, owner):
		return false
	var owner_item: ItemData = preview.slot_item(PLAYER, owner)
	var target_item: ItemData = preview.slot_item(PLAYER, target)
	if owner_item == null or target_item == null:
		return false
	if owner_item.item_id == FURNACE_ITEM_ID:
		return preview.slot_ready(PLAYER, target)
	if owner_item.item_id == DEPOSIT_ITEM_ID or owner_item.item_id == INSURANCE_ITEM_ID:
		return preview.slot_ready(PLAYER, target)
	if owner_item.item_id == POINTSTONE_ITEM_ID:
		return preview.slot_ready(PLAYER, target) and target_item.tier == 1
	if owner_item.item_id == EXCHANGE_ITEM_ID:
		return true
	return false


## 取消一个来源及其下游依赖。点金石目标若已选择使用，也一起取消，避免悄悄改回使用旧 T1。
func _remove_item_target_owner(owner: int) -> void:
	selected_item_choices.erase(owner)
	selected_item_choice_options.erase(owner)
	if not selected_item_targets.has(owner):
		selected_item_slots.erase(owner)
		return
	var target := int(selected_item_targets[owner])
	var mode: int = _slot_target_mode(owner)
	selected_item_targets.erase(owner)
	selected_item_slots.erase(owner)
	if BattleCore.item_requires_enemy_item_slot_target(_effective_slot_item(owner)):
		if _pending_enemy_item_target_slot == owner:
			_pending_enemy_item_target_slot = -1
		return
	if mode != ItemSlotTargetMode.PRESERVES:
		selected_item_slots.erase(target)
	if selected_item_targets.has(target):
		_remove_item_target_owner(target)
	if _pending_item_target_slot == owner or _pending_item_target_slot == target:
		_pending_item_target_slot = -1


## 普通点击的取消语义：变换目标只取消“使用新 T2”，保留点金石配对；燃料则拆掉熔炉整组。
func _clear_item_selection_for_slot(s: int) -> void:
	if _pending_item_hero_target_slot == s:
		_pending_item_hero_target_slot = -1
		_clear_friendly_item_target_prompts()
		return
	if selected_item_hero_targets.has(s):
		selected_item_hero_targets.erase(s)
		_clear_friendly_item_target_prompts()
	if _pending_item_target_slot == s:
		_pending_item_target_slot = -1
		return
	if selected_item_targets.has(s):
		_remove_item_target_owner(s)
		return
	var owner := _target_owner_for_slot(s)
	if owner >= 0 and _slot_target_mode(owner) == ItemSlotTargetMode.CONSUMES:
		_remove_item_target_owner(owner)
		return
	selected_item_slots.erase(s)


## 新配对的目标必须先退出旧的普通使用、旧来源目标或自身下游关系，确保一槽只属一组。
func _clear_item_selection_for_new_target(s: int, owner: int = -1) -> void:
	var preserves_target: bool = owner >= 0 \
		and _slot_target_mode(owner) == ItemSlotTargetMode.PRESERVES
	selected_item_hero_targets.erase(s)
	if selected_item_targets.has(s):
		_remove_item_target_owner(s)
	var prior_owner := _target_owner_for_slot(s)
	if prior_owner >= 0:
		_remove_item_target_owner(prior_owner)
	if not preserves_target:
		selected_item_slots.erase(s)
	if _pending_item_target_slot == s:
		_pending_item_target_slot = -1


func _clear_selected_items() -> void:
	selected_item_slots.clear()
	selected_item_targets.clear()
	selected_item_hero_targets.clear()
	selected_item_choices.clear()
	selected_item_choice_options.clear()
	_pending_item_target_slot = -1
	_pending_item_hero_target_slot = -1
	_pending_enemy_item_target_slot = -1
	_clear_friendly_item_target_prompts()
	_pending_pointstone_offer.clear()
	_refresh_enemy_targets_after_item_change()


## 道具行现有 selected 接口只有槽数组；把使用件、目标和待选来源合并后交给它高亮。
func _highlighted_item_slots() -> Array[int]:
	var highlighted: Array[int] = selected_item_slots.duplicate()
	if _pending_item_target_slot >= 0 and not highlighted.has(_pending_item_target_slot):
		highlighted.append(_pending_item_target_slot)
	if _pending_item_hero_target_slot >= 0 and not highlighted.has(_pending_item_hero_target_slot):
		highlighted.append(_pending_item_hero_target_slot)
	for target_variant in selected_item_targets.values():
		var target := int(target_variant)
		var target_owner: int = _target_owner_for_slot(target)
		if target_owner >= 0 and target >= 0 and not highlighted.has(target):
			highlighted.append(target)
	if not _pending_pointstone_offer.is_empty():
		for key in ["source", "target"]:
			var pending_slot: int = int(_pending_pointstone_offer.get(key, -1))
			if pending_slot >= 0 and not highlighted.has(pending_slot):
				highlighted.append(pending_slot)
	return highlighted


## 私有候选完成后才把道具加入本回合提交；目标是否被替换由 BattleCore 权威执行。
func _complete_item_choice(owner: int, target: int, choice: int,
		option_ids: Array = []) -> bool:
	if choice < 0 or choice >= option_ids.size():
		return false
	var item: ItemData = _effective_slot_item(owner)
	if item == null:
		return false
	if item.item_id == REPURCHASE_ITEM_ID:
		if target != -1:
			return false
	else:
		if not _is_valid_item_slot_target(owner, target):
			return false
		_clear_item_selection_for_new_target(target, owner)
		selected_item_targets[owner] = target
	selected_item_choices[owner] = choice
	selected_item_choice_options[owner] = option_ids.duplicate()
	if not selected_item_slots.has(owner):
		selected_item_slots.append(owner)
	_pending_item_target_slot = -1
	return true


## 旧定向测试与调试探针沿用的点金石入口；正式流程已泛化为道具私有候选。
func _complete_pointstone_pair(owner: int, target: int, choice: int,
		option_ids: Array = []) -> bool:
	return _complete_item_choice(owner, target, choice, option_ids)


## 就绪槽的使用点选。槽目标道具先进入待选；合法配对后才进入提交数组。
func _toggle_ready_item_selection(s: int) -> bool:
	if not battle.slot_ready(PLAYER, s):
		return false
	if _pending_enemy_item_target_slot >= 0:
		if s == _pending_enemy_item_target_slot:
			_pending_enemy_item_target_slot = -1
			return true
		_pending_enemy_item_target_slot = -1
	if _pending_item_hero_target_slot >= 0:
		if s == _pending_item_hero_target_slot:
			_pending_item_hero_target_slot = -1
			_clear_friendly_item_target_prompts()
			return true
		_pending_item_hero_target_slot = -1
		_clear_friendly_item_target_prompts()
	if _pending_item_target_slot >= 0:
		var owner := _pending_item_target_slot
		if s == owner:
			_pending_item_target_slot = -1
			return true
		if _slot_target_mode(owner) == ItemSlotTargetMode.TRANSFORMS:
			return false   # 变换目标还需私有候选选择，由槽点击入口异步完成。
		# 配对验证必须基于“目标退出旧使用/旧配对”后的棋盘；否则已选择使用的新 T2 会因 used=true
		# 被误判为不能改作熔炉燃料。非法目标则完整恢复旧选择，不制造破坏性误点。
		var previous_slots: Array[int] = selected_item_slots.duplicate()
		var previous_targets: Dictionary = selected_item_targets.duplicate()
		_clear_item_selection_for_new_target(s, owner)
		if not _is_valid_item_slot_target(owner, s):
			selected_item_slots = previous_slots
			selected_item_targets = previous_targets
			_pending_item_target_slot = owner
			return false
		_pending_item_target_slot = -1
		selected_item_targets[owner] = s
		if not selected_item_slots.has(owner):
			selected_item_slots.append(owner)
		return true

	if selected_item_slots.has(s):
		_clear_item_selection_for_slot(s)
		_refresh_enemy_targets_after_item_change()
		return true
	var target_owner := _target_owner_for_slot(s)
	if target_owner >= 0 and _slot_target_mode(target_owner) == ItemSlotTargetMode.CONSUMES:
		# 燃料再次点击：拆掉熔炉配对，再按该槽自身道具处理。
		_remove_item_target_owner(target_owner)
	elif target_owner >= 0:
		return false   # 点金石目标已变成锁定 T3，本回合不能再次选择使用。
	var mode := _slot_target_mode(s)
	if mode != ItemSlotTargetMode.NONE:
		_pending_item_target_slot = s
	elif BattleCore.item_requires_friendly_hero_target(_effective_slot_item(s)):
		_disarm_switch()
		_pending_item_hero_target_slot = s
		_refresh_friendly_item_target_prompts()
	elif BattleCore.item_requires_enemy_item_slot_target(_effective_slot_item(s)):
		_pending_enemy_item_target_slot = s
	else:
		selected_item_slots.append(s)
	_refresh_enemy_targets_after_item_change()
	return true


func _is_valid_friendly_item_target(owner: int, target: int) -> bool:
	if battle == null or owner < 0 or target < 0 or target >= battle.hp[PLAYER].size():
		return false
	if not battle.slot_ready(PLAYER, owner):
		return false
	var item: ItemData = battle.slot_item(PLAYER, owner)
	if not BattleCore.item_requires_friendly_hero_target(item):
		return false
	if BattleCore.item_requires_friendly_dead_hero_target(item):
		return battle.is_dead_reserve(PLAYER, target)
	if battle.hp[PLAYER][target] <= 0:
		return false
	if BattleCore.item_requires_friendly_reserve_target(item) \
			and target == battle.active_index[PLAYER]:
		return false
	return true


func _clear_friendly_item_target_prompts() -> void:
	for frame_idx in _item_target_prompt_frames:
		if frame_idx >= 0 and frame_idx < p1_frames.size() and p1_frames[frame_idx] != null:
			p1_frames[frame_idx].set_switch_prompt(false)
			p1_frames[frame_idx].is_selected = false
	_item_target_prompt_frames.clear()


func _refresh_friendly_item_target_prompts() -> void:
	_clear_friendly_item_target_prompts()
	if _pending_item_hero_target_slot < 0 or p1_frames.size() < 3:
		return
	for frame_idx in range(p1_frames.size()):
		var hero_slot: int = p1_frame_slots[frame_idx]
		if _is_valid_friendly_item_target(_pending_item_hero_target_slot, hero_slot):
			p1_frames[frame_idx].set_switch_prompt(true, tr("选"))
			_item_target_prompt_frames.append(frame_idx)


func _select_friendly_item_target(frame_idx: int) -> bool:
	if frame_idx < 0 or frame_idx >= p1_frame_slots.size():
		return false
	var owner: int = _pending_item_hero_target_slot
	var hero_slot: int = p1_frame_slots[frame_idx]
	if not _complete_friendly_item_target(owner, hero_slot):
		return false
	_clear_friendly_item_target_prompts()
	if frame_idx < p1_frames.size() and p1_frames[frame_idx] != null:
		p1_frames[frame_idx].is_selected = true
		_item_target_prompt_frames.append(frame_idx)
	_refresh_enemy_targets_after_item_change()
	_update_all()
	_start_ai_think()
	return true


func _complete_friendly_item_target(owner: int, hero_slot: int) -> bool:
	if not _is_valid_friendly_item_target(owner, hero_slot):
		return false
	selected_item_hero_targets[owner] = hero_slot
	if not selected_item_slots.has(owner):
		selected_item_slots.append(owner)
	_pending_item_hero_target_slot = -1
	return true


func _is_valid_enemy_item_slot_target(owner: int, target: int) -> bool:
	if battle == null or owner < 0 or not battle.slot_ready(PLAYER, owner):
		return false
	var item: ItemData = battle.slot_item(PLAYER, owner)
	return BattleCore.item_requires_enemy_item_slot_target(item) \
		and battle.valid_enemy_item_target_for(item, PLAYER, target)


func _complete_enemy_item_slot_target(owner: int, target: int) -> bool:
	if not _is_valid_enemy_item_slot_target(owner, target):
		return false
	selected_item_targets[owner] = target
	if not selected_item_slots.has(owner):
		selected_item_slots.append(owner)
	_pending_enemy_item_target_slot = -1
	return true


func _on_p2_item_target_clicked(slot: int) -> void:
	if _pending_enemy_item_target_slot < 0:
		return
	if _complete_enemy_item_slot_target(_pending_enemy_item_target_slot, slot):
		_update_all()
		_start_ai_think()


func _pending_target_owner_needs_choice() -> bool:
	return _pending_item_target_slot >= 0 \
		and _slot_target_mode(_pending_item_target_slot) == ItemSlotTargetMode.TRANSFORMS


func _item_choice_options_local(owner: int, target: int) -> Array:
	var item: ItemData = _effective_slot_item(owner)
	if item == null:
		return []
	match item.item_id:
		POINTSTONE_ITEM_ID:
			return battle.begin_pointstone_draft(PLAYER, owner, target)
		EXCHANGE_ITEM_ID:
			return battle.begin_exchange_draft(PLAYER, owner, target)
		REPURCHASE_ITEM_ID:
			return battle.begin_repurchase_draft(PLAYER, owner)
	return []


func _item_choice_title(item_id: String, count: int) -> String:
	match item_id:
		POINTSTONE_ITEM_ID:
			return tr("点金石：选择传说道具（3 选 1）")
		EXCHANGE_ITEM_ID:
			return tr("换签筒：选择替换道具（%d 选 1）") % count
		REPURCHASE_ITEM_ID:
			return tr("回购券：选择已使用的普通道具")
	return tr("选择道具")


func _select_item_choice_local(owner: int, target: int) -> void:
	var item: ItemData = _effective_slot_item(owner)
	if item == null:
		return
	var options: Array = _item_choice_options_local(owner, target)
	if options.is_empty():
		return
	var choice: int = await _show_draft(
		owner, options, _item_choice_title(item.item_id, options.size()))
	if choice >= 0:
		var option_ids: Array[String] = []
		for item_variant in options:
			option_ids.append((item_variant as ItemData).item_id)
		_complete_item_choice(owner, target, choice, option_ids)


func _select_choice_target_local(target: int) -> void:
	var owner: int = _pending_item_target_slot
	if owner < 0:
		return
	if owner == target:
		_pending_item_target_slot = -1
		_update_all()
		return
	# 选作变换目标即放弃其原本的“本回合使用”选择。
	_clear_item_selection_for_new_target(target, owner)
	if not _is_valid_item_slot_target(owner, target):
		return
	await _select_item_choice_local(owner, target)
	if not selected_item_choices.has(owner):
		_pending_item_target_slot = owner
	_update_all()
	_start_ai_think()


func _request_item_choice_net(owner: int, target: int) -> void:
	if not _pending_pointstone_offer.is_empty():
		return
	if owner < 0:
		return
	if owner == target:
		_pending_item_target_slot = -1
		_update_all()
		return
	if target >= 0:
		_clear_item_selection_for_new_target(target, owner)
		if not _is_valid_item_slot_target(owner, target):
			return
	var item: ItemData = _effective_slot_item(owner)
	if item == null:
		return
	_pending_pointstone_offer = {source = owner, target = target, item_id = item.item_id}
	_pending_item_target_slot = -1
	BattleSetup.net_session.client.request_item_draft(owner, target)
	_update_all()


## M3：P1 道具槽点击分派（按槽态）。抽/补 = 立即生效（公开电报）；
## 使用 = 暂存点选（金边），确认时与动作一起盲选提交。
## 格解锁自动（第 3/4/5 回合·无开格步骤/费用·2026-07-03）→ SEALED（未到解锁回合）点击无操作。
func _on_p1_slot_clicked(s: int) -> void:
	if state != State.PLAYER_SELECT or _drafting or not _pending_pointstone_offer.is_empty():
		return
	# 联机（M1）：抽/补=向服务器请求（选项服务器生成·draft_offer 回来经 _net_open_offer 弹窗）；
	# 使用点选=纯本地暂存（提交时随 payload 上行），与本地同款 toggle。
	if _net:
		match battle.slot_state(PLAYER, s):
			BattleCore.SlotState.OPENED:
				if battle.can_draw_slot(PLAYER, s):
					BattleSetup.net_session.client.request_draft(s, false)
			BattleCore.SlotState.CHARGING:
				if battle.slot_ready(PLAYER, s):
					if _pending_target_owner_needs_choice():
						_request_item_choice_net(_pending_item_target_slot, s)
					elif (battle.slot_item(PLAYER, s) as ItemData).item_id == REPURCHASE_ITEM_ID \
							and not selected_item_slots.has(s):
						_request_item_choice_net(s, -1)
					elif _toggle_ready_item_selection(s):
						_update_all()
			BattleCore.SlotState.EMPTY:
				if battle.can_refill(PLAYER, s):
					BattleSetup.net_session.client.request_refill(s)
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
				if _pending_target_owner_needs_choice():
					await _select_choice_target_local(s)
				elif (battle.slot_item(PLAYER, s) as ItemData).item_id == REPURCHASE_ITEM_ID \
						and not selected_item_slots.has(s):
					await _select_item_choice_local(s, -1)
					_update_all()
				elif _toggle_ready_item_selection(s):
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
	if _net:
		if battle.can_upgrade(PLAYER, s):
			_pending_item_target_slot = -1
			_clear_item_selection_for_new_target(s)
			_update_all()
			BattleSetup.net_session.client.request_draft(s, true)
		return
	if battle.can_upgrade(PLAYER, s):
		_pending_item_target_slot = -1
		_clear_item_selection_for_new_target(s)
		_update_all()
		var c: int = await _show_draft(s, battle.begin_upgrade_draft(PLAYER, s), tr("升级道具（3 选 1）"))
		if c >= 0:
			battle.pick_upgrade(PLAYER, s, c)   # 付能量 → 换升级件 → 锁本回合
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
	_refresh_switch_module()
	if p1_item_row != null:
		p1_item_row.refresh(_battle_for_item_row(), 0, _highlighted_item_slots())
	if p2_item_row != null:
		p2_item_row.targetable = _pending_enemy_item_target_slot >= 0
		p2_item_row.refresh(battle, 1, [], bool(
			battle.info_distortion[1].get("hide_item_bar", false)))
	_update_character_displays()
	_update_energy_labels()
	_update_hp_labels()
	if state == State.PLAYER_SELECT:
		_update_button_states()


func _update_character_displays() -> void:
	for p in [0, 1]:
		var cd: CharacterDisplay = p1_char_display if p == 0 else p2_char_display
		# 死亡节拍守卫：
		# 出战位还是遗体（阵亡未换人 / 终局尸身）时跳过刷新——sprite_frames_path setter
		# 会重播 idle 把遗体拉起来站好；结算尾的 _update_all 正撞在倒地中段。
		# 换人后出战位是活人，刷新自然恢复。
		if battle.hp[p][battle.active_index[p]] <= 0:
			continue
		cd.modulate = Color.WHITE  # 复位防御蓝闪 / 攒黄闪等临时染色
		cd.reset_death_dissolve()
		cd.offset_transform_position = Vector2.ZERO
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


## 出战位(is_active)：只画头像，血量/护盾由上方大血条显示 → 替补血量行隐藏。
## 待选位：头像 + 单个平行四边形血量符号 + 数字；有护盾时追加银灰符号 + 数字。
## 内容按真实文本宽度整体居中，整数和半点数都不会偏轴。
## hp_row 在 index 0(出战位) 为 null；摆位/大小在 battle_screen_base.tscn 调，代码只填值。
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
	frame.is_active = is_active
	frame.is_dead = dead
	frame.player_color = pcolor
	frame.frame_size = Vector2(FRAME_ACTIVE_SIZE, FRAME_ACTIVE_SIZE) if is_active else Vector2(FRAME_BENCH_SIZE, FRAME_BENCH_SIZE)
	# 头像大小/抬升与框解耦（见常量注释）：框尺寸再动也不会连带缩放头像。
	var base_portrait_px := PORTRAIT_ACTIVE_PX if is_active else PORTRAIT_BENCH_PX
	var portrait_tune: Dictionary = BATTLE_PORTRAIT_TUNING.get(h.hero_id, {})
	frame.diamond_portrait_px = base_portrait_px * float(portrait_tune.get("scale", 1.0))
	var base_rise := PORTRAIT_ACTIVE_RISE if is_active else PORTRAIT_BENCH_RISE
	frame.diamond_portrait_rise = base_rise + float(portrait_tune.get("y", 0.0)) * base_portrait_px / PORTRAIT_ACTIVE_PX
	frame.diamond_portrait_shift_x = float(portrait_tune.get("x", 0.0)) * base_portrait_px / PORTRAIT_ACTIVE_PX
	frame.diamond_stroke_px = BATTLE_DIAMOND_STROKE_PX
	# 备选框只加结构重量：外暗轮廓 +1px、内暗线 +0.5px；主色带/尺寸/头像构图均不变。
	frame.diamond_rim_px = 2.0 if is_active else 3.0
	frame.diamond_inner_rim_px = 1.5 if is_active else 2.0
	# 放在所有几何参数之后赋值：换贴图时一次性按最终框宽/抬升重新布局。
	frame.portrait_path = _battle_portrait_path(h)

	# 出战位 / 阵亡位：替补血量行隐藏（出战血量看上方大心条；阵亡不显示 0hp/护盾）。
	if is_active or dead:
		if hp_row != null:
			hp_row.visible = false
		return

	# 待选位：一个斜切血量符号 + 数字（护盾同理），而不是按 HP 个数铺满多个血块。
	if hp_row != null:
		hp_row.visible = true
		var hp_now := battle.hp_display(battle.hp[player][slot])
		var sh := battle.hp_display(battle.shield[player][slot])
		hp_row.set_values(hp_now, sh)


func _battle_portrait_path(h: HeroData) -> String:
	return String(BATTLE_PORTRAIT_OVERRIDES.get(h.hero_id, h.portrait_path))


func _update_energy_labels() -> void:
	# 金币能量点：energy 内部为半能(×2)，显示除以 ENERGY_UNIT → 整能（0.5 能可显半枚·allow_half）。
	var e0 := battle.energy[0] / float(ActionDef.ENERGY_UNIT)
	var e1 := battle.energy[1] / float(ActionDef.ENERGY_UNIT)
	p1_coin_row.set_value(e0, e0)
	p2_coin_row.set_value(e1, e1)
	var caps: Array[int] = battle.energy_max
	for p in 2:
		var label: Label = p1_energy_cap_label if p == 0 else p2_energy_cap_label
		var reduced: bool = caps[p] < ActionDef.MAX_ENERGY
		label.visible = reduced
		if reduced:
			label.text = tr("能量上限 %s") % _fmt_hp(float(caps[p]) / float(ActionDef.ENERGY_UNIT))
	var cap0 := float(caps[0]) / float(ActionDef.ENERGY_UNIT)
	var cap1 := float(caps[1]) / float(ActionDef.ENERGY_UNIT)
	p1_coin_row.tooltip_text = tr("当前能量 %s / 上限 %s") % [_fmt_hp(e0), _fmt_hp(cap0)]
	p2_coin_row.tooltip_text = tr("当前能量 %s / 上限 %s") % [_fmt_hp(e1), _fmt_hp(cap1)]


func _update_hp_labels() -> void:
	p1_char_display.visible = true
	p2_char_display.visible = true
	for p in [0, 1]:
		var hp_now := battle.hp_display(battle.current_hp(p))
		var hp_max := battle.hp_display(battle.current_max_hp(p))
		var sh := battle.hp_display(battle.shield[p][battle.active_index[p]])
		# 心形血珠：满+半+暗色空心到 max；护盾作青色额外心追加。
		var row: HpSlantBarScript = p1_heart_row if p == 0 else p2_heart_row
		row.set_value(hp_now, hp_max, sh)
		# 数字重量(b)：HP 变化时心条 flinch 脉冲（掉血偏红 / 回血偏绿）。
		if _prev_hp_disp[p] >= 0.0 and not is_equal_approx(hp_now, _prev_hp_disp[p]):
			_fx._flinch_heart_row(row, hp_now < _prev_hp_disp[p])
		_prev_hp_disp[p] = hp_now


func _fmt_hp(v: float) -> String:
	v = maxf(v, 0.0)
	if is_equal_approx(v, roundf(v)):
		return "%d" % int(roundf(v))
	return "%.1f" % v


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
	# M3c 反作弊面收口：调试面=全项目唯一 UI 直写引擎入口——联机局禁用（写镜像=自欺+乱像）·
	# 发布构建剥离（导出模板 release 下 is_debug_build()=false·开发期照常）。
	if _net or not OS.is_debug_build():
		return
	var panel: Node = load("res://src/ui/debug/battle_debug_panel.gd").new()
	panel.name = "DebugButtons"
	add_child(panel)
	panel.setup(battle)
	panel.state_changed.connect(_on_debug_state_changed)
	panel.hit_fx.connect(_on_debug_hit_fx)
	panel.overtime_requested.connect(_on_debug_overtime)


## debug 面板改了 battle 状态 → 刷新全套显示。
func _on_debug_state_changed() -> void:
	_update_all()
	_start_ai_think()   # 任务G：调试面板直改引擎状态 → 预想作废重想


## debug 一键进加时赛：跳过平局判定与选人浮窗，双方各用当前出战英雄组白板 1v1
## （BattleSetup 带旗标整场景重载 = 与真实加时同一条路·测加时规则+日食演出用）。
func _on_debug_overtime() -> void:
	BattleSetup.p1_heroes = BattleCore.overtime_roster(battle.heroes[PLAYER], battle.active_index[PLAYER])
	BattleSetup.p2_heroes = BattleCore.overtime_roster(battle.heroes[AI], battle.active_index[AI])
	BattleSetup.overtime = true
	get_tree().reload_current_scene()


## debug 造伤按钮 → 播打击表现（飘字 / 斩击 / 白闪 / 震屏）。
func _on_debug_hit_fx(player: int, dmg_half: int) -> void:
	_impact(player, dmg_half)
	stage.shake(SHAKE_HIT)


# ============================================================
# 动画 / juice
# ============================================================

## A 方案 juice：出招（攻击前冲 / 防御蓝闪沉身 / 攒上浮黄闪）→ 命中（白闪 + 斩击光
## + 伤害数字 + 震屏）。dmg/dead 为 [p0, p1]。无逐帧 attack/hit 动画，全靠代码表现。
func _play_battle_anims(a0: int, a1: int, dmg: Array, dead: Array, fx: Dictionary = {}) -> void:
	var reserve_hits: Array = fx.get("reserve_hits", [{}, {}])
	var reserve_blocks: Array = fx.get("reserve_blocks", [{}, {}])
	var reserve_hit: Array[bool] = [
		not (reserve_hits[0] as Dictionary).is_empty(),
		not (reserve_hits[1] as Dictionary).is_empty()]
	var reserve_dmg: Array[int] = [0, 0]
	for p in 2:
		for hit_data in (reserve_hits[p] as Dictionary).values():
			reserve_dmg[p] += int((hit_data as Dictionary).get("amount", 0))
	# 执行动作 → 镜头聚焦"冲突落点"（Eddy 2026-07-09 镜头规格）：双方都进攻=居中放大对撞（配震屏）；
	# 仅对方进攻=偏左聚受击的己方；仅己方进攻=偏右聚受击的敌方；双方都未进攻=不推近。
	var p1_off := _is_offense(a0, int(dmg[1]), bool(dead[1]))
	var p2_off := _is_offense(a1, int(dmg[0]), bool(dead[0]))
	var strength_price_executed: Array = fx.get("strength_price_executed", [false, false])
	# 终结演出（Q1A）：本拍"动作直接击杀出战英雄"→ 专用慢放演出取代普通结算演出。
	# 毒引爆随攻击结算=攻击致死会触发；反弹死/纯道具死（击杀侧非进攻动作）不触发；
	# 还魂等保命效果让目标未实际阵亡时，自然不触发终结演出。
	var fin_kill_p2 := bool(dead[1]) and not bool(strength_price_executed[1]) and p1_off
	var fin_kill_p1 := bool(dead[0]) and not bool(strength_price_executed[0]) and p2_off
	if fin_kill_p1 or fin_kill_p2:
		await _play_finisher(dmg, fin_kill_p2, fin_kill_p1, fx)
		return
	var fdir := 0.0
	if p1_off != p2_off:
		fdir = 1.0 if p1_off else -1.0
	stage.set_focus(p1_off or p2_off, fdir)
	_act_juice(0, a0)
	_act_juice(1, a1)
	# A3b 出招拍注解：力竭/定身（解释"预期动作为何没发生"）+ 到期延迟伤害（结算在动作前·此刻掉的血）。
	var pre_tags: Array = fx.get("pre_tags", [[], []])
	for p in 2:
		_fx._pop_tags(p, pre_tags[p], 0.0)
	# ③ 能量获得反馈：金币粒子从角色飞向 HUD 金币行（到位时金币行金色脉冲）。
	var egain: Array = fx.get("egain", [0, 0])
	for p in 2:
		if int(egain[p]) > 0:
			_fx._fly_energy_motes(p, int(egain[p]))
	# P3：仅"大波且确实打中（伤害/击杀）"时镜头前推蓄势，峰值正好落在 0.45*phase 后的命中瞬间，
	# 与 stage.shake() + _hitstop 合拍（被挡的大波无 impact → 不触发，避免推近落空）。
	var big_lands := (a0 == A.BIG_ATTACK and (int(dmg[1]) > 0 or reserve_dmg[1] > 0 \
		or (bool(dead[1]) and not bool(strength_price_executed[1])))) \
		or (a1 == A.BIG_ATTACK and (int(dmg[0]) > 0 or reserve_dmg[0] > 0 \
		or (bool(dead[0]) and not bool(strength_price_executed[0]))))
	if big_lands:
		_big_attack_punch()
	await get_tree().create_timer(action_phase_duration * 0.45).timeout

	var pen: Array = fx.get("pen", [0, 0])
	var any := false
	if int(dmg[1]) > 0 or bool(dead[1]):
		_impact(1, int(dmg[1]), int(pen[1]))
		any = true
	if int(dmg[0]) > 0 or bool(dead[0]):
		_impact(0, int(dmg[0]), int(pen[0]))
		any = true
	for p in 2:
		for slot_variant in (reserve_hits[p] as Dictionary):
			var hit_data: Dictionary = reserve_hits[p][slot_variant]
			_impact_reserve_slot(p, int(slot_variant), int(hit_data.get("amount", 0)),
				int(hit_data.get("pen", 0)))
			any = true
	# ② 被挡拍（与命中同拍）：防守方盾感反馈——钢蓝火花+「被挡」飘字；大防挡大波更隆重。
	var blocked: Array = fx.get("blocked", [false, false])
	var block_big: Array = fx.get("block_big", [false, false])
	var any_block := false
	for p in 2:
		if bool(blocked[p]):
			_fx._block_fx(p, bool(block_big[p]))
			any_block = true
		for slot_variant in (reserve_blocks[p] as Dictionary):
			_impact_reserve_slot(p, int(slot_variant), 0, ActionDef.Pen.NORMAL, true,
				bool(reserve_blocks[p][slot_variant]))
			any_block = true
	# ③ 治疗飘字（命中拍后微错开·避免与 -N 叠死）
	var healed: Array = fx.get("healed", [0.0, 0.0])
	for p in 2:
		if float(healed[p]) > 0.0:
			_fx._pop_heal(p, float(healed[p]))
	# A3b 命中拍注解：毒爆/印记/脆弱/护盾/替身/免疫/破甲/追击/还魂/能量上限——腹位小字逐条弹出。
	var tags: Array = fx.get("tags", [[], []])
	for p in 2:
		_fx._pop_tags(p, tags[p])
	# ⑤ 方向性后坐：单侧受击=镜头朝受击方踢一脚（P0 左=-1/P1 右=+1）；双方同拍受击=对撞抵消不偏向。
	var hit0 := int(dmg[0]) > 0 or reserve_hit[0] or bool(dead[0])
	var hit1 := int(dmg[1]) > 0 or reserve_hit[1] or bool(dead[1])
	var lethal := bool(dead[0]) or bool(dead[1])
	if any:
		var kick := _base_attack_response_direction(a0, a1)
		if is_nan(kick):
			kick = (1.0 if hit1 else 0.0) - (1.0 if hit0 else 0.0)
		# 击杀拍震屏强制加档（死亡节拍 v3 ①：这一下就该和普通命中不一样）
		stage.shake(SHAKE_BIG if (lethal or a0 == A.BIG_ATTACK or a1 == A.BIG_ATTACK) else SHAKE_HIT, kick)
	elif any_block:
		# 没打进也有"接触感"：轻震朝防守方踢（力被盾接住的方向感）
		var blocked_side: Array[bool] = [
			bool(blocked[0]) or not (reserve_blocks[0] as Dictionary).is_empty(),
			bool(blocked[1]) or not (reserve_blocks[1] as Dictionary).is_empty()]
		var bkick := (1.0 if blocked_side[1] else 0.0) - (1.0 if blocked_side[0] else 0.0)
		stage.shake(SHAKE_BLOCK, bkick)
	# ①② 死亡节拍 v3（2026-07-18 Eddy 批 A 方案）：致命一击加重定格（盖过 _impact 常规档·
	# token 后发覆盖），按真实时长等冻结放开 → 倒地独享一拍起播，不再被命中特效淹没。
	if lethal:
		_hitstop(kill_hitstop_duration)
		await get_tree().create_timer(kill_hitstop_duration + 0.02, true, false, true).timeout
		if bool(dead[0]):
			_play_defeat(0)
		if bool(dead[1]):
			_play_defeat(1)

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
func _play_finisher(dmg: Array, kill_p2: bool, kill_p1: bool, fx: Dictionary = {}) -> void:
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
	# ⑤ 方向性后坐：朝倒下一方踢（双杀=对撞不偏向）
	stage.shake(SHAKE_BIG * 1.3, (1.0 if kill_p2 else 0.0) - (1.0 if kill_p1 else 0.0))
	# A3b：终结拍也补事件注解（毒爆致死的"为什么死了"就在这拍）——tween 随慢放自然慢速展开。
	var ftags: Array = fx.get("tags", [[], []])
	for p in 2:
		_fx._pop_tags(p, ftags[p], 0.12)
	# 冲击帧（终结命中拍专属）：硬切三段（正片→负片→恢复·真实计时不受慢放拖拽）·炸开中心=受击者
	var bw_center := Vector2(0.5, 0.58)   # 双杀=对撞中点
	if not (kill_p1 and kill_p2):
		var vcd := _cd(1 if kill_p2 else 0)
		bw_center = (vcd.global_position + vcd.size * 0.5) / get_viewport_rect().size
	_fx._bw_flash(bw_center)
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
	# A3b：终结分支早退不经过普通拍的能量粒起飞——恢复后补飞（饕餮吞魂等"死亡产能"正是这一拍）。
	var eg: Array = fx.get("egain", [0, 0])
	for p in 2:
		if int(eg[p]) > 0:
			_fx._fly_energy_motes(p, int(eg[p]))
	await get_tree().create_timer(0.3, true, false, true).timeout


## 终结版命中表现：不用 _impact——其 _char_pop 会把拉出的 1.35 放大拽回 1.0、自带顿帧也与
## 终结统一顿帧冲突。改为放大基础上的小 punch + 阵亡变灰下沉。
func _finisher_impact(target_player: int, dmg_half: int) -> void:
	var cd := _cd(target_player)
	cd.flash_white(0.3)
	cd.pulse_rim(1.0, 0.3)
	_fx._spawn_slash(target_player)
	_fx._spawn_spark(target_player, true)
	if dmg_half > 0:
		_fx._pop_damage(target_player, float(dmg_half) / 2.0)
	var tw := create_tween()
	tw.tween_property(cd, "scale", Vector2.ONE * (FINISHER_SCALE * 1.08), 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(cd, "scale", Vector2.ONE * FINISHER_SCALE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_play_defeat(target_player, false)   # 终结已自带冲击位移，不叠加普通死亡受力桥
	var tw2 := create_tween()
	tw2.tween_property(cd, "position:y", cd.position.y + 14.0, 0.3).set_trans(Tween.TRANS_SINE)
	_fin_impact_tweens.append(tw)
	_fin_impact_tweens.append(tw2)


var _defeat_at_ms: Array[int] = [0, 0]
var _defeat_contact_at_ms: Array[int] = [0, 0]
var _defeat_tokens: Array[int] = [0, 0]
var _defeat_dissolve_started: Array[bool] = [false, false]
var _defeat_dissolve_completed: Array[bool] = [false, false]


## 普通致命击先做极短的向外受力桥，再开始倒地；终结技已有自身冲击位移，可关闭该桥。
func _play_defeat(player: int, bridge_recoil: bool = true) -> void:
	_defeat_tokens[player] += 1
	var token := _defeat_tokens[player]
	_defeat_at_ms[player] = Time.get_ticks_msec()
	_defeat_contact_at_ms[player] = 0
	_defeat_dissolve_started[player] = false
	_defeat_dissolve_completed[player] = false
	var cd := _cd(player)
	cd.reset_death_dissolve()
	cd.offset_transform_position = Vector2.ZERO
	if bridge_recoil:
		var outward := -1.0 if player == 0 else 1.0
		var recoil := create_tween()
		recoil.tween_property(cd, "offset_transform_position",
				Vector2(outward * death_recoil_distance, 2.0), death_recoil_duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		recoil.tween_callback(_start_defeat_animation.bind(player, token))
		recoil.tween_property(cd, "offset_transform_position", Vector2.ZERO,
				death_recoil_duration + 0.04).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_start_defeat_animation(player, token)


func _start_defeat_animation(player: int, token: int) -> void:
	if token != _defeat_tokens[player]:
		return
	var cd := _cd(player)
	if cd.has_action_anim("defeat"):
		var callback := _on_defeat_animation_finished.bind(player, token)
		cd.action_animation_finished.connect(callback, CONNECT_ONE_SHOT)
		cd.play_animation("defeat", false)
		# 信号是主路径；此计时器只防损坏的 SpriteFrames 永不发 finished。
		var fallback := maxf(0.12, cd.animation_duration(&"defeat") + 0.08)
		get_tree().create_timer(fallback).timeout.connect(_announce_death.bind(player, token))
	else:
		_announce_death(player, token)


func _on_defeat_animation_finished(
		animation_name: StringName, player: int, token: int) -> void:
	if animation_name == &"defeat":
		_announce_death(player, token)


## 真正落地时只触发尘与轻震；角色保持原亮度，token 防止旧定时器污染后续英雄。
func _announce_death(player: int, token: int = -1) -> void:
	if token >= 0 and token != _defeat_tokens[player]:
		return
	if _defeat_contact_at_ms[player] > 0:
		return
	_defeat_contact_at_ms[player] = Time.get_ticks_msec()
	_fx._spawn_dust(player)
	stage.shake(SHAKE_HIT * 0.6, 1.0 if player == 1 else -1.0)
	# 清掉可能残留的受击染色，但不再播放从明到暗的死亡灰化。
	_cd(player).modulate = Color.WHITE
	_run_death_dissolve(player, _defeat_tokens[player])


func _wait_for_death_contact(player: int) -> void:
	if _defeat_at_ms[player] <= 0 or _defeat_contact_at_ms[player] > 0:
		return
	var deadline := Time.get_ticks_msec() + 5000
	while _defeat_contact_at_ms[player] <= 0 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if _defeat_contact_at_ms[player] <= 0:
		_announce_death(player, _defeat_tokens[player])


## 倒地末帧以原亮度静止停顿后，自动开始四周向内的硬切瓦解。
## 该协程与换人选择解耦：玩家必须先看完瓦解，之后才出现强制换人界面。
func _run_death_dissolve(player: int, token: int) -> void:
	if token != _defeat_tokens[player] or _defeat_dissolve_started[player]:
		return
	_defeat_dissolve_started[player] = true
	await get_tree().create_timer(maxf(0.0, death_final_frame_hold_duration)).timeout
	if token != _defeat_tokens[player]:
		return
	var cd := _cd(player)
	var from_right := player == PLAYER
	cd.set_death_dissolve(0.0, from_right, death_dissolve_steps)
	var erosion := create_tween()
	var duration := maxf(0.01, death_dissolve_duration)
	# 三段式阶梯：前三阶慢咬入，中段快速扩散，最后两阶重新放慢收尾。
	erosion.tween_method(
			cd.set_death_dissolve.bind(from_right, death_dissolve_steps),
			0.0, DEATH_DISSOLVE_OPEN_PROGRESS,
			duration * DEATH_DISSOLVE_OPEN_SHARE)
	erosion.tween_method(
			cd.set_death_dissolve.bind(from_right, death_dissolve_steps),
			DEATH_DISSOLVE_OPEN_PROGRESS, DEATH_DISSOLVE_MIDDLE_PROGRESS,
			duration * DEATH_DISSOLVE_MIDDLE_SHARE)
	erosion.tween_method(
			cd.set_death_dissolve.bind(from_right, death_dissolve_steps),
			DEATH_DISSOLVE_MIDDLE_PROGRESS, 1.0,
			duration * DEATH_DISSOLVE_CLOSE_SHARE)
	await erosion.finished
	if token != _defeat_tokens[player]:
		return
	cd.set_death_dissolve(1.0, from_right, death_dissolve_steps)
	_defeat_dissolve_completed[player] = true


func _wait_for_death_dissolve(player: int) -> void:
	if _defeat_at_ms[player] <= 0:
		return
	await _wait_for_death_contact(player)
	if not _defeat_dissolve_started[player]:
		_run_death_dissolve(player, _defeat_tokens[player])
	var deadline := Time.get_ticks_msec() + 5000
	while not _defeat_dissolve_completed[player] and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not _defeat_dissolve_completed[player]:
		# 损坏的 Tween/场景帧也不应永久卡死换人；保底仍是硬切完全瓦解。
		_cd(player).set_death_dissolve(1.0, player == PLAYER, death_dissolve_steps)
		_defeat_dissolve_completed[player] = true


func _wait_for_active_death_dissolves() -> void:
	for player in [PLAYER, AI]:
		if _defeat_at_ms[player] > 0 and battle.hp[player][battle.active_index[player]] <= 0:
			await _wait_for_death_dissolve(player)


## 遗体已瓦解后才调用：透明期换装，再用无回弹短落位入场。
func _death_switch_transition(player: int) -> void:
	await _wait_for_death_dissolve(player)
	var cd := _cd(player)
	var home: Vector2 = _cd_home[player]
	_update_all()   # 瓦解进度=1 → 换装不可见
	cd.reset_death_dissolve()
	cd.modulate = Color(1.0, 1.0, 1.0, 0.0)
	cd.position = home
	cd.offset_transform_position = Vector2(0.0, -death_entry_drop)
	var inw := create_tween().set_parallel(true)
	inw.tween_property(cd, "modulate:a", 1.0, death_entry_duration * 0.75)
	inw.tween_property(cd, "offset_transform_position", Vector2.ZERO, death_entry_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	inw.chain().tween_callback(_fx._spawn_dust.bind(player))
	await inw.finished
	cd.position = home
	cd.offset_transform_position = Vector2.ZERO


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
				_fx._spawn_dust(player)   # ⑦ 起步蹬地尘
				tw.tween_property(cd, "position", home + Vector2(reach * 1.3 * dir, 0), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw.tween_interval(0.14)
				tw.tween_property(cd, "position", home, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_callback(_fx._spawn_dust.bind(player))   # ⑦ 回位落定尘
			else:
				# 静态图英雄：后撤蓄势 → 前冲 → 回位（平移=唯一攻击运动信号·原配方不动）。
				tw.tween_property(cd, "position", home + Vector2(-28.0 * dir, 0), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tw.tween_callback(_fx._spawn_dust.bind(player))   # ⑦ 蓄势转前冲的蹬地尘
				tw.tween_property(cd, "position", home + Vector2(reach * dir, 0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw.tween_property(cd, "position", home, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_callback(_fx._spawn_dust.bind(player))   # ⑦ 回位落定尘
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



func _impact(target_player: int, dmg_half: int, pen: int = 0) -> void:
	var cd := _cd(target_player)
	var big := dmg_half >= 4   # ≥2HP=重击：更强退弹/火花/定格
	cd.flash_white(0.18)
	cd.pulse_rim(0.7, 0.22)   # A3：被弧光照亮
	_fx._char_pop(target_player, 0.12 if big else 0.08)   # 受击退弹（scale 弹一下）
	_fx._spawn_slash(target_player)
	_fx._spawn_spark(target_player, big)                  # c：命中火花
	if dmg_half > 0:
		_fx._pop_damage(target_player, float(dmg_half) / 2.0, pen)
	_hitstop(0.075 if big else 0.045)                 # c：命中定格（不 await，自管恢复）


## 十方无次第命中或被挡时的替补局部反馈：只震对应头像框，不把结果错误演到中央出战角色身上。
func _impact_reserve_slot(target_player: int, target_slot: int, dmg_half: int, pen: int = 0,
		blocked: bool = false, blocked_big: bool = false) -> void:
	var frames: Array[HeroFrame] = p1_frames if target_player == PLAYER else p2_frames
	var frame_slots: Array[int] = p1_frame_slots if target_player == PLAYER else p2_frame_slots
	var frame_idx: int = frame_slots.find(target_slot)
	if frame_idx < 0 or frame_idx >= frames.size():
		return
	var frame: HeroFrame = frames[frame_idx]
	if not frame.visible:
		return

	var base_modulate: Color = frame.modulate
	var base_scale: Vector2 = frame.scale
	frame.pivot_offset = frame.size * 0.5
	var pulse := create_tween()
	pulse.set_parallel(true)
	var pulse_color := Color(0.62, 0.86, 1.45) if blocked else Color(1.55, 0.58, 0.50)
	var pulse_scale := 1.10 if blocked_big else 1.08
	pulse.tween_property(frame, "modulate", pulse_color, 0.08)
	pulse.tween_property(frame, "scale", base_scale * pulse_scale, 0.08).set_trans(Tween.TRANS_BACK)
	pulse.chain().set_parallel(true)
	pulse.tween_property(frame, "modulate", base_modulate, 0.20)
	pulse.tween_property(frame, "scale", base_scale, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if dmg_half <= 0 and not blocked:
		return
	var damage_label := Label.new()
	damage_label.name = "ReserveBlock" if blocked else "ReserveDamage"
	damage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_label.text = tr("挡") if blocked else "-%s" % _fmt_hp(float(dmg_half) / 2.0)
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	damage_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_label.z_index = 100
	FontManager.apply(damage_label, 24)
	var damage_color := BattleFxScript.COL_BLOCK_TEXT if blocked \
		else (BattleFxScript.COL_DMG_BIG if dmg_half >= 4 else BattleFxScript.COL_DMG_SMALL)
	if not blocked and pen == ActionDef.Pen.TRUE_DMG:
		damage_color = BattleFxScript.COL_DMG_TRUE
	elif not blocked and pen in [ActionDef.Pen.PIERCE_DEF, ActionDef.Pen.PIERCE_BIGDEF]:
		damage_color = BattleFxScript.COL_DMG_PIERCE
	damage_label.add_theme_color_override("font_color", damage_color)
	damage_label.add_theme_color_override("font_outline_color", Color(0.12, 0.03, 0.02, 0.95))
	damage_label.add_theme_constant_override("outline_size", 5)
	frame.add_child(damage_label)
	var float_up := create_tween()
	float_up.set_parallel(true)
	float_up.tween_property(damage_label, "position:y", -24.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	float_up.tween_property(damage_label, "modulate:a", 0.0, 0.42).set_delay(0.12)
	float_up.chain().tween_callback(damage_label.queue_free)



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






func _process(_delta: float) -> void:
	# 联机（M1）：每帧泵网络——收包喂房间（房主）/消化服务器消息（双方）·状态机见 _net_pump。
	if _net:
		_net_pump()
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
	_sync_world_foreground_occluder()
	_update_character_reflections()


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
		A.CHARGE: return tr("攒")
		A.ATTACK: return tr("波")
		A.DEFEND: return tr("防")
		A.BIG_ATTACK: return tr("大波")
		A.BIG_DEFEND: return tr("大防")
		A.SWITCH: return tr("切换")
		ACTIVE: return tr("技能")
	return "?"
