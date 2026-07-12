class_name BattleCore
extends RefCounted

## Battle 战斗核心引擎 —— ADR-002 架构（v4 重写，已转正为唯一核心）。
## 纯逻辑、无 UI 依赖、可 headless（联机服务器权威前提，延续 ADR-001 §D5）。
##
## 进度：
##   Step 2.1 ✅ 状态模型 + setup + 只读视图 + HeroSkill 契约。
##   Step 2.2a ✅ 基础动作（攒/波/防/大波/大防）+ 同时独立结算 + 伤害管线骨架。
##   Step 2.2b ✅ 切换（甲时机：先于伤害→打到换上来的新英雄）+ 死亡结算/强制换人
##              + 全部 hook 触发点接入（英雄 no-op 时行为不变）。
##   ⏳ 待补：高级管线相位（月相/减免/穿透；易伤已实装[h20 触邪·罪已昭]，「伤害转移/延迟」原属已弃用的旧塔罗英雄 h27/h30、随塔罗架构弃用作废）、
##           overkill 连锁(§D8)、英雄组件注册表(_build_skills)。
##
## 半点制 (§D3)：HP / 伤害 / 护盾 / pending 内部以"半点"整数存储，
##    1 HP = HP_UNIT(2) 半点，最小伤害 0.5 = 1 半点。能量是独立整数资源。
##
## 组件无状态 (§D2)：所有 per-hero 状态都在本引擎的容器里；HeroSkill 只读写传入的 self。

const HP_UNIT := 2  # 必须与 ActionDef.HP_UNIT 一致

## 英雄机制数值（从引擎逻辑里的裸魔数提出来，集中可调）
const HUZHU_CAP := 2             # 天狗 h23【护主·顶替承伤】每局上限（次·2026-07-05 批③ 1→2·Eddy 批 C 案）
const HUZHU_COUNTER_DMG := 2     # 御凶登场反击（半点=1.0 普通伤害·批③新增·Eddy 定去真伤·天狗扑咬攻击者）
const HUZHU_SHIELD := 2          # 天狗御凶登场护盾（2 半点=1.0·2026-07-04 Eddy 批·垫着承伤更可能活下来）
const CHONGZHUANG_DAMAGE := 1    # 星日登场冲撞 = 0.5 HP（半点）
const DOUBLEABLE_ACTIONS := [ActionDef.Action.ATTACK, ActionDef.Action.BIG_ATTACK, ActionDef.Action.CHARGE, ActionDef.Action.DEFEND, ActionDef.Action.BIG_DEFEND]  # 广寒 h16【疾风】可"附加同种再做一次"的动作（仅技能/切换除外·防/大防可选但二元整体挡=无额外效果）

# Winner 常量（延续 v3 B-007 语义：UNDECIDED=-1 / DRAW=0 / P1=1 / P2=2）
const WINNER_UNDECIDED := -1
const WINNER_DRAW := 0
const WINNER_P1 := 1
const WINNER_P2 := 2

# 加时赛回合上限（2026-07-05 Eddy 定·任务5 平局调查产物）：打满 → 双方出战同时扣血裁决。
# 旧规则"不限回合"废（sim 实锤：同 HP 白板镜像互龟 → 加时再平率 52%·安全阀 300 回合形同虚设）。
const OVERTIME_TURN_CAP := 30

# === 核心状态（全部可序列化）===
var heroes: Array = [[], []]              # heroes[player] = Array[HeroData]
var active_index: Array[int] = [0, 0]
var energy: Array[int] = [0, 0]           # 团队共享能量池
var hp: Array = [[], []]                  # hp[player][slot]，半点
var max_hp: Array = [[], []]              # 半点
var shield: Array = [[], []]              # shield[player][slot]，半点
var pending_damage: Array = [[], []]      # 半点，延迟伤害队列（道具：妖火/藤蔓陷阱施加，Phase0 结算）
var statuses: Array = [[], []]            # statuses[player][slot]: Dictionary，per-slot 状态容器 (§D5)

var selected_action: Array[int] = [-1, -1]
var _switch_to: Array[int] = [-1, -1]               # SWITCH 动作的目标槽位
var _forced_pull: Array[int] = [-1, -1]             # 枭阳 h21【调虎离山】：_forced_pull[受害方]=被强制揪上场的替补槽（execute_active 设·resolve Phase 2.7 执行后清）
var _active_target: Array[int] = [-1, -1]           # 主动技玩家指定目标槽（枭阳 h21 揪敌方哪个替补·-1=未指定→execute_active 随机选·resolve 末清）
var pending_death_switch: Array[bool] = [false, false]  # 出战阵亡待玩家选替补上场
var _death_processed: Array = [[], []]              # 每槽位死亡 hook 是否已触发（防重复）
var _shuchao_procs: Array[int] = [0, 0]             # 本回合各方已计入的 combo proc 数（鼠潮 h13·仅计数·2026-07-01 去每回合封顶）
var _double: Array[bool] = [false, false]           # 本回合各方是否"附加同种动作再做一次"（疾风 h16·选择阶段设·resolve 末重置）
var _killer: Array = [[], []]                       # _killer[player][slot]=直接攻击致死该英雄的攻击方;-1=非攻击致死。on_kill 只对直接攻击触发(防 splash/AOE 连锁)
var _last_action: Array[int] = [-1, -1]             # 上回合双方动作（传说级雪球·惯性件读取；h04 敌方重复动作产能比对·Phase 5.7）

# === 道具状态（ADR-003）===
var items: Array = [[], []]                  # items[player] = Array[ItemData]：持有/可用的道具（经济系统前由 give_item 直接给）
var item_uses: Array = [[], []]             # 本回合提交的道具使用（有序）：[{data:ItemData, when:int, target:int}]
var info_distortion: Array[Dictionary] = [{}, {}]  # 信息层（幻影/迷雾）：持续到该玩家下次用道具
var item_buffs: Array[Dictionary] = [{}, {}]       # 跨回合道具 buff（风之靴 next_atk_bonus 等）
var _imod: Array = [{}, {}]                  # 本回合道具修正器累加器（resolve 内重置·transient）
var relics: Array = [[], []]                 # relics[player] = Array[{data:ItemData, state:Dictionary}]：激活的遗物（持久·每回合 tick）
var slots: Array = [[], []]                  # slots[player] = Array[Dictionary]：道具经济槽位（econ_init 后填充；测试不填→走 give_item）

var turn_number: int = 0
var game_over: bool = false
var winner: int = WINNER_UNDECIDED
var overtime_mode: bool = false           # 加时赛局（create_overtime / apply_overtime_bench 置位·启用骤死裁决）
var action_lock_turn: Array[int] = [-1, -1]     # 烛阴 h17【阖眸成夜】v5（锁招）：该回合号时此玩家只能使用 action_locked（-1=无锁）
var action_locked: Array[int] = [-1, -1]        # 被锁定动作（ActionDef.Action 或 ActionDef.ACTIVE·=施放拍对手用过的动作·不可执行时兜底只能攒）
var pierce_next_attack: Array[bool] = [false, false]   # 毕方 h22【焚天火兆】v3：该方下一次动作攻击穿大防（全队资源·不过期·兑现/落空即消·2026-07-06 批④）

var rng := RandomNumberGenerator.new()    # 可 seed (§D7)：联机/录像/测试可复现
var _skills: Array = [[], []]             # _skills[player][slot]: HeroSkill 或 null

## 英雄技能组件注册表：hero_id → 组件脚本。未列入者 = 无技能（_skills 为 null）。
## 随实装逐个加入。swap 后此表与 v3 _HERO_SKILL_SCRIPTS 合并/替换。
const _HERO_SKILL_SCRIPTS := {
	"h01": preload("res://src/battle/skills/h01_dunshu.gd"),
	"h02": preload("res://src/battle/skills/h02_xiejin.gd"),
	"h03": preload("res://src/battle/skills/h03_lianpu.gd"),
	"h04": preload("res://src/battle/skills/h04_jiaotu.gd"),
	"h05": preload("res://src/battle/skills/h05_liejia.gd"),
	"h06": preload("res://src/battle/skills/h06_cuidu.gd"),
	"h07": preload("res://src/battle/skills/h07_dangxian.gd"),
	"h08": preload("res://src/battle/skills/h08_muyang.gd"),
	"h09": preload("res://src/battle/skills/h09_liezhao.gd"),
	"h10": preload("res://src/battle/skills/h10_jianyi.gd"),
	"h11": preload("res://src/battle/skills/h11_zhuibu.gd"),
	"h12": preload("res://src/battle/skills/h12_nafu.gd"),
	"h13": preload("res://src/battle/skills/h13_shuchao.gd"),
	"h14": preload("res://src/battle/skills/h14_fanzhen.gd"),
	"h15": preload("res://src/battle/skills/h15_xueyong.gd"),
	"h16": preload("res://src/battle/skills/h16_jifeng.gd"),
	"h17": preload("res://src/battle/skills/h17_zhenya.gd"),
	"h18": preload("res://src/battle/skills/h18_chanrao.gd"),
	"h19": preload("res://src/battle/skills/h19_jianta.gd"),
	"h20": preload("res://src/battle/skills/h20_duanzui.gd"),
	"h21": preload("res://src/battle/skills/h21_diaohu.gd"),
	"h22": preload("res://src/battle/skills/h22_yiming.gd"),
	"h23": preload("res://src/battle/skills/h23_huzhu.gd"),
	"h24": preload("res://src/battle/skills/h24_taotie.gd"),
}

## 注册表整体校验只跑一次（静态守卫）。
static var _registry_validated := false


## seed_value = 0 时用随机 seed（单机）；联机/测试传入确定 seed。
func setup(p1_heroes: Array, p2_heroes: Array, seed_value: int = 0) -> void:
	heroes = [p1_heroes, p2_heroes]
	rng.seed = seed_value if seed_value != 0 else randi()

	hp = [[], []]
	max_hp = [[], []]
	shield = [[], []]
	pending_damage = [[], []]
	statuses = [[], []]
	_death_processed = [[], []]
	_killer = [[], []]
	for p in [0, 1]:
		for h in heroes[p]:
			var hp_half: int = int(h.max_hp) * HP_UNIT
			hp[p].append(hp_half)
			max_hp[p].append(hp_half)
			shield[p].append(0)
			pending_damage[p].append(0)
			statuses[p].append({})
			_death_processed[p].append(false)
			_killer[p].append(-1)

	active_index = [0, 0]
	energy = [ActionDef.INITIAL_ENERGY, ActionDef.INITIAL_ENERGY]
	selected_action = [-1, -1]
	_switch_to = [-1, -1]
	_forced_pull = [-1, -1]
	_active_target = [-1, -1]
	pending_death_switch = [false, false]
	_shuchao_procs = [0, 0]
	_double = [false, false]
	_last_action = [-1, -1]
	items = [[], []]
	item_uses = [[], []]
	info_distortion = [{}, {}]
	item_buffs = [{}, {}]
	_imod = [{}, {}]
	relics = [[], []]
	slots = [[], []]
	turn_number = 0
	game_over = false
	winner = WINNER_UNDECIDED

	_build_skills()
	_validate_skills()
	for p in [0, 1]:
		for s in range(heroes[p].size()):
			if _skills[p][s] != null:
				_skills[p][s].on_setup(self, p, s)


func _build_skills() -> void:
	_skills = [[], []]
	for p in [0, 1]:
		for h in heroes[p]:
			var script: Script = _HERO_SKILL_SCRIPTS.get(h.hero_id, null)
			_skills[p].append(script.new() if script != null else null)


## 校验技能装配，及早暴露注册表 id 拼写/漏注册（联机准备）。
## 注册表整体只校验一次：key 须 hXX 格式、value 须 HeroSkill 子类。
## 本局阵容每次 setup 都查：数据有技能描述却装配出 null = 多半 key 拼错/漏注册。
func _validate_skills() -> void:
	if not _registry_validated:
		_registry_validated = true
		for id in _HERO_SKILL_SCRIPTS:
			var sid := str(id)
			if not (sid.length() == 3 and sid.begins_with("h") and sid.substr(1).is_valid_int()):
				push_error("BattleCore: 技能注册表 key 非法 hero_id（应为 hXX）：%s" % sid)
			if not (_HERO_SKILL_SCRIPTS[id].new() is HeroSkill):
				push_error("BattleCore: 技能注册表 %s 的脚本不是 HeroSkill 子类" % sid)
	for p in [0, 1]:
		for s in range(heroes[p].size()):
			var h: HeroData = heroes[p][s]
			if _skills[p][s] == null and h.skill_description != "" and h.skill_description != "待设计":
				push_warning("BattleCore: 英雄 %s 数据标注有技能但未注册（检查 _HERO_SKILL_SCRIPTS 的 key 拼写）" % h.hero_id)


# === 只读视图（UI / 测试用；半点 → 显示）===

func hp_display(half: int) -> float:
	return float(half) / float(HP_UNIT)

