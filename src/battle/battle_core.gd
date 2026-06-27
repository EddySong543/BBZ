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
##   ⏳ 待补：高级管线相位（易伤/月相/减免/护盾外的转移 h30/延迟 h27/穿透）、
##           overkill 连锁(§D8)、英雄组件注册表(_build_skills)。
##
## 半点制 (§D3)：HP / 伤害 / 护盾 / pending 内部以"半点"整数存储，
##    1 HP = HP_UNIT(2) 半点，最小伤害 0.5 = 1 半点。能量是独立整数资源。
##
## 组件无状态 (§D2)：所有 per-hero 状态都在本引擎的容器里；HeroSkill 只读写传入的 self。

const HP_UNIT := 2  # 必须与 ActionDef.HP_UNIT 一致

## 英雄机制数值（从引擎逻辑里的裸魔数提出来，集中可调）
const LETHAL_GUARDIAN_CAP := 2   # 顶替型致死救援每局上限·⚠当前无英雄用(原未羊已转牧养·守护见 h23 护主)
const HUZHU_CAP := 1             # 黑暗戌狗 h23【护主】替死每局上限（次）
const STORED_CAP := 2            # 黑暗酉鸡 h22【一鸣惊人】可囤积的「存储行动」上限（防无限攒）
const CHONGZHUANG_DAMAGE := 1    # 午马登场冲撞 = 0.5 HP（半点）
const SHUCHAO_CAP_PER_TURN := 3  # 黑暗子鼠 h13【鼠潮】每回合 combo→能量返还封顶 = 3 次 proc = 1.5 能（回路刹车·PvE 可解封顶·§6/§10）
const DOUBLEABLE_ACTIONS := [ActionDef.Action.ATTACK, ActionDef.Action.BIG_ATTACK, ActionDef.Action.CHARGE, ActionDef.Action.DEFEND, ActionDef.Action.BIG_DEFEND]  # 黑暗卯兔 h16【疾风】可"附加同种再做一次"的动作（仅技能/切换除外·防/大防可选但二元整体挡=无额外效果）
const DUANZUI_THRESHOLD := 2  # 黑暗未羊 h20【断罪】处决阈值 = 2 半点(1.0HP)：印记目标出战血量 ≤ 此值即斩（主旋钮）

# Winner 常量（延续 v3 B-007 语义：UNDECIDED=-1 / DRAW=0 / P1=1 / P2=2）
const WINNER_UNDECIDED := -1
const WINNER_DRAW := 0
const WINNER_P1 := 1
const WINNER_P2 := 2

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
var _forced_pull: Array[int] = [-1, -1]             # 黑暗申猴 h21【调虎离山】：_forced_pull[受害方]=被强制揪上场的替补槽（execute_active 设·resolve Phase 2.7 执行后清）
var pending_death_switch: Array[bool] = [false, false]  # 出战阵亡待玩家选替补上场
var _death_processed: Array = [[], []]              # 每槽位死亡 hook 是否已触发（防重复）
var _dmg_dealt: Array[int] = [0, 0]                 # 本回合各方造成的实际伤害(半点)·通用记账
var _shuchao_procs: Array[int] = [0, 0]             # 本回合各方已计入的 combo proc 数（鼠潮 h13·每回合封顶 SHUCHAO_CAP_PER_TURN）
var _double: Array[bool] = [false, false]           # 本回合各方是否"附加同种动作再做一次"（疾风 h16·选择阶段设·resolve 末重置）
var stored_action: Array[int] = [0, 0]              # 黑暗酉鸡 h22【一鸣惊人】各方已存储的行动数（空过囤积·跨回合保留·release 时 -1）
var _killer: Array = [[], []]                       # _killer[player][slot]=直接攻击致死该英雄的攻击方;-1=非攻击致死。on_kill 只对直接攻击触发(防 splash/AOE 连锁)
var _last_action: Array[int] = [-1, -1]             # 上回合双方动作（传说级雪球·惯性件读取）

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
	pending_death_switch = [false, false]
	_dmg_dealt = [0, 0]
	_shuchao_procs = [0, 0]
	_double = [false, false]
	stored_action = [0, 0]
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

func energy_display(half: int) -> float:
	return float(half) / float(ActionDef.ENERGY_UNIT)

## 统一能量获得入口：应用出战英雄的 energy_gain_bonus（子鼠囤鼠 = 每次 +1 能），clamp 到 MAX。
func _gain_energy(player: int, amount: int) -> void:
	if amount <= 0:
		return
	var sk: HeroSkill = _skills[player][active_index[player]]
	if sk != null:
		amount += sk.energy_gain_bonus(self, player, active_index[player])
	energy[player] = mini(energy[player] + amount, ActionDef.MAX_ENERGY)