## 统一能量获得入口：应用出战英雄的 energy_gain_bonus（虚日囤鼠 = 每次 +0.5 能），clamp 到 MAX。
## boostable=false 的来源不吃加成（2026-07-04 Eddy 批：被动 +1 能/回合 = 白给收入不加成——
##   虚日站场挂机躺赚 0.5/回合的通胀漏洞；只有主动来源（攒/转化/combo/道具）吃加成）。
func _gain_energy(player: int, amount: int, boostable: bool = true) -> void:
	if amount <= 0:
		return
	if boostable:
		var sk: HeroSkill = _skills[player][active_index[player]]
		if sk != null:
			amount += sk.energy_gain_bonus(self, player, active_index[player])
	energy[player] = mini(energy[player] + amount, ActionDef.MAX_ENERGY)


## 玄冥 h13【鼠潮】：player 队触发一次 combo 效果时，引擎在该结算点调本函数。
## 在场（含替补·存活）有鼠潮型英雄 → 团队能量 +其 combo_proc_energy()（走 _gain_energy·享囤鼠叠加）。
## 无鼠潮 = no-op。（2026-07-01 Eddy 去每回合封顶·combo→能量回路刹车移除；_shuchao_procs 仅留计数。）
func note_combo_proc(player: int) -> void:
	var amt := 0
	for s in range(heroes[player].size()):
		if hp[player][s] > 0:
			var sk2: HeroSkill = _skills[player][s]
			if sk2 != null:
				amt += sk2.combo_proc_energy()
	if amt <= 0:
		return
	_shuchao_procs[player] += 1
	_gain_energy(player, amt)


## === 技能组件 / UI 的公共调用接口（B3 私有访问转正·行为不变）===
## 技能组件用：记账「attacker_player 击杀 victim_player 的 victim_slot」——h11 娄金穷追致死后归因（on_kill 只对直接攻击触发）。
func credit_kill(attacker_player: int, victim_player: int, victim_slot: int) -> void:
	_killer[victim_player][victim_slot] = attacker_player

## 技能组件用：请求在 victim_player 身上强制揪 slot 号替补上场——h21 枭阳【调虎离山】（resolve Phase 2.7 执行）。
func request_forced_pull(victim_player: int, slot: int) -> void:
	_forced_pull[victim_player] = slot

## 技能组件用：读 player 本回合为主动技指定的目标槽（-1=未指定）。resolve 末统一清。
func active_target(player: int) -> int:
	return _active_target[player]

## UI 只读：取指定槽位的 HeroSkill（不暴露 _skills 私有容器）。
func get_skill(player: int, slot: int) -> HeroSkill:
	return _skills[player][slot]

## UI 只读：该玩家当前能否切换（公共包装 _can_switch）。
func can_switch(player: int) -> bool:
	return _can_switch(player)

## UI 只读：指定动作的能量成本（半能·公共包装 _get_cost）。
func action_cost(player: int, action: int) -> int:
	return _get_cost(player, action)

func get_status(player: int, slot: int, key: String, default: Variant = null) -> Variant:
	return statuses[player][slot].get(key, default)

func set_status(player: int, slot: int, key: String, value: Variant) -> void:
	statuses[player][slot][key] = value

func active_hero(player: int) -> HeroData:
	return heroes[player][active_index[player]]

func current_hp(player: int) -> int:
	return hp[player][active_index[player]]

func current_max_hp(player: int) -> int:
	return max_hp[player][active_index[player]]

func alive_count(player: int) -> int:
	var c := 0
	for v in hp[player]:
		if v > 0:
			c += 1
	return c

func living_reserves(player: int) -> Array[int]:
	var result: Array[int] = []
	for i in range(hp[player].size()):
		if hp[player][i] > 0 and i != active_index[player]:
			result.append(i)
	return result


# === 动作选择 / 费用 ===

func _get_cost(player: int, action: int) -> int:
	if action == ActionDef.ACTIVE:
		var sk: HeroSkill = _skills[player][active_index[player]]
		return sk.active_cost(self, player, active_index[player]) if sk != null and sk.has_active() else 0
	if action in ActionDef.BASE_ACTION_DEF:
		var c: int = ActionDef.BASE_ACTION_DEF[action]["cost"]
		# 泽国防御税（相柳 h18·2026-07-05 批③ J 案）：敌方出战是相柳(存活·未被沉默) → 你的防不再免费(+1 能)。
		#   本函数是费用唯一出口（can_afford/疾风双动作/resolve 扣费全走此）→ 单点收口；大防不加税（已 2 能）。
		if action == ActionDef.Action.DEFEND:
			var e: int = 1 - player
			var esk: HeroSkill = _eff_skill(e, active_index[e])
			if esk != null and hp[e][active_index[e]] > 0:
				c += esk.enemy_defend_cost_add()
		return c
	return 0


## 本方【可用】能量（半能）= 能量池（最低 0）。
## 本函数是全引擎唯一能量闸口（can_afford/主动技/疾风双动作/道具补·升全走此）。
## ⚠ 2026-07-06：烛阴 h17 能量冻结已弃（大轮 29.5% 三连败=锁钱锁不住免费「防」）→
##   四改动作禁用→批⑤五改锁招（action_lock_*·can_afford/can_use_active 收口），本函数保持纯能量语义。
func usable_energy(player: int) -> int:
	return maxi(0, energy[player])


## 沉默感知技能取用：被沉默英雄(silenced>0) 视作"无 unique"(返回 null)。
## resolve 期间另有「置 null 换位」统一收口所有 hook；本 helper 供 resolve 外的选择门(防/切换/主动技)用。
## ⚠ 2026-07-05：原使用者烛阴 h17 已重设计为能量冻结（沉默两次加强无效·机制价值不足）——
##   沉默现无英雄使用者，保留为通用 status 基建（远征怪物/道具候选·由 test_silence_status 直测锁行为）。
func _eff_skill(player: int, slot: int) -> HeroSkill:
	if int(get_status(player, slot, "silenced", 0)) > 0:
		return null
	return _skills[player][slot]


## 出战英雄是否可用防/大防（穷奇 h15【血勇】= 不可）。下场即恢复（按出战英雄判定）。
func _can_defend(player: int) -> bool:
	var sk: HeroSkill = _eff_skill(player, active_index[player])
	return sk == null or sk.can_defend()


## player 能否【主动切换】：对手出战是"缠绕"英雄(相柳 h18·存活) → 不能（被缠住）。
## 只锁主动切换；死亡换人/救援/道具强制切换走各自路径、不经此 gate。
func _can_switch(player: int) -> bool:
	var e: int = 1 - player
	var sk: HeroSkill = _eff_skill(e, active_index[e])
	return not (sk != null and hp[e][active_index[e]] > 0 and sk.locks_enemy_switch())


func can_afford(player: int, action: int) -> bool:
	if turn_number == action_lock_turn[player]:
		# 阖眸成夜 h17 v5（锁招）：锁定动作可执行 → 本拍仅它合法；不可执行（付不起 /
		# 被其他规则禁 / 切换无活替补 / 主动技 cap 满）→ 兜底只能「攒」（无死锁保证）。
		if _locked_action_doable(player):
			if action != action_locked[player]:
				return false
		elif action != ActionDef.Action.CHARGE:
			return false
	if action in ActionDef.DEFEND_ACTIONS and not _can_defend(player):
		return false   # 血勇：嗜杀红温·防/大防不合法（单一收口，legal_actions/UI/AI 全走此）
	if action == ActionDef.Action.SWITCH and not _can_switch(player):
		return false   # 缠绕：对手出战是暗蛇 → 切换不合法（legal_actions/select_switch/UI 全走此）
	return usable_energy(player) >= _get_cost(player, action)


## 锁定动作当前是否可执行（不含锁定规则自身·防递归）——付得起且未被其他规则禁；
## 锁「切换」需有存活替补（否则合法集为空=死锁）；锁主动技走 _can_use_active_raw（cap/费用/前置）。
## 仅在锁定生效拍被调用（非常态热路径）·零分配。
func _locked_action_doable(player: int) -> bool:
	var a: int = action_locked[player]
	if a == ActionDef.ACTIVE:
		return _can_use_active_raw(player)
	if a in ActionDef.DEFEND_ACTIONS and not _can_defend(player):
		return false
	if a == ActionDef.Action.SWITCH:
		if not _can_switch(player):
			return false
		var has_bench := false
		for s in range(hp[player].size()):
			if s != active_index[player] and hp[player][s] > 0:
				has_bench = true
				break
		if not has_bench:
			return false
	return usable_energy(player) >= _get_cost(player, a)


func select_action(player: int, action: int) -> bool:
	if not can_afford(player, action):
		return false
	selected_action[player] = action
	return true


## 统一回血入口（妖火：施加的下回合禁回血）。返回实际回复量（半点）。
func _heal(player: int, slot: int, amount: int) -> int:
	if turn_number == int(get_status(player, slot, "noheal_turn", -999)):
		return 0   # 妖火：施加的下回合无法回血
	var before: int = hp[player][slot]
	hp[player][slot] = mini(hp[player][slot] + amount, max_hp[player][slot])
	return hp[player][slot] - before


## 当前出战英雄的主动技是否可用（has_active + cap 未满 + 能量够 + 组件自定前置 + 锁招收口）。
func can_use_active(player: int) -> bool:
	if turn_number == action_lock_turn[player] and action_locked[player] != ActionDef.ACTIVE:
		return false   # 阖眸成夜 h17 v5：本拍被锁定在非主动技动作 → 主动技不可用（兜底攒不经此口）
	return _can_use_active_raw(player)


## 主动技可用性（不含锁招规则·供 can_use_active 与 _locked_action_doable 复用防递归）。
func _can_use_active_raw(player: int) -> bool:
	var slot: int = active_index[player]
	var sk: HeroSkill = _eff_skill(player, slot)   # 沉默 → null → 主动技不可用
	if sk == null or not sk.has_active():
		return false
	var cap: int = sk.active_per_game_cap()
	if cap >= 0 and int(get_status(player, slot, "active_uses", 0)) >= cap:
		return false
	if usable_energy(player) < sk.active_cost(self, player, slot):
		return false
	return sk.can_use_active(self, player, slot)


## 选择主动技（target = 玩家指定的目标槽，-1=未指定→由技能自行默认，如枭阳随机揪）。
func select_active(player: int, target: int = -1) -> bool:
	if not can_use_active(player):
		return false
	selected_action[player] = ActionDef.ACTIVE
	_active_target[player] = target
	return true


## 选择切换（目标必须存活、非当前出战）。切换 = 本回合的动作（占动作槽，0 能）。
func select_switch(player: int, target_slot: int) -> bool:
	if target_slot < 0 or target_slot >= hp[player].size():
		return false
	if target_slot == active_index[player] or hp[player][target_slot] <= 0:
		return false
	if not can_afford(player, ActionDef.Action.SWITCH):
		return false
	selected_action[player] = ActionDef.Action.SWITCH
	_switch_to[player] = target_slot
	return true


## 出战英雄阵亡后由玩家选替补上场。返回是否成功。
func execute_death_switch(player: int, slot: int) -> bool:
	if not pending_death_switch[player]:
		return false
	if slot < 0 or slot >= hp[player].size() or hp[player][slot] <= 0:
		return false
	active_index[player] = slot
	pending_death_switch[player] = false
	var sk: HeroSkill = _skills[player][slot]
	if sk != null:
		sk.on_switch_in(self, player, slot)
	return true


func both_ready() -> bool:
	return selected_action[0] >= 0 and selected_action[1] >= 0


# === 广寒 h16【疾风】：附加同种动作（resolve 内按 _double 处理）===

## player 队【出战】英雄是否为"疾风"型（存活）且每局 cap 未满 → 返回其槽(=active_index)，否则 -1。
## （2026-07-02 Eddy：由团队级在场收缩为出战限定——暗兔须亲自出战才能双动作，不再躲替补席给队友加倍。）
func _double_grantor(player: int) -> int:
	var s: int = active_index[player]
	if hp[player][s] <= 0:
		return -1
	var sk: HeroSkill = _skills[player][s]
	if sk != null:
		var cap: int = sk.double_action_cap()
		if cap > 0 and int(get_status(player, s, "jifeng_uses", 0)) < cap:
			return s
	return -1


## 指定动作能否"附加再做一次"：动作可双（波/大波/攒/防/大防）+ 在场有疾风(cap 未满)
## + 能量够付双份。取 action 参数（不读 selected_action）→ UI 在【提交前】可用本地待选动作校验。
func can_double_action(player: int, action: int) -> bool:
	if action < 0 or not (action in DOUBLEABLE_ACTIONS):
		return false
	if _double_grantor(player) < 0:
		return false   # 无疾风（cap 未满）→ 不可双
	return usable_energy(player) >= 2 * _get_cost(player, action)


## 当前【已提交】动作能否附加（AI / 提交后用）。
func can_double(player: int) -> bool:
	return can_double_action(player, selected_action[player])


## 本队是否可双（疾风 cap 未满）——UI 决定是否显示「附加」开关。
func has_double(player: int) -> bool:
	return _double_grantor(player) >= 0


## 本队"附加"剩余可用次数（UI 标签；= 出战疾风剩余；无返 0）。
func double_uses_left(player: int) -> int:
	var s: int = active_index[player]
	if hp[player][s] <= 0:
		return 0
	var sk: HeroSkill = _skills[player][s]
	if sk != null and sk.double_action_cap() > 0:
		return sk.double_action_cap() - int(get_status(player, s, "jifeng_uses", 0))
	return 0


## 切换"附加动作"开关（须先选好可双的主动作）。on=true 时校验 can_double。
func select_double(player: int, on: bool) -> bool:
	if on and not can_double(player):
		return false
	_double[player] = on
	return true