## 黑暗子鼠 h13【鼠潮】：player 队触发一次 combo 效果时，引擎在该结算点调本函数。
## 在场（含替补·存活）有鼠潮型英雄 → 团队能量 +其 combo_proc_energy()（走 _gain_energy·享囤鼠叠加），
## 每回合封顶 SHUCHAO_CAP_PER_TURN 次（回路刹车）。无鼠潮 / 已达上限 = no-op。
func _note_combo_proc(player: int) -> void:
	if _shuchao_procs[player] >= SHUCHAO_CAP_PER_TURN:
		return
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

func get_dmg_dealt(player: int) -> int:
	return _dmg_dealt[player]


# === 动作选择 / 费用 ===

func _get_cost(player: int, action: int) -> int:
	if action == ActionDef.ACTIVE:
		var sk: HeroSkill = _skills[player][active_index[player]]
		return sk.active_cost(self, player, active_index[player]) if sk != null and sk.has_active() else 0
	if action in ActionDef.BASE_ACTION_DEF:
		return ActionDef.BASE_ACTION_DEF[action]["cost"]
	return 0


## 本方【可用】能量（半能）= 能量池（最低 0）。
func usable_energy(player: int) -> int:
	return maxi(0, energy[player])


## 沉默感知技能取用（黑暗辰龙 h17【镇压】）：被沉默英雄(silenced>0) 视作"无 unique"(返回 null)。
## resolve 期间另有「置 null 换位」统一收口所有 hook；本 helper 供 resolve 外的选择门(防/切换/主动技)用。
func _eff_skill(player: int, slot: int) -> HeroSkill:
	if int(get_status(player, slot, "silenced", 0)) > 0:
		return null
	return _skills[player][slot]


## 出战英雄是否可用防/大防（黑暗寅虎 h15【血勇】= 不可）。下场即恢复（按出战英雄判定）。
func _can_defend(player: int) -> bool:
	var sk: HeroSkill = _eff_skill(player, active_index[player])
	return sk == null or sk.can_defend()


## player 能否【主动切换】：对手出战是"缠绕"英雄(黑暗巳蛇 h18·存活) → 不能（被缠住）。
## 只锁主动切换；死亡换人/救援/道具强制切换走各自路径、不经此 gate。
func _can_switch(player: int) -> bool:
	var e: int = 1 - player
	var sk: HeroSkill = _eff_skill(e, active_index[e])
	return not (sk != null and hp[e][active_index[e]] > 0 and sk.locks_enemy_switch())


func can_afford(player: int, action: int) -> bool:
	if action == ActionDef.STORE:
		return can_store(player)   # 一鸣惊人：空过存行动·仅在场有 h22 + 存储未满（0 能）
	if action in ActionDef.DEFEND_ACTIONS and not _can_defend(player):
		return false   # 血勇：嗜杀红温·防/大防不合法（单一收口，legal_actions/UI/AI 全走此）
	if action == ActionDef.Action.SWITCH and not _can_switch(player):
		return false   # 缠绕：对手出战是暗蛇 → 切换不合法（legal_actions/select_switch/UI 全走此）
	return usable_energy(player) >= _get_cost(player, action)


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


## 当前出战英雄的主动技是否可用（has_active + cap 未满 + 能量够 + 组件自定前置）。
func can_use_active(player: int) -> bool:
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


func select_active(player: int) -> bool:
	if not can_use_active(player):
		return false
	selected_action[player] = ActionDef.ACTIVE
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


# === 黑暗卯兔 h16【疾风】：附加同种动作（resolve 内按 _double 处理）===

## player 队是否有"疾风"型存活英雄（含替补）且其每局 cap 未满 → 返回该英雄槽，否则 -1。
func _double_grantor(player: int) -> int:
	for s in range(heroes[player].size()):
		if hp[player][s] <= 0:
			continue
		var sk: HeroSkill = _skills[player][s]
		if sk != null:
			var cap: int = sk.double_action_cap()
			if cap > 0 and int(get_status(player, s, "jifeng_uses", 0)) < cap:
				return s
	return -1


## 指定动作能否"附加再做一次"：动作可双（波/大波/攒/防/大防）+ 在场有疾风(cap 未满)或有存储行动(h22)
## + 能量够付双份。取 action 参数（不读 selected_action）→ UI 在【提交前】可用本地待选动作校验。
func can_double_action(player: int, action: int) -> bool:
	if action < 0 or not (action in DOUBLEABLE_ACTIONS):
		return false
	if _double_grantor(player) < 0 and stored_action[player] <= 0:
		return false   # 既无疾风（cap 未满）又无存储行动 → 不可双
	return usable_energy(player) >= 2 * _get_cost(player, action)


## 当前【已提交】动作能否附加（AI / 提交后用）。
func can_double(player: int) -> bool:
	return can_double_action(player, selected_action[player])


## 本队是否可双（疾风 cap 未满 或 有存储行动 h22）——UI 决定是否显示「附加」开关。
func has_double(player: int) -> bool:
	return _double_grantor(player) >= 0 or stored_action[player] > 0


## 本队"附加"剩余可用次数（UI 标签；= 疾风剩余 与 存储行动数 取大；都无返 0）。
func double_uses_left(player: int) -> int:
	var best := stored_action[player]
	for s in range(heroes[player].size()):
		if hp[player][s] <= 0:
			continue
		var sk: HeroSkill = _skills[player][s]
		if sk != null and sk.double_action_cap() > 0:
			best = maxi(best, sk.double_action_cap() - int(get_status(player, s, "jifeng_uses", 0)))
	return best


# === 黑暗酉鸡 h22【一鸣惊人 / 蓄势】：空过存行动 → 之后双动作释放 ===

## 本队是否有"一鸣惊人"型存活英雄（含替补）→ 可空过存行动 / 可释放双动作。
func _has_action_store(player: int) -> bool:
	for s in range(heroes[player].size()):
		if hp[player][s] <= 0:
			continue
		var sk: HeroSkill = _skills[player][s]
		if sk != null and sk.grants_action_store():
			return true
	return false


## player 当前能否"空过存行动"（在场有 h22 + 存储未满）。空过 0 能、无防御。
func can_store(player: int) -> bool:
	return _has_action_store(player) and stored_action[player] < STORED_CAP


## player 的出战英雄是否"逼战"型（黑暗辰龙 h17）且存活 → 对手不攻它就挨饿（UI/AI/resolve 用）。
func _forces_enemy_attack(player: int) -> bool:
	var s: int = active_index[player]
	var sk: HeroSkill = _skills[player][s]
	return sk != null and hp[player][s] > 0 and sk.forces_enemy_attack()


## p 本回合的动作 act 是否"攻击"（波/大波 或 攻击型主动技）——逼战判定 + 通用。
func _is_attack_action(p: int, act: int) -> bool:
	if ActionDef.is_attack(act):
		return true
	if act == ActionDef.ACTIVE:
		var sk: HeroSkill = _skills[p][active_index[p]]
		return sk != null and sk.active_is_attack()
	return false


## 切换"附加动作"开关（须先选好可双的主动作）。on=true 时校验 can_double。
func select_double(player: int, on: bool) -> bool:
	if on and not can_double(player):
		return false
	_double[player] = on
	return true


# === 道具（ADR-003）===
#
# 经济状态机（开槽/draft/refill·D5）后续实装；当前 give_item 直接给（测试/临时）。
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


## 某玩家是否持有指定 id 的遗物（鹤顶红毒爆放大 / 夜明珠登场冲撞读此判定）。
func _has_relic(player: int, item_id: String) -> bool:
	for rl in relics[player]:
		if rl["data"].item_id == item_id:
			return true
	return false


# ===== 道具经济（ADR-003 §2·M1·2026-06-19）=====
# 槽位状态机，与底层 items[]/use_item 并存（单元测试走 give_item 绕过经济）。
# 开局带 1（slot0·随机基础件·即用·降记忆成本）；slot1/2 第 3/4 回合解锁。
# 三步部署锁（电报）：开格(1能·锁本回合) → 抽道具(3选1·锁本回合) → 下回合可用；
#   一次性用后 EMPTY，refill(1能·重抽)。升级 = 就绪件花能量从「下一级池」3 选 1·重新锁本回合。
# 槽 dict：{state:int, item:ItemData|null, since:int(进入该态的回合), used:bool, draft:Array, upg_draft:Array}

enum SlotState { SEALED, OPENED, CHARGING, EMPTY }
const SLOT_COUNT := 3
const SLOT_UNLOCK_TURN := [0, 2, 3]    # 0-indexed turn_number（= 第 1/3/4 回合）
const ITEM_OPEN_COST := 2              # 开格 1 能（= 2 半能）
const ITEM_REFILL_COST := 2            # refill 1 能
const UPGRADE_COST_T1 := 2             # 升级 1→2 花 1 能（= 2 半能·ADR D5）
const UPGRADE_COST_T2 := 4             # 升级 2→3 花 2 能（= 4 半能·ADR D5）
const UPGRADE_FAVORED_WEIGHT := 5.0    # 升级 3 选 1 里「预设升级款」(upgrade_to) 的相对权重（>1 → 更易出现·B2）
const STARTER_ITEM_IDS := ["t1_feibiao", "t1_jiudun", "t1_lzhi_shengming"]  # 开局带 1 随机池
## 开局带件按设计同样走「部署延迟」：turn_number 2（= 显示回合 3）才可用，**非首回合**
## （design build-design-framework.md §2 部署时序表：开格①t1→抽①t2→①可用t3）。
## 自动部署（"带入道具"·玩家不需点开格/抽，降记忆成本）→ CHARGING + since 使其 turn 2 就绪。
const STARTER_READY_TURN := 2