# === 道具（ADR-003）===
#
# 经济状态机（自动解锁/draft/补充·D5·2026-07-03 免入场税）已实装（见 _econ_unlock / use_slot / can_refill / begin_upgrade_draft 等）；give_item = 测试 / 直接给的旁路。
# 道具不占动作槽：use_item 与 select_action 正交，可在同一回合都提交。

## 给玩家一件道具（持有/可用池）。返回其在 items[player] 的索引。
func give_item(player: int, data: ItemData) -> int:
	items[player].append(data)
	return items[player].size() - 1


## 默认指向解析（§D6）：SELF→己方出战 / ENEMY→敌方出战。target_override >=0 时特指。
func _resolve_item_target(player: int, data: ItemData, target_override: int) -> int:
	if target_override >= 0:
		return target_override
	if data.target_mode == ItemData.Target.SELF:
		return active_index[player]
	return active_index[1 - player]


## 提交一次道具使用（盲选阶段·揭示前·§3A）。index = items[player] 下标。
## 不占动作槽、用时免费、用量不限。返回是否合法。
func use_item(player: int, index: int, target_override: int = -1) -> bool:
	if index < 0 or index >= items[player].size():
		return false
	var data: ItemData = items[player][index]
	if data == null or data.effect == null:
		return false
	# 封印卷轴 / 天罗地网：你的道具槽被对手封住 → 消耗一次锁、本次用道具被拒。
	if int(item_buffs[player].get("item_lock", 0)) > 0:
		item_buffs[player]["item_lock"] = int(item_buffs[player]["item_lock"]) - 1
		return false
	# 遗物（持久·每回合 tick）：激活即登记到 relics，不走一次性 item_uses。
	if bool(data.params.get("relic", false)):
		relics[player].append({data = data, state = {}})
		return true
	item_uses[player].append({
		data = data,
		when = data.resolved_when(),
		target = _resolve_item_target(player, data, target_override),
	})
	return true


# --- 本回合道具修正器累加器（_imod·transient）---

func item_mod(player: int, key: String, default: Variant = 0) -> Variant:
	return _imod[player].get(key, default)

func add_item_mod(player: int, key: String, amount: int) -> void:
	_imod[player][key] = int(_imod[player].get(key, 0)) + amount

func set_item_mod(player: int, key: String, value: Variant) -> void:
	_imod[player][key] = value


## 护身符：target_player 是否对一次 debuff/干扰免疫；是则【消耗】该次免疫并返回 true。
## 对敌 debuff 类道具（妖火/香蕉皮…）施加前调用，被免疫则不施加。
func item_debuff_blocked(target_player: int) -> bool:
	var n: int = int(_imod[target_player].get("immune", 0))
	if n > 0:
		_imod[target_player]["immune"] = n - 1
		return true
	return false


## 登记一个【动作攻击命中骑乘】（吸血鬼的獠牙/毒刺）：data 在 player 本回合动作攻击连接时触发。
func add_item_rider(player: int, data: ItemData) -> void:
	var r: Array = _imod[player].get("riders", [])
	r.append(data)
	_imod[player]["riders"] = r




# ===== 道具经济（ADR-003 §2·M1·2026-06-19；2026-07-03 经济重做=免入场税）=====
# 槽位状态机，与底层 items[]/use_item 并存（单元测试走 give_item 绕过经济）。
# 三格第 3/4/5 回合（显示回合）自动解锁，无开格步骤/费用：
#   slot0 解锁时自带随机 T1（后期改玩家自选 T1/T2 携带·PvE）；slot1/2 解锁当回合 T1 池 3 选 1。
# 统一锁定规则（明牌电报）：格里出现新道具（自带/抽/补/升级）的当回合锁定，下回合才可用。
# 使用免费一次性，用后 EMPTY；补充(1能·T1 池 3 选 1)；升级 = 就绪件花 1 能从「下一级池」3 选 1。
# 槽 dict：{state:int, item:ItemData|null, since:int(进入该态的回合), used:bool, draft:Array, upg_draft:Array}

enum SlotState { SEALED, OPENED, CHARGING, EMPTY }   # SEALED = 未到解锁回合（到点自动 → OPENED）
const SLOT_COUNT := 3
const SLOT_UNLOCK_TURN := [2, 3, 4]    # 0-indexed turn_number（= 显示回合 3/4/5·到点自动解锁）
const ITEM_REFILL_COST := 2            # 补充 1 能（= 2 半能·T1 池 3 选 1）
const UPGRADE_COST := 2                # 升级统一 1 能（T1→2 / T2→3 同价·2026-07-03；T3 泛滥再回调）
const UPGRADE_FAVORED_WEIGHT := 5.0    # 升级 3 选 1 里「预设升级款」(upgrade_to) 的相对权重（>1 → 更易出现·B2）
const DRAFT_DIM_WEIGHT := 2.0          # 抽卡 3 选 1 里维度命中我方阵容的道具相对权重（2× 封顶不叠加·T2·2026-07-04）
# 遗物效果数值（半点·从裸魔数提出集中可调）
const WEIHOUZHEN_STING_DMG := 1        # 尾后针：出战阵亡反击敌方出战 0.5 HP 真伤（通用 death_reflect 状态机制·见 _resolve_deaths）
const STARTER_ITEM_IDS := ["t1_feibiao", "t1_jiudun", "t1_lzhi_shengming"]  # slot0 自带随机池（后期改玩家自选 T1/T2 携带·PvE）


## 启用经济并初始化槽位（实战由 battle_screen 调；单元测试不调 → 槽空、不影响既有行为）。
func econ_init() -> void:
	slots = [[], []]
	for p in [0, 1]:
		# slot0 = 自带随机 T1：开局即公开亮相（明牌电报），since=解锁回合 → 解锁当回合仍锁、
		# turn_number 3(显示回合4)才 slot_ready（统一锁定规则：新道具出现回合锁定、下回合可用）。
		var sid: String = STARTER_ITEM_IDS[rng.randi() % STARTER_ITEM_IDS.size()]
		slots[p].append({state = SlotState.CHARGING, item = ItemCatalog.make(sid), since = int(SLOT_UNLOCK_TURN[0]), used = false, draft = [], upg_draft = []})
		for _s in range(SLOT_COUNT - 1):
			slots[p].append({state = SlotState.SEALED, item = null, since = -1, used = false, draft = [], upg_draft = []})
	_econ_unlock()


## 远征 PvE（任务 D·2026-07-06）：带入跨战 HP（玩家按存活序·怪物单体·余槽 0 血板凳）。
## setup 后调用（UI 只读铁律：battle_screen 不直写 hp·统一走此入口）。
func pve_apply_hp(team_hp: Array, monster_hp: int) -> void:
	for i in range(hp[0].size()):
		hp[0][i] = int(team_hp[i]) if i < team_hp.size() else 0
	hp[1][0] = maxi(1, monster_hp)
	for s in range(1, hp[1].size()):
		hp[1][s] = 0


var pve_no_econ: bool = false   # 远征 PvE：锁死局内道具经济（补充/升级/抽卡全禁·装备件只用不换）

## 远征 PvE（任务 D·2026-07-06）：装备栏道具直接入槽·不走经济状态机。
## 玩家(P0)前 N 槽 = 装备道具（CHARGING·since=-1 开局即就绪）；其余与怪物(P1)全 EMPTY
## （⚠ 用 EMPTY 非 SEALED——SEALED 会被 _econ_unlock 到点解锁触发 3 选 1 draft·PvE 无局内经济）；
## 同时置 pve_no_econ：EMPTY 槽在 PvP 语义下可花能补充 → PvE 一并锁死（can_refill/can_upgrade 收口）。
func pve_equip_init(equipped_ids: Array) -> void:
	pve_no_econ = true
	slots = [[], []]
	for p in [0, 1]:
		for _s in range(SLOT_COUNT):
			slots[p].append({state = SlotState.EMPTY, item = null, since = -1, used = false, draft = [], upg_draft = []})
	for i in range(mini(equipped_ids.size(), SLOT_COUNT)):
		slots[0][i] = {state = SlotState.CHARGING, item = ItemCatalog.make(String(equipped_ids[i])), since = -1, used = false, draft = [], upg_draft = []}


## 到点自动解锁道具格（无开格步骤/费用·2026-07-03）：SEALED + 到解锁回合 → OPENED，
## since = turn_number-1 使解锁当回合即可 3 选 1（抽后 CHARGING 锁 1 回合 → 下回合可用）。
## econ_init 与每次 resolve 末（turn_number 递增后）各调一次；econ 未启用时槽空 = no-op。
## 防御式读 state（get 缺省 CHARGING≠SEALED → 跳过）：道具测试会注入只含 item/used 的精简槽字典。
func _econ_unlock() -> void:
	for p in range(slots.size()):
		for s in range(mini(slots[p].size(), SLOT_UNLOCK_TURN.size())):
			if int(slots[p][s].get("state", SlotState.CHARGING)) == SlotState.SEALED and turn_number >= int(SLOT_UNLOCK_TURN[s]):
				slots[p][s]["state"] = SlotState.OPENED
				slots[p][s]["since"] = turn_number - 1


func slot_state(player: int, s: int) -> int:
	return int(slots[player][s]["state"])


func slot_item(player: int, s: int) -> ItemData:
	return slots[player][s]["item"]


## 槽本回合是否可用（CHARGING + 部署锁已过 + 未用过）。
func slot_ready(player: int, s: int) -> bool:
	var sl: Dictionary = slots[player][s]
	return int(sl["state"]) == SlotState.CHARGING and not bool(sl["used"]) and turn_number > int(sl["since"])


## 能否抽道具（OPENED·自动解锁当回合即可抽）。
func can_draw_slot(player: int, s: int) -> bool:
	return int(slots[player][s]["state"]) == SlotState.OPENED and turn_number > int(slots[player][s]["since"])


## 生成并返回 3 选 1 选项（存入槽供 UI 展示；同回合重复调用沿用已生成结果）。
## T2 加权抽卡池（2026-07-04）：① 3 候选互不重复 ② 维度命中我方阵容 → DRAFT_DIM_WEIGHT× 加权
## ③ 小保底：3 候选至少跨 2 个维度（全同维度时末位换抽其他维度）。
func begin_draft(player: int, s: int) -> Array:
	var sl: Dictionary = slots[player][s]
	if (sl["draft"] as Array).is_empty():
		sl["draft"] = _lineup_weighted_draft(player, _draft_pool(), 3)
	return sl["draft"]


## 抽中第 choice 个（OPENED→CHARGING·锁本回合·下回合可用）。
func pick_draft(player: int, s: int, choice: int) -> bool:
	if not can_draw_slot(player, s):
		return false
	var opts: Array = begin_draft(player, s)
	if choice < 0 or choice >= opts.size():
		return false
	var sl: Dictionary = slots[player][s]
	sl["item"] = ItemCatalog.make((opts[choice] as ItemData).item_id)   # 独立实例
	sl["state"] = SlotState.CHARGING
	sl["since"] = turn_number
	sl["draft"] = []
	sl["upg_draft"] = []   # 新件 → 旧升级候选作废
	return true


## 用某个已就绪的槽（提交到盲选 item_uses；用后标记 → 结算末置 EMPTY）。
func use_slot(player: int, s: int, target_override: int = -1) -> bool:
	if not slot_ready(player, s):
		return false
	var data: ItemData = slots[player][s]["item"]
	if data == null or data.effect == null:
		return false
	slots[player][s]["used"] = true
	if bool(data.params.get("relic", false)):
		relics[player].append({data = data, state = {}})
		return true
	item_uses[player].append({
		data = data,
		when = data.resolved_when(),
		target = _resolve_item_target(player, data, target_override),
	})
	return true


## 升级到下一级的能量成本（半能）：统一 1 能（T1→2 / T2→3 同价·2026-07-03 经济重做）。
func upgrade_cost(player: int, s: int) -> int:
	var item: ItemData = slots[player][s]["item"]
	if item == null:
		return 0
	return UPGRADE_COST


## 能否升级（就绪 + 有更高 tier 可升 + 能量够）：就绪槽的「用 or 升」二选一决策点。
## 升级 = 花能量从「下一级 tier 池」3 选 1（不再要求预设 upgrade_to —— 多数道具没有升级款；
## 预设款只是「以后加权让它更易出现」的偏好·B2）。故 T1/T2 件均可升、T3 封顶。
func can_upgrade(player: int, s: int) -> bool:
	if pve_no_econ:
		return false   # 远征 PvE：装备件只用不升（无局内经济）
	if not slot_ready(player, s):
		return false
	var item: ItemData = slots[player][s]["item"]
	return item != null and item.tier < 3 and usable_energy(player) >= upgrade_cost(player, s)


## 生成升级 3 选 1 候选（下一级 tier 池随机 3·预设 upgrade_to 款加权更易出现·见 _weighted_draft_pick）。
## 存入槽 "upg_draft" 供 UI 展示；同回合重复调用沿用已生成结果（防 reroll）。换件 / refill / 用掉时清空（见各处 upg_draft=[]）。
func begin_upgrade_draft(player: int, s: int) -> Array:
	var sl: Dictionary = slots[player][s]
	if (sl["upg_draft"] as Array).is_empty():
		var item: ItemData = sl["item"]
		var pool: Array = ItemCatalog.all_for_tier(item.tier + 1) if item != null else []
		var fav: String = item.upgrade_to if item != null else ""
		sl["upg_draft"] = _weighted_draft_pick(pool, fav, 3)
	return sl["upg_draft"]