## 启用经济并初始化槽位（实战由 battle_screen 调；单元测试不调 → 槽空、不影响既有行为）。
func econ_init() -> void:
	slots = [[], []]
	for p in [0, 1]:
		# slot0 = 开局带 1：随机基础件，CHARGING 但走部署延迟 → since=STARTER_READY_TURN-1，
		# turn_number 2(显示回合3)才 slot_ready；前两回合显示「(锁)」公开电报，非首回合即用（design §2）。
		var sid: String = STARTER_ITEM_IDS[rng.randi() % STARTER_ITEM_IDS.size()]
		slots[p].append({state = SlotState.CHARGING, item = ItemCatalog.make(sid), since = STARTER_READY_TURN - 1, used = false, draft = [], upg_draft = []})
		for _s in range(SLOT_COUNT - 1):
			slots[p].append({state = SlotState.SEALED, item = null, since = -1, used = false, draft = [], upg_draft = []})


func slot_state(player: int, s: int) -> int:
	return int(slots[player][s]["state"])


func slot_item(player: int, s: int) -> ItemData:
	return slots[player][s]["item"]


## 槽本回合是否可用（CHARGING + 部署锁已过 + 未用过）。
func slot_ready(player: int, s: int) -> bool:
	var sl: Dictionary = slots[player][s]
	return int(sl["state"]) == SlotState.CHARGING and not bool(sl["used"]) and turn_number > int(sl["since"])


## 能否开格（SEALED + 到解锁回合 + 能量够）。
func can_open_slot(player: int, s: int) -> bool:
	return int(slots[player][s]["state"]) == SlotState.SEALED \
		and turn_number >= int(SLOT_UNLOCK_TURN[s]) and usable_energy(player) >= ITEM_OPEN_COST


## 开格：付 1 能，SEALED→OPENED（锁本回合，下回合才能抽）。
func open_slot(player: int, s: int) -> bool:
	if not can_open_slot(player, s):
		return false
	energy[player] -= ITEM_OPEN_COST
	slots[player][s]["state"] = SlotState.OPENED
	slots[player][s]["since"] = turn_number
	return true


## 能否抽道具（OPENED + 已过开格当回合）。
func can_draw_slot(player: int, s: int) -> bool:
	return int(slots[player][s]["state"]) == SlotState.OPENED and turn_number > int(slots[player][s]["since"])


## 生成并返回 3 选 1 选项（存入槽供 UI 展示；同回合重复调用沿用已生成结果）。
func begin_draft(player: int, s: int) -> Array:
	var sl: Dictionary = slots[player][s]
	if (sl["draft"] as Array).is_empty():
		var pool: Array = _draft_pool()
		var opts: Array = []
		var n: int = mini(3, pool.size())
		for _i in range(n):
			opts.append(pool[rng.randi() % pool.size()])
		sl["draft"] = opts
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


## 升级线下一级的能量成本（半能）：tier1→2 = 1 能 / tier2→3 = 2 能（ADR D5）。
func upgrade_cost(player: int, s: int) -> int:
	var item: ItemData = slots[player][s]["item"]
	if item == null:
		return 0
	return UPGRADE_COST_T2 if item.tier >= 2 else UPGRADE_COST_T1


## 能否升级（就绪 + 有更高 tier 可升 + 能量够）：就绪槽的「用 or 升」二选一决策点。
## 升级 = 花能量从「下一级 tier 池」3 选 1（不再要求预设 upgrade_to —— 多数道具没有升级款；
## 预设款只是「以后加权让它更易出现」的偏好·B2）。故 T1/T2 件均可升、T3 封顶。
func can_upgrade(player: int, s: int) -> bool:
	if not slot_ready(player, s):
		return false
	var item: ItemData = slots[player][s]["item"]
	return item != null and item.tier < 3 and usable_energy(player) >= upgrade_cost(player, s)


## 生成升级 3 选 1 候选（下一级 tier 池随机 3·占位无加权）。存入槽 "upg_draft" 供 UI 展示；
## 同回合重复调用沿用已生成结果（防 reroll）。换件 / refill / 用掉时清空（见各处 upg_draft=[]）。
## TODO（B2 加权池）：预设 upgrade_to 存在时提高其出现概率；当前等概率随机。
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
	return int(slots[player][s]["state"]) == SlotState.EMPTY and usable_energy(player) >= ITEM_REFILL_COST


## refill：付 1 能，EMPTY→可抽（格已在，故立即 3 选 1；返回选项供 UI；随后 pick_draft）。
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


## 抽卡池（占位：T1 地板 + T2 连携；T3/遗物留升级线·待升级系统接入）。
func _draft_pool() -> Array:
	var pool: Array = []
	pool.append_array(ItemCatalog.all_tier1())
	pool.append_array(ItemCatalog.all_tier2())
	return pool


## 结算末：本回合用掉的槽置 EMPTY（一次性消耗）。在 resolve Phase 6 调。
func _econ_after_resolve() -> void:
	for p in [0, 1]:
		for sl in slots[p]:
			if bool(sl["used"]):
				sl["state"] = SlotState.EMPTY
				sl["item"] = null
				sl["used"] = false
				sl["upg_draft"] = []


# === AI / 模拟支持（纯加法，不改任何结算行为）===
#
# clone(): 深拷当前战局供前瞻模拟（AI 枚举各动作后果）。
# legal_actions(): 枚举合法动作。apply_choice(): 按 {action,target} 分派提交。
# 三者均只读/封装既有逻辑，结算结果与手动 select_* 完全一致。

## 深拷战局。状态容器全部独立深拷；HeroData（只读资源）/ HeroSkill（无状态组件 §D2）
## 共享引用（duplicate(true) 不复制 Object）；rng 独立复制（seed+state）→ 推演不扰动本局序列。
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
	c.stored_action = stored_action.duplicate()
	c._switch_to = _switch_to.duplicate()
	c._forced_pull = _forced_pull.duplicate()
	c.pending_death_switch = pending_death_switch.duplicate()
	c._death_processed = _death_processed.duplicate(true)
	c._dmg_dealt = _dmg_dealt.duplicate()
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
	c.rng = RandomNumberGenerator.new()
	c.rng.seed = rng.seed
	c.rng.state = rng.state
	# §D2 锁死：重建【无状态】技能实例，而非 duplicate(true) 共享同一引用
	# （Array[Object].duplicate(true) 并不复制 Object，原本是浅拷）。
	# → 推演局与真实局零共享，即便将来某技能误加实例成员变量也不会破坏确定性。
	# 技能无状态，重建与共享行为等价；statuses 已在上面深拷，故不重跑 on_setup。
	c._build_skills()
	return c


## 枚举该玩家当前所有合法动作。返回 Array[{action:int, target:int}]，
## target 仅 SWITCH 有效（替补槽位），其余 -1。CHARGE 恒合法 → 列表非空。
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
		out.append({action = ActionDef.ACTIVE, target = -1})
	if can_store(player):
		out.append({action = ActionDef.STORE, target = -1})   # 一鸣惊人：空过存行动
	return out