## 加权不重复抽 n 件：预设升级款 favored_id 权重 UPGRADE_FAVORED_WEIGHT× → 更易出现但不保证（B2）。
## favored_id="" 或不在池中 → 退化为等概率随机。结果 n 个互不重复（升级 3 选 1 不出现重复款）。
func _weighted_draft_pick(pool: Array, favored_id: String, n: int) -> Array:
	var remaining: Array = pool.duplicate()
	var picks: Array = []
	var count: int = mini(n, remaining.size())
	for _k in range(count):
		var total: float = 0.0
		for it in remaining:
			total += UPGRADE_FAVORED_WEIGHT if (it as ItemData).item_id == favored_id else 1.0
		var r: float = rng.randf() * total
		var idx: int = remaining.size() - 1   # 浮点兜底（落最后一个）
		for j in range(remaining.size()):
			r -= UPGRADE_FAVORED_WEIGHT if (remaining[j] as ItemData).item_id == favored_id else 1.0
			if r <= 0.0:
				idx = j
				break
		picks.append(remaining[idx])
		remaining.remove_at(idx)
	return picks


## 选中升级候选第 choice 个：付能量（按【当前】tier 计费）→ 换成该件 → 重新锁 1 回合
## （CHARGING·下回合可用·电报·ADR D5）。取消（不调本函数）则不扣能、候选保留供再选。
func pick_upgrade(player: int, s: int, choice: int) -> bool:
	if not can_upgrade(player, s):
		return false
	var opts: Array = begin_upgrade_draft(player, s)
	if choice < 0 or choice >= opts.size():
		return false
	energy[player] -= upgrade_cost(player, s)
	var sl: Dictionary = slots[player][s]
	sl["item"] = ItemCatalog.make((opts[choice] as ItemData).item_id)
	sl["state"] = SlotState.CHARGING
	sl["since"] = turn_number      # 锁本回合 → 下回合可用
	sl["used"] = false
	sl["upg_draft"] = []
	return true


func can_refill(player: int, s: int) -> bool:
	if pve_no_econ:
		return false   # 远征 PvE：空槽不可花能补充（无局内经济）
	return int(slots[player][s]["state"]) == SlotState.EMPTY and usable_energy(player) >= ITEM_REFILL_COST


## 补充：付 1 能，EMPTY→可抽（格已在，故立即 3 选 1；返回选项供 UI；随后 pick_draft）。
func start_refill(player: int, s: int) -> Array:
	if not can_refill(player, s):
		return []
	energy[player] -= ITEM_REFILL_COST
	var sl: Dictionary = slots[player][s]
	sl["state"] = SlotState.OPENED
	sl["since"] = turn_number - 1   # 复用格→本回合即可抽
	sl["used"] = false
	sl["draft"] = []
	sl["upg_draft"] = []
	return begin_draft(player, s)


## 抽卡池 = T1 池（解锁 3 选 1 / 补充 3 选 1 均只出 T1；T2/T3 只走升级线·2026-07-03）。
func _draft_pool() -> Array:
	return ItemCatalog.all_tier1()


## 我方阵容维度集合（keys=维度名）。只认阵容标签、不认战况——每局静态，
## 杜绝「顺风加权滚雪球」（反杰弗里斯护栏·T2）。空 dimension 的英雄不计入。
func _lineup_dims(player: int) -> Dictionary:
	var dims: Dictionary = {}
	for h in heroes[player]:
		var d: String = (h as HeroData).dimension
		if d != "":
			dims[d] = true
	return dims


## 阵容加权、不重复抽 n 件（T2）。命中阵容维度的道具权重 DRAFT_DIM_WEIGHT（封顶·多英雄同维不叠加），
## 其余 1。小保底：候选全同维度时，末位换成其余维度里的加权抽（池里没有其他维度则保持原样）。
func _lineup_weighted_draft(player: int, pool: Array, n: int) -> Array:
	var dims: Dictionary = _lineup_dims(player)
	var remaining: Array = pool.duplicate()
	var picks: Array = []
	var count: int = mini(n, remaining.size())
	for _k in range(count):
		var idx: int = _weighted_dim_pick_index(remaining, dims)
		picks.append(remaining[idx])
		remaining.remove_at(idx)
	if picks.size() >= 2:
		var first_dim: String = (picks[0] as ItemData).dimension
		var all_same: bool = true
		for it in picks:
			if (it as ItemData).dimension != first_dim:
				all_same = false
				break
		if all_same:
			var alt: Array = []
			for it in remaining:
				if (it as ItemData).dimension != first_dim:
					alt.append(it)
			if not alt.is_empty():
				picks[picks.size() - 1] = alt[_weighted_dim_pick_index(alt, dims)]
	return picks


## 按维度权重从 pool 抽 1 个下标（命中 dims = DRAFT_DIM_WEIGHT·否则 1）。pool 不得为空。
func _weighted_dim_pick_index(pool: Array, dims: Dictionary) -> int:
	var total: float = 0.0
	for it in pool:
		total += DRAFT_DIM_WEIGHT if dims.has((it as ItemData).dimension) else 1.0
	var r: float = rng.randf() * total
	var idx: int = pool.size() - 1   # 浮点兜底（落最后一个）
	for j in range(pool.size()):
		r -= DRAFT_DIM_WEIGHT if dims.has((pool[j] as ItemData).dimension) else 1.0
		if r <= 0.0:
			idx = j
			break
	return idx


## 结算末：本回合用掉的槽置 EMPTY（一次性消耗）。在 resolve Phase 6 调。
func _econ_after_resolve() -> void:
	for p in [0, 1]:
		for sl in slots[p]:
			if bool(sl["used"]):
				sl["state"] = SlotState.EMPTY
				sl["item"] = null
				sl["used"] = false
				sl["upg_draft"] = []


# === 加时赛（2026-07-03 Eddy 定·Q5；2026-07-05 修订：不限回合 → 30 回合骤死裁决）===
#
# 触发（由调用方 battle_screen / run_sim 判定）：正常局平局（双方同时死光）或打满回合上限。
# 规则：双方各从队伍 3 选 1（盲选）→ 满血白板 1v1 —— 禁道具（不 econ_init）、禁英雄技能
#   （英雄数据剥离为白板克隆·纯波波攒）、被动能量与正常局一致（+1 能/回合）、
#   上限 OVERTIME_TURN_CAP=30 回合：打满 → 双方出战【同时扣血】等量（=较低者当前 HP）
#   → 低血者归零判负、等血同归 = 真平局（2026-07-05 Eddy 定·治加时再平率 52%）。

## 组一场加时赛战局（白板 1v1·满血）。选人与触发由调用方负责。
static func create_overtime(hero_a: HeroData, hero_b: HeroData, seed_value: int = 0) -> BattleCore:
	var b := BattleCore.new()
	b.setup([_vanilla_copy(hero_a)], [_vanilla_copy(hero_b)], seed_value)
	b.overtime_mode = true
	return b


## 组加时赛 3 人组（UI 场景重载用·battle_screen）：选中者白板化放 slot0（出战），其余队友白板化跟随
## ——调用方随后把 slot1/2 置 0 血躺板凳（同归余烬）→ 引擎/UI 全程走正常 3 人局、零特判。
static func overtime_roster(team: Array, pick: int) -> Array[HeroData]:
	var out: Array[HeroData] = [_vanilla_copy(team[pick])]
	for i in range(team.size()):
		if i != pick:
			out.append(_vanilla_copy(team[i]))
	return out


## 加时赛开局整备（与 overtime_roster 配套·UI 场景重载后调）：slot0 之外的白板队友置 0 血躺板凳
## （同归余烬·唯一存活=出战位）→ 引擎/UI 全程正常 3 人局零特判。状态写入收口在引擎（UI 只读铁律）。
func apply_overtime_bench() -> void:
	overtime_mode = true
	for p in [0, 1]:
		for s in range(1, hp[p].size()):
			hp[p][s] = 0


## 白板克隆：保留名字/血量/美术路径（UI 复用），剥离 hero_id 与技能描述 → 不注册技能组件、不触发校验警告。
static func _vanilla_copy(h: HeroData) -> HeroData:
	var c := HeroData.new()
	c.hero_id = ""
	c.hero_name = h.hero_name
	c.max_hp = h.max_hp
	c.skill_description = ""
	c.skill_detail = ""
	c.portrait_path = h.portrait_path
	c.skill_icon_path = ""
	c.spritesheet_path = h.spritesheet_path
	c.sprite_frames_path = h.sprite_frames_path
	c.attack_spritesheet_path = h.attack_spritesheet_path
	c.hit_spritesheet_path = h.hit_spritesheet_path
	c.defend_spritesheet_path = h.defend_spritesheet_path
	c.defeat_spritesheet_path = h.defeat_spritesheet_path
	return c


# === AI / 模拟支持（纯加法，不改任何结算行为）===
#
# clone(): 深拷当前战局供前瞻模拟（AI 枚举各动作后果）。
# legal_actions(): 枚举合法动作。apply_choice(): 按 {action,target} 分派提交。
# 三者均只读/封装既有逻辑，结算结果与手动 select_* 完全一致。

## 深拷战局。状态容器全部独立深拷；HeroData（只读资源）/ HeroSkill（无状态组件 §D2）
## 共享引用（duplicate(true) 不复制 Object）；rng 独立复制（seed+state）→ 推演不扰动本局序列。
## ⚠ 新增引擎状态字段必须三处同步：clone() / to_snapshot()+from_snapshot() / test_battle_snapshot.gd（ADR-004）。
func clone() -> BattleCore:
	var c := BattleCore.new()
	c.heroes = heroes.duplicate(true)
	c.active_index = active_index.duplicate()
	c.energy = energy.duplicate()
	c.hp = hp.duplicate(true)
	c.max_hp = max_hp.duplicate(true)
	c.shield = shield.duplicate(true)
	c.pending_damage = pending_damage.duplicate(true)
	c.statuses = statuses.duplicate(true)
	c.selected_action = selected_action.duplicate()
	c._double = _double.duplicate()
	c._switch_to = _switch_to.duplicate()
	c._forced_pull = _forced_pull.duplicate()
	c._active_target = _active_target.duplicate()
	c.pending_death_switch = pending_death_switch.duplicate()
	c._death_processed = _death_processed.duplicate(true)
	c._shuchao_procs = _shuchao_procs.duplicate()
	c._last_action = _last_action.duplicate()
	c._killer = _killer.duplicate(true)
	c.items = items.duplicate(true)
	c.item_uses = item_uses.duplicate(true)
	c.info_distortion = info_distortion.duplicate(true)
	c.item_buffs = item_buffs.duplicate(true)
	c._imod = _imod.duplicate(true)
	c.relics = relics.duplicate(true)
	c.slots = slots.duplicate(true)
	c.turn_number = turn_number
	c.game_over = game_over
	c.winner = winner
	c.overtime_mode = overtime_mode
	c.action_lock_turn = action_lock_turn.duplicate()
	c.action_locked = action_locked.duplicate()
	c.pierce_next_attack = pierce_next_attack.duplicate()
	c.pve_no_econ = pve_no_econ
	c.rng = RandomNumberGenerator.new()
	c.rng.seed = rng.seed
	c.rng.state = rng.state
	# §D2 锁死：重建【无状态】技能实例，而非 duplicate(true) 共享同一引用
	# （Array[Object].duplicate(true) 并不复制 Object，原本是浅拷）。
	# → 推演局与真实局零共享，即便将来某技能误加实例成员变量也不会破坏确定性。
	# 技能无状态，重建与共享行为等价；statuses 已在上面深拷，故不重跑 on_setup。
	c._build_skills()
	return c


# === 联机/持久化快照（联机准备批②·2026-07-12）===
#
# to_snapshot()/from_snapshot()：全量战局 ↔ 纯数据 Dictionary。
# 用途：联机断线重连/观战入场/服务端持久化/录像。设计约束：
#   - 资源引用全部降为可重建数据：HeroData→{id,name,max_hp,skill_type}（恢复优先加载
#     assets/data/heroes/<id>.tres·无资源文件=白板重建 → 测试/PvE 白板英雄同样可快照）；
#     ItemData→item_id（ItemCatalog.make 重建独立实例）。
#   - JSON 安全（网络消息可直接走文本）：数字经 JSON 往返会 int→float，恢复端 _snap_norm 归一；
#     rng seed/state 是 64 位整数 → 存字符串（JSON double 在 2^53 以上丢精度）。
#   - 版本化（网络代码规则：所有消息版本化）：SNAPSHOT_VERSION 不符拒绝恢复。
#   - 单线程使用；非热路径（仅重连/落盘时调用，允许分配）。
#   - ⚠ 新增引擎状态字段必须三处同步：clone() / 本快照对 / test_battle_snapshot.gd（ADR-004）。
#
# 用法：
#   var wire := JSON.stringify(battle.to_snapshot())      # 服务端落盘 / 发给重连客户端
#   var b := BattleCore.new()
#   if b.from_snapshot(JSON.parse_string(wire)):
#       b.select_action(0, ...)                           # 恢复后战局含随机流逐位一致，直接续打
# 行为锁定：tests/unit/battle/v4/test_battle_snapshot.gd