## 按 {action,target} 提交该玩家动作（封装 select_* 分派）。返回是否合法成功。
func apply_choice(player: int, choice: Dictionary) -> bool:
	var a: int = int(choice["action"])
	if a == ActionDef.ACTIVE:
		return select_active(player)
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

	# Phase 0.3: 沉默换位（黑暗辰龙 h17【镇压】）——被沉默英雄(silenced>0)的技能槽临时置 null，
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
	_dmg_dealt = [0, 0]
	_shuchao_procs = [0, 0]
	for p in [0, 1]:
		for s in range(_killer[p].size()):
			_killer[p][s] = -1

	# Phase 0: 结算上回合延迟伤害（道具妖火/藤蔓挂的债；直接扣）
	for p in [0, 1]:
		for s in range(hp[p].size()):
			if pending_damage[p][s] > 0:
				hp[p][s] -= pending_damage[p][s]
				events.append({id = "deferred_damage", player = p, slot = s, amount = pending_damage[p][s]})
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
		elif a[p] == ActionDef.STORE:
			# 一鸣惊人 h22：空过 —— 不行动、不拿能量（_get_cost=0 已无扣）、无防御，存储 +1（封顶 STORED_CAP）。
			stored_action[p] = mini(stored_action[p] + 1, STORED_CAP)
			events.append({id = "yiming_store", player = p, count = stored_action[p]})
		# 附加同种动作（疾风 h16 / 一鸣惊人 h22 释放）——付第二份能；攒额外再产一次能（攻击第二段在 Phase 3+4 挂 hitlist）。
		if _double[p]:
			var g: int = _double_grantor(p)
			if a[p] in DOUBLEABLE_ACTIONS and (stored_action[p] > 0 or g >= 0):
				# 优先消耗"存储行动"（h22 玩家刻意囤的资源），其次才用疾风每局 cap。
				if stored_action[p] > 0:
					stored_action[p] -= 1
					events.append({id = "yiming_release", player = p, action = a[p]})
				else:
					set_status(p, g, "jifeng_uses", int(get_status(p, g, "jifeng_uses", 0)) + 1)
				energy[p] -= _get_cost(p, a[p])   # 第二份按原始费用（不重复享道具折扣）
				if a[p] == ActionDef.Action.CHARGE:
					var gd: int = ActionDef.BASE_ACTION_DEF[ActionDef.Action.CHARGE]["energy_gain"]
					_gain_energy(p, gd)
					events.append({id = "charge_gain", player = p, amount = gd})
				events.append({id = "jifeng_double", player = p, action = a[p]})
			else:
				_double[p] = false   # 非法双动作（不可双 / 既无疾风又无存储）→ 撤销，Phase 3+4 不再 double

	# Phase 2.5: 切换（甲时机，先于伤害）→ 攻击将打到换上来的新英雄
	for p in [0, 1]:
		if a[p] == ActionDef.Action.SWITCH:
			if int(item_mod(p, "no_switch", 0)) > 0:
				events.append({id = "switch_locked", player = p})
				continue
			_do_switch(p, events)

	# Phase 2.55: 打神鞭强制切换（forced_switch 由道具在 apply_pre 设·指向某存活替补槽）。
	#   仅当该方未主动切换、且未被定身（no_switch）时触发；走 _perform_switch → 触发戌狗穷追。
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

	# Phase 2.7: 黑暗申猴 h21【调虎离山】强制揪人 —— execute_active 设的 _forced_pull[受害方]
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
			var dealt: int = _apply_damage(1 - p, int(h["damage"]), p, int(h["kind"]), int(h["pen"]), a[1 - p], events, riders)
			if bool(h.get("active", false)):
				var sk2: HeroSkill = _skills[p][active_index[p]]
				if sk2 != null and sk2.active_is_attack():
					sk2.on_active_attack_resolved(self, p, active_index[p], dealt)

	# Phase 4.9: 断罪处决（h20 暗羊）——印记目标【出战】血量 ≤ 阈值 → 斩杀(置 0)，随后走正常死亡结算(还魂/救援仍可拦)。
	for p in [0, 1]:
		var ds: int = active_index[p]
		if hp[p][ds] > 0 and hp[p][ds] <= DUANZUI_THRESHOLD and int(get_status(p, ds, "duanzui", 0)) > 0:
			hp[p][ds] = 0
			events.append({id = "duanzui_execute", player = p, slot = ds})

	# Phase 5: 死亡结算 + 强制切换 + 胜负
	_resolve_deaths(a, events)

	# Phase 5.5: 回合结算末 hook（on_resolve_end）
	for p in [0, 1]:
		var s: int = active_index[p]
		if hp[p][s] > 0:
			var sk: HeroSkill = _skills[p][s]
			if sk != null:
				sk.on_resolve_end(self, p, s)

	# Phase 5.6: 牧养（光版未羊 h08）——在场有未羊(含替补·存活) → 你方存活【替补席】英雄每回合回 reserve_heal 半点。
	#   退下火线休养、出战英雄不回；走 _heal（尊重妖火禁回血、封顶 max_hp）。
	for p in [0, 1]:
		var rheal := 0
		for s in range(heroes[p].size()):
			if hp[p][s] > 0:
				var msk: HeroSkill = _skills[p][s]
				if msk != null:
					rheal = maxi(rheal, msk.reserve_heal_per_turn())
		if rheal > 0:
			for s in range(hp[p].size()):
				if s != active_index[p] and hp[p][s] > 0:
					var got: int = _heal(p, s, rheal)
					if got > 0:
						events.append({id = "muyang_heal", player = p, slot = s, amount = got})

	# Phase 6: cleanup
	# 遗物·Phase 6：每回合末 tick（产出/计数/充能；读 selected_action 判断本回合是否攻击）。
	#   返回 false 的遗物移除（碎/耗尽）。在被动能量前结算，故遗物产能也享受不到/不影响被动。
	for p in [0, 1]:
		var kept_relics: Array = []
		for relic in relics[p]:
			if bool(relic["data"].effect.relic_end(self, p, relic["data"], relic["state"])):
				kept_relics.append(relic)
		relics[p] = kept_relics
	# 被动能量入口（A2 引入·2026-06-24 去除 → PASSIVE_ENERGY_GAIN=0·当前 no-op；保留入口便于将来重调）。
	for p in [0, 1]:
		_gain_energy(p, ActionDef.PASSIVE_ENERGY_GAIN)
	# 沉默还原 + 递减时长（黑暗辰龙 h17【镇压】；只递减本回合生效过的，见 Phase 0.3）。
	for sw in _silenced_swap:
		_skills[sw[0]][sw[1]] = sw[2]
		set_status(sw[0], sw[1], "silenced", maxi(0, int(get_status(sw[0], sw[1], "silenced", 0)) - 1))
	_econ_after_resolve()
	_last_action = [a[0], a[1]]
	turn_number += 1
	var result := {
		p1_hp = current_hp(0), p2_hp = current_hp(1),
		p1_energy = energy[0], p2_energy = energy[1],
		p1_action = a[0], p2_action = a[1],
		events = events, game_over = game_over, winner = winner,
		turn = turn_number,
	}
	selected_action = [-1, -1]
	_switch_to = [-1, -1]
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
	events.append({id = "switch", player = player, from_to = [from_slot, to_slot]})

	var entering: HeroSkill = _skills[player][to_slot]
	if entering != null:
		entering.on_switch_in(self, player, to_slot)

	# 夜明珠遗物：你切换登场 → 本回合攻击 +0.5（_imod）+ 登场冲撞 0.5 给敌方出战（直接真伤·简化版）。
	if _has_relic(player, "t3_yemingzhu"):
		add_item_mod(player, "atk_bonus", 1)
		var oa: int = active_index[opp]
		if hp[opp][oa] > 0:
			hp[opp][oa] -= 1
			events.append({id = "yemingzhu_charge", player = player})


## h07 当先：免费切换（不占动作槽；午马 free_switch_cap 默认 -1 = 不限次）。在【选择阶段】调用：
## 立即换人 + 计 cap，不设 selected_action，之后玩家照常为新出战英雄选一个动作。
## 二元设计："涉及马的切换"都免动作槽 = 起点（马在场→重定位下场）或终点（顶马上场）任一为午马即免费。

## 指定槽位的英雄当前能否提供免费切换（has_free_switch + 该英雄 cap 未满）。
func _grants_free_switch(player: int, slot: int) -> bool:
	var sk: HeroSkill = _skills[player][slot]
	if sk == null or not sk.has_free_switch():
		return false
	var cap: int = sk.free_switch_cap()
	if cap >= 0 and int(get_status(player, slot, "dangxian_uses", 0)) >= cap:
		return false
	return true


## 当前出战英雄能否免费重定位（任意存活替补都免费）。保留旧语义供 UI / 测试调用。
func can_free_switch(player: int) -> bool:
	return _grants_free_switch(player, active_index[player]) and living_reserves(player).size() > 0


## 切换到 target 是否免动作槽：起点（出战）或终点（target）任一英雄提供免费切换 → true 走 free_switch。
func is_free_switch_target(player: int, target: int) -> bool:
	if target < 0 or target >= hp[player].size() or target == active_index[player] or hp[player][target] <= 0:
		return false
	if not _can_switch(player):
		return false   # 缠绕：暗蛇也锁午马的免费切换
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


## 午马登场冲撞：对敌方出战造成 0.5 冲撞伤，走完整 on-hit 管线（引爆毒 / 喂剑气）。
## 用 PIERCE_BIGDEF 让冲撞无视防御直接连接（登场突袭）；事件用本地数组（不并入 resolve 事件流）。
func chongzhuang(attacker_player: int) -> void:
	var opp: int = 1 - attacker_player
	if hp[opp][active_index[opp]] <= 0:
		return
	var ev: Array = []
	_apply_damage(opp, CHONGZHUANG_DAMAGE, attacker_player, ActionDef.Action.ATTACK, ActionDef.Pen.PIERCE_BIGDEF, ActionDef.Action.CHARGE, ev)
	_note_combo_proc(attacker_player)   # 鼠潮：午马登场冲撞 = 一次 combo proc


## 把伤害"踏/溅"到 victim_player 最高血存活替补（午马 h19 践踏溢出用·shield 先吸·触发 on_self_damaged）。
func _splash_to_reserve(victim_player: int, dmg: int) -> void:
	if dmg <= 0:
		return
	var target := -1
	var best_hp := 0
	for s in range(hp[victim_player].size()):
		if s != active_index[victim_player] and hp[victim_player][s] > best_hp:
			best_hp = hp[victim_player][s]
			target = s
	if target < 0:
		return   # 无存活替补 → 溢出无处可去
	var d: int = dmg
	if shield[victim_player][target] > 0:
		var absorbed: int = mini(shield[victim_player][target], d)
		shield[victim_player][target] -= absorbed
		d -= absorbed
	if d <= 0:
		return
	hp[victim_player][target] -= d
	_dmg_dealt[1 - victim_player] += d
	var sk: HeroSkill = _skills[victim_player][target]
	if sk != null:
		sk.on_self_damaged(self, victim_player, target, d, 1 - victim_player)


## 找 player 替补席可用的「顶替型」致死救援守护者（is_lethal_guardian + 每局 < 2 次）；无则 -1。
## ⚠ 当前无英雄 override is_lethal_guardian（原未羊已转牧养·守护见 h23 护主 is_protect_guardian）；保留作扩展接口。
func _find_lethal_guardian(player: int) -> int:
	for s in range(hp[player].size()):
		if s == active_index[player] or hp[player][s] <= 0:
			continue
		var sk: HeroSkill = _skills[player][s]
		if sk != null and sk.is_lethal_guardian() and int(get_status(player, s, "tizui_uses", 0)) < LETHAL_GUARDIAN_CAP:
			return s
	return -1


## 找 player 替补席可用的「护主」守护者（黑暗戌狗 h23：is_protect_guardian + 每局 < HUZHU_CAP 次）；无则 -1。
func _find_protect_guardian(player: int) -> int:
	for s in range(hp[player].size()):
		if s == active_index[player] or hp[player][s] <= 0:
			continue
		var sk: HeroSkill = _skills[player][s]
		if sk != null and sk.is_protect_guardian() and int(get_status(player, s, "huzhu_uses", 0)) < HUZHU_CAP:
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