const SNAPSHOT_VERSION := 1
const HERO_RES_DIR := "res://assets/data/heroes/"


## 导出全量战局快照（纯数据·与本局零共享·JSON 安全）。
func to_snapshot() -> Dictionary:
	return {
		v = SNAPSHOT_VERSION,
		heroes = [_snap_pack_team(0), _snap_pack_team(1)],
		active_index = active_index.duplicate(),
		energy = energy.duplicate(),
		hp = hp.duplicate(true),
		max_hp = max_hp.duplicate(true),
		shield = shield.duplicate(true),
		pending_damage = pending_damage.duplicate(true),
		statuses = statuses.duplicate(true),
		selected_action = selected_action.duplicate(),
		switch_to = _switch_to.duplicate(),
		forced_pull = _forced_pull.duplicate(),
		active_target = _active_target.duplicate(),
		pending_death_switch = pending_death_switch.duplicate(),
		death_processed = _death_processed.duplicate(true),
		shuchao_procs = _shuchao_procs.duplicate(),
		double = _double.duplicate(),
		killer = _killer.duplicate(true),
		last_action = _last_action.duplicate(),
		items = [_snap_pack_items(items[0]), _snap_pack_items(items[1])],
		item_uses = [_snap_pack_uses(0), _snap_pack_uses(1)],
		info_distortion = info_distortion.duplicate(true),
		item_buffs = item_buffs.duplicate(true),
		imod = _imod.duplicate(true),
		relics = [_snap_pack_relics(0), _snap_pack_relics(1)],
		slots = [_snap_pack_slots(0), _snap_pack_slots(1)],
		turn_number = turn_number,
		game_over = game_over,
		winner = winner,
		overtime_mode = overtime_mode,
		action_lock_turn = action_lock_turn.duplicate(),
		action_locked = action_locked.duplicate(),
		pierce_next_attack = pierce_next_attack.duplicate(),
		pve_no_econ = pve_no_econ,
		rng_seed = str(rng.seed),
		rng_state = str(rng.state),
	}


## 从快照恢复战局（覆盖本实例全部状态·技能组件重建）。版本不符返回 false 且不动现状。
func from_snapshot(d: Dictionary) -> bool:
	if int(d.get("v", -1)) != SNAPSHOT_VERSION:
		push_warning("BattleCore.from_snapshot: 快照版本不符 %s（期望 %d）" % [d.get("v"), SNAPSHOT_VERSION])
		return false
	var s: Dictionary = _snap_norm(d)
	heroes = [_snap_unpack_team(s["heroes"][0]), _snap_unpack_team(s["heroes"][1])]
	active_index.assign(s["active_index"])
	energy.assign(s["energy"])
	hp = s["hp"]
	max_hp = s["max_hp"]
	shield = s["shield"]
	pending_damage = s["pending_damage"]
	statuses = s["statuses"]
	selected_action.assign(s["selected_action"])
	_switch_to.assign(s["switch_to"])
	_forced_pull.assign(s["forced_pull"])
	_active_target.assign(s["active_target"])
	pending_death_switch.assign(s["pending_death_switch"])
	_death_processed = s["death_processed"]
	_shuchao_procs.assign(s["shuchao_procs"])
	_double.assign(s["double"])
	_killer = s["killer"]
	_last_action.assign(s["last_action"])
	items = [_snap_unpack_items(s["items"][0]), _snap_unpack_items(s["items"][1])]
	item_uses = [_snap_unpack_uses(s["item_uses"][0]), _snap_unpack_uses(s["item_uses"][1])]
	var idist: Array[Dictionary] = []
	idist.assign(s["info_distortion"])
	info_distortion = idist
	var ibuff: Array[Dictionary] = []
	ibuff.assign(s["item_buffs"])
	item_buffs = ibuff
	_imod = s["imod"]
	relics = [_snap_unpack_relics(s["relics"][0]), _snap_unpack_relics(s["relics"][1])]
	slots = [_snap_unpack_slots(s["slots"][0]), _snap_unpack_slots(s["slots"][1])]
	turn_number = int(s["turn_number"])
	game_over = bool(s["game_over"])
	winner = int(s["winner"])
	overtime_mode = bool(s["overtime_mode"])
	action_lock_turn.assign(s["action_lock_turn"])
	action_locked.assign(s["action_locked"])
	pierce_next_attack.assign(s["pierce_next_attack"])
	pve_no_econ = bool(s["pve_no_econ"])
	rng = RandomNumberGenerator.new()
	rng.seed = String(s["rng_seed"]).to_int()    # ⚠ 先 seed 后 state（设 seed 会重置 state）
	rng.state = String(s["rng_state"]).to_int()
	_build_skills()
	return true