## 伤害管线 (§D4)：防御门 → 中毒引爆 → 受伤 hook(平减) → 护盾 → 落 HP → on-hit 触发。
## 返回实际落在 HP 上的伤害（半点），供攻击型主动技回调使用。
func _apply_damage(target_player: int, raw: int, attacker_player: int, atk_action: int, pen: int, def_action: int, events: Array, item_riders: Array = []) -> int:
	var slot: int = active_index[target_player]

	# Stage B4: 防御动作门（大防挡全部；防挡波，不挡大波/穿防攻击）
	var eff_def: int = def_action
	var broken: int = int(get_status(target_player, slot, "broken_armor", 0))
	if broken > 0 and def_action in ActionDef.DEFEND_ACTIONS:
		set_status(target_player, slot, "broken_armor", broken - 1)
		eff_def = ActionDef.Action.DEFEND if def_action == ActionDef.Action.BIG_DEFEND else -1
		events.append({id = "armor_broken", player = target_player})
	# 魔笛：施加的"防御失效"——对手下一次防/大防完全失效（消耗一次）
	var dnull: int = int(get_status(target_player, slot, "defend_null", 0))
	if dnull > 0 and def_action in ActionDef.DEFEND_ACTIONS:
		set_status(target_player, slot, "defend_null", dnull - 1)
		eff_def = -1
		events.append({id = "defend_nullified", player = target_player})
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
		events.append({id = ("big_defend_block" if eff_def == ActionDef.Action.BIG_DEFEND else "defend_block"), player = target_player})
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
		if _has_relic(attacker_player, "t3_hedinghong"):
			dmg += 2   # 鹤顶红遗物：引爆毒额外 +1.0（2 半点）
		statuses[target_player][slot].erase("poison")
		events.append({id = "poison_detonate", player = target_player, layers = poison})
		_note_combo_proc(attacker_player)   # 鼠潮：毒爆 = 一次 combo proc
	# 猎物印记（易伤）：本回合下次受击 +N（消耗）
	var marked: int = int(get_status(target_player, slot, "marked", 0))
	if marked > 0:
		dmg += marked
		statuses[target_player][slot].erase("marked")
		events.append({id = "marked_hit", player = target_player, amount = marked})
		_note_combo_proc(attacker_player)   # 鼠潮：易伤消费 = 一次 combo proc

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
	# 护主（黑暗戌狗 h23）：出战将死 + 替补有狗(每局<HUZHU_CAP) → 狗替死碎掉下场、这一击完全免除、
	#   carry 留前线。「完全免除」优先于未羊「顶替承伤」，故先判。狗的死亡走 Phase 5 正常结算(触发亥猪饕餮等)。
	if dmg > 0 and dmg >= hp[target_player][slot] and slot == active_index[target_player]:
		var protector: int = _find_protect_guardian(target_player)
		if protector >= 0:
			set_status(target_player, protector, "huzhu_uses", int(get_status(target_player, protector, "huzhu_uses", 0)) + 1)
			hp[target_player][protector] = 0   # 狗碎掉（替补位阵亡）
			events.append({id = "huzhu_protect", player = target_player, guardian = protector})
			return 0   # 这一击完全免除·carry 不掉血、不触发 on-hit（视同挡下）
	# 致死救援（顶替型·扩展接口·当前无英雄用→原未羊已转牧养）：出战将死 + 替补有 is_lethal_guardian → 顶上、原 carry 获救（强制换人触发狗）
	if dmg > 0 and dmg >= hp[target_player][slot] and slot == active_index[target_player]:
		var guard: int = _find_lethal_guardian(target_player)
		if guard >= 0:
			set_status(target_player, guard, "tizui_uses", int(get_status(target_player, guard, "tizui_uses", 0)) + 1)
			events.append({id = "lethal_rescue", player = target_player, guardian = guard})
			_perform_switch(target_player, slot, guard, events)
			slot = active_index[target_player]   # 出战改为羊，本次伤害改落羊身上

	# 还魂丹：出战将死且持有"还魂"（本局一次）→ 保留 0.5 HP（1 半点）
	if dmg > 0 and dmg >= hp[target_player][slot] and slot == active_index[target_player] and int(get_status(target_player, slot, "huanhun_ready", 0)) > 0:
		set_status(target_player, slot, "huanhun_ready", 0)
		dmg = maxi(0, hp[target_player][slot] - 1)
		events.append({id = "huanhun_revive", player = target_player})

	var dealt: int = 0
	if dmg > 0:
		hp[target_player][slot] -= dmg
		_dmg_dealt[attacker_player] += dmg
		dealt = dmg
		events.append({id = "damage_taken", player = target_player, amount = dmg})
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
				# 饕餮（黑暗亥猪 h24）：任一英雄阵亡(敌我皆可) → 在场(含替补·存活)的亥猪 → 其【团队】+能。
				#   扫双方存活英雄(死者已 hp≤0 自动不计=尸不自食)；走 _gain_energy 享囤鼠叠加。
				for pp in [0, 1]:
					var feast: int = 0
					for hs in range(hp[pp].size()):
						if hp[pp][hs] > 0:
							var hsk: HeroSkill = _skills[pp][hs]
							if hsk != null:
								feast += hsk.death_energy_bonus()
					if feast > 0:
						_gain_energy(pp, feast)
						events.append({id = "taotie_feast", player = pp, amount = feast})
				# 尾后针：你出战阵亡 → 对敌方出战 0.5 真伤（无视防御/护甲），随后消耗标记。
				if slot == active_index[p] and int(item_buffs[p].get("death_reflect", 0)) > 0:
					item_buffs[p].erase("death_reflect")
					var ea: int = active_index[1 - p]
					if hp[1 - p][ea] > 0:
						hp[1 - p][ea] -= 1
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