## JSON 往返归一：float 整数值还原为 int（JSON 无整数类型），数组/字典递归。深拷副本，不动入参。
static func _snap_norm(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			return int(v) if is_equal_approx(v, roundf(v)) else v
		TYPE_ARRAY:
			var oa: Array = []
			for e in v:
				oa.append(_snap_norm(e))
			return oa
		TYPE_DICTIONARY:
			var od: Dictionary = {}
			for k in v:
				od[k] = _snap_norm(v[k])
			return od
	return v


func _snap_pack_team(p: int) -> Array:
	var out: Array = []
	for h in heroes[p]:
		var hd: HeroData = h
		out.append({id = hd.hero_id, name = hd.hero_name, max_hp = hd.max_hp, skill_type = int(hd.skill_type)})
	return out


## 英雄恢复：优先资源文件（正式英雄全量字段）；无文件=白板重建（测试/PvE 白板·战斗所需四字段足够）。
static func _snap_unpack_team(arr: Array) -> Array:
	var team: Array = []
	for hd in arr:
		var id: String = String(hd["id"])
		var path: String = HERO_RES_DIR + id + ".tres"
		if ResourceLoader.exists(path):
			team.append(load(path))
		else:
			var h := HeroData.new()
			h.hero_id = id
			h.hero_name = String(hd.get("name", id))
			h.max_hp = int(hd.get("max_hp", 5))
			h.skill_type = int(hd.get("skill_type", 0)) as HeroData.SkillType
			team.append(h)
	return team


static func _snap_item_id(it: ItemData) -> String:
	return "" if it == null else it.item_id


static func _snap_item_make(id: String) -> ItemData:
	return null if id.is_empty() else ItemCatalog.make(id)


static func _snap_pack_items(arr: Array) -> Array:
	var out: Array = []
	for it in arr:
		out.append(_snap_item_id(it))
	return out


static func _snap_unpack_items(arr: Array) -> Array:
	var out: Array = []
	for id in arr:
		out.append(_snap_item_make(String(id)))
	return out


func _snap_pack_uses(p: int) -> Array:
	var out: Array = []
	for u in item_uses[p]:
		out.append({id = _snap_item_id(u["data"]), when = int(u["when"]), target = int(u["target"])})
	return out


static func _snap_unpack_uses(arr: Array) -> Array:
	var out: Array = []
	for u in arr:
		out.append({data = _snap_item_make(String(u["id"])), when = int(u["when"]), target = int(u["target"])})
	return out


func _snap_pack_relics(p: int) -> Array:
	var out: Array = []
	for r in relics[p]:
		out.append({id = _snap_item_id(r["data"]), state = (r["state"] as Dictionary).duplicate(true)})
	return out


static func _snap_unpack_relics(arr: Array) -> Array:
	var out: Array = []
	for r in arr:
		out.append({data = _snap_item_make(String(r["id"])), state = r["state"]})
	return out


func _snap_pack_slots(p: int) -> Array:
	var out: Array = []
	for sl in slots[p]:
		out.append({state = int(sl["state"]), item = _snap_item_id(sl["item"]), since = int(sl["since"]),
			used = bool(sl["used"]), draft = _snap_pack_items(sl["draft"]), upg_draft = _snap_pack_items(sl["upg_draft"])})
	return out


static func _snap_unpack_slots(arr: Array) -> Array:
	var out: Array = []
	for sl in arr:
		out.append({state = int(sl["state"]), item = _snap_item_make(String(sl["item"])), since = int(sl["since"]),
			used = bool(sl["used"]), draft = _snap_unpack_items(sl["draft"]), upg_draft = _snap_unpack_items(sl["upg_draft"])})
	return out


## 枚举该玩家当前所有合法动作。返回 Array[{action:int, target:int}]，
## target 于 SWITCH=己方替补槽、于带敌方目标的 ACTIVE（枭阳 h21）=敌方替补槽，其余 -1。
## CHARGE 恒合法 → 列表非空。
func legal_actions(player: int) -> Array:
	var out: Array = []
	for a in [ActionDef.Action.CHARGE, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND,
			ActionDef.Action.BIG_ATTACK, ActionDef.Action.BIG_DEFEND]:
		if can_afford(player, a):
			out.append({action = a, target = -1})
	if can_afford(player, ActionDef.Action.SWITCH):
		for t in living_reserves(player):
			out.append({action = ActionDef.Action.SWITCH, target = t})
	if can_use_active(player):
		var ask: HeroSkill = _skills[player][active_index[player]]
		if ask != null and ask.active_needs_enemy_target():
			# 带敌方目标的主动技（枭阳 h21 调虎离山）：逐个敌方存活替补枚举成独立选项 →
			# AI 搜索自己挑最优揪谁（2026-07-05 批③④：旧枚举只有 target=-1=随机揪，
			# 随机可能拽出满血坦克帮倒忙 → 搜索学会不按 = 用后率 0.27 的病根）。
			for et in living_reserves(1 - player):
				out.append({action = ActionDef.ACTIVE, target = et})
		else:
			out.append({action = ActionDef.ACTIVE, target = -1})
	return out


## 按 {action,target} 提交该玩家动作（封装 select_* 分派）。返回是否合法成功。
func apply_choice(player: int, choice: Dictionary) -> bool:
	var a: int = int(choice["action"])
	if a == ActionDef.ACTIVE:
		return select_active(player, int(choice.get("target", -1)))
	if a == ActionDef.Action.SWITCH:
		return select_switch(player, int(choice["target"]))
	var ok: bool = select_action(player, a)
	if ok and bool(choice.get("double", false)):
		select_double(player, true)   # 疾风：附加同种动作（select_double 内部 can_double 校验·不合法则忽略）
	return ok


# === resolve ===
#
# 保留 v3 同时独立结算（B-001/2/3）：双方攻击各自走一遍管线、不抵消。
# 切换采用【甲】时机（ADR-002 Q1 / 2026-05-25 Eddy 裁定）：切换先于伤害结算，
#   攻击打到换【上来】的新英雄 → 切换 = 可垫刀/调度的防御工具。

func resolve() -> Dictionary:
	var events: Array = []

	# Phase 0.3: 沉默换位（烛阴 h17【镇压】）——被沉默英雄(silenced>0)的技能槽临时置 null，
	#   借引擎全程 null-check 统一收口其【所有 hook】(=unique 失效)。resolve 末还原 + 递减时长。
	#   只递减本回合生效过的（cast 当回合 silenced 在本 swap 之后才写入 → 不计 → 恰好 2 个完整回合）。
	var _silenced_swap: Array = []
	for sp in [0, 1]:
		for ss in range(_skills[sp].size()):
			if int(get_status(sp, ss, "silenced", 0)) > 0 and _skills[sp][ss] != null:
				_silenced_swap.append([sp, ss, _skills[sp][ss]])
				_skills[sp][ss] = null

	# Phase 0.4: 龙息力竭（上回合大波被大防挡下）→ 本回合强制 CHARGE（喘息·失这次动作选择）
	for p in [0, 1]:
		if bool(item_buffs[p].get("exhausted_next", false)):
			item_buffs[p].erase("exhausted_next")
			selected_action[p] = ActionDef.Action.CHARGE
			events.append({id = "exhausted", player = p})

	# Phase 1: guard 未选动作 / 被禁动作 → CHARGE（延续 v3 B-004）
	for p in [0, 1]:
		if selected_action[p] < 0:
			push_warning("BattleCore.resolve(): P%d 未选动作，fallback CHARGE" % (p + 1))
			selected_action[p] = ActionDef.Action.CHARGE

	var a: Array[int] = [selected_action[0], selected_action[1]]
	_shuchao_procs = [0, 0]
	for p in [0, 1]:
		for s in range(_killer[p].size()):
			_killer[p][s] = -1

	# Phase 0: 取出【本回合到期】的延迟伤害账目并清零（妖火/藤蔓上回合挂的债）。
	#   ⚠ 2026-07-04 拆两步：此处只记账、结算延后到 Phase IS.5（道具相位之后）——
	#   让当回合道具修正（周天罡气免疫）能作用于它；本回合道具新挂的债不在账上（保持"下回合生效"语义）。
	#   旧单步版在 _imod 重置前结算、读的是上一回合残留修正器（隐患一并修掉）。
	var due_damage: Array = [[], []]
	for p in [0, 1]:
		for s in range(hp[p].size()):
			due_damage[p].append(pending_damage[p][s])
			pending_damage[p][s] = 0

	# Phase IS: 道具 S 相位（ADR-003 D3）。重置本回合修正器 → 注入跨回合 buff →
	#   用道具者先清旧信息扭曲 → setup_pre(免疫/信息·先于 debuff) → apply_pre(自身向/对敌/动作修正器)。
	_imod = [{}, {}]
	for p in [0, 1]:
		if item_buffs[p].has("next_atk_bonus"):
			add_item_mod(p, "atk_bonus", int(item_buffs[p]["next_atk_bonus"]))
			item_buffs[p].erase("next_atk_bonus")
		if item_buffs[p].has("next_armor"):
			shield[p][active_index[p]] += int(item_buffs[p]["next_armor"])
			item_buffs[p].erase("next_armor")
		if item_buffs[p].has("next_energy_penalty"):
			energy[p] = maxi(0, energy[p] - int(item_buffs[p]["next_energy_penalty"]))
			item_buffs[p].erase("next_energy_penalty")
		if item_uses[p].size() > 0:
			info_distortion[p] = {}
	for p in [0, 1]:
		for use_s in item_uses[p]:
			use_s["data"].effect.setup_pre(self, p, use_s["data"])
	for p in [0, 1]:
		for use_a in item_uses[p]:
			if int(use_a["when"]) == ItemData.Seq.PRE:
				use_a["data"].effect.apply_pre(self, p, int(use_a["target"]), use_a["data"])
	# 遗物·Phase IS：注入本回合被动修正器（_imod）。新激活的遗物本回合也在此生效。
	for p in [0, 1]:
		for relic in relics[p]:
			relic["data"].effect.relic_pre(self, p, relic["data"], relic["state"])

	# Phase IS.5: 结算 Phase 0 记下的到期延迟伤害（本回合道具新挂的债不在账上·下回合才生效）。
	for p in [0, 1]:
		for s in range(due_damage[p].size()):
			var owed: int = int(due_damage[p][s])
			if owed > 0:
				if damage_immune(p):   # 周天罡气：本回合到期的延迟伤害被免掉（不顺延）
					continue
				hp[p][s] -= owed
				events.append({id = "deferred_damage", player = p, slot = s, amount = owed})

	# Phase 2: 扣能量 / 攒能量 / 主动技执行（道具：省力咒省能 / 分神铃铛削攒）
	for p in [0, 1]:
		energy[p] -= maxi(0, _get_cost(p, a[p]) - int(item_mod(p, "cost_save", 0)) + int(item_mod(p, "cost_add", 0)))
		if a[p] == ActionDef.Action.CHARGE:
			var gain: int = ActionDef.BASE_ACTION_DEF[ActionDef.Action.CHARGE]["energy_gain"]
			gain = maxi(0, gain - int(item_mod(p, "charge_penalty", 0)))
			_gain_energy(p, gain)
			events.append({id = "charge_gain", player = p, amount = gain})
		elif a[p] == ActionDef.ACTIVE:
			# 扣能由上面的 _get_cost 完成；cap 计数 + 事件在此；effect 执行延后到 Phase 2.6（切换之后）。
			var slot: int = active_index[p]
			var sk: HeroSkill = _skills[p][slot]
			if sk != null:
				set_status(p, slot, "active_uses", int(get_status(p, slot, "active_uses", 0)) + 1)
				events.append({id = "active_used", player = p, slot = slot})
		# 附加同种动作（疾风 h16）——付第二份能；攒额外再产一次能（攻击第二段在 Phase 3+4 挂 hitlist）。
		if _double[p]:
			var g: int = _double_grantor(p)
			if a[p] in DOUBLEABLE_ACTIONS and g >= 0:
				set_status(p, g, "jifeng_uses", int(get_status(p, g, "jifeng_uses", 0)) + 1)
				energy[p] -= _get_cost(p, a[p])   # 第二份按原始费用（不重复享道具折扣）
				if a[p] == ActionDef.Action.CHARGE:
					var gd: int = ActionDef.BASE_ACTION_DEF[ActionDef.Action.CHARGE]["energy_gain"]
					_gain_energy(p, gd)
					events.append({id = "charge_gain", player = p, amount = gd})
				events.append({id = "jifeng_double", player = p, action = a[p]})
			else:
				_double[p] = false   # 非法双动作（不可双 / 无疾风）→ 撤销，Phase 3+4 不再 double

	# Phase 2.5: 切换（甲时机，先于伤害）→ 攻击将打到换上来的新英雄
	for p in [0, 1]:
		if a[p] == ActionDef.Action.SWITCH:
			if int(item_mod(p, "no_switch", 0)) > 0:
				events.append({id = "switch_locked", player = p})
				continue
			_do_switch(p, events)

	# Phase 2.55: 打神鞭强制切换（forced_switch 由道具在 apply_pre 设·指向某存活替补槽）。
	#   仅当该方未主动切换、且未被定身（no_switch）时触发；走 _perform_switch → 触发娄金穷追。
	for p in [0, 1]:
		var fs: int = int(item_mod(p, "forced_switch", -1))
		if fs >= 0 and a[p] != ActionDef.Action.SWITCH and int(item_mod(p, "no_switch", 0)) == 0 and fs < hp[p].size() and hp[p][fs] > 0:
			_perform_switch(p, active_index[p], fs, events)

	# Phase 2.6: 即时型主动技执行（在切换之后 → 命中对手 post-switch 出战位）
	for p in [0, 1]:
		if a[p] == ActionDef.ACTIVE:
			var sk: HeroSkill = _skills[p][active_index[p]]
			if sk != null and not sk.active_is_attack():
				sk.execute_active(self, p, active_index[p])

	# Phase 2.7: 枭阳 h21【调虎离山】强制揪人 —— execute_active 设的 _forced_pull[受害方]
	#   在此执行（切换之后、伤害之前）→ 被揪英雄成为对手出战、本回合攻击落它身上、原出战下场触发
	#   我方 on_enemy_switch_out（光狗穷追）。与打神鞭强制切换同语义、独立计揪。
	for p in [0, 1]:
		var pull: int = _forced_pull[p]
		if pull >= 0 and pull < hp[p].size() and hp[p][pull] > 0 and pull != active_index[p]:
			_perform_switch(p, active_index[p], pull, events)
		_forced_pull[p] = -1

	# Phase 3+4: 同时独立结算（含道具伤害 hit·ADR-003 D3）。先把双方完整出伤 hit-list 对快照
	# 算好（动作前道具 hit → 动作攻击 → 动作后道具 hit），再一起施加 → 保持 B-001/2/3 跨玩家同时。
	var hitlists: Array = [[], []]
	for p in [0, 1]:
		var aslot: int = active_index[p]
		# 1) 动作【前】道具自身伤害 hit（生锈飞镖/闪电/幸运四叶草）
		for use_h in item_uses[p]:
			if int(use_h["when"]) == ItemData.Seq.PRE:
				for ih in use_h["data"].effect.hits(self, p, int(use_h["target"]), use_h["data"]):
					hitlists[p].append(ih)
		# 2) 动作攻击（基础 / 攻击型主动技）+ 道具修正器（先手·赌徒+ / 香蕉皮- / 破盾咒穿透 / 赌徒落空）
		var nullified: bool = bool(item_mod(p, "atk_nullify", false))
		# 焚天火兆 h22 v3：攻击落空（草人 atk_nullify）也交掉火兆——反制链保留（2026-07-06 批④）。
		if nullified and (ActionDef.is_attack(a[p]) or a[p] == ActionDef.ACTIVE) and pierce_next_attack[p]:
			pierce_next_attack[p] = false
		if not nullified and ActionDef.is_attack(a[p]):
			var dmg: int = maxi(_calc_outgoing(p, a[p]) + int(item_mod(p, "atk_bonus", 0)) - int(item_mod(p, "atk_penalty", 0)), 0)
			dmg *= maxi(1, int(item_mod(p, "atk_mult", 1)))
			var kind: int = a[p]
			var pen: int = ActionDef.base_penetration(a[p])
			var ksk: HeroSkill = _skills[p][aslot]
			if ksk != null:
				kind = ksk.override_attack_kind(a[p], self, p, aslot)
				pen = ksk.attack_penetration(ActionDef.base_penetration(kind), a[p], self, p, aslot)
			var ipen: int = int(item_mod(p, "atk_pen", -1))
			if ipen >= 0:
				pen = ipen
			if pierce_next_attack[p]:
				pen = maxi(pen, ActionDef.Pen.PIERCE_BIGDEF)   # 火兆兑现（Pen 枚举有序·真伤不降档）
				pierce_next_attack[p] = false                  # 兑现即消（疾风双发复制 hit=两段同穿）
			if dmg > 0:
				var hit := {damage = dmg, kind = kind, pen = pen, riders = item_mod(p, "riders", []), action = true, active = false}
				hitlists[p].append(hit)
				if _double[p] and a[p] in DOUBLEABLE_ACTIONS:   # 疾风：附加同一攻击再打一次
					hitlists[p].append(hit.duplicate(true))
		elif not nullified and a[p] == ActionDef.ACTIVE:
			var sk: HeroSkill = _skills[p][aslot]
			if sk != null and sk.active_is_attack():
				var akind: int = sk.active_attack_kind()
				var admg: int = maxi(_apply_team_outgoing(sk.active_attack_damage(self, p, aslot), akind, p, aslot) + int(item_mod(p, "atk_bonus", 0)) - int(item_mod(p, "atk_penalty", 0)), 0)
				admg *= maxi(1, int(item_mod(p, "atk_mult", 1)))
				var apen: int = sk.attack_penetration(ActionDef.base_penetration(akind), ActionDef.ACTIVE, self, p, aslot)
				var ipen2: int = int(item_mod(p, "atk_pen", -1))
				if ipen2 >= 0:
					apen = ipen2
				if pierce_next_attack[p]:
					apen = maxi(apen, ActionDef.Pen.PIERCE_BIGDEF)   # 火兆兑现（攻击型主动技同属"我方下一次攻击"）
					pierce_next_attack[p] = false
				if admg > 0:
					hitlists[p].append({damage = admg, kind = akind, pen = apen, riders = item_mod(p, "riders", []), action = true, active = true})
		# 3) 动作【后】道具自身伤害 hit（T1 暂无）
		for use_h2 in item_uses[p]:
			if int(use_h2["when"]) == ItemData.Seq.POST:
				for ih2 in use_h2["data"].effect.hits(self, p, int(use_h2["target"]), use_h2["data"]):
					hitlists[p].append(ih2)
	# 施加：值已对快照算好 → 跨玩家同时；己方 hit-list 按序施加（动作前道具 → 动作 → 动作后道具）。
	for p in [0, 1]:
		for h in hitlists[p]:
			var riders: Array = h.get("riders", [])
			var hsrc: String = "action" if bool(h.get("action", false)) else "item"
			var dealt: int = _apply_damage(1 - p, int(h["damage"]), p, int(h["kind"]), int(h["pen"]), a[1 - p], events, riders, hsrc)
			if bool(h.get("active", false)):
				var sk2: HeroSkill = _skills[p][active_index[p]]
				if sk2 != null and sk2.active_is_attack():
					sk2.on_active_attack_resolved(self, p, active_index[p], dealt)

	# Phase 5: 死亡结算 + 强制切换 + 胜负
	_resolve_deaths(a, events)

	# Phase 5.5: 回合结算末 hook（on_resolve_end）
	for p in [0, 1]:
		var s: int = active_index[p]
		if hp[p][s] > 0:
			var sk: HeroSkill = _skills[p][s]
			if sk != null:
				sk.on_resolve_end(self, p, s)

	# Phase 5.6: 牧养（光版鬼金 h08）——鬼金【出战】(存活) → 你方存活【替补席】英雄每回合回 reserve_heal 半点。
	#   鬼金站前线牧养、出战英雄(含鬼金自己)不回；走 _heal（尊重妖火禁回血、封顶 max_hp）。
	#   （2026-07-02 Eddy：由在场收缩为出战限定——鬼金须亲自出战才牧养，不再躲替补席续航。）
	for p in [0, 1]:
		var act: int = active_index[p]
		var msk: HeroSkill = _skills[p][act]
		var rheal := 0
		if hp[p][act] > 0 and msk != null:
			rheal = msk.reserve_heal_per_turn()
		if rheal > 0:
			for s in range(hp[p].size()):
				if s != act and hp[p][s] > 0:
					var got: int = _heal(p, s, rheal)
					if got > 0:
						events.append({id = "muyang_heal", player = p, slot = s, amount = got})

	# Phase 5.7: 敌方重复动作产能（房日 h04【玉魄乘隙】·重做 2026-07-04）——房日【出战】(存活) 且
	#   敌方本回合动作与其上回合相同 → 己方团队能量 +enemy_repeat_energy 半能。
	#   逐回合判定（敌方换动作即断供）；第 1 回合无上回合(_last_action=-1)不触发；
	#   被迫动作（力竭强制攒 / 被锁切换后连防等）也算重复；道具不是动作、不参与比对。
	#   沉默自动失效（Phase 0.3 已把 _skills 置 null、Phase 6 末才还原）。
	for p in [0, 1]:
		var foe: int = 1 - p
		if _last_action[foe] >= 0 and a[foe] == _last_action[foe]:
			var ract: int = active_index[p]
			var rsk: HeroSkill = _skills[p][ract]
			if hp[p][ract] > 0 and rsk != null:
				var rgain: int = rsk.enemy_repeat_energy()
				if rgain > 0:
					_gain_energy(p, rgain)
					events.append({id = "repeat_energy", player = p, amount = rgain})

	# Phase 6: cleanup
	# 遗物·Phase 6：每回合末 tick（产出/计数/充能；读 selected_action 判断本回合是否攻击）。
	#   返回 false 的遗物移除（碎/耗尽）。在被动能量前结算，故遗物产能也享受不到/不影响被动。
	for p in [0, 1]:
		var kept_relics: Array = []
		for relic in relics[p]:
			if bool(relic["data"].effect.relic_end(self, p, relic["data"], relic["state"])):
				kept_relics.append(relic)
		relics[p] = kept_relics
	# 被动能量 +1/回合（A2 引入·2026-06-24 去除·2026-07-03 恢复——sim 实锤攒-only 下最优解=互龟死锁）。
	for p in [0, 1]:
		_gain_energy(p, ActionDef.PASSIVE_ENERGY_GAIN, false)   # 被动收入不吃囤鼠加成（2026-07-04）
	# 沉默还原 + 递减时长（烛阴 h17【镇压】；只递减本回合生效过的，见 Phase 0.3）。
	for sw in _silenced_swap:
		_skills[sw[0]][sw[1]] = sw[2]
		set_status(sw[0], sw[1], "silenced", maxi(0, int(get_status(sw[0], sw[1], "silenced", 0)) - 1))
	_econ_after_resolve()
	_last_action = [a[0], a[1]]
	turn_number += 1
	_econ_unlock()   # 到点自动解锁道具格（新回合的选择阶段即可 3 选 1）
	# 加时骤死裁决（2026-07-05 Eddy 定·任务5）：打满 OVERTIME_TURN_CAP 回合仍未分出 →
	#   双方出战英雄【同时扣血】等量（=较低者当前 HP）：低血者归零判负、等血同归 = 真平。
	#   等价于"比剩余 HP、相等真平"；以同时扣血落账 → UI 沿用正常掉血/死亡演出、零特判。
	if overtime_mode and not game_over and turn_number >= OVERTIME_TURN_CAP:
		var oa: int = active_index[0]
		var ob: int = active_index[1]
		var drain: int = mini(hp[0][oa], hp[1][ob])
		hp[0][oa] -= drain
		hp[1][ob] -= drain
		events.append({id = "overtime_sudden_death", drain = drain})
		var od0 := alive_count(0) == 0
		var od1 := alive_count(1) == 0
		if od0 and od1:
			game_over = true
			winner = WINNER_DRAW
			events.append({id = "draw"})
		elif od1:
			game_over = true
			winner = WINNER_P1
			events.append({id = "victory", winner = WINNER_P1})
		elif od0:
			game_over = true
			winner = WINNER_P2
			events.append({id = "victory", winner = WINNER_P2})
	var result := {
		p1_hp = current_hp(0), p2_hp = current_hp(1),
		p1_energy = energy[0], p2_energy = energy[1],
		p1_action = a[0], p2_action = a[1],
		events = events, game_over = game_over, winner = winner,
		turn = turn_number,
	}
	selected_action = [-1, -1]
	_switch_to = [-1, -1]
	_active_target = [-1, -1]
	_double = [false, false]
	item_uses = [[], []]
	return result


func _do_switch(player: int, events: Array) -> void:
	_perform_switch(player, active_index[player], _switch_to[player], events)


## 执行切换：离场 hook → 对手 on_enemy_switch_out（h11 穷追）→ 改 active → 入场 hook。
## _do_switch（动作槽切换）与 free_switch（h07 免费切）共用。
func _perform_switch(player: int, from_slot: int, to_slot: int, events: Array) -> void:
	# 防御：调用方已校验，这里再挡一次非法目标
	if to_slot < 0 or to_slot == from_slot or to_slot >= hp[player].size() or hp[player][to_slot] <= 0:
		return

	var leaving: HeroSkill = _skills[player][from_slot]
	if leaving != null:
		leaving.on_switch_out(self, player, from_slot)

	var opp: int = 1 - player
	var opp_active: HeroSkill = _skills[opp][active_index[opp]]
	if opp_active != null:
		opp_active.on_enemy_switch_out(from_slot, self, opp, active_index[opp])

	active_index[player] = to_slot
	set_status(player, from_slot, "vuln", 0)   # 罪已昭（触邪 h20）：易伤印随出战英雄换下场清除
	events.append({id = "switch", player = player, from_to = [from_slot, to_slot]})

	var entering: HeroSkill = _skills[player][to_slot]
	if entering != null:
		entering.on_switch_in(self, player, to_slot)

	# 遗物·登场 hook：本方遗物在此响应"切换登场"（夜明珠 = 登场者攻击加成 + 登场冲撞）。A4：由 core 硬编码搬入遗物 effect。
	for relic in relics[player]:
		relic["data"].effect.relic_on_switch_in(self, player, to_slot, relic["data"], relic["state"], events)


## h07 当先：免费切换（不占动作槽；星日 free_switch_cap 默认 -1 = 不限次）。在【选择阶段】调用：
## 立即换人 + 计 cap，不设 selected_action，之后玩家照常为新出战英雄选一个动作。
## 二元设计："涉及马的切换"都免动作槽 = 起点（马在场→重定位下场）或终点（顶马上场）任一为星日即免费。

## 指定槽位的英雄当前能否提供免费切换（has_free_switch + 该英雄 cap 未满）。
func _grants_free_switch(player: int, slot: int) -> bool:
	var sk: HeroSkill = _skills[player][slot]
	if sk == null or not sk.has_free_switch():
		return false
	var cap: int = sk.free_switch_cap()
	if cap >= 0 and int(get_status(player, slot, "dangxian_uses", 0)) >= cap:
		return false
	return true


## 切换到 target 是否免动作槽：起点（出战）或终点（target）任一英雄提供免费切换 → true 走 free_switch。
func is_free_switch_target(player: int, target: int) -> bool:
	if target < 0 or target >= hp[player].size() or target == active_index[player] or hp[player][target] <= 0:
		return false
	if not _can_switch(player):
		return false   # 缠绕：暗蛇也锁星日的免费切换
	return _grants_free_switch(player, active_index[player]) or _grants_free_switch(player, target)


func free_switch(player: int, target: int) -> bool:
	if not is_free_switch_target(player, target):
		return false
	# cap 计在"提供"免费切换的英雄上：起点（马在场重定位）优先，否则终点（顶马上场）。
	var grantor: int = active_index[player] if _grants_free_switch(player, active_index[player]) else target
	set_status(player, grantor, "dangxian_uses", int(get_status(player, grantor, "dangxian_uses", 0)) + 1)
	var ev: Array = []
	_perform_switch(player, active_index[player], target, ev)
	return true


## 星日登场冲撞：对敌方出战造成 0.5 冲撞伤，走完整 on-hit 管线（引爆毒 / 喂剑气）。
## 用 PIERCE_BIGDEF 让冲撞无视防御直接连接（登场突袭）；事件用本地数组（不并入 resolve 事件流）。
func chongzhuang(attacker_player: int) -> void:
	var opp: int = 1 - attacker_player
	if hp[opp][active_index[opp]] <= 0:
		return
	var ev: Array = []
	_apply_damage(opp, CHONGZHUANG_DAMAGE, attacker_player, ActionDef.Action.ATTACK, ActionDef.Pen.PIERCE_BIGDEF, ActionDef.Action.CHARGE, ev)
	note_combo_proc(attacker_player)   # 鼠潮：星日登场冲撞 = 一次 combo proc


## 把伤害"踏/溅"到 victim_player 随机一名存活替补（乌骓 h19 践踏溢出用·shield 先吸·触发 on_self_damaged·2026-07-01 由"最高血"改随机）。
func _splash_to_reserve(victim_player: int, dmg: int) -> void:
	if dmg <= 0 or damage_immune(victim_player):   # 周天罡气：溅射也免
		return
	var candidates: Array[int] = []
	for s in range(hp[victim_player].size()):
		if s != active_index[victim_player] and hp[victim_player][s] > 0:
			candidates.append(s)
	if candidates.is_empty():
		return   # 无存活替补 → 溢出无处可去
	var target: int = candidates[rng.randi() % candidates.size()]
	var d: int = dmg
	if shield[victim_player][target] > 0:
		var absorbed: int = mini(shield[victim_player][target], d)
		shield[victim_player][target] -= absorbed
		d -= absorbed
	if d <= 0:
		return
	hp[victim_player][target] -= d
	var sk: HeroSkill = _skills[victim_player][target]
	if sk != null:
		sk.on_self_damaged(self, victim_player, target, d, 1 - victim_player)


## 找 player 替补席可用的「顶替承伤」守护者（天狗 h23：is_lethal_guardian + 每局 < HUZHU_CAP 次）；无则 -1。
func _find_lethal_guardian(player: int) -> int:
	for s in range(hp[player].size()):
		if s == active_index[player] or hp[player][s] <= 0:
			continue
		var sk: HeroSkill = _skills[player][s]
		if sk != null and sk.is_lethal_guardian() and int(get_status(player, s, "huzhu_uses", 0)) < HUZHU_CAP:
			return s
	return -1


## 计算 player 本次攻击的造成伤害（半点）。
## 出伤 = 基础 → 出战英雄 modify_outgoing_damage → 全队 modify_team_outgoing_damage（团队层 buff）。
func _calc_outgoing(player: int, action: int) -> int:
	var slot: int = active_index[player]
	var dmg := ActionDef.get_base_damage(action)
	var skill: HeroSkill = _skills[player][slot]
	if skill != null:
		dmg = skill.modify_outgoing_damage(dmg, action, self, player, slot)
	return _apply_team_outgoing(dmg, action, player, slot)


## 团队层出伤修正：扫攻击方全队（含替补），让团队 buff 源生效（modify_team_outgoing_damage hook）。
## 基础攻击与攻击型主动技命中前都会过本管线。attacker_slot = 发起攻击的出战英雄槽。
func _apply_team_outgoing(dmg: int, action: int, player: int, attacker_slot: int) -> int:
	for s in range(heroes[player].size()):
		var tsk: HeroSkill = _skills[player][s]
		if tsk != null:
			dmg = tsk.modify_team_outgoing_damage(dmg, action, self, player, attacker_slot, player, s)
	return dmg


## 技能/反击类「管线打击」公共入口（h14 反震·h23 御凶反击等）：走完整 _apply_damage——
## def_action=CHARGE 视作不可挡（反击语义），毒引爆/护盾/护主/on-hit 原语链全生效。返回实际落 HP 半点。
func strike(target_player: int, raw: int, attacker_player: int, pen: int, events: Array = []) -> int:
	return _apply_damage(target_player, raw, attacker_player, ActionDef.Action.ATTACK, pen, ActionDef.Action.CHARGE, events)


## 伤害管线 (§D4)：防御门 → 中毒引爆 → 受伤 hook(平减) → 护盾 → 落 HP → on-hit 触发。
## 返回实际落在 HP 上的伤害（半点），供攻击型主动技回调使用。
## src = 本次 hit 的来源标签（"action"=动作攻击/技能·"item"=道具 hit）——只写进事件供统计（sim 道具伤害占比），不影响结算。
## 周天罡气（t3_yiqi·2026-07-04 重做）：该方本回合是否"无敌"——免疫一切【敌源】伤害
## （动作攻击/道具直伤/延迟灼烧/溅射/穷追/反震/冲撞/死亡反击）。自付代价（凶药）不算"受到伤害"、不拦。
func damage_immune(player: int) -> bool:
	return int(item_mod(player, "damage_immune", 0)) > 0


func _apply_damage(target_player: int, raw: int, attacker_player: int, atk_action: int, pen: int, def_action: int, events: Array, item_riders: Array = [], src: String = "action") -> int:
	var slot: int = active_index[target_player]

	# 周天罡气：无敌方本回合所有指向性伤害事件整个不发生（含附带 on-hit·同"落空"语义）
	if damage_immune(target_player):
		events.append({id = "damage_immune", player = target_player})
		return 0

	# Stage B4: 防御动作门（大防挡全部；防挡波，不挡大波/穿防攻击）
	var eff_def: int = def_action
	var broken: int = int(get_status(target_player, slot, "broken_armor", 0))
	if broken > 0 and def_action in ActionDef.DEFEND_ACTIONS:
		set_status(target_player, slot, "broken_armor", broken - 1)
		eff_def = ActionDef.Action.DEFEND if def_action == ActionDef.Action.BIG_DEFEND else -1
		events.append({id = "armor_broken", player = target_player})
	# 噬心钉：持有者无法防御（其防/大防完全失效）
	if int(item_mod(target_player, "self_no_defend", 0)) > 0 and def_action in ActionDef.DEFEND_ACTIONS:
		eff_def = -1
	# 魔法气泡：本回合"防"临时升级为可挡大波一次（条件=对手大波·已在 apply_pre 校验）
	if eff_def == ActionDef.Action.DEFEND and int(item_mod(target_player, "def_upgrade", 0)) > 0:
		set_item_mod(target_player, "def_upgrade", int(item_mod(target_player, "def_upgrade", 0)) - 1)
		eff_def = ActionDef.Action.BIG_DEFEND
	var blocked: bool = false
	if pen == ActionDef.Pen.TRUE_DMG or pen == ActionDef.Pen.PIERCE_BIGDEF:
		blocked = false
	elif pen == ActionDef.Pen.PIERCE_DEF:
		blocked = eff_def == ActionDef.Action.BIG_DEFEND
	else:
		blocked = eff_def == ActionDef.Action.BIG_DEFEND or eff_def == ActionDef.Action.DEFEND
	if blocked:
		events.append({id = ("big_defend_block" if eff_def == ActionDef.Action.BIG_DEFEND else "defend_block"), player = target_player, kind = atk_action, src = src})
		# 魔力源泉：防御成功 → +能量（每回合一次）
		var be: int = int(item_mod(target_player, "block_energy", 0))
		if be > 0:
			set_item_mod(target_player, "block_energy", 0)
			_gain_energy(target_player, be)
		# 不动明王甲：防御成功 → +HP（每回合一次）
		var bh: int = int(item_mod(target_player, "block_heal", 0))
		if bh > 0:
			set_item_mod(target_player, "block_heal", 0)
			_heal(target_player, slot, bh)
		var dsk: HeroSkill = _skills[target_player][slot]
		if dsk != null:
			dsk.on_block(self, target_player, slot, attacker_player, atk_action, raw)
		return 0

	var dmg := raw
	# Stage B3a: 中毒引爆（命中时引爆全部毒层，每层 +0.5 = 1 半点，随后清空）
	var poison: int = int(get_status(target_player, slot, "poison", 0))
	if poison > 0:
		dmg += poison
		# 遗物·毒爆 hook：本方遗物在此追加毒爆伤害（鹤顶红 = +1.0）。A4：由 core 硬编码搬入遗物 effect。
		for relic in relics[attacker_player]:
			dmg += relic["data"].effect.relic_poison_detonate_bonus(self, attacker_player, relic["data"], relic["state"])
		statuses[target_player][slot].erase("poison")
		events.append({id = "poison_detonate", player = target_player, layers = poison})
		note_combo_proc(attacker_player)   # 鼠潮：毒爆 = 一次 combo proc
	# 猎物印记（易伤）：本回合下次受击 +N（消耗）
	var marked: int = int(get_status(target_player, slot, "marked", 0))
	if marked > 0:
		dmg += marked
		statuses[target_player][slot].erase("marked")
		events.append({id = "marked_hit", player = target_player, amount = marked})
		note_combo_proc(attacker_player)   # 鼠潮：易伤消费 = 一次 combo proc
	# 罪已昭（触邪 h20·持续易伤）：被印敌方出战英雄受到的伤害 +N（不消耗·换下场清；附印那次由触邪 on_deal_hit 记 proc）
	var vuln: int = int(get_status(target_player, slot, "vuln", 0))
	if vuln > 0:
		dmg += vuln
		events.append({id = "vuln_hit", player = target_player, amount = vuln})

	# Stage B5: 受伤 hook（平减；沉默 h15 时跳过）
	var skill: HeroSkill = _skills[target_player][slot]
	if skill != null:
		dmg = skill.modify_incoming_damage(dmg, atk_action, self, target_player, slot, attacker_player)
	dmg = maxi(dmg, 0)

	# Stage B6: 护盾（丘比特之箭穿甲：无视护甲层、不被吸收）
	if dmg > 0 and pen != ActionDef.Pen.TRUE_DMG and not bool(item_mod(attacker_player, "pierce_armor", false)) and shield[target_player][slot] > 0:
		var absorbed: int = mini(shield[target_player][slot], dmg)
		shield[target_player][slot] -= absorbed
		dmg -= absorbed
		events.append({id = "shield_absorb", player = target_player, amount = absorbed})

	# 巫毒娃娃：替身吃下这一次伤害（吸收上限 = 娃娃 HP，溢出穿过；挨一下即碎）
	var decoy: int = int(get_status(target_player, slot, "decoy_hp", 0))
	if dmg > 0 and decoy > 0:
		var eaten: int = mini(decoy, dmg)
		dmg -= eaten
		statuses[target_player][slot].erase("decoy_hp")
		events.append({id = "decoy_absorb", player = target_player, amount = eaten})

	# Stage B9: 落 HP（半点）
	# 护主（天狗 h23·顶替承伤）：出战将死 + 替补有存活天狗(每局<HUZHU_CAP) → 天狗立刻登场顶替，
	#   原 carry 退居替补获救、这一击改落到天狗身上（天狗吃这下·可能被这下打死＝去掉旧「完全免除+自我碎掉」）。
	#   走 _perform_switch（含娄金穷追等切换副作用）；天狗若被打死走 Phase 5 正常结算(触发室火饕餮等)。
	if dmg > 0 and dmg >= hp[target_player][slot] and slot == active_index[target_player]:
		var guard: int = _find_lethal_guardian(target_player)
		if guard >= 0:
			set_status(target_player, guard, "huzhu_uses", int(get_status(target_player, guard, "huzhu_uses", 0)) + 1)
			events.append({id = "lethal_rescue", player = target_player, guardian = guard})
			_perform_switch(target_player, slot, guard, events)
			slot = active_index[target_player]   # 出战改为天狗·本次伤害改落天狗身上
			# 2026-07-04 Eddy 批③①：御凶登场带 1.0 护盾且【垫住当下这一击】——主护盾段(B6)已跑过、
			# 此处按同套规则（真伤/穿甲不吸）手动结算这次吸收；天狗替补席攒的旧护盾一并参与。
			shield[target_player][slot] += HUZHU_SHIELD
			events.append({id = "huzhu_shield", player = target_player, amount = HUZHU_SHIELD})
			if dmg > 0 and pen != ActionDef.Pen.TRUE_DMG and not bool(item_mod(attacker_player, "pierce_armor", false)) and shield[target_player][slot] > 0:
				var gabsorb: int = mini(shield[target_player][slot], dmg)
				shield[target_player][slot] -= gabsorb
				dmg -= gabsorb
				events.append({id = "shield_absorb", player = target_player, amount = gabsorb})
			# 御凶登场反击（2026-07-05 批③·Eddy 批 C 案·同日定普通伤害非真伤）：天狗扑咬攻击者 1.0——
			#   走管线打击（可喂剑气/引爆毒·普通档=对方护盾可吸收）；救场变"救场+复仇"。
			if not damage_immune(attacker_player):
				strike(attacker_player, HUZHU_COUNTER_DMG, target_player, ActionDef.Pen.NORMAL, events)
				events.append({id = "huzhu_counter", player = target_player, guardian = slot})

	# 濒死保命（通用 huanhun_ready 状态机制·非道具专属硬编码）：出战将死且带该标记 → 保留 0.5 HP（1 半点）·随后清标记。
	# 当前仅还魂丹 t2_huanhundan 设此标记（apply_pre）。
	if dmg > 0 and dmg >= hp[target_player][slot] and slot == active_index[target_player] and int(get_status(target_player, slot, "huanhun_ready", 0)) > 0:
		set_status(target_player, slot, "huanhun_ready", 0)
		dmg = maxi(0, hp[target_player][slot] - 1)
		events.append({id = "huanhun_revive", player = target_player})

	var dealt: int = 0
	if dmg > 0:
		hp[target_player][slot] -= dmg
		dealt = dmg
		# pen 档位随事件外发（Pen 枚举有序）：UI 按档位给伤害飘字分级配色（普通/穿透/真伤）·纯增量字段不影响旧读者。
		events.append({id = "damage_taken", player = target_player, amount = dmg, src = src, pen = pen})
		var dsk2: HeroSkill = _skills[target_player][slot]
		if dsk2 != null:
			dsk2.on_self_damaged(self, target_player, slot, dealt, attacker_player)
		if hp[target_player][slot] <= 0:
			_killer[target_player][slot] = attacker_player

	# Stage B10: on-hit 触发（穿过防御门即算命中，按 hit_count 次；含队友监听如鸡剑气）
	var aslot: int = active_index[attacker_player]
	var atk_skill: HeroSkill = _skills[attacker_player][aslot]
	var hc: int = 1
	if atk_skill != null:
		hc = maxi(1, atk_skill.hit_count(atk_action, self, attacker_player, aslot))
	hc += int(item_mod(attacker_player, "extra_hits", 0))   # 双生咒符：本回合多触发 N 次 on-hit
	for _h in range(hc):
		if atk_skill != null:
			atk_skill.on_deal_hit(self, attacker_player, aslot, target_player, slot, dealt, atk_action)
		for s2 in range(heroes[attacker_player].size()):
			var tsk: HeroSkill = _skills[attacker_player][s2]
			if tsk != null:
				tsk.on_team_deal_hit(self, attacker_player, s2, aslot, target_player, slot, dealt)
	# 道具骑乘（吸血鬼的獠牙/毒刺）：使用者本回合动作攻击命中（穿过防御门连接）→ 触发一次
	for rider in item_riders:
		rider.effect.on_attack_connect(self, attacker_player, target_player, slot, dealt, rider)
	return dealt


## 死亡结算（§D8 基础版）：扫全场，新死亡触发 hook 链；出战位死且有替补 → 待玩家切换。
## 参数 a = 本回合双方动作（cleanup 前缓存，用于判定击杀者）。
func _resolve_deaths(_a: Array[int], events: Array) -> void:
	# 连锁死亡（§D8）：死亡 hook 可能造成新死亡 → 反复扫到稳定。
	# guard 防无限连锁（如设计错误导致互杀循环）。
	var guard := 0
	var changed := true
	while changed and guard < 12:
		changed = false
		guard += 1
		for p in [0, 1]:
			for slot in range(hp[p].size()):
				if hp[p][slot] > 0 or _death_processed[p][slot]:
					continue
				var skill: HeroSkill = _skills[p][slot]
				# 致死拦截（on_before_death hook：组件自管"每局1次"重生等）
				if skill != null and skill.on_before_death(self, p, slot):
					continue
				_death_processed[p][slot] = true
				changed = true
				var overkill: int = maxi(-hp[p][slot], 0)
				# 击杀者 on_kill：仅【直接攻击致死】触发（_killer 标记）。
				# 非直接攻击致死（道具延迟伤害等）不归因 → 不触发 → 防连锁。
				var killer: int = _killer[p][slot]
				if killer >= 0:
					var ks: HeroSkill = _skills[killer][active_index[killer]]
					if ks != null:
						ks.on_kill(p, slot, overkill, self, killer, active_index[killer])
				# 自身死亡 hook
				if skill != null:
					skill.on_death(self, p, slot)
				# 队友阵亡 hook
				for ally in range(hp[p].size()):
					if ally != slot and hp[p][ally] > 0:
						var ally_skill: HeroSkill = _skills[p][ally]
						if ally_skill != null:
							ally_skill.on_ally_death(slot, self, p, ally)
				events.append({id = "hero_died", player = p, slot = slot})
				# 饕餮（并封 h24）：任一英雄阵亡(敌我皆可) → 在场(含替补·存活)的并封 → 其【团队】+能，
				#   且并封【自己】回血（2026-07-04 双头分食优化：一头吞魂产能·一头食肉回血）。
				#   扫双方存活英雄(死者已 hp≤0 自动不计=尸不自食)；能量走 _gain_energy 享囤鼠叠加、
				#   回血走 _heal（尊重禁回血·封顶 max_hp·替补席也回）。
				for pp in [0, 1]:
					var feast: int = 0
					for hs in range(hp[pp].size()):
						if hp[pp][hs] > 0:
							var hsk: HeroSkill = _skills[pp][hs]
							if hsk != null:
								feast += hsk.death_energy_bonus()
								var dheal: int = hsk.death_heal_self()
								if dheal > 0:
									var flesh: int = _heal(pp, hs, dheal)
									if flesh > 0:
										events.append({id = "taotie_flesh", player = pp, slot = hs, amount = flesh})
					if feast > 0:
						_gain_energy(pp, feast)
						events.append({id = "taotie_feast", player = pp, amount = feast})
				# 死亡反击（通用 death_reflect 状态机制·非道具专属硬编码）：出战阵亡且带该标记 →
				# 对敌方出战真伤（无视防御/护甲）·随后清标记。当前仅尾后针 t1_weihouzhen 设此标记（apply_pre）。
				if slot == active_index[p] and int(item_buffs[p].get("death_reflect", 0)) > 0:
					item_buffs[p].erase("death_reflect")
					var ea: int = active_index[1 - p]
					if hp[1 - p][ea] > 0 and not damage_immune(1 - p):   # 周天罡气：死亡反击也免
						hp[1 - p][ea] -= WEIHOUZHEN_STING_DMG
						events.append({id = "weihouzhen_sting", player = p})

	# 出战位阵亡 → 待玩家选替补（甲死亡换人）
	for p in [0, 1]:
		if hp[p][active_index[p]] <= 0 and living_reserves(p).size() > 0:
			pending_death_switch[p] = true
			events.append({id = "force_switch_prompt", player = p})

	# 胜负
	var d0 := alive_count(0) == 0
	var d1 := alive_count(1) == 0
	if d0 and d1:
		game_over = true
		winner = WINNER_DRAW
		events.append({id = "draw"})
	elif d1:
		game_over = true
		winner = WINNER_P1
		events.append({id = "victory", winner = WINNER_P1})
	elif d0:
		game_over = true
		winner = WINNER_P2
		events.append({id = "victory", winner = WINNER_P2})
