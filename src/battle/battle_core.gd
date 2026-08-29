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
##   ⏳ 待补：高级管线相位（月相/减免/穿透；脆弱已实装[h20 触邪·罪已昭]，「伤害转移/延迟」原属已弃用的旧塔罗英雄 h27/h30、随塔罗架构弃用作废）、
##           overkill 连锁(§D8)、英雄组件注册表(_build_skills)。
##
## 半点制 (§D3)：HP / 伤害 / 护甲 / pending 内部以"半点"整数存储，
##    1 HP = HP_UNIT(2) 半点，最小伤害 0.5 = 1 半点。能量是独立整数资源。
##
## 组件无状态 (§D2)：所有 per-hero 状态都在本引擎的容器里；HeroSkill 只读写传入的 self。

const HP_UNIT := 2  # 必须与 ActionDef.HP_UNIT 一致

## 英雄机制数值（从引擎逻辑里的裸魔数提出来，集中可调）
const CHONGZHUANG_DAMAGE := 1    # 星日登场冲撞 = 0.5 HP（半点）
const EMPOWERED_WAVE_COST := 2   # 亢金 h05【龙御极】：强化波额外支付 1 能（半能）
const EMPOWERED_WAVE_DAMAGE := 2 # 亢金 h05【龙御极】：强化波额外造成 1 点伤害（半点）
const ENERGY_CAP_DISCOUNT_COST := ActionDef.ENERGY_UNIT # 并封 h24：永久降低 1 点团队能量上限
const ENERGY_CAP_DISCOUNT_AMOUNT := ActionDef.ENERGY_UNIT # 并封 h24：本回合行动少消耗 1 点能量
const ENERGY_CAP_DISCOUNT_FLOOR := 3 * ActionDef.ENERGY_UNIT # 并封 h24：团队能量上限最低 3 点

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
var energy_max: Array[int] = [ActionDef.MAX_ENERGY, ActionDef.MAX_ENERGY] # 团队动态能量上限（半能）；H23 可永久压低
var hp: Array = [[], []]                  # hp[player][slot]，半点
var max_hp: Array = [[], []]              # 半点
var shield: Array = [[], []]              # shield[player][slot]，半点
var pending_damage: Array = [[], []]      # 半点，旧延迟伤害队列（Phase0 结算）；妖火已改用 timed_item_effects
var statuses: Array = [[], []]            # statuses[player][slot]: Dictionary，per-slot 状态容器 (§D5)
## 队伍级状态与出战槽无关。剑气是首个迁入者；统一容器避免未来再把共享资源误绑到英雄槽位。
var team_statuses: Array[Dictionary] = [{}, {}]
const TEAM_SCOPED_STATUS_KEYS: Array[String] = ["jianqi"]

var selected_action: Array[int] = [-1, -1]
var _switch_to: Array[int] = [-1, -1]               # SWITCH 动作的目标槽位
var _forced_pull: Array[int] = [-1, -1]             # 枭阳 h21【调虎离山】：_forced_pull[受害方]=被强制揪上场的替补槽（execute_active 设·resolve Phase 2.7 执行后清）
var _active_target: Array[int] = [-1, -1]           # 主动技玩家指定目标槽（枭阳 h21 揪敌方哪个替补·-1=未指定→execute_active 随机选·resolve 末清）
var _attack_target: Array[int] = [-1, -1]           # 基础攻击显式敌方目标槽（房日 h04【十方无次第】；-1=标准攻击结算时出战位）
var _second_action: Array[int] = [-1, -1]            # 连环鼓：第二个公共行动（仅攒/波/防/大波/大防）
var _second_attack_target: Array[int] = [-1, -1]     # 连环鼓第二行动为攻击时的显式敌方目标
var pending_death_switch: Array[bool] = [false, false]  # 出战阵亡待玩家选替补上场
var _death_processed: Array = [[], []]              # 每槽位死亡 hook 是否已触发（防重复）
var _empowered_wave: Array[bool] = [false, false]   # 本回合各方是否为基础「波」启用龙御极强化（额外 1 能 / +1 伤）
var _split_big_wave: Array[bool] = [false, false]   # 本回合玄冥是否把自己的「大波」改为连续两次「波」
var _blood_payment: Array[bool] = [false, false]    # 本回合是否由已记录的蚩尤以等量血量支付英雄费用
var _blood_payment_source: Array[int] = [-1, -1]    # 发动技能的蚩尤槽位；免费切换后仍由该槽付款
var _energy_cap_discount: Array[bool] = [false, false] # 本回合是否降低 1 点能量上限，换取行动费用 -1
var free_switch_usage_turn: Array[int] = [-1, -1]   # 千里自在风：各方免费切换计数所属的 turn_number
var free_switch_uses: Array[int] = [0, 0]           # 千里自在风：各方在 usage_turn 内已免费切换次数
var _pending_free_switches: Array = [[], []]         # 选择期免费切换意图；active_index 仅预览，揭示后才原子提交 hook
var _pending_reserve_pursuit_source: Array[int] = [-1, -1] # resolve 临时态：触发广寒追击的出手槽；不跨回合/快照
var _pending_reserve_pursuit_target: Array[int] = [-1, -1] # resolve 临时态：广寒待追击的敌方槽；不跨回合/快照
var _active_transform_requested: Array[bool] = [false, false] # resolve 临时态：烛阴请求转变为敌方当前出战英雄；Phase 2.65 同时落地
var _killer: Array = [[], []]                       # _killer[player][slot]=直接攻击致死该英雄的攻击方;-1=非攻击致死。on_kill 只对直接攻击触发(防 splash/AOE 连锁)
var _last_action: Array[int] = [-1, -1]             # 上回合双方动作（传说级雪球·惯性件读取）

# === 道具状态（ADR-003）===
var items: Array = [[], []]                  # items[player] = Array[ItemData]：持有/可用的道具（经济系统前由 give_item 直接给）
var item_uses: Array = [[], []]             # 本回合提交的道具使用（有序）：[{data:ItemData, when:int, target:int}]
var info_distortion: Array[Dictionary] = [{}, {}]  # 信息层（幻影/迷雾）：持续到该玩家下次用道具
var item_buffs: Array[Dictionary] = [{}, {}]       # 跨回合道具 buff（风之靴 next_atk_bonus 等）
var timed_item_effects: Array = [[], []]     # 团队级定时道具效果；不随英雄转变复制（妖火等）
var _imod: Array = [{}, {}]                  # 本回合道具修正器累加器（resolve 内重置·transient）
var relics: Array = [[], []]                 # relics[player] = Array[{data:ItemData, state:Dictionary}]：激活的遗物（持久·每回合 tick）
var slots: Array = [[], []]                  # slots[player] = Array[Dictionary]：道具经济槽位（econ_init 后填充；测试不填→走 give_item）
var battle_backpack_enabled: bool = false    # 赛前背包已注入；false 保持旧版全局 T1 draft
var battle_backpacks: Array = [[], []]       # 真实物件：{uid,item_id,temporary}
var used_item_history: Array = [[], []]      # 本场已实际消耗记录：{item_id,tier}
var revealed_backpack_uids: Array = [{}, {}] # viewer -> {enemy item uid:true}，仅私有视图读取
var _next_backpack_uid: int = 1

var turn_number: int = 0
var game_over: bool = false
var winner: int = WINNER_UNDECIDED
var overtime_mode: bool = false           # 加时赛局（create_overtime / apply_overtime_bench 置位·启用骤死裁决）
var action_lock_turn: Array[int] = [-1, -1]     # 动作锁定保留基建（原烛阴 h17 v5 使用，2026-08-06 重设计后暂无施加者）
var action_locked: Array[int] = [-1, -1]        # 被锁定动作（ActionDef.Action 或 ActionDef.ACTIVE；不可执行时兜底只能攒）
var energy_burn_turn: int = -1                         # 毕方 h22【焚天火兆】：在该 turn_number 的回合末清空双方能量；-1=无火兆
var upgrade_next_wave: Array[bool] = [false, false]     # 牛金 h02【玄金不动相】：挡下波/大波后，该方下一次波按大波结算
var retained_big_defend: Array[bool] = [false, false]   # 鬼金 h08【不坠神言】：未兑现的大防由队伍保留至下一回合结束
var retained_big_defend_until_turn: Array[int] = [-1, -1] # 保留大防最后生效的 turn_number；-1=无状态
var _retain_big_defend_candidate: Array[bool] = [false, false]  # resolve 原子相位临时态：本回合哪方由鬼金打出了待判定的大防
var _retained_big_defend_in_use: Array[bool] = [false, false]   # resolve 临时态：已消费的后备大防继续挡完同一次多段基础攻击

var rng := RandomNumberGenerator.new()    # 可 seed (§D7)：联机/录像/测试可复现
var _skills: Array = [[], []]             # _skills[player][slot]: HeroSkill 或 null

## 英雄技能组件注册表：hero_id → 组件脚本。未列入者 = 无技能（_skills 为 null）。
## 随实装逐个加入。swap 后此表与 v3 _HERO_SKILL_SCRIPTS 合并/替换。
const _HERO_SKILL_SCRIPTS := {
	"h01": preload("res://src/battle/skills/h01_dunshu.gd"),
	"h02": preload("res://src/battle/skills/h02_xuanjinbudongxiang.gd"),
	"h03": preload("res://src/battle/skills/h03_leiyin.gd"),
	"h04": preload("res://src/battle/skills/h04_wucidi.gd"),
	"h05": preload("res://src/battle/skills/h05_longyuji.gd"),
	"h06": preload("res://src/battle/skills/h06_shenda.gd"),
	"h07": preload("res://src/battle/skills/h07_qianlizizaifeng.gd"),
	"h08": preload("res://src/battle/skills/h08_buzhuishenyan.gd"),
	"h09": preload("res://src/battle/skills/h09_liuzhaoyanluo.gd"),
	"h10": preload("res://src/battle/skills/h10_taichuwanfa.gd"),
	"h11": preload("res://src/battle/skills/h11_yingshou.gd"),
	"h12": preload("res://src/battle/skills/h12_nafu.gd"),
	"h13": preload("res://src/battle/skills/h13_anchao.gd"),
	"h14": preload("res://src/battle/skills/h14_tianbuzang.gd"),
	"h15": preload("res://src/battle/skills/h15_qishazhangui.gd"),
	"h16": preload("res://src/battle/skills/h16_baihong.gd"),
	"h17": preload("res://src/battle/skills/h17_zhenya.gd"),
	"h18": preload("res://src/battle/skills/h18_base_damage_field.gd"),
	"h19": preload("res://src/battle/skills/h19_jianta.gd"),
	"h20": preload("res://src/battle/skills/h20_duanzui.gd"),
	"h21": preload("res://src/battle/skills/h21_diaohu.gd"),
	"h22": preload("res://src/battle/skills/h22_yiming.gd"),
	"h23": preload("res://src/battle/skills/h23_tianguangchangshi.gd"),
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
	team_statuses = [{}, {}]
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
	energy_max = [ActionDef.MAX_ENERGY, ActionDef.MAX_ENERGY]
	selected_action = [-1, -1]
	_switch_to = [-1, -1]
	_forced_pull = [-1, -1]
	_active_target = [-1, -1]
	_attack_target = [-1, -1]
	_second_action = [-1, -1]
	_second_attack_target = [-1, -1]
	pending_death_switch = [false, false]
	_empowered_wave = [false, false]
	_split_big_wave = [false, false]
	_blood_payment = [false, false]
	_blood_payment_source = [-1, -1]
	_energy_cap_discount = [false, false]
	free_switch_usage_turn = [-1, -1]
	free_switch_uses = [0, 0]
	_pending_free_switches = [[], []]
	_pending_reserve_pursuit_source = [-1, -1]
	_pending_reserve_pursuit_target = [-1, -1]
	_active_transform_requested = [false, false]
	_last_action = [-1, -1]
	items = [[], []]
	item_uses = [[], []]
	info_distortion = [{}, {}]
	item_buffs = [{}, {}]
	timed_item_effects = [[], []]
	_imod = [{}, {}]
	relics = [[], []]
	slots = [[], []]
	battle_backpack_enabled = false
	battle_backpacks = [[], []]
	used_item_history = [[], []]
	revealed_backpack_uids = [{}, {}]
	_next_backpack_uid = 1
	turn_number = 0
	game_over = false
	winner = WINNER_UNDECIDED
	energy_burn_turn = -1
	upgrade_next_wave = [false, false]
	retained_big_defend = [false, false]
	retained_big_defend_until_turn = [-1, -1]
	_retain_big_defend_candidate = [false, false]
	_retained_big_defend_in_use = [false, false]

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
			_skills[p].append(_make_skill(h.hero_id))


func _make_skill(hero_id: String) -> HeroSkill:
	var script: Script = _HERO_SKILL_SCRIPTS.get(hero_id, null)
	return script.new() if script != null else null


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

## 统一能量获得入口：应用出战英雄的 energy_gain_bonus（虚日【步虚无有乡】= 每次 +0.5 能），
## clamp 到本队动态 energy_max。现有能量若已达到/超过上限则原样保留且本次不得能，绝不反向截断超额能量。
## boostable=false 的来源不吃加成；passive=true 仅供固定回合被动收入使用。
## （2026-07-04 Eddy 批：被动 +1 能/回合 = 白给收入不加成——
##   虚日站场挂机躺赚 0.5/回合的通胀漏洞；只有主动来源（攒/转化/combo/道具）吃加成）。
func _gain_energy(player: int, amount: int, boostable: bool = true,
		passive: bool = false, allow_overflow_conversion: bool = true) -> int:
	if amount <= 0:
		return 0
	var lock_turn: int = int(item_buffs[player].get("energy_gain_lock_turn", -1))
	# 回合被动收入在上一回合 Phase 6 发放，因此用 turn_number + 1 对齐它服务的选择回合。
	# 其他主动来源按实际发生时的 turn_number 判断。花能、减能与能量交换不走本入口。
	if (passive and lock_turn == turn_number + 1) \
			or (not passive and lock_turn == turn_number):
		return 0
	if boostable:
		var sk: HeroSkill = _skills[player][active_index[player]]
		if sk != null:
			amount += sk.energy_gain_bonus(self, player, active_index[player])
	var before: int = energy[player]
	if energy[player] < energy_max[player]:
		energy[player] = mini(energy[player] + amount, energy_max[player])
	var gained: int = energy[player] - before
	var overflow: int = maxi(0, amount - gained)
	if allow_overflow_conversion and overflow > 0:
		if int(item_buffs[player].get("energy_overflow_turn", -1)) != turn_number:
			item_buffs[player]["energy_overflow_turn"] = turn_number
			item_buffs[player]["unconverted_energy_overflow"] = 0
		item_buffs[player]["unconverted_energy_overflow"] = int(
			item_buffs[player].get("unconverted_energy_overflow", 0)) + overflow
	if allow_overflow_conversion and overflow > 0 \
			and int(item_buffs[player].get("overflow_energy_to_heal_turn", -1)) == turn_number:
		_convert_pending_energy_overflow_to_heal(player)
	elif allow_overflow_conversion and overflow > 0 \
			and bool(item_mod(player, "overflow_energy_to_heal", false)):
		_convert_pending_energy_overflow_to_heal(player)
	if not passive and gained > 0:
		item_buffs[player]["active_energy_gain_turn"] = turn_number
		var armor: int = int(item_mod(player, "first_active_energy_gain_shield", 0))
		if armor > 0:
			shield[player][active_index[player]] += armor
			set_item_mod(player, "first_active_energy_gain_shield", 0)
	return gained


func _convert_pending_energy_overflow_to_heal(player: int) -> void:
	var overflow: int = int(item_buffs[player].get("unconverted_energy_overflow", 0))
	if overflow <= 0:
		return
	item_buffs[player]["unconverted_energy_overflow"] = 0
	var living: Array = living_heroes(player)
	if not living.is_empty():
		var lowest: int = int(living[0])
		for slot_variant in living:
			var slot: int = int(slot_variant)
			if hp[player][slot] < hp[player][lowest]:
				lowest = slot
		_heal(player, lowest, overflow, false)


func arm_overflow_energy_to_heal(player: int) -> void:
	item_buffs[player]["overflow_energy_to_heal_turn"] = turn_number
	set_item_mod(player, "overflow_energy_to_heal", true)
	if int(item_buffs[player].get("energy_overflow_turn", -1)) == turn_number:
		_convert_pending_energy_overflow_to_heal(player)


## 永久降低一方的团队能量上限；返回实际降低的半能量。
## 只改上限，不删除已经存在的超额能量。minimum 与 amount 均使用半能单位。
func reduce_energy_max(player: int, amount: int, minimum: int) -> int:
	if player < 0 or player >= energy_max.size() or amount <= 0:
		return 0
	var old_max: int = energy_max[player]
	var floor_value: int = mini(maxi(minimum, 0), old_max)
	energy_max[player] = maxi(old_max - amount, floor_value)
	return old_max - energy_max[player]


## === 技能组件 / UI 的公共调用接口（B3 私有访问转正·行为不变）===
## 技能组件用：记账「attacker_player 击杀 victim_player 的 victim_slot」——h11 娄金穷追致死后归因（on_kill 只对直接攻击触发）。
func credit_kill(attacker_player: int, victim_player: int, victim_slot: int) -> void:
	_killer[victim_player][victim_slot] = attacker_player

## 技能组件用：请求在 victim_player 身上强制揪 slot 号替补上场——h21 枭阳【调虎离山】（resolve Phase 2.7 执行）。
func request_forced_pull(victim_player: int, slot: int) -> void:
	_forced_pull[victim_player] = slot

## 技能组件用：请求本方当前出战英雄在即时主动技阶段结束后，转变为敌方当前出战英雄。
## 延后到 Phase 2.65 批量落地，确保双方同时发动时都读取转变前的敌方快照。
func request_active_transform(player: int) -> void:
	_active_transform_requested[player] = true

## 技能组件用：读 player 本回合为主动技指定的目标槽（-1=未指定）。resolve 末统一清。
func active_target(player: int) -> int:
	return _active_target[player]

## UI / 测试只读：player 本回合基础攻击显式指定的敌方槽（-1=标准出战位）。
func attack_target(player: int) -> int:
	return _attack_target[player]


func second_action(player: int) -> int:
	return _second_action[player]


func second_attack_target(player: int) -> int:
	return _second_attack_target[player]

## UI 只读：取指定槽位的 HeroSkill（不暴露 _skills 私有容器）。
func get_skill(player: int, slot: int) -> HeroSkill:
	return _skills[player][slot]

## UI 只读：该玩家当前能否切换（公共包装 _can_switch）。
func can_switch(player: int) -> bool:
	return _can_switch(player)

## UI 只读：指定动作的能量成本（半能·公共包装 _get_cost）。
func action_cost(player: int, action: int) -> int:
	if action == ActionDef.Action.BIG_ATTACK \
			and int(item_buffs[player].get("free_big_attack_until_turn", -1)) == turn_number:
		return 0
	return maxi(0, _get_cost(player, action) + _queued_action_cost_delta(player, action))

func get_status(player: int, slot: int, key: String, default: Variant = null) -> Variant:
	if TEAM_SCOPED_STATUS_KEYS.has(key):
		return get_team_status(player, key, default)
	return statuses[player][slot].get(key, default)

func set_status(player: int, slot: int, key: String, value: Variant) -> void:
	if TEAM_SCOPED_STATUS_KEYS.has(key):
		set_team_status(player, key, value)
		return
	statuses[player][slot][key] = value


func get_team_status(player: int, key: String, default: Variant = null) -> Variant:
	if player < 0 or player >= team_statuses.size():
		return default
	return team_statuses[player].get(key, default)


func set_team_status(player: int, key: String, value: Variant) -> void:
	if player < 0 or player >= team_statuses.size():
		return
	if (value is int or value is float) and int(value) <= 0:
		team_statuses[player].erase(key)
	else:
		team_statuses[player][key] = value


## 罪已昭只记录并回收自己实际补上的脆弱层数，避免到期时误删猎物印记等其他来源。
func apply_h20_vulnerability(player: int, slot: int, amount: int = 1) -> void:
	if player < 0 or player >= statuses.size() \
			or slot < 0 or slot >= statuses[player].size() or amount <= 0:
		return
	var current: int = int(get_status(player, slot, "vuln", 0))
	var contribution: int = int(get_status(player, slot, "h20_vuln_contribution", 0))
	if current < amount:
		contribution += amount - current
		set_status(player, slot, "vuln", amount)
	set_status(player, slot, "h20_vuln_contribution", contribution)
	set_status(player, slot, "h20_vuln_until_turn", turn_number + 1)


func clear_vulnerability(player: int, slot: int) -> void:
	(statuses[player][slot] as Dictionary).erase("vuln")
	(statuses[player][slot] as Dictionary).erase("h20_vuln_contribution")
	(statuses[player][slot] as Dictionary).erase("h20_vuln_until_turn")


func _expire_h20_vulnerabilities(events: Array) -> void:
	for side in [0, 1]:
		for slot in range(statuses[side].size()):
			var until_turn: int = int(get_status(side, slot, "h20_vuln_until_turn", -1))
			if until_turn < 0 or until_turn > turn_number:
				continue
			var contribution: int = maxi(0, int(get_status(
					side, slot, "h20_vuln_contribution", 0)))
			var remaining: int = maxi(0, int(get_status(side, slot, "vuln", 0)) - contribution)
			(statuses[side][slot] as Dictionary).erase("h20_vuln_contribution")
			(statuses[side][slot] as Dictionary).erase("h20_vuln_until_turn")
			if remaining > 0:
				set_status(side, slot, "vuln", remaining)
			else:
				(statuses[side][slot] as Dictionary).erase("vuln")
			if contribution > 0:
				events.append({id = "h20_vulnerability_expired", player = side, slot = slot})


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


func living_heroes(player: int) -> Array[int]:
	var result: Array[int] = []
	for i in range(hp[player].size()):
		if hp[player][i] > 0:
			result.append(i)
	return result


## 返回当前生命最低的存活英雄；exclude_slot>=0 时排除该槽。平手取较小槽位，保证联机确定性。
func lowest_hp_living_hero(player: int, exclude_slot: int = -1) -> int:
	var best_slot: int = -1
	var best_hp: int = 0x7FFFFFFF
	for slot in range(hp[player].size()):
		if slot == exclude_slot or hp[player][slot] <= 0:
			continue
		if hp[player][slot] < best_hp:
			best_hp = hp[player][slot]
			best_slot = slot
	return best_slot


# === 动作选择 / 费用 ===

func _get_cost(player: int, action: int) -> int:
	if action == ActionDef.ACTIVE:
		var sk: HeroSkill = _skills[player][active_index[player]]
		return sk.active_cost(self, player, active_index[player]) if sk != null and sk.has_active() else 0
	if action in ActionDef.BASE_ACTION_DEF:
		return ActionDef.BASE_ACTION_DEF[action]["cost"]
	return 0


## 已提交道具对行动费用的纯查询修正。选招、AI/预览、血量支付、并封折扣与最终扣费共用。
func _queued_action_cost_delta(player: int, action: int) -> int:
	var delta: int = 0
	for use_variant in item_uses[player]:
		var use: Dictionary = use_variant
		var data: ItemData = use.get("data", null)
		if data != null and data.effect != null:
			delta += data.effect.action_cost_delta(self, player, action, data)
	return delta


## 本方【可用】能量（半能）= 能量池（最低 0）。
## 本函数是全引擎唯一能量闸口（can_afford/主动技/道具补·升全走此）。
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
	# 息灵铃公开提交后，双方在同一选择阶段就必须按“技能无效”计算动作合法性。
	for side in [0, 1]:
		for use_variant in item_uses[side]:
			var use: Dictionary = use_variant
			var data: ItemData = use.get("data", null)
			if data != null and data.item_id == "t3_xiling_ling":
				return null
	return _skills[player][slot]


## 出战英雄是否可用防/大防（穷奇 h15【七杀战鬼】= 不可）。下场即恢复（按出战英雄判定）。
func _can_defend(player: int) -> bool:
	var sk: HeroSkill = _eff_skill(player, active_index[player])
	return sk == null or sk.can_defend()


## 定身符的持续禁切期限包含当前回合与下回合；死亡后的替补登场不走本闸口。
func switch_locked(player: int) -> bool:
	return int(item_buffs[player].get("switch_lock_until_turn", -1)) >= turn_number


func _turn_switch_locked(player: int) -> bool:
	return switch_locked(player) \
		or int(item_buffs[player].get("tianluo_switch_lock_turn", -1)) == turn_number


## 主动/免费切换统一闸口。结算期的强制换位另由 _perform_switch 再收口一次。
func _can_switch(player: int) -> bool:
	return not _turn_switch_locked(player)


func _can_afford_with_cost(player: int, action: int, cost: int) -> bool:
	if turn_number == action_lock_turn[player]:
		# 动作锁定保留基建：锁定动作可执行 → 本拍仅它合法；不可执行（付不起 /
		# 被其他规则禁 / 切换无活替补 / 主动技 cap 满）→ 兜底只能「攒」（无死锁保证）。
		if _locked_action_doable(player):
			if action != action_locked[player]:
				return false
		elif action != ActionDef.Action.CHARGE:
			return false
	if action in ActionDef.DEFEND_ACTIONS and not _can_defend(player):
		return false   # 七杀战鬼：嗜杀红温·防/大防不合法（单一收口，legal_actions/UI/AI 全走此）
	if action == ActionDef.Action.SWITCH and not _can_switch(player):
		return false
	return usable_energy(player) >= maxi(0, cost)


func can_afford(player: int, action: int) -> bool:
	return _can_afford_with_cost(player, action, action_cost(player, action))


## 锁定动作当前是否可执行（不含锁定规则自身·防递归）——付得起且未被其他规则禁；
## 锁「切换」需有存活替补（否则合法集为空=死锁）；锁主动技走 _can_use_active_raw（cap/费用/前置）。
## 仅在锁定生效拍被调用（非常态热路径）·零分配。
func _locked_action_doable(player: int) -> bool:
	var a: int = action_locked[player]
	if a == ActionDef.ACTIVE:
		return _can_use_active_raw(player) \
			or _can_use_active_raw(player, false, true) \
			or (_blood_payment_source[player] >= 0 and (_can_use_active_raw(player, true) \
				or _can_use_active_raw(player, true, true)))
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
	var cost: int = action_cost(player, a)
	var discounted_cost: int = maxi(0, cost - ENERGY_CAP_DISCOUNT_AMOUNT)
	var can_discount: bool = cost > 0 and has_energy_cap_discount(player) \
		and energy_max[player] - ENERGY_CAP_DISCOUNT_COST >= ENERGY_CAP_DISCOUNT_FLOOR
	return usable_energy(player) >= cost or _can_pay_blood_raw(player, cost) \
		or (can_discount and (usable_energy(player) >= discounted_cost \
			or _can_pay_blood_raw(player, discounted_cost)))


## target = 房日基础攻击显式指定的敌方英雄槽；-1 保持标准“攻击结算时出战位”语义。
## empowered_wave = 亢金在队时为本次基础「波」额外支付 1 能并增加 1 点伤害。
## split_big_wave = 玄冥出战时把本次「大波」改为连续两次「波」。
## blood_payment = 蚩尤主动把本回合我方英雄费用改为消耗自己的血量。
## energy_cap_discount = 并封在队时降低 1 点能量上限，使本回合行动费用减少 1 点。
func select_action(player: int, action: int, target: int = -1, empowered_wave: bool = false,
		split_big_wave: bool = false, blood_payment: bool = false,
		energy_cap_discount: bool = false) -> bool:
	if energy_cap_discount:
		if not can_use_energy_cap_discount(player, action, empowered_wave, blood_payment):
			return false
	elif blood_payment:
		if not can_pay_action_with_blood(player, action, empowered_wave):
			return false
	elif not can_afford(player, action):
		return false
	if empowered_wave and not can_empower_wave_action(
			player, action, blood_payment, energy_cap_discount):
		return false
	if split_big_wave and not can_split_big_wave_action(
			player, action, blood_payment, energy_cap_discount):
		return false
	if target < -1:
		return false
	if target >= 0:
		if not ActionDef.is_attack(action) or not can_target_any_enemy_with_base_attack(player, action):
			return false
		var foe: int = 1 - player
		if target >= hp[foe].size() or hp[foe][target] <= 0:
			return false
	selected_action[player] = action
	_empowered_wave[player] = empowered_wave
	_split_big_wave[player] = split_big_wave
	_blood_payment[player] = blood_payment
	_energy_cap_discount[player] = energy_cap_discount
	if blood_payment and _blood_payment_source[player] < 0:
		_blood_payment_source[player] = active_index[player]
	_attack_target[player] = target if ActionDef.is_attack(action) else -1
	_switch_to[player] = -1
	_active_target[player] = -1
	if _second_action[player] == action or action == ActionDef.ACTIVE \
			or action == ActionDef.Action.SWITCH:
		_second_action[player] = -1
		_second_attack_target[player] = -1
	return true


func has_lianhuan_gu_queued(player: int) -> bool:
	for use_variant in item_uses[player]:
		var use: Dictionary = use_variant
		var data: ItemData = use.get("data", null)
		if data != null and data.item_id == "t3_lianhuan_gu":
			return true
	return false


func _projected_energy_after_primary(player: int) -> int:
	var action: int = selected_action[player]
	if action < ActionDef.Action.CHARGE or action > ActionDef.Action.BIG_DEFEND:
		return usable_energy(player)
	var cost: int = action_cost(player, action)
	if _empowered_wave[player]:
		cost += EMPOWERED_WAVE_COST
	if _energy_cap_discount[player] and cost > 0:
		cost = maxi(0, cost - ENERGY_CAP_DISCOUNT_AMOUNT)
	var projected: int = usable_energy(player)
	if not _blood_payment[player]:
		projected -= cost
		if cost > 0 and projected == 0:
			projected += _queued_exact_spend_refund(player)
	if action == ActionDef.Action.CHARGE:
		var gain: int = int(ActionDef.BASE_ACTION_DEF[action]["energy_gain"])
		var skill: HeroSkill = _skills[player][active_index[player]]
		if skill != null:
			gain += skill.energy_gain_bonus(self, player, active_index[player])
		projected = mini(projected + gain, energy_max[player])
	return maxi(projected, 0)


func _queued_exact_spend_refund(player: int) -> int:
	var amount: int = 0
	for use_variant in item_uses[player]:
		var use: Dictionary = use_variant
		var data: ItemData = use.get("data", null)
		if data != null and data.item_id == "t2_huiliu_zhu":
			amount += int(data.params.get("energy", 4))
	return amount


func _settle_exact_spend_refund(player: int, events: Array, step: int = 1) -> void:
	var amount: int = int(item_mod(player, "exact_spend_refund_pending", 0))
	if amount <= 0:
		return
	set_item_mod(player, "exact_spend_refund_pending", 0)
	var gained: int = _gain_energy(player, amount)
	events.append({id = "exact_spend_refund", player = player, amount = gained, step = step})


## 连环鼓的第二行动只接受五个公共动作；不含切换、英雄主动技及其额外付款形态。
## 费用按第一行动执行后的预计资源校验，因此“攒→大波”等顺序规划可成立。
func select_second_action(player: int, action: int, target: int = -1) -> bool:
	if not has_lianhuan_gu_queued(player):
		return false
	if selected_action[player] < ActionDef.Action.CHARGE \
			or selected_action[player] > ActionDef.Action.BIG_DEFEND:
		return false
	if action < ActionDef.Action.CHARGE or action > ActionDef.Action.BIG_DEFEND \
			or action == selected_action[player]:
		return false
	if action in ActionDef.DEFEND_ACTIONS and not _can_defend(player):
		return false
	if _projected_energy_after_primary(player) < action_cost(player, action):
		return false
	if target < -1:
		return false
	if target >= 0:
		if not ActionDef.is_attack(action) or not can_target_any_enemy_with_base_attack(player, action):
			return false
		var opponent: int = 1 - player
		if target >= hp[opponent].size() or hp[opponent][target] <= 0:
			return false
	_second_action[player] = action
	_second_attack_target[player] = target if ActionDef.is_attack(action) else -1
	return true


func legal_second_actions(player: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not has_lianhuan_gu_queued(player) or selected_action[player] < 0:
		return out
	var saved_action: int = _second_action[player]
	var saved_target: int = _second_attack_target[player]
	for action in [ActionDef.Action.CHARGE, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND,
			ActionDef.Action.BIG_ATTACK, ActionDef.Action.BIG_DEFEND]:
		var targets: Array = living_heroes(1 - player) \
			if ActionDef.is_attack(action) and can_target_any_enemy_with_base_attack(player, action) else [-1]
		for target_variant in targets:
			var target: int = int(target_variant)
			if select_second_action(player, action, target):
				out.append({action = action, target = target})
	_second_action[player] = saved_action
	_second_attack_target[player] = saved_target
	return out


## 当前出战英雄是否提供基础攻击自由选敌（存活、未沉默、组件明确授权）。
func can_target_any_enemy_with_base_attack(player: int,
		action: int = ActionDef.Action.ATTACK) -> bool:
	var slot: int = active_index[player]
	if slot < 0 or slot >= hp[player].size() or hp[player][slot] <= 0:
		return false
	var sk: HeroSkill = _eff_skill(player, slot)
	if sk != null and sk.can_target_any_enemy_with_base_attack():
		return true
	if action != ActionDef.Action.ATTACK:
		return false
	if int(item_mod(player, "next_wave_any_target", 0)) > 0:
		return true
	# 选择期的道具尚未进入 apply_pre；已提交寻星坠也必须立即开放选敌。
	for use_variant in item_uses[player]:
		var use: Dictionary = use_variant
		var data: ItemData = use.get("data", null)
		if data != null and data.item_id == "t1_xunxing_zhui":
			return true
	return false


## 统一回血入口。返回实际回复量（半点）。
func _heal(player: int, slot: int, amount: int,
		allow_overflow_conversion: bool = true) -> int:
	if slot < 0 or slot >= hp[player].size() or hp[player][slot] <= 0 or amount <= 0:
		return 0
	# 凝血膏先把“生命回复”改写为护甲，因此可以在封脉针的禁疗规则下正常产甲。
	if bool(item_mod(player, "healing_to_shield", false)):
		shield[player][slot] += amount
		return 0
	if bool(item_mod(player, "healing_blocked", false)):
		return 0
	var before: int = hp[player][slot]
	hp[player][slot] = mini(hp[player][slot] + amount, max_hp[player][slot])
	var healed: int = hp[player][slot] - before
	var overflow: int = maxi(0, amount - healed)
	if allow_overflow_conversion and overflow > 0 \
			and bool(item_mod(player, "overheal_to_energy", false)):
		_gain_energy(player, overflow, true, false, false)
	return healed


## 当前出战英雄的主动技是否可用（has_active + cap 未满 + 费用够 + 组件自定前置 + 锁招收口）。
## blood_payment=true 时，费用由本回合已发动技能的蚩尤支付。
func can_use_active(player: int, blood_payment: bool = false,
		energy_cap_discount: bool = false) -> bool:
	if turn_number == action_lock_turn[player] and action_locked[player] != ActionDef.ACTIVE:
		return false   # 动作锁定拍被锁在非主动技动作 → 主动技不可用（兜底攒不经此口）
	return _can_use_active_raw(player, blood_payment, energy_cap_discount)


## 主动技可用性（不含锁招规则·供 can_use_active 与 _locked_action_doable 复用防递归）。
func _can_use_active_raw(player: int, blood_payment: bool = false,
		energy_cap_discount: bool = false) -> bool:
	var slot: int = active_index[player]
	var sk: HeroSkill = _eff_skill(player, slot)   # 沉默 → null → 主动技不可用
	if sk == null or not sk.has_active():
		return false
	var cap: int = sk.active_per_game_cap()
	if cap >= 0 and int(get_status(player, slot, "active_uses", 0)) >= cap:
		return false
	var cost: int = action_cost(player, ActionDef.ACTIVE)
	if energy_cap_discount:
		if cost <= 0 or not _can_spend_energy_cap_for_discount(player):
			return false
		cost = maxi(0, cost - ENERGY_CAP_DISCOUNT_AMOUNT)
	if blood_payment:
		if not _can_pay_blood_raw(player, cost):
			return false
	elif usable_energy(player) < cost:
		return false
	return sk.can_use_active(self, player, slot)


## 选择主动技（target = 玩家指定的目标槽，-1=未指定→由技能自行默认，如枭阳随机揪）。
func select_active(player: int, target: int = -1, blood_payment: bool = false,
		energy_cap_discount: bool = false) -> bool:
	if not can_use_active(player, blood_payment, energy_cap_discount):
		return false
	selected_action[player] = ActionDef.ACTIVE
	_empowered_wave[player] = false
	_split_big_wave[player] = false
	_blood_payment[player] = blood_payment
	_energy_cap_discount[player] = energy_cap_discount
	_active_target[player] = target
	_attack_target[player] = -1
	_switch_to[player] = -1
	return true


## 选择切换（目标必须存活、非当前出战）。切换 = 本回合的动作（占动作槽，0 能）。
func select_switch(player: int, target_slot: int) -> bool:
	if target_slot < 0 or target_slot >= hp[player].size():
		return false
	if target_slot == active_index[player] or hp[player][target_slot] <= 0:
		return false
	if not _can_switch(player):
		return false
	if not can_afford(player, ActionDef.Action.SWITCH):
		return false
	selected_action[player] = ActionDef.Action.SWITCH
	_empowered_wave[player] = false
	_split_big_wave[player] = false
	_blood_payment[player] = false
	_blood_payment_source[player] = -1
	_energy_cap_discount[player] = false
	_switch_to[player] = target_slot
	_attack_target[player] = -1
	_active_target[player] = -1
	return true


## 出战英雄阵亡后由玩家选替补上场。返回是否成功。
func execute_death_switch(player: int, slot: int) -> bool:
	if not pending_death_switch[player]:
		return false
	if slot < 0 or slot >= hp[player].size() or hp[player][slot] <= 0:
		return false
	active_index[player] = slot
	pending_death_switch[player] = false
	var replacement_shield: int = int(item_buffs[player].get(
		"pending_death_replacement_shield", 0))
	if replacement_shield > 0:
		shield[player][slot] += replacement_shield
		item_buffs[player].erase("pending_death_replacement_shield")
	var sk: HeroSkill = _skills[player][slot]
	if sk != null:
		sk.on_switch_in(self, player, slot)
	return true


func both_ready() -> bool:
	return selected_action[0] >= 0 and selected_action[1] >= 0


# === 鬼金 h08【不坠神言】：下一回合团队后备大防 ===

## 保留大防只在建立后的下一回合完整结算期间有效。
func has_retained_big_defend(player: int) -> bool:
	return retained_big_defend[player] \
		and retained_big_defend_until_turn[player] >= turn_number


# === 亢金 h05【龙御极】：可选强化波 ===

## 本队是否有亢金提供强化波。按“在队时”扫描全队（含替补）；沉默期间该技能不生效。
func has_empowered_wave(player: int) -> bool:
	for s in range(_skills[player].size()):
		var sk: HeroSkill = _eff_skill(player, s)
		if sk != null and sk.enables_empowered_wave():
			return true
	return false


## 指定动作当前能否启用强化波：只认基础「波」，且总费用能由所选资源支付。
func can_empower_wave_action(player: int, action: int, blood_payment: bool = false,
		energy_cap_discount: bool = false) -> bool:
	var can_pay: bool
	if energy_cap_discount:
		can_pay = can_use_energy_cap_discount(player, action, true, blood_payment)
	elif blood_payment:
		can_pay = can_pay_action_with_blood(player, action, true)
	else:
		can_pay = can_afford(player, action) \
			and usable_energy(player) >= action_cost(player, action) + EMPOWERED_WAVE_COST
	return action == ActionDef.Action.ATTACK \
		and has_empowered_wave(player) \
		and can_pay


func empowered_wave_selected(player: int) -> bool:
	return _empowered_wave[player]


## 切换已提交波的强化开关。关闭始终允许；开启时重新经过动作与能量门。
func select_empowered_wave(player: int, on: bool) -> bool:
	if on and not can_empower_wave_action(player, selected_action[player],
			_blood_payment[player], _energy_cap_discount[player]):
		return false
	_empowered_wave[player] = on
	return true


# === 玄冥 h13：可选双波形态 ===

## 只有当前出战、存活且未沉默的玄冥能改变自己的大波。
func has_split_big_wave(player: int) -> bool:
	var slot: int = active_index[player]
	if slot < 0 or slot >= hp[player].size() or hp[player][slot] <= 0:
		return false
	var sk: HeroSkill = _eff_skill(player, slot)
	return sk != null and sk.allows_split_big_wave()


func can_split_big_wave_action(player: int, action: int, blood_payment: bool = false,
		energy_cap_discount: bool = false) -> bool:
	return action == ActionDef.Action.BIG_ATTACK \
		and has_split_big_wave(player) \
		and (can_use_energy_cap_discount(player, action, false, blood_payment) \
			if energy_cap_discount else (can_pay_action_with_blood(player, action) \
			if blood_payment else can_afford(player, action)))


func split_big_wave_selected(player: int) -> bool:
	return _split_big_wave[player]


func select_split_big_wave(player: int, on: bool) -> bool:
	if on and not can_split_big_wave_action(player, selected_action[player],
			_blood_payment[player], _energy_cap_discount[player]):
		return false
	_split_big_wave[player] = on
	return true


# === 蚩尤 h14：本回合以血量支付我方英雄费用 ===

## 只有当前出战、存活且未沉默的蚩尤可主动开启血量支付。
func has_blood_payment(player: int) -> bool:
	var slot: int = active_index[player]
	if slot < 0 or slot >= hp[player].size() or hp[player][slot] <= 0:
		return false
	var sk: HeroSkill = _eff_skill(player, slot)
	return sk != null and sk.enables_blood_payment()


## 开启时把付款者钉在当前蚩尤槽位；星日免费切换只换出战位，不改变付款者。
func set_blood_payment_active(player: int, on: bool) -> bool:
	if not on:
		_blood_payment_source[player] = -1
		_blood_payment[player] = false
		return true
	if not has_blood_payment(player):
		return false
	_blood_payment_source[player] = active_index[player]
	return true


func blood_payment_source(player: int) -> int:
	var slot: int = _blood_payment_source[player]
	if slot < 0 or slot >= hp[player].size():
		return -1
	var sk: HeroSkill = _eff_skill(player, slot)
	if sk == null or not sk.enables_blood_payment():
		return -1
	return slot


## 选择动作时允许直接按 blood_payment=true 发动（AI / 联机旧入口），
## 也允许先在选择阶段发动再经星日免费切换；后者读取已记录的原蚩尤槽位。
func _candidate_blood_payment_source(player: int) -> int:
	var recorded: int = blood_payment_source(player)
	if recorded >= 0 and hp[player][recorded] > 0:
		return recorded
	return active_index[player] if has_blood_payment(player) else -1


## 只检查支付者与血量，不重复进入动作规则门；供锁招可执行性判断。
func _can_pay_blood_raw(player: int, cost: int) -> bool:
	var slot: int = _candidate_blood_payment_source(player)
	if slot < 0:
		return false
	return hp[player][slot] >= maxi(0, cost)


## 指定动作能否改用血量支付。empowered_wave 会把龙御极的额外 1 能一并计入。
func can_pay_action_with_blood(player: int, action: int, empowered_wave: bool = false,
		energy_cap_discount: bool = false) -> bool:
	if _candidate_blood_payment_source(player) < 0:
		return false
	if action in ActionDef.DEFEND_ACTIONS and not _can_defend(player):
		return false
	if action == ActionDef.Action.SWITCH and not _can_switch(player):
		return false
	if turn_number == action_lock_turn[player]:
		if _locked_action_doable(player):
			if action != action_locked[player]:
				return false
		elif action != ActionDef.Action.CHARGE:
			return false
	var cost: int = action_cost(player, action)
	if empowered_wave:
		cost += EMPOWERED_WAVE_COST
	if energy_cap_discount:
		if cost <= 0 or not _can_spend_energy_cap_for_discount(player):
			return false
		cost = maxi(0, cost - ENERGY_CAP_DISCOUNT_AMOUNT)
	return _can_pay_blood_raw(player, cost)


func blood_payment_selected(player: int) -> bool:
	return _blood_payment[player]


func select_blood_payment(player: int, on: bool) -> bool:
	if on and not can_pay_action_with_blood(player, selected_action[player],
			_empowered_wave[player], _energy_cap_discount[player]):
		return false
	_blood_payment[player] = on
	if on and _blood_payment_source[player] < 0:
		_blood_payment_source[player] = active_index[player]
	elif not on:
		_blood_payment_source[player] = -1
	return true


# === 并封 h24：降低能量上限，换取本回合行动减费 ===

## “在队时”=本队任一存活槽位（含未出战）携带该技能，且该槽未沉默。
func has_energy_cap_discount(player: int) -> bool:
	for s in range(_skills[player].size()):
		if hp[player][s] <= 0:
			continue
		var sk: HeroSkill = _eff_skill(player, s)
		if sk != null and sk.enables_energy_cap_discount():
			return true
	return false


## 必须能完整支付 1 点上限；3.5 点不能折半支付来换取完整 1 点减费。
func _can_spend_energy_cap_for_discount(player: int) -> bool:
	return has_energy_cap_discount(player) \
		and energy_max[player] - ENERGY_CAP_DISCOUNT_COST >= ENERGY_CAP_DISCOUNT_FLOOR


## 正费用行动才可选择；费用包含龙御极追加费用。道具对行动的费用修正在 resolve 时再合并。
func can_use_energy_cap_discount(player: int, action: int, empowered_wave: bool = false,
		blood_payment: bool = false) -> bool:
	if not _can_spend_energy_cap_for_discount(player):
		return false
	var cost: int = action_cost(player, action)
	if empowered_wave:
		cost += EMPOWERED_WAVE_COST
	if cost <= 0:
		return false
	var discounted_cost: int = maxi(0, cost - ENERGY_CAP_DISCOUNT_AMOUNT)
	if action == ActionDef.ACTIVE:
		return _can_use_active_raw(player, blood_payment, true)
	if blood_payment:
		return can_pay_action_with_blood(player, action, empowered_wave, true)
	return _can_afford_with_cost(player, action, discounted_cost)


func energy_cap_discount_selected(player: int) -> bool:
	return _energy_cap_discount[player]


func select_energy_cap_discount(player: int, on: bool) -> bool:
	if on and not can_use_energy_cap_discount(player, selected_action[player],
			_empowered_wave[player], _blood_payment[player]):
		return false
	_energy_cap_discount[player] = on
	return true


# === 广寒 h16：替补追击 ===

## 找到 player 替补席中存活、未沉默且声明追击伤害的英雄；无则 -1。
func _reserve_pursuer(player: int) -> int:
	for s in range(hp[player].size()):
		if s == active_index[player] or hp[player][s] <= 0:
			continue
		var sk: HeroSkill = _skills[player][s]
		if sk != null and sk.reserve_pursuit_damage() > 0:
			return s
	return -1


## 基础攻击穿过防御门后登记追击。一个动作即使包含多段命中，也只登记一次；
## 真正切换与伤害延后到双方主攻击全部完成后，避免破坏同时独立结算的目标快照。
func _queue_reserve_pursuit(attacker_player: int, attacker_slot: int, target_slot: int) -> void:
	if _pending_reserve_pursuit_target[attacker_player] >= 0:
		return
	var pursuer: int = _reserve_pursuer(attacker_player)
	if pursuer < 0 or pursuer == attacker_slot:
		return
	_pending_reserve_pursuit_source[attacker_player] = attacker_slot
	_pending_reserve_pursuit_target[attacker_player] = target_slot


## 双方主攻击完成后的追击相位：先按同一快照确认双方资格并全部完成登场，再依次落追击伤害。
## 原出战者或原目标已在主攻击中阵亡时不追尸，也不借技能替代死亡换人。
func _resolve_reserve_pursuits(events: Array) -> void:
	var pursuits: Array[Dictionary] = []
	for p in [0, 1]:
		var source: int = _pending_reserve_pursuit_source[p]
		var target: int = _pending_reserve_pursuit_target[p]
		var pursuer: int = _reserve_pursuer(p)
		var foe: int = 1 - p
		if source < 0 or target < 0 or pursuer < 0:
			continue
		if source >= hp[p].size() or hp[p][source] <= 0 or active_index[p] != source:
			continue
		if target >= hp[foe].size() or hp[foe][target] <= 0:
			continue
		pursuits.append({player = p, from_slot = source, pursuer = pursuer, target = target})

	for pursuit: Dictionary in pursuits:
		var switch_event_start: int = events.size()
		_perform_switch(
			int(pursuit["player"]),
			int(pursuit["from_slot"]),
			int(pursuit["pursuer"]),
			events)
		for event_index: int in range(switch_event_start, events.size()):
			var switch_event: Dictionary = events[event_index]
			switch_event["resolution_phase"] = "h16_pursuit_switch"
			switch_event["pursuit_player"] = int(pursuit["player"])

	for pursuit: Dictionary in pursuits:
		var p: int = int(pursuit["player"])
		var source: int = int(pursuit["from_slot"])
		var pursuer: int = int(pursuit["pursuer"])
		var target: int = int(pursuit["target"])
		var sk: HeroSkill = _skills[p][pursuer]
		if sk == null or active_index[p] != pursuer or hp[p][pursuer] <= 0:
			continue
		var damage: int = sk.reserve_pursuit_damage()
		if damage <= 0:
			continue
		var pursuit_event := {
			id = "h16_reserve_pursuit", player = p, from_slot = source,
			slot = pursuer, target = target,
		}
		events.append(pursuit_event)
		var detail_event_start: int = events.size()
		var outcome: Dictionary = {}
		var hp_damage: int = _apply_damage(
			1 - p, damage, p, ActionDef.Action.ATTACK, ActionDef.Pen.NORMAL,
			ActionDef.Action.CHARGE, events, [], "skill", pursuer, target, false,
			outcome)
		for event_index: int in range(detail_event_start, events.size()):
			var detail_event: Dictionary = events[event_index]
			detail_event["resolution_phase"] = "h16_pursuit"
			detail_event["pursuit_player"] = p
		pursuit_event["hp_damage"] = hp_damage
		pursuit_event["damage_total"] = int(outcome.get("damage_total", 0))
		pursuit_event["shield_damage"] = maxi(
			int(outcome.get("damage_total", 0)) - hp_damage, 0)
		pursuit_event["connected"] = bool(outcome.get("connected", false))
		pursuit_event["target_defeated"] = bool(outcome.get("defeated", false))


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


## 需要玩家明确选择己方英雄的道具。联机/UI/AI 共用，避免把英雄槽误作道具槽。
static func item_requires_friendly_hero_target(data: ItemData) -> bool:
	return data != null and data.item_id in [
		"t1_houzhen_qian",
		"t2_yijia_huan", "t2_huzhen_ding", "t2_jieyin_pei", "t2_daishang_san",
		"t2_xingjun_yaonang",
		"t3_huanming_qi", "t3_zhaohun_fan", "t3_yiyuan_deng",
	]


## 只能选择我方存活未出战英雄的道具；UI 与 AI 共用本口径。
static func item_requires_friendly_reserve_target(data: ItemData) -> bool:
	return data != null and data.item_id in [
		"t1_houzhen_qian",
		"t2_huzhen_ding", "t2_jieyin_pei", "t2_daishang_san", "t2_xingjun_yaonang",
		"t3_yiyuan_deng",
	]


## 招魂幡只选死亡替补；它复用通用英雄目标字段，但不能套用“存活英雄”UI门。
static func item_requires_friendly_dead_hero_target(data: ItemData) -> bool:
	return data != null and data.item_id == "t3_zhaohun_fan"


## 需要明确选择敌方道具槽的道具；复用 item_slot_targets，不新增联机字段。
static func item_requires_enemy_item_slot_target(data: ItemData) -> bool:
	return data != null and data.item_id in [
		"t2_shizhi_jiasuo", "t2_yawu_piao", "t2_cuiyong_pai",
	]


static func item_requires_friendly_item_slot_target(data: ItemData) -> bool:
	return data != null and data.item_id in [
		"t1_ronglu", "t1_jicun_pai", "t2_dianjinshi", "t2_baojia_feng",
		"t2_huanqian_tong",
	]


func is_living_reserve(player: int, slot: int) -> bool:
	return player >= 0 and player < hp.size() and slot >= 0 and slot < hp[player].size() \
		and slot != active_index[player] and hp[player][slot] > 0


func is_dead_reserve(player: int, slot: int) -> bool:
	return player >= 0 and player < hp.size() and slot >= 0 and slot < hp[player].size() \
		and slot != active_index[player] and hp[player][slot] <= 0


## 候阵签：按道具提交顺序缓存回合末计划登场位；实际结算时再次校验其仍为存活替补。
func queue_end_turn_entry(player: int, target: int) -> void:
	var entries: Array = item_mod(player, "end_turn_entries", [])
	entries.append(target)
	set_item_mod(player, "end_turn_entries", entries)


func valid_enemy_locked_item_target(player: int, slot: int) -> bool:
	var opponent: int = 1 - player
	if slot < 0 or slot >= slots[opponent].size():
		return false
	var target_slot: Dictionary = slots[opponent][slot]
	return int(target_slot.get("state", SlotState.SEALED)) == SlotState.CHARGING \
		and target_slot.get("item", null) != null and not bool(target_slot.get("used", false)) \
		and turn_number <= int(target_slot.get("since", -1))


func valid_enemy_ready_item_target(player: int, slot: int) -> bool:
	var opponent: int = 1 - player
	return slot >= 0 and slot < slots[opponent].size() and slot_ready(opponent, slot)


func valid_enemy_item_target_for(data: ItemData, player: int, slot: int) -> bool:
	if data == null:
		return false
	return valid_enemy_ready_item_target(player, slot) \
		if data.item_id in ["t2_yawu_piao", "t2_cuiyong_pai"] \
		else valid_enemy_locked_item_target(player, slot)


## 孤锋锥只在自己是当前唯一仍可使用的槽位道具时合法。
func is_only_ready_item_slot(player: int, data: ItemData) -> bool:
	if data == null or player < 0 or player >= slots.size():
		return false
	var ready_count: int = 0
	for slot_index in range(slots[player].size()):
		if slot_ready(player, slot_index):
			ready_count += 1
	return ready_count == 1


func queued_item_slot_target(player: int, item_id: String) -> int:
	for use_variant in item_uses[player]:
		var use: Dictionary = use_variant
		var data: ItemData = use.get("data", null)
		if data != null and data.item_id == item_id:
			return int(use.get("item_slot_target", -1))
	return -1


func _mark_item_slot_used_this_turn(player: int, source_slot: int) -> void:
	if source_slot < 0:
		return
	var used: Array = item_buffs[player].get("used_item_slots_this_turn", [])
	if not used.has(source_slot):
		used.append(source_slot)
	item_buffs[player]["used_item_slots_this_turn"] = used


func _mark_item_countered_this_turn(player: int, source_slot: int) -> void:
	if source_slot < 0:
		return
	var countered: Array = item_buffs[player].get("countered_item_slots_this_turn", [])
	if not countered.has(source_slot):
		countered.append(source_slot)
	item_buffs[player]["countered_item_slots_this_turn"] = countered


func _record_consumed_item(player: int, data: ItemData) -> void:
	if data != null:
		used_item_history[player].append({item_id = data.item_id, tier = data.tier})


func arm_item_wager(player: int, enemy_slot: int, amount: int) -> void:
	if amount <= 0:
		return
	var wagers: Array = item_mod(player, "item_wagers", [])
	wagers.append({slot = enemy_slot, amount = amount})
	set_item_mod(player, "item_wagers", wagers)


func arm_item_insurance(player: int, own_slot: int) -> void:
	if own_slot < 0:
		return
	var insured: Array = item_mod(player, "insured_item_slots", [])
	if not insured.has(own_slot):
		insured.append(own_slot)
	set_item_mod(player, "insured_item_slots", insured)


func _insured_slot(player: int, source_slot: int) -> bool:
	return (item_mod(player, "insured_item_slots", []) as Array).has(source_slot)


func _return_countered_insured_item(player: int, source_slot: int,
		item_id: String, events: Array) -> void:
	if not battle_backpack_enabled or not _insured_slot(player, source_slot):
		return
	var temporary: bool = false
	var uid: int = -1
	if source_slot >= 0 and source_slot < slots[player].size():
		temporary = bool(slots[player][source_slot].get("temporary", false))
		uid = int(slots[player][source_slot].get("instance_uid", -1))
	var entry: Dictionary = {uid = uid, item_id = item_id, temporary = temporary}
	if uid < 0 or _bag_entry_index(player, uid) >= 0:
		entry = _new_backpack_entry(item_id, temporary)
	battle_backpacks[player].append(entry)
	events.append({id = "insured_item_returned", player = player,
		slot = source_slot, item_id = item_id})


## 封印卷轴：只封下一回合；同一到期回合的多件合并为多次抵消。
func schedule_item_seal(player: int, charges: int = 1) -> void:
	if charges <= 0:
		return
	var due_turn: int = turn_number + 1
	var windows: Array = item_buffs[player].get("sealed_item_turns", [])
	for window_variant in windows:
		var window: Dictionary = window_variant
		if int(window.get("turn", -1)) == due_turn:
			window["charges"] = int(window.get("charges", 0)) + charges
			item_buffs[player]["sealed_item_turns"] = windows
			return
	windows.append({turn = due_turn, charges = charges})
	item_buffs[player]["sealed_item_turns"] = windows


## 返回本次合法道具是否被当前回合到期的封印抵消；抵消仍由调用方消耗正式槽位。
func _consume_due_item_seal(player: int) -> bool:
	var windows: Array = item_buffs[player].get("sealed_item_turns", [])
	for i in range(windows.size()):
		var window: Dictionary = windows[i]
		if int(window.get("turn", -1)) != turn_number or int(window.get("charges", 0)) <= 0:
			continue
		window["charges"] = int(window["charges"]) - 1
		if int(window["charges"]) <= 0:
			windows.remove_at(i)
		if windows.is_empty():
			item_buffs[player].erase("sealed_item_turns")
		else:
			item_buffs[player]["sealed_item_turns"] = windows
		return true
	return false


func _schedule_energy_debt(player: int, amount: int) -> void:
	if amount <= 0:
		return
	var due_turn: int = turn_number + 1
	var debts: Array = item_buffs[player].get("energy_debt_turns", [])
	for debt_variant in debts:
		var debt: Dictionary = debt_variant
		if int(debt.get("turn", -1)) == due_turn:
			debt["amount"] = int(debt.get("amount", 0)) + amount
			item_buffs[player]["energy_debt_turns"] = debts
			return
	debts.append({turn = due_turn, amount = amount})
	item_buffs[player]["energy_debt_turns"] = debts


func _expire_due_item_seals() -> void:
	for player in [0, 1]:
		var kept: Array = []
		for window_variant in item_buffs[player].get("sealed_item_turns", []):
			var window: Dictionary = window_variant
			if int(window.get("turn", -1)) > turn_number and int(window.get("charges", 0)) > 0:
				kept.append(window)
		if kept.is_empty():
			item_buffs[player].erase("sealed_item_turns")
		else:
			item_buffs[player]["sealed_item_turns"] = kept


## 在 turn_number 已递增到新回合后调用，确保偿还先于该回合任何选招查询。
func _apply_due_energy_debts(events: Array) -> void:
	for player in [0, 1]:
		var kept: Array = []
		var repayment: int = 0
		for debt_variant in item_buffs[player].get("energy_debt_turns", []):
			var debt: Dictionary = debt_variant
			var due_turn: int = int(debt.get("turn", -1))
			if due_turn == turn_number:
				repayment += int(debt.get("amount", 0))
			elif due_turn > turn_number:
				kept.append(debt)
		if kept.is_empty():
			item_buffs[player].erase("energy_debt_turns")
		else:
			item_buffs[player]["energy_debt_turns"] = kept
		if repayment > 0:
			var paid: int = mini(energy[player], repayment)
			energy[player] = maxi(0, energy[player] - repayment)
			events.append({id = "magic_crystal_repay", player = player, amount = paid})


func _commit_magic_crystal(player: int, data: ItemData) -> void:
	_gain_energy(player, int(data.params.get("energy", 6)))
	_schedule_energy_debt(player, int(data.params.get("penalty", 2)))


func _valid_pointstone_target(player: int, source_slot: int, target_slot: int) -> bool:
	if target_slot < 0 or target_slot >= slots[player].size() \
			or target_slot == source_slot or not slot_ready(player, target_slot):
		return false
	var target_item: ItemData = slots[player][target_slot].get("item", null)
	return target_item != null and int(target_item.tier) == 1


## 点金石：来源槽缓存固定的传说三选一；换普通道具目标不会重掷候选。
func begin_pointstone_draft(player: int, source_slot: int, target_slot: int) -> Array:
	if source_slot < 0 or source_slot >= slots[player].size() or not slot_ready(player, source_slot):
		return []
	var source_item: ItemData = slots[player][source_slot].get("item", null)
	if source_item == null or source_item.item_id != "t2_dianjinshi" \
			or not _valid_pointstone_target(player, source_slot, target_slot):
		return []
	var source: Dictionary = slots[player][source_slot]
	if (source.get("upg_draft", []) as Array).is_empty():
		source["upg_draft"] = _weighted_draft_pick(ItemCatalog.all_tier3(), "", 3)
	return source["upg_draft"]


func _pointstone_upgrade(player: int, source_slot: int, target_slot: int,
		item_choice: int) -> ItemData:
	var choices: Array = begin_pointstone_draft(player, source_slot, target_slot)
	if item_choice < 0 or item_choice >= choices.size():
		return null
	var chosen: ItemData = choices[item_choice]
	return ItemCatalog.make(chosen.item_id)


const _ITEM_TX_SNAPSHOT := "_item_transaction_snapshot"
const _ITEM_TX_ACTIONS := "_item_transaction_actions"
const _PENDING_ITEM_EVENTS := "_pending_item_events"


## 本回合第一件道具真正提交前拍下可被天罗撤销的选择期事务状态。
## 使用现有快照 packer，令该临时快照仍可随 clone/联机快照安全往返。
func _begin_item_transaction(player: int) -> void:
	if item_buffs[player].has(_ITEM_TX_SNAPSHOT):
		return
	var prior_buffs: Dictionary = item_buffs[player].duplicate(true)
	item_buffs[player][_ITEM_TX_SNAPSHOT] = {
		energy = energy[player],
		item_buffs = prior_buffs,
		slots = _snap_pack_slots(player),
		relics = _snap_pack_relics(player),
		item_uses = _snap_pack_uses(player),
		backpack = battle_backpacks[player].duplicate(true),
		used_item_history = used_item_history[player].duplicate(true),
		revealed_backpack_uids = revealed_backpack_uids[player].duplicate(true),
	}
	item_buffs[player][_ITEM_TX_ACTIONS] = []


func _record_item_action(player: int, action: Dictionary) -> void:
	var actions: Array = item_buffs[player].get(_ITEM_TX_ACTIONS, [])
	actions.append(action.duplicate(true))
	item_buffs[player][_ITEM_TX_ACTIONS] = actions


func _queue_item_event(player: int, event: Dictionary) -> void:
	var pending: Array = item_buffs[player].get(_PENDING_ITEM_EVENTS, [])
	pending.append(event.duplicate(true))
	item_buffs[player][_PENDING_ITEM_EVENTS] = pending


## 供 PRE 道具把统一生命结算产生的事件并入本回合权威事件流。
func queue_item_events(player: int, queued: Array) -> void:
	for event_variant in queued:
		if event_variant is Dictionary:
			_queue_item_event(player, event_variant as Dictionary)


func _flush_pending_item_events(events: Array) -> void:
	for player in [0, 1]:
		for event_variant in item_buffs[player].get(_PENDING_ITEM_EVENTS, []):
			events.append((event_variant as Dictionary).duplicate(true))
		item_buffs[player].erase(_PENDING_ITEM_EVENTS)


## 同 ID 遗物共享一个状态区；各脚本按 stack_mode 在激活 hook 中追加次数/回合，
## unique 遗物则只维持唯一状态，不产生并行乘区。
func _register_relic(player: int, data: ItemData) -> void:
	var entry: Dictionary = {}
	for relic_variant in relics[player]:
		var relic: Dictionary = relic_variant
		if String((relic["data"] as ItemData).item_id) == data.item_id:
			entry = relic
			break
	if entry.is_empty():
		entry = {data = data, state = {}}
		relics[player].append(entry)
	var activation_events: Array = []
	data.effect.relic_on_activate(self, player, data, entry["state"], activation_events)
	_queue_item_event(player, {id = "relic_activated", player = player, item_id = data.item_id})
	for event_variant in activation_events:
		_queue_item_event(player, event_variant as Dictionary)


func _apply_submit_effect(player: int, target: int, data: ItemData) -> void:
	var submit_events: Array = []
	data.effect.apply_on_submit(self, player, target, data, submit_events)
	for event_variant in submit_events:
		_queue_item_event(player, event_variant as Dictionary)


## 提交一次道具使用（盲选阶段·揭示前·§3A）。index = items[player] 下标。
## 不占动作槽、用时免费、用量不限。返回是否合法。
func use_item(player: int, index: int, target_override: int = -1) -> bool:
	if index < 0 or index >= items[player].size():
		return false
	var data: ItemData = items[player][index]
	if data == null or data.effect == null:
		return false
	# 随身熔炉必须从三格经济栏明确选择另一件就绪道具作为燃料；
	# items[] 测试/兼容入口没有槽位语义，禁止在这里空放。
	if data.item_id == "t1_ronglu" or data.item_id == "t2_dianjinshi" \
			or item_requires_enemy_item_slot_target(data):
		return false
	if item_requires_friendly_hero_target(data) and target_override < 0:
		return false
	var resolved_target: int = _resolve_item_target(player, data, target_override)
	if not data.effect.can_use(self, player, resolved_target, data):
		return false
	_begin_item_transaction(player)
	info_distortion[player].erase("hide_item_bar")
	data.effect.on_consumed(self, player, resolved_target, data)
	# 封印卷轴：第一件合法道具照常消耗但不进入效果队列；兼容 items[] 入口以成功返回表达“已使用”。
	var sealed: bool = _consume_due_item_seal(player)
	_record_item_action(player, {item_id = data.item_id, source_slot = -1,
		target = resolved_target, item_slot_target = -1, upgraded_id = "", sealed = sealed})
	if sealed:
		return true
	# 遗物（持久·每回合 tick）：激活即登记到 relics，不走一次性 item_uses。
	if bool(data.params.get("relic", false)):
		_register_relic(player, data)
		return true
	if data.effect.resolves_on_submit():
		_apply_submit_effect(player, resolved_target, data)
		if not data.effect.queues_after_submit():
			return true
	if data.item_id == "t2_mojing":
		_commit_magic_crystal(player, data)
	item_uses[player].append({
		data = data,
		when = data.resolved_when(),
		target = resolved_target,
	})
	return true


# --- 本回合道具修正器累加器（_imod·transient）---

func item_mod(player: int, key: String, default: Variant = 0) -> Variant:
	return _imod[player].get(key, default)

func add_item_mod(player: int, key: String, amount: int) -> void:
	_imod[player][key] = int(_imod[player].get(key, 0)) + amount

func set_item_mod(player: int, key: String, value: Variant) -> void:
	_imod[player][key] = value


## 时滞枷锁：只延长敌方尚在冷却中的正式槽；槽若已改变则安全白板。
func delay_enemy_locked_item(player: int, slot: int, turns: int) -> bool:
	if turns <= 0 or not valid_enemy_locked_item_target(player, slot):
		return false
	var opponent: int = 1 - player
	slots[opponent][slot]["since"] = int(slots[opponent][slot]["since"]) + turns
	return true


## 催用牌：记录被点名的敌方就绪槽；回合末仍是同一件且未使用时，锁定下回合。
func arm_use_or_lock(player: int, slot: int) -> void:
	if not valid_enemy_ready_item_target(player, slot):
		return
	var opponent: int = 1 - player
	var watched: Dictionary = slots[opponent][slot]
	var watches: Array = item_mod(player, "use_or_lock_watches", [])
	watches.append({
		target_player = opponent,
		slot = slot,
		instance_uid = int(watched.get("instance_uid", -1)),
		item_id = String((watched.get("item", null) as ItemData).item_id),
	})
	set_item_mod(player, "use_or_lock_watches", watches)


## 净纹帚：只清除三种由基础攻击命中产生、会留待后续结算的英雄技能成果。
func clear_pending_hit_skill_effects() -> int:
	var cleared: int = 0
	for side in [0, 1]:
		for slot in range(statuses[side].size()):
			for key in ["poison", "vuln"]:
				if int(get_status(side, slot, key, 0)) > 0:
					if key == "vuln":
						clear_vulnerability(side, slot)
					else:
						(statuses[side][slot] as Dictionary).erase(key)
					cleared += 1
		if int(get_team_status(side, "jianqi", 0)) > 0:
			set_team_status(side, "jianqi", 0)
			cleared += 1
	return cleared


## 遗愿灯：实际牺牲与指定替补登场统一留给揭示后的核心死亡链。
func arm_last_wish(player: int, target: int) -> void:
	if is_living_reserve(player, target):
		set_item_mod(player, "last_wish_target", target)


func _resolve_last_wishes(actions: Array[int], events: Array) -> void:
	for player in [0, 1]:
		var target: int = int(item_mod(player, "last_wish_target", -1))
		if target < 0:
			continue
		# 无论牺牲是否被还魂丹等最低层保险拦下，本回合的行动机会都已经支付。
		actions[player] = -2
		selected_action[player] = -2
		_second_action[player] = -1
		_second_attack_target[player] = -1
		var sacrificed: int = active_index[player]
		var before: int = hp[player][sacrificed]
		lose_life(player, sacrificed, before, events, "last_wish")
		_resolve_deaths(actions, events)
		if hp[player][sacrificed] > 0 or not is_living_reserve(player, target):
			events.append({id = "last_wish_failed", player = player, slot = sacrificed})
			continue
		var healed: int = _heal(player, target, maxi(0, max_hp[player][target] - hp[player][target]))
		if execute_death_switch(player, target):
			for event_index in range(events.size() - 1, -1, -1):
				var event: Dictionary = events[event_index]
				if String(event.get("id", "")) == "force_switch_prompt" \
						and int(event.get("player", -1)) == player:
					events.remove_at(event_index)
					break
			events.append({id = "last_wish_entry", player = player, from = sacrificed,
				to = target, amount = healed})


## 借印佩：一件对应一个后排英雄；整次攻击结算时逐件兑现一次。
func arm_borrowed_mark(player: int, slot: int) -> void:
	var borrowed: Array = item_mod(player, "borrowed_mark_slots", [])
	borrowed.append(slot)
	set_item_mod(player, "borrowed_mark_slots", borrowed)


## 代伤伞：同拍多件按第一件确定目标，避免后提交者悄悄覆盖已公开选择。
func arm_attack_decoy(player: int, slot: int) -> void:
	if int(item_mod(player, "attack_decoy_target", -1)) < 0:
		set_item_mod(player, "attack_decoy_target", slot)


## 归营牌：多件在下一次实际切换一并治疗换下者。
func arm_return_camp_heal(player: int, amount: int) -> void:
	if amount > 0:
		item_buffs[player]["return_camp_heal"] = int(
			item_buffs[player].get("return_camp_heal", 0)) + amount


## 得能护符：每件都响应本回合第一次主动得能；若主动得能已在选择期发生，则揭示时补发。
func arm_first_active_energy_gain_shield(player: int, amount: int) -> void:
	if amount <= 0:
		return
	if int(item_buffs[player].get("active_energy_gain_turn", -1)) == turn_number:
		shield[player][active_index[player]] += amount
		return
	add_item_mod(player, "first_active_energy_gain_shield", amount)


## 藤蔓陷阱按受影响方累计；同拍多件共享来源并叠加伤害。
func arm_switch_out_trap(victim: int, source_player: int, amount: int) -> void:
	if amount <= 0:
		return
	var trap: Dictionary = item_mod(victim, "switch_out_trap", {})
	trap["damage"] = int(trap.get("damage", 0)) + amount
	trap["source_player"] = source_player
	set_item_mod(victim, "switch_out_trap", trap)


## 护身符：target_player 是否对一次 debuff/干扰免疫；是则【消耗】该次免疫并返回 true。
## 对敌 debuff 类道具（妖火/香蕉皮…）施加前调用，被免疫则不施加。
func item_debuff_blocked(target_player: int) -> bool:
	var n: int = int(_imod[target_player].get("immune", 0))
	if n > 0:
		_imod[target_player]["immune"] = n - 1
		return true
	return false


## 天罗脚本在 setup 期只登记请求；双方保护效果都建立后，由核心统一对称解析。
func request_tianluo(player: int) -> void:
	add_item_mod(player, "tianluo_requests", 1)


## 锁泉塞：只锁定目标方的下一个选择回合；同拍多件不延长、不叠加额外损失。
func schedule_energy_gain_lock(player: int) -> void:
	item_buffs[player]["energy_gain_lock_turn"] = maxi(
		int(item_buffs[player].get("energy_gain_lock_turn", -1)), turn_number + 1)


## 梦蝶只登记有效请求；实际交换固定在双方动作按原能量扣费后、切换与攻击前。
func request_mengdie(player: int) -> void:
	var opponent: int = 1 - player
	if item_debuff_blocked(opponent):
		add_item_mod(player, "mengdie_blocked", 1)
		return
	add_item_mod(player, "mengdie_requests", 1)


## 散契钟：只结束仍可继续影响未来结算的“道具状态”。已经到账的伤害、治疗、护甲、
## 能量与槽位变更不回滚；毒素/脆弱等英雄战斗状态因来源可能不是道具，也不在这里误删。
func end_all_active_item_effects() -> int:
	var ended: int = 0
	const PERSISTENT_ITEM_BUFF_KEYS: Array[String] = [
		"sealed_item_turns", "energy_debt_turns", "return_camp_heal",
		"energy_gain_lock_turn", "switch_lock_until_turn", "free_big_attack_until_turn",
		"exhausted_next", "exhausted_turn", "next_atk_bonus", "next_atk_total_bonus", "next_armor",
		"next_energy_penalty", "pending_death_replacement_shield",
	]
	for side in [0, 1]:
		ended += relics[side].size()
		relics[side] = []
		ended += timed_item_effects[side].size()
		timed_item_effects[side] = []
		for key in PERSISTENT_ITEM_BUFF_KEYS:
			if item_buffs[side].erase(key):
				ended += 1
		for slot in range(statuses[side].size()):
			if int(get_status(side, slot, "fatal_damage_immunity", 0)) > 0:
				ended += 1
				statuses[side].erase("fatal_damage_immunity")
	return ended


func revive_dead_reserve(player: int, target: int, amount: int, item_id: String) -> bool:
	if not is_dead_reserve(player, target) or amount <= 0:
		return false
	hp[player][target] = mini(amount, max_hp[player][target])
	shield[player][target] = 0
	pending_damage[player][target] = 0
	_death_processed[player][target] = false
	_killer[player][target] = -1
	pending_death_switch[player] = false if active_index[player] == target else pending_death_switch[player]
	_queue_item_event(player, {id = "hero_revived", player = player, slot = target,
		item_id = item_id, amount = hp[player][target]})
	return true


func swap_active_reserve_vitals(player: int, target: int, item_id: String) -> bool:
	if not is_living_reserve(player, target):
		return false
	var active: int = active_index[player]
	var active_hp: int = hp[player][active]
	var active_shield: int = shield[player][active]
	hp[player][active] = hp[player][target]
	shield[player][active] = shield[player][target]
	hp[player][target] = active_hp
	shield[player][target] = active_shield
	_queue_item_event(player, {id = "vitals_swapped", player = player, from = active,
		to = target, item_id = item_id})
	return true


func lower_active_hp_to(player: int, amount: int, item_id: String) -> int:
	var slot: int = active_index[player]
	if amount <= 0 or hp[player][slot] <= amount:
		return 0
	var lost: int = hp[player][slot] - amount
	hp[player][slot] = amount
	_killer[player][slot] = -1
	_queue_item_event(player, {id = "life_lowered", player = player, slot = slot,
		amount = lost, item_id = item_id})
	return lost


func request_energy_equalize(player: int) -> void:
	var opponent: int = 1 - player
	if item_debuff_blocked(opponent):
		add_item_mod(player, "energy_equalize_blocked", 1)
		return
	set_item_mod(player, "energy_equalize_requested", true)


func _resolve_energy_equalize_requests(events: Array) -> void:
	var requested: bool = false
	for player in [0, 1]:
		requested = requested or bool(item_mod(player, "energy_equalize_requested", false))
		if bool(item_mod(player, "energy_equalize_blocked", false)):
			events.append({id = "energy_equalize_blocked", player = 1 - player,
				source_player = player})
	if not requested:
		return
	var total: int = energy[0] + energy[1]
	var low_side: int = 0 if energy[0] <= energy[1] else 1
	var shares: Array[int] = [total / 2, total / 2]
	shares[low_side] += total % 2
	for side in [0, 1]:
		energy[side] = mini(shares[side], energy_max[side])
	events.append({id = "energy_equalized", p1_amount = energy[0], p2_amount = energy[1]})


func _resolve_bag_bonfire(events: Array) -> void:
	var requested: bool = bool(item_mod(0, "bag_bonfire_requested", false)) \
		or bool(item_mod(1, "bag_bonfire_requested", false))
	if not requested:
		return
	for side in [0, 1]:
		var burned: int = 0
		for slot_index in range(slots[side].size()):
			if not slot_ready(side, slot_index):
				continue
			var slot: Dictionary = slots[side][slot_index]
			if bool(slot.get("used", false)):
				continue
			slot["used"] = true
			burned += 1
			_gain_energy(side, ActionDef.ENERGY_UNIT)
		if burned > 0:
			events.append({id = "bag_bonfire", player = side, count = burned,
				amount = burned * ActionDef.ENERGY_UNIT})


func refill_one_empty_slot_with_random_t1(player: int, item_id: String,
		events: Array) -> bool:
	var empty_slot: int = -1
	for slot_index in range(slots[player].size()):
		if int(slots[player][slot_index].get("state", SlotState.EMPTY)) == SlotState.EMPTY:
			empty_slot = slot_index
			break
	if empty_slot < 0:
		return false
	var pool: Array[ItemData] = ItemCatalog.all_tier1()
	if pool.is_empty():
		return false
	var chosen: ItemData = pool[rng.randi_range(0, pool.size() - 1)]
	var slot: Dictionary = slots[player][empty_slot]
	slot["item"] = ItemCatalog.make(chosen.item_id)
	slot["state"] = SlotState.CHARGING
	slot["since"] = turn_number
	slot["used"] = false
	slot["draft"] = []
	slot["upg_draft"] = []
	events.append({id = "jubao_refill", player = player, slot = empty_slot,
		item_id = chosen.item_id, source_item_id = item_id})
	return true


func _replay_item_effect(player: int, target: int, data: ItemData) -> void:
	if bool(data.params.get("relic", false)):
		_register_relic(player, data)
		return
	if data.effect.resolves_on_submit():
		_apply_submit_effect(player, target, data)
		if not data.effect.queues_after_submit():
			return
	if data.item_id == "t2_mojing":
		_commit_magic_crystal(player, data)
	item_uses[player].append({data = data, when = data.resolved_when(), target = target})


## 天罗只取消首件道具：先恢复首件提交前快照，再按原提交顺序重放；首件仅消耗来源，不施加效果。
func _replay_item_action(player: int, action: Dictionary, suppress_effect: bool) -> void:
	var data: ItemData = ItemCatalog.make(String(action.get("item_id", "")))
	if data == null or data.effect == null:
		return
	var source_slot: int = int(action.get("source_slot", -1))
	if source_slot >= 0:
		if source_slot >= slots[player].size():
			return
		slots[player][source_slot]["used"] = true
	info_distortion[player].erase("hide_item_bar")
	data.effect.on_consumed(self, player, int(action.get("target", player)), data)
	_record_consumed_item(player, data)
	_mark_item_slot_used_this_turn(player, source_slot)
	var sealed: bool = bool(action.get("sealed", false))
	if sealed:
		_consume_due_item_seal(player)
	if suppress_effect or sealed:
		_mark_item_countered_this_turn(player, source_slot)
		return
	var target: int = int(action.get("target", player))
	var item_slot_target: int = int(action.get("item_slot_target", -1))
	match data.item_id:
		"t1_ronglu":
			if item_slot_target < 0 or item_slot_target >= slots[player].size():
				return
			slots[player][item_slot_target]["used"] = true
			_gain_energy(player, int(data.params.get("energy", 4)))
			_append_slot_item_use(player, data, target, source_slot, item_slot_target,
				int(slots[player][source_slot].get("instance_uid", -1)),
				bool(slots[player][source_slot].get("temporary", false)))
		"t2_dianjinshi":
			if item_slot_target < 0 or item_slot_target >= slots[player].size():
				return
			var upgraded: ItemData = ItemCatalog.make(String(action.get("upgraded_id", "")))
			if upgraded == null:
				return
			var target_slot: Dictionary = slots[player][item_slot_target]
			target_slot["item"] = upgraded
			target_slot["state"] = SlotState.CHARGING
			target_slot["since"] = turn_number
			target_slot["used"] = false
			target_slot["draft"] = []
			target_slot["upg_draft"] = []
			_append_slot_item_use(player, data, target, source_slot, item_slot_target,
				int(slots[player][source_slot].get("instance_uid", -1)),
				bool(slots[player][source_slot].get("temporary", false)))
		"t1_jicun_pai":
			_return_slot_item_to_backpack(player, item_slot_target)
			_gain_energy(player, int(data.params.get("energy", 2)))
			_append_slot_item_use(player, data, target, source_slot, item_slot_target,
				int(slots[player][source_slot].get("instance_uid", -1)),
				bool(slots[player][source_slot].get("temporary", false)))
		"t2_huigou_quan":
			add_item_to_battle_backpack(player, String(action.get("chosen_id", "")), true)
			_append_slot_item_use(player, data, target, source_slot, item_slot_target,
				int(slots[player][source_slot].get("instance_uid", -1)),
				bool(slots[player][source_slot].get("temporary", false)))
		"t2_yingji_xiang":
			var emergency_entry: Dictionary = _take_bag_entry(
				player, int(action.get("chosen_bag_uid", -1)))
			_put_entry_in_slot(player, source_slot, emergency_entry, true)
			_append_slot_item_use(player, data, target, source_slot, item_slot_target, -1, false)
		"t2_huanqian_tong":
			var returned_entry: Dictionary = _return_slot_item_to_backpack(player, item_slot_target)
			var chosen_uid: int = int(action.get("chosen_bag_uid", -1))
			var chosen_entry: Dictionary = returned_entry if chosen_uid < 0 \
				else _take_bag_entry(player, chosen_uid)
			if chosen_uid < 0:
				_take_bag_entry(player, int(returned_entry.get("uid", -1)))
			_put_entry_in_slot(player, item_slot_target, chosen_entry, false)
			_append_slot_item_use(player, data, target, source_slot, item_slot_target,
				int(slots[player][source_slot].get("instance_uid", -1)),
				bool(slots[player][source_slot].get("temporary", false)))
		_:
			var uses_before: int = item_uses[player].size()
			_replay_item_effect(player, target, data)
			if item_uses[player].size() > uses_before:
				var replayed: Dictionary = item_uses[player][item_uses[player].size() - 1]
				replayed["source_slot"] = source_slot
				replayed["item_slot_target"] = item_slot_target
				replayed["instance_uid"] = int(slots[player][source_slot].get(
					"instance_uid", -1)) if source_slot >= 0 else -1
				replayed["temporary"] = bool(slots[player][source_slot].get(
					"temporary", false)) if source_slot >= 0 else false


func _restore_item_transaction(player: int, events: Array) -> void:
	var snapshot_variant: Variant = item_buffs[player].get(_ITEM_TX_SNAPSHOT, null)
	if snapshot_variant == null:
		return
	var snapshot: Dictionary = snapshot_variant
	var actions: Array = (item_buffs[player].get(_ITEM_TX_ACTIONS, []) as Array).duplicate(true)
	energy[player] = int(snapshot.get("energy", energy[player]))
	item_buffs[player] = (snapshot.get("item_buffs", {}) as Dictionary).duplicate(true)
	slots[player] = _snap_unpack_slots(snapshot.get("slots", []))
	relics[player] = _snap_unpack_relics(snapshot.get("relics", []))
	item_uses[player] = _snap_unpack_uses(snapshot.get("item_uses", []))
	battle_backpacks[player] = (snapshot.get("backpack", []) as Array).duplicate(true)
	used_item_history[player] = (snapshot.get("used_item_history", []) as Array).duplicate(true)
	revealed_backpack_uids[player] = (snapshot.get("revealed_backpack_uids", {}) as Dictionary).duplicate(true)
	for action_index in range(actions.size()):
		_replay_item_action(player, actions[action_index], action_index == 0)
	# 后续全局规则（独用封）仍需读取同一份原始提交顺序并可能再次原子重放。
	item_buffs[player][_ITEM_TX_SNAPSHOT] = snapshot
	item_buffs[player][_ITEM_TX_ACTIONS] = actions
	events.append({id = "tianluo_first_item_rolled_back", player = player})


## 独用封：恢复第一件提交前的状态，只重放各方原始首件；其余来源照常消耗但效果无效。
## 若该方首件已被天罗抵消，则本方没有任何道具效果可以保留。
func _restore_item_transaction_first_only(player: int, suppress_first: bool,
		events: Array) -> void:
	var snapshot_variant: Variant = item_buffs[player].get(_ITEM_TX_SNAPSHOT, null)
	if snapshot_variant == null:
		return
	var snapshot: Dictionary = snapshot_variant
	var actions: Array = (item_buffs[player].get(_ITEM_TX_ACTIONS, []) as Array).duplicate(true)
	var tianluo_lock: int = int(item_buffs[player].get("tianluo_switch_lock_turn", -1))
	energy[player] = int(snapshot.get("energy", energy[player]))
	item_buffs[player] = (snapshot.get("item_buffs", {}) as Dictionary).duplicate(true)
	slots[player] = _snap_unpack_slots(snapshot.get("slots", []))
	relics[player] = _snap_unpack_relics(snapshot.get("relics", []))
	item_uses[player] = _snap_unpack_uses(snapshot.get("item_uses", []))
	battle_backpacks[player] = (snapshot.get("backpack", []) as Array).duplicate(true)
	used_item_history[player] = (snapshot.get("used_item_history", []) as Array).duplicate(true)
	revealed_backpack_uids[player] = (snapshot.get(
		"revealed_backpack_uids", {}) as Dictionary).duplicate(true)
	for action_index in range(actions.size()):
		_replay_item_action(player, actions[action_index], suppress_first or action_index > 0)
	if tianluo_lock >= 0:
		item_buffs[player]["tianluo_switch_lock_turn"] = tianluo_lock
	item_buffs[player][_ITEM_TX_SNAPSHOT] = snapshot
	item_buffs[player][_ITEM_TX_ACTIONS] = actions
	events.append({id = "single_item_rule_applied", player = player,
		first_countered = suppress_first})


func _resolve_single_item_rule(tianluo_affected: Array[bool], events: Array) -> void:
	var active: bool = false
	for player in [0, 1]:
		if tianluo_affected[player]:
			continue
		var actions: Array = item_buffs[player].get(_ITEM_TX_ACTIONS, [])
		if not actions.is_empty() \
				and String((actions[0] as Dictionary).get("item_id", "")) == "t2_duyong_feng":
			active = true
			break
	if not active:
		return
	for player in [0, 1]:
		_restore_item_transaction_first_only(player, tianluo_affected[player], events)


func _discard_item_transactions() -> void:
	for player in [0, 1]:
		item_buffs[player].erase(_ITEM_TX_SNAPSHOT)
		item_buffs[player].erase(_ITEM_TX_ACTIONS)


func _selected_action_payable_after_rollback(player: int, action: int) -> bool:
	var cost: int = action_cost(player, action)
	if _empowered_wave[player]:
		cost += EMPOWERED_WAVE_COST
	if _energy_cap_discount[player] and cost > 0 \
			and energy_max[player] - ENERGY_CAP_DISCOUNT_COST >= ENERGY_CAP_DISCOUNT_FLOOR:
		cost = maxi(0, cost - ENERGY_CAP_DISCOUNT_AMOUNT)
	if _blood_payment[player]:
		return _can_pay_blood_raw(player, cost)
	return usable_energy(player) >= cost


func _fallback_action_to_charge(player: int, actions: Array[int], events: Array) -> void:
	selected_action[player] = ActionDef.Action.CHARGE
	actions[player] = ActionDef.Action.CHARGE
	_empowered_wave[player] = false
	_split_big_wave[player] = false
	_blood_payment[player] = false
	_blood_payment_source[player] = -1
	_energy_cap_discount[player] = false
	_switch_to[player] = -1
	_active_target[player] = -1
	_attack_target[player] = -1
	events.append({id = "tianluo_action_fallback", player = player})


func _settle_pending_free_switches(affected: Array[bool], events: Array) -> void:
	# 先同时撤回双方逻辑预览，再按固定玩家序提交或取消；任何一方的离/入场 hook
	# 都不会读到对手仍停留在选择期预览位，且网络消息到达顺序不影响权威结果。
	for player in [0, 1]:
		var intents: Array = _pending_free_switches[player]
		if not intents.is_empty():
			active_index[player] = int((intents[0] as Dictionary).get(
				"from", active_index[player]))
	for player in [0, 1]:
		var intents: Array = _pending_free_switches[player]
		if intents.is_empty():
			continue
		var first: Dictionary = intents[0]
		# active_index 在选择期只是用于动作/UI合法性预览；所有 hook 尚未发生，故取消只需
		# 恢复原位与使用次数，不存在冲撞、离场清状态、夜明珠等补偿性回滚。
		if affected[player]:
			free_switch_usage_turn[player] = int(first.get(
				"usage_turn_before", free_switch_usage_turn[player]))
			free_switch_uses[player] = int(first.get("uses_before", free_switch_uses[player]))
			_blood_payment_source[player] = int(first.get(
				"blood_payment_source_before", _blood_payment_source[player]))
			events.append({id = "free_switch_cancelled", player = player,
				source = "t3_tianluodiwang", from = active_index[player],
				hp_before = hp[player][active_index[player]]})
		else:
			for intent_variant in intents:
				var intent: Dictionary = intent_variant
				_perform_switch(player, int(intent.get("from", active_index[player])),
					int(intent.get("to", active_index[player])), events, true)
		_pending_free_switches[player] = []


func _action_valid_after_tianluo(player: int, action: int) -> bool:
	# 付费切换保持原选择，统一在 Phase 2.5 由天罗切换锁判无效；它不回退为攒。
	if action == ActionDef.Action.SWITCH:
		return true
	if action == ActionDef.ACTIVE:
		return _can_use_active_raw(player, _blood_payment[player], _energy_cap_discount[player])
	if action in ActionDef.DEFEND_ACTIONS and not _can_defend(player):
		return false
	if _empowered_wave[player] and not can_empower_wave_action(
			player, action, _blood_payment[player], _energy_cap_discount[player]):
		return false
	if _split_big_wave[player] and not can_split_big_wave_action(
			player, action, _blood_payment[player], _energy_cap_discount[player]):
		return false
	var target: int = _attack_target[player]
	if target >= 0:
		var opponent: int = 1 - player
		if not ActionDef.is_attack(action) or not can_target_any_enemy_with_base_attack(player, action) \
				or target >= hp[opponent].size() or hp[opponent][target] <= 0:
			return false
	return _selected_action_payable_after_rollback(player, action)


func _revalidate_tianluo_actions(affected: Array[bool], actions: Array[int],
		events: Array) -> void:
	for player in [0, 1]:
		if not _action_valid_after_tianluo(player, actions[player]):
			_fallback_action_to_charge(player, actions, events)


func _resolve_tianluo_requests(events: Array) -> Array[bool]:
	var affected: Array[bool] = [false, false]
	# 先只裁定全部请求，再统一回滚，避免玩家编号或回滚顺序改变另一方结果。
	for attacker in [0, 1]:
		var requests: int = int(item_mod(attacker, "tianluo_requests", 0))
		for _request in range(requests):
			var victim: int = 1 - attacker
			if item_debuff_blocked(victim):
				events.append({id = "tianluo_blocked", player = victim, source_player = attacker})
			else:
				affected[victim] = true
	for victim in [0, 1]:
		if not affected[victim]:
			continue
		_restore_item_transaction(victim, events)
		item_buffs[victim]["tianluo_switch_lock_turn"] = turn_number
		events.append({id = "tianluo_applied", player = victim})
	return affected


## 回照镜：天罗/封印等先行裁定完成后，按敌方原提交顺序反制敌向道具。
## 被反制道具来源已在选择期消耗；这里只从效果队列移除，不退款、不改槽位。
func _resolve_hostile_item_counters(events: Array) -> void:
	var charges: Array[int] = [0, 0]
	for defender in [0, 1]:
		for use_variant in item_uses[defender]:
			var use: Dictionary = use_variant
			var data: ItemData = use.get("data", null)
			if data != null and data.effect != null:
				charges[defender] += maxi(0, data.effect.hostile_item_counter_charges(data))
	for attacker in [0, 1]:
		var defender: int = 1 - attacker
		if charges[defender] <= 0:
			continue
		var kept: Array = []
		for use_variant in item_uses[attacker]:
			var use: Dictionary = use_variant
			var data: ItemData = use.get("data", null)
			var hostile: bool = data != null and data.effect != null \
				and data.target_mode == ItemData.Target.ENEMY \
				and not data.effect.resolves_before_hostile_item_counters()
			if hostile and charges[defender] > 0:
				charges[defender] -= 1
				var source_slot: int = int(use.get("source_slot", -1))
				_mark_item_countered_this_turn(attacker, source_slot)
				_return_countered_insured_item(attacker, source_slot, data.item_id, events)
				events.append({id = "item_countered", player = attacker,
					source_player = defender, item_id = data.item_id,
					counter_item_id = "t2_huizhao_jing"})
				continue
			kept.append(use)
		item_uses[attacker] = kept


func _collect_item_insurance(events: Array) -> void:
	for player in [0, 1]:
		for use_variant in item_uses[player]:
			var use: Dictionary = use_variant
			var data: ItemData = use.get("data", null)
			if data != null and data.item_id == "t2_baojia_feng":
				arm_item_insurance(player, int(use.get("item_slot_target", -1)))
		for slot_variant in item_buffs[player].get("countered_item_slots_this_turn", []):
			var source_slot: int = int(slot_variant)
			if not _insured_slot(player, source_slot) or source_slot < 0 \
					or source_slot >= slots[player].size():
				continue
			var data: ItemData = slots[player][source_slot].get("item", null)
			if data != null:
				_return_countered_insured_item(player, source_slot, data.item_id, events)


func _resolve_item_wagers(events: Array) -> void:
	for player in [0, 1]:
		var opponent: int = 1 - player
		var used_slots: Array = item_buffs[opponent].get("used_item_slots_this_turn", [])
		for wager_variant in item_mod(player, "item_wagers", []):
			var wager: Dictionary = wager_variant
			if used_slots.has(int(wager.get("slot", -1))):
				var gained: int = _gain_energy(player, int(wager.get("amount", 0)))
				events.append({id = "item_wager_won", player = player,
					slot = int(wager.get("slot", -1)), amount = gained})


func _resolve_mengdie_requests(events: Array) -> void:
	var effective: int = 0
	for player in [0, 1]:
		effective += int(item_mod(player, "mengdie_requests", 0))
		for _blocked in range(int(item_mod(player, "mengdie_blocked", 0))):
			events.append({id = "mengdie_blocked", player = 1 - player, source_player = player})
	if effective % 2 == 0:
		if effective > 0:
			events.append({id = "mengdie_cancelled_even", count = effective})
		return
	var swapped_energy: int = energy[0]
	energy[0] = energy[1]
	energy[1] = swapped_energy
	var swapped_slots: Array = slots[0]
	slots[0] = slots[1]
	slots[1] = swapped_slots
	events.append({id = "mengdie_swap", count = effective})


## 登记一次基础攻击结束后的道具回调（按整次攻击汇总，而非逐 hit）。
func add_base_attack_aftereffect(player: int, data: ItemData) -> void:
	var effects: Array = _imod[player].get("base_attack_aftereffects", [])
	effects.append(data)
	_imod[player]["base_attack_aftereffects"] = effects


## 借印佩只借用三种专属印记，不调用通用 hero hook，故双生／三花不会复制本次道具结算。
func _resolve_borrowed_marks(player: int, context: Dictionary, events: Array) -> void:
	if not bool(context.get("connected", false)):
		return
	var target_player: int = 1 - player
	var target_slot: int = int(context.get("target_slot", active_index[target_player]))
	if target_slot < 0 or target_slot >= hp[target_player].size():
		return
	for slot_variant in item_mod(player, "borrowed_mark_slots", []):
		var slot: int = int(slot_variant)
		if not is_living_reserve(player, slot):
			continue
		var hero_id: String = (heroes[player][slot] as HeroData).hero_id
		match hero_id:
			"h06":
				set_status(target_player, target_slot, "poison", int(
					get_status(target_player, target_slot, "poison", 0)) + 1)
			"h10":
				set_team_status(player, "jianqi", mini(4, int(
					get_team_status(player, "jianqi", 0)) + 1))
			"h20":
				apply_h20_vulnerability(target_player, target_slot)
			_:
				continue
		events.append({id = "borrowed_mark", player = player, slot = slot,
			target_player = target_player, target_slot = target_slot, hero_id = hero_id})


func _lowest_hp_living_reserve(player: int) -> int:
	var best: int = -1
	for slot in living_reserves(player):
		if best < 0 or hp[player][slot] < hp[player][best]:
			best = slot
	return best


## 点将鼓在整次攻击完成后换入最低生命替补；致死攻击直接完成死亡补位，不重复弹选择框。
func _resolve_dianjiang_after_hit(player: int, context: Dictionary, events: Array) -> void:
	if not bool(item_mod(player, "dianjiang_after_hit", false)) \
			or not bool(context.get("connected", false)):
		return
	var victim: int = 1 - player
	if _turn_switch_locked(victim):
		events.append({id = "dianjiang_switch_locked", player = victim, source_player = player})
		return
	var target: int = _lowest_hp_living_reserve(victim)
	if target < 0:
		return
	var from_slot: int = active_index[victim]
	if hp[victim][from_slot] > 0:
		_perform_switch(victim, from_slot, target, events)
	else:
		active_index[victim] = target
		var entering: HeroSkill = _skills[victim][target]
		if entering != null:
			entering.on_switch_in(self, victim, target)
	events.append({id = "dianjiang_forced_entry", player = victim, source_player = player,
		from = from_slot, to = target})


func will_attack_this_turn(player: int) -> bool:
	return ActionDef.is_attack(selected_action[player]) or ActionDef.is_attack(_second_action[player])


func will_use_action_this_turn(player: int, action: int) -> bool:
	return selected_action[player] == action or _second_action[player] == action


func _consume_next_attack_item_mods(player: int) -> void:
	for key in [
		"atk_bonus", "base_attack_total_bonus", "atk_penalty", "base_attack_total_penalty",
		"atk_pen", "atk_mult", "next_wave_target_penalty", "whole_attack_extra_hit_effects",
		"next_base_attack_true_damage", "bound_base_attack_target", "riders",
		"base_attack_aftereffects", "borrowed_mark_slots", "dianjiang_after_hit",
		"share_next_base_attack", "blocked_wave_shield",
	]:
		_imod[player].erase(key)


func _second_attack_context(action: int, source_slot: int) -> Dictionary:
	return {executed = false, source_slot = source_slot, target_slot = -1,
		connected = false, original_action = action, raw_damage_total = 0,
		damage_total = 0, hp_damage_total = 0, blocked = false,
		blocked_by_big_defend = false, target_defeated = false, hit_effect_triggers = 1}


## 连环鼓的第二行动是独立的公共行动阶段：双方第二行动同时处理，第一阶段的防御不会跨阶段。
## “下一次攻击”类道具若已在第一阶段攻击中兑现则已消费；力量代价、噬心钉、末日火种等
## 明写“本回合/所有攻击”的增益通过 turn_base_attack_total_bonus 保留到第二阶段。
func _resolve_lianhuan_second_actions(first_actions: Array[int], requested: Array[int],
		events: Array) -> void:
	var actions: Array[int] = [requested[0], requested[1]]
	for player in [0, 1]:
		if not bool(item_mod(player, "lianhuan_active", false)) \
				or actions[player] < ActionDef.Action.CHARGE \
				or actions[player] > ActionDef.Action.BIG_DEFEND \
				or actions[player] == first_actions[player] \
				or hp[player][active_index[player]] <= 0:
			if requested[player] >= 0:
				events.append({id = "lianhuan_second_cancelled", player = player})
			actions[player] = -1
			continue
	var saved_selected: Array[int] = selected_action.duplicate()
	var saved_targets: Array[int] = _attack_target.duplicate()
	var exact_spend_refunds: Array[int] = [0, 0]
	for player in [0, 1]:
		if ActionDef.is_attack(first_actions[player]):
			_consume_next_attack_item_mods(player)
	for player in [0, 1]:
		selected_action[player] = actions[player] if actions[player] >= 0 else ActionDef.Action.CHARGE
		_attack_target[player] = _second_attack_target[player]
	for player in [0, 1]:
		if actions[player] < 0:
			continue
		for use_variant in item_uses[player]:
			var use: Dictionary = use_variant
			if int(use.get("when", ItemData.Seq.PRE)) == ItemData.Seq.PRE:
				var data: ItemData = use.get("data", null)
				if data != null and data.effect != null:
					data.effect.apply_second_pre(
						self, player, int(use.get("target", -1)), data, events)
		for relic_variant in relics[player]:
			var relic: Dictionary = relic_variant
			(relic["data"] as ItemData).effect.relic_second_pre(
				self, player, relic["data"], relic["state"], events)
		var cost: int = action_cost(player, actions[player])
		if usable_energy(player) < cost:
			actions[player] = -1
			selected_action[player] = ActionDef.Action.CHARGE
			_attack_target[player] = -1
			events.append({id = "lianhuan_second_cancelled", player = player,
				reason = "insufficient_energy"})
			continue
		if cost > 0 and usable_energy(player) == cost:
			exact_spend_refunds[player] = int(item_mod(player, "exact_spend_refund", 0))
		energy[player] -= cost
		if actions[player] == ActionDef.Action.BIG_ATTACK \
				and int(item_buffs[player].get("free_big_attack_until_turn", -1)) == turn_number:
			item_buffs[player].erase("free_big_attack_until_turn")
			events.append({id = "free_big_attack_consumed", player = player})
		if actions[player] == ActionDef.Action.CHARGE:
			var gain: int = int(ActionDef.BASE_ACTION_DEF[ActionDef.Action.CHARGE]["energy_gain"])
			gain = maxi(0, gain - int(item_mod(player, "charge_penalty", 0)))
			var gained: int = _gain_energy(player, gain)
			if gained > 0:
				events.append({id = "charge_gain", player = player, amount = gained,
					step = 2})
		events.append({id = "lianhuan_second_action", player = player,
			action = actions[player]})

	if actions[0] < 0 and actions[1] < 0:
		selected_action = saved_selected
		_attack_target = saved_targets
		return
	for player in [0, 1]:
		if ActionDef.is_attack(actions[player]) \
				and int(item_mod(player, "base_attack_damage_cap", -1)) >= 0:
			set_item_mod(player, "base_attack_damage_cap_remaining",
				int(item_mod(player, "base_attack_damage_cap", 0)))

	for player in [0, 1]:
		if actions[player] == ActionDef.Action.BIG_DEFEND:
			var skill: HeroSkill = _skills[player][active_index[player]]
			if skill != null and skill.retains_unused_big_defend():
				_retain_big_defend_candidate[player] = true

	var contexts: Array = [
		_second_attack_context(actions[0], active_index[0]),
		_second_attack_context(actions[1], active_index[1]),
	]
	var hits: Array = [null, null]
	for player in [0, 1]:
		var action: int = actions[player]
		if not ActionDef.is_attack(action):
			continue
		var source_slot: int = active_index[player]
		var opponent: int = 1 - player
		if hp[player][source_slot] <= 0 or hp[opponent][active_index[opponent]] <= 0:
			continue
		var wave_upgraded: bool = action == ActionDef.Action.ATTACK and upgrade_next_wave[player]
		var damage_action: int = ActionDef.Action.BIG_ATTACK if wave_upgraded else action
		var damage: int = maxi(_calc_outgoing(player, damage_action), 0)
		damage *= maxi(1, int(item_mod(player, "atk_mult", 1)))
		damage += int(item_mod(player, "atk_bonus", 0)) \
			+ int(item_mod(player, "base_attack_total_bonus", 0)) \
			+ int(item_mod(player, "turn_base_attack_total_bonus", 0)) \
			- int(item_mod(player, "atk_penalty", 0)) \
			- int(item_mod(player, "base_attack_total_penalty", 0))
		if action == ActionDef.Action.BIG_ATTACK:
			damage += int(item_mod(1 - player, "enemy_big_wave_total_bonus", 0))
		if action == ActionDef.Action.ATTACK:
			damage -= int(item_mod(player, "next_wave_target_penalty", 0))
		damage = maxi(damage, 0)
		var kind: int = ActionDef.Action.BIG_ATTACK if wave_upgraded else action
		var skill: HeroSkill = _skills[player][source_slot]
		if skill != null:
			kind = skill.override_attack_kind(action, self, player, source_slot)
		var pen: int = ActionDef.base_penetration(kind)
		if skill != null:
			pen = skill.attack_penetration(pen, action, self, player, source_slot)
		var item_pen: int = int(item_mod(player, "atk_pen", -1))
		if item_pen >= 0:
			pen = item_pen
		if bool(item_mod(player, "next_base_attack_true_damage", false)):
			pen = ActionDef.Pen.TRUE_DMG
		var target_slot: int = int(item_mod(player, "bound_base_attack_target", -1))
		if target_slot < 0:
			target_slot = _second_attack_target[player]
		var extra_hits: int = int(item_mod(player, "whole_attack_extra_hit_effects", 0))
		if extra_hits <= 0:
			for relic in relics[player]:
				if (relic["data"] as ItemData).item_id == "t3_judingsanhua" \
						and int(relic["state"].get("charges", 0)) > 0:
					extra_hits = int((relic["data"] as ItemData).params.get("hits", 1))
					break
		hits[player] = {damage = damage, kind = kind, pen = pen,
			riders = item_mod(player, "riders", []), action = true, active = false,
			src_slot = source_slot, target_slot = target_slot,
			force_zero_damage = action == ActionDef.Action.ATTACK and bool(item_mod(
				1 - player, "enemy_wave_no_damage", false)),
			consume_true_damage = bool(item_mod(player, "next_base_attack_true_damage", false)),
			whole_attack_extra_hits = extra_hits}
		if wave_upgraded:
			upgrade_next_wave[player] = false

	var order: Array[int] = [0, 1]
	if hits[0] != null and hits[1] != null:
		var p0_skill: HeroSkill = _skills[0][int(hits[0].get("src_slot", active_index[0]))]
		var p1_skill: HeroSkill = _skills[1][int(hits[1].get("src_slot", active_index[1]))]
		var p0_priority: int = p0_skill.base_attack_clash_priority() if p0_skill != null else 0
		var p1_priority: int = p1_skill.base_attack_clash_priority() if p1_skill != null else 0
		if p1_priority > p0_priority:
			order = [1, 0]
	for player in order:
		if hits[player] == null:
			continue
		var source_slot: int = int(hits[player].get("src_slot", active_index[player]))
		if hp[player][source_slot] <= 0:
			events.append({id = "base_attack_cancelled", player = player, step = 2})
			continue
		_apply_resolve_hit(player, hits[player], selected_action, events, contexts[player])

	_resolve_reserve_pursuits(events)
	for player in [0, 1]:
		if not ActionDef.is_attack(actions[player]):
			continue
		var context: Dictionary = contexts[player]
		for data in item_mod(player, "base_attack_aftereffects", []):
			(data as ItemData).effect.on_base_attack_resolved(self, player, context, data, events)
		_resolve_borrowed_marks(player, context, events)
		for relic in relics[player]:
			relic["data"].effect.relic_on_attack_resolved(
				self, player, context, relic["data"], relic["state"], events)
		var defender: int = 1 - player
		for relic in relics[defender]:
			relic["data"].effect.relic_on_defense_resolved(
				self, defender, context, relic["data"], relic["state"], events)
		_resolve_dianjiang_after_hit(player, context, events)
		_consume_next_attack_item_mods(player)
	for player in [0, 1]:
		if exact_spend_refunds[player] > 0:
			set_item_mod(player, "exact_spend_refund_pending", exact_spend_refunds[player])
			_settle_exact_spend_refund(player, events, 2)
	selected_action = saved_selected
	_attack_target = saved_targets


## 兼容旧消耗式攻击印记：按英雄槽累计，首次命中的基础攻击消费全部层数。
func add_base_attack_mark(player: int, slot: int, amount: int) -> void:
	if slot < 0 or slot >= hp[player].size() or amount <= 0:
		return
	var marks: Dictionary = _imod[player].get("base_attack_marks", {})
	marks[slot] = int(marks.get(slot, 0)) + amount
	_imod[player]["base_attack_marks"] = marks


## 替身草人是本方自保效果，不消耗敌方的非伤害道具免疫。
## 若选择阶段已发生 h07 免费切换则立即落保护；否则等待本回合实际切换 hook。
func arm_caoren(player: int) -> void:
	if free_switch_usage_turn[player] == turn_number and free_switch_uses[player] > 0:
		set_item_mod(1 - player, "atk_nullify", true)
		return
	set_item_mod(player, "caoren_switch_guard", 1)


## 定身符：锁到指定回合结束；重复施加只延长期限，不缩短既有期限。
func lock_switch_until(player: int, until_turn: int) -> void:
	item_buffs[player]["switch_lock_until_turn"] = maxi(
		int(item_buffs[player].get("switch_lock_until_turn", -1)), until_turn)


## 登记团队级定时道具效果；不会随英雄转变复制。
func add_timed_item_effect(target_player: int, effect: Dictionary) -> void:
	timed_item_effects[target_player].append(effect.duplicate(true))


## 登记本回合死亡反击，按绑定英雄槽累计普通伤害。
func add_death_retaliation(player: int, slot: int, amount: int) -> void:
	if slot < 0 or slot >= hp[player].size() or amount <= 0:
		return
	var by_slot: Dictionary = _imod[player].get("death_retaliations", {})
	by_slot[slot] = int(by_slot.get(slot, 0)) + amount
	_imod[player]["death_retaliations"] = by_slot


## 失去生命：绕过防御/护甲/受伤 hook，不属于敌方击败来源。
func lose_life(player: int, slot: int, amount: int, events: Array, source: String) -> int:
	if slot < 0 or slot >= hp[player].size() or hp[player][slot] <= 0 or amount <= 0:
		return 0
	if _consume_fatal_damage_immunity(player, slot, amount, events):
		return 0
	var lost: int = mini(hp[player][slot], amount)
	hp[player][slot] -= amount
	_killer[player][slot] = -1
	events.append({id = "life_lost", player = player, slot = slot, amount = lost, src = source})
	return lost


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
const STARTER_ITEM_IDS := ["t1_feibiao", "t1_jiudun", "t1_lzhi_shengming"]  # slot0 自带随机池（后期改玩家自选 T1/T2 携带·PvE）


func _empty_econ_slot() -> Dictionary:
	return {state = SlotState.EMPTY, item = null, since = -1, used = false,
		draft = [], upg_draft = [], draft_entry_uids = [], instance_uid = -1,
		temporary = false}


func _new_backpack_entry(item_id: String, temporary: bool = false) -> Dictionary:
	var entry := {uid = _next_backpack_uid, item_id = item_id, temporary = temporary}
	_next_backpack_uid += 1
	return entry


func configure_battle_backpacks(player0_ids: Array, player1_ids: Array) -> void:
	battle_backpack_enabled = true
	battle_backpacks = [[], []]
	used_item_history = [[], []]
	revealed_backpack_uids = [{}, {}]
	_next_backpack_uid = 1
	for player in [0, 1]:
		var ids: Array = player0_ids if player == 0 else player1_ids
		var copies: Dictionary = {}
		for id_variant in ids:
			var item_id: String = String(id_variant)
			var data: ItemData = ItemCatalog.make(item_id)
			if data == null or data.tier >= 3 or int(copies.get(item_id, 0)) >= 2:
				continue
			copies[item_id] = int(copies.get(item_id, 0)) + 1
			battle_backpacks[player].append(_new_backpack_entry(item_id))


func add_item_to_battle_backpack(player: int, item_id: String,
		temporary: bool = false) -> int:
	if not battle_backpack_enabled or player < 0 or player > 1 \
			or ItemCatalog.make(item_id) == null:
		return -1
	var entry: Dictionary = _new_backpack_entry(item_id, temporary)
	battle_backpacks[player].append(entry)
	return int(entry["uid"])


func _bag_entry_index(player: int, uid: int) -> int:
	for index in range(battle_backpacks[player].size()):
		if int((battle_backpacks[player][index] as Dictionary).get("uid", -1)) == uid:
			return index
	return -1


func _take_bag_entry(player: int, uid: int) -> Dictionary:
	var index: int = _bag_entry_index(player, uid)
	if index < 0:
		return {}
	var entry: Dictionary = battle_backpacks[player][index]
	battle_backpacks[player].remove_at(index)
	return entry


func _put_entry_in_slot(player: int, slot_index: int, entry: Dictionary,
		ready_now: bool) -> bool:
	if entry.is_empty() or slot_index < 0 or slot_index >= slots[player].size():
		return false
	var data: ItemData = ItemCatalog.make(String(entry.get("item_id", "")))
	if data == null:
		return false
	var slot: Dictionary = slots[player][slot_index]
	slot["item"] = data
	slot["state"] = SlotState.CHARGING
	slot["since"] = -1 if ready_now else turn_number
	slot["used"] = false
	slot["draft"] = []
	slot["upg_draft"] = []
	slot["draft_entry_uids"] = []
	slot["instance_uid"] = int(entry.get("uid", -1))
	slot["temporary"] = bool(entry.get("temporary", false))
	return true


func _return_slot_item_to_backpack(player: int, slot_index: int) -> Dictionary:
	if not battle_backpack_enabled or slot_index < 0 or slot_index >= slots[player].size():
		return {}
	var slot: Dictionary = slots[player][slot_index]
	var data: ItemData = slot.get("item", null)
	if data == null:
		return {}
	var uid: int = int(slot.get("instance_uid", -1))
	var entry: Dictionary = {uid = uid, item_id = data.item_id,
		temporary = bool(slot.get("temporary", false))}
	if uid < 0 or _bag_entry_index(player, uid) >= 0:
		entry = _new_backpack_entry(data.item_id, bool(slot.get("temporary", false)))
	battle_backpacks[player].append(entry)
	slot["used"] = true
	return entry


func _sample_bag_entries(entries: Array, count: int) -> Array:
	var pool: Array = entries.duplicate(true)
	var out: Array = []
	while not pool.is_empty() and out.size() < count:
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out


func _cache_bag_draft(slot: Dictionary, entries: Array) -> Array:
	slot["draft"] = []
	slot["draft_entry_uids"] = []
	for entry_variant in entries:
		var entry: Dictionary = entry_variant
		var data: ItemData = ItemCatalog.make(String(entry.get("item_id", "")))
		if data == null:
			continue
		(slot["draft"] as Array).append(data)
		(slot["draft_entry_uids"] as Array).append(int(entry.get("uid", -1)))
	return slot["draft"]


func begin_repurchase_draft(player: int, source_slot: int) -> Array:
	if not battle_backpack_enabled or source_slot < 0 or source_slot >= slots[player].size():
		return []
	var source: Dictionary = slots[player][source_slot]
	var data: ItemData = source.get("item", null)
	if data == null or data.item_id != "t2_huigou_quan" or not slot_ready(player, source_slot):
		return []
	if (source.get("upg_draft", []) as Array).is_empty():
		var seen: Dictionary = {}
		for history_variant in used_item_history[player]:
			var history: Dictionary = history_variant
			var id: String = String(history.get("item_id", ""))
			if int(history.get("tier", 0)) == 1 and not seen.has(id):
				seen[id] = true
				(source["upg_draft"] as Array).append(ItemCatalog.make(id))
	return source["upg_draft"]


func begin_exchange_draft(player: int, source_slot: int, target_slot: int) -> Array:
	if not battle_backpack_enabled or source_slot < 0 or source_slot >= slots[player].size() \
			or target_slot < 0 or target_slot >= slots[player].size() or target_slot == source_slot:
		return []
	var source: Dictionary = slots[player][source_slot]
	var source_data: ItemData = source.get("item", null)
	var target_data: ItemData = slots[player][target_slot].get("item", null)
	if source_data == null or source_data.item_id != "t2_huanqian_tong" \
			or target_data == null or bool(slots[player][target_slot].get("used", false)) \
			or not slot_ready(player, source_slot):
		return []
	if (source.get("draft", []) as Array).is_empty():
		var pool: Array = battle_backpacks[player].duplicate(true)
		pool.append({uid = -1, item_id = target_data.item_id,
			temporary = bool(slots[player][target_slot].get("temporary", false))})
		_cache_bag_draft(source, _sample_bag_entries(pool, 3))
	return source["draft"]


func reveal_enemy_backpack(viewer: int, count: int) -> Array[String]:
	var owner: int = 1 - viewer
	var candidates: Array = []
	for entry_variant in battle_backpacks[owner]:
		var entry: Dictionary = entry_variant
		if not _revealed_uid(revealed_backpack_uids[viewer], int(entry.get("uid", -1))):
			candidates.append(entry)
	var revealed: Array[String] = []
	for entry_variant in _sample_bag_entries(candidates, maxi(0, count)):
		var entry: Dictionary = entry_variant
		revealed_backpack_uids[viewer][int(entry["uid"])] = true
		revealed.append(String(entry["item_id"]))
	return revealed


func revealed_backpack_items_for(viewer: int, owner: int) -> Array[String]:
	var out: Array[String] = []
	if viewer < 0 or viewer > 1 or owner != 1 - viewer:
		return out
	for entry_variant in battle_backpacks[owner]:
		var entry: Dictionary = entry_variant
		if _revealed_uid(revealed_backpack_uids[viewer], int(entry.get("uid", -1))):
			out.append(String(entry.get("item_id", "")))
	return out


static func _revealed_uid(reveals: Dictionary, uid: int) -> bool:
	return reveals.has(uid) or reveals.has(str(uid))


## 启用经济并初始化槽位（实战由 battle_screen 调；单元测试不调 → 槽空、不影响既有行为）。
func econ_init() -> void:
	slots = [[], []]
	if battle_backpack_enabled:
		for player in [0, 1]:
			for _slot_index in range(SLOT_COUNT):
				slots[player].append(_empty_econ_slot())
		return
	for p in [0, 1]:
		# slot0 = 自带随机 T1：开局即公开亮相（明牌电报），since=解锁回合 → 解锁当回合仍锁、
		# turn_number 3(显示回合4)才 slot_ready（统一锁定规则：新道具出现回合锁定、下回合可用）。
		var sid: String = STARTER_ITEM_IDS[rng.randi() % STARTER_ITEM_IDS.size()]
		slots[p].append({state = SlotState.CHARGING, item = ItemCatalog.make(sid), since = int(SLOT_UNLOCK_TURN[0]), used = false, draft = [], upg_draft = [], draft_entry_uids = [], instance_uid = -1, temporary = false})
		for _s in range(SLOT_COUNT - 1):
			slots[p].append({state = SlotState.SEALED, item = null, since = -1, used = false, draft = [], upg_draft = [], draft_entry_uids = [], instance_uid = -1, temporary = false})
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
		if battle_backpack_enabled:
			_cache_bag_draft(sl, _sample_bag_entries(battle_backpacks[player], 3))
		else:
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
	if battle_backpack_enabled:
		var uids: Array = sl.get("draft_entry_uids", [])
		if choice >= uids.size():
			return false
		var entry: Dictionary = _take_bag_entry(player, int(uids[choice]))
		if not _put_entry_in_slot(player, s, entry, false):
			return false
	else:
		sl["item"] = ItemCatalog.make((opts[choice] as ItemData).item_id)   # 独立实例
		sl["state"] = SlotState.CHARGING
		sl["since"] = turn_number
		sl["draft"] = []
		sl["upg_draft"] = []   # 新件 → 旧升级候选作废
	return true


func _random_t1_bag_entry(player: int) -> Dictionary:
	var candidates: Array = []
	for entry_variant in battle_backpacks[player]:
		var entry: Dictionary = entry_variant
		var data: ItemData = ItemCatalog.make(String(entry.get("item_id", "")))
		if data != null and data.tier == 1:
			candidates.append(entry)
	if candidates.is_empty():
		return {}
	var chosen: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
	return _take_bag_entry(player, int(chosen.get("uid", -1)))


func _append_slot_item_use(player: int, data: ItemData, resolved_target: int,
		source_slot: int, item_slot_target: int, instance_uid: int,
		temporary: bool) -> void:
	item_uses[player].append({data = data, when = data.resolved_when(),
		target = resolved_target, source_slot = source_slot,
		item_slot_target = item_slot_target, instance_uid = instance_uid,
		temporary = temporary})


## 用某个已就绪的槽（提交到盲选 item_uses；用后标记 → 结算末置 EMPTY）。
## item_slot_target 供需要选择道具槽的效果使用：熔炉/点金石选己方槽，时滞枷锁选敌方槽。
func use_slot(player: int, s: int, target_override: int = -1, item_slot_target: int = -1,
		item_choice: int = -1) -> bool:
	if not slot_ready(player, s):
		return false
	var data: ItemData = slots[player][s]["item"]
	if data == null or data.effect == null:
		return false
	if bool(data.params.get("requires_backpack", false)) and not battle_backpack_enabled:
		return false
	var source_uid: int = int(slots[player][s].get("instance_uid", -1))
	var source_temporary: bool = bool(slots[player][s].get("temporary", false))
	var fuel: ItemData = null
	var upgraded: ItemData = null
	var repurchased_data: ItemData = null
	var selected_choice_id: String = ""
	var selected_bag_uid: int = -1
	if data.item_id == "t1_ronglu":
		if item_slot_target < 0 or item_slot_target >= slots[player].size() \
				or item_slot_target == s or not slot_ready(player, item_slot_target):
			return false
		fuel = slots[player][item_slot_target]["item"]
		if fuel == null:
			return false
	elif data.item_id == "t2_dianjinshi":
		upgraded = _pointstone_upgrade(player, s, item_slot_target, item_choice)
		if upgraded == null:
			return false
	elif data.item_id in ["t1_jicun_pai", "t2_baojia_feng"]:
		if item_slot_target < 0 or item_slot_target >= slots[player].size() \
				or item_slot_target == s or not slot_ready(player, item_slot_target):
			return false
	elif data.item_id == "t2_huanqian_tong":
		var exchange_options: Array = begin_exchange_draft(player, s, item_slot_target)
		if item_choice < 0 or item_choice >= exchange_options.size():
			return false
		selected_choice_id = (exchange_options[item_choice] as ItemData).item_id
		selected_bag_uid = int((slots[player][s].get("draft_entry_uids", []) as Array)[item_choice])
	elif data.item_id == "t2_huigou_quan":
		var repurchase_options: Array = begin_repurchase_draft(player, s)
		if item_choice < 0 or item_choice >= repurchase_options.size():
			return false
		repurchased_data = repurchase_options[item_choice]
		selected_choice_id = repurchased_data.item_id
	elif data.item_id == "t2_yingji_xiang":
		var t1_entries: Array = []
		for entry_variant in battle_backpacks[player]:
			var entry: Dictionary = entry_variant
			var entry_data: ItemData = ItemCatalog.make(String(entry.get("item_id", "")))
			if entry_data != null and entry_data.tier == 1:
				t1_entries.append(entry)
		if t1_entries.is_empty():
			return false
		var emergency_choice: Dictionary = t1_entries[rng.randi_range(0, t1_entries.size() - 1)]
		selected_choice_id = String(emergency_choice.get("item_id", ""))
		selected_bag_uid = int(emergency_choice.get("uid", -1))
	elif item_requires_enemy_item_slot_target(data):
		if not valid_enemy_item_target_for(data, player, item_slot_target):
			return false
	if item_requires_friendly_hero_target(data) and target_override < 0:
		return false
	var resolved_target: int = item_slot_target if item_requires_enemy_item_slot_target(data) \
			or item_requires_friendly_item_slot_target(data) \
		else _resolve_item_target(player, data, target_override)
	if not data.effect.can_use(self, player, resolved_target, data):
		return false
	_begin_item_transaction(player)
	info_distortion[player].erase("hide_item_bar")
	data.effect.on_consumed(self, player, resolved_target, data)
	_record_consumed_item(player, data)
	_mark_item_slot_used_this_turn(player, s)
	# 封印卷轴只抵消效果：正式槽道具照常消耗；带副目标的道具不消耗/改写副目标。
	var sealed: bool = _consume_due_item_seal(player)
	_record_item_action(player, {item_id = data.item_id, source_slot = s,
		target = resolved_target, item_slot_target = item_slot_target,
		item_choice = item_choice, chosen_id = selected_choice_id,
		chosen_bag_uid = selected_bag_uid,
		upgraded_id = upgraded.item_id if upgraded != null else "", sealed = sealed})
	if sealed:
		slots[player][s]["used"] = true
		_mark_item_countered_this_turn(player, s)
		return true
	if data.item_id == "t1_ronglu":
		# 炉与燃料在一次校验成功后同时锁定，产能立即到账，可支付本回合行动。
		slots[player][s]["used"] = true
		slots[player][item_slot_target]["used"] = true
		_gain_energy(player, int(data.params.get("energy", 4)))
		_append_slot_item_use(player, data, resolved_target, s, item_slot_target,
			source_uid, source_temporary)
		return true
	if data.item_id == "t2_dianjinshi":
		slots[player][s]["used"] = true
		var target_slot: Dictionary = slots[player][item_slot_target]
		target_slot["item"] = upgraded
		target_slot["state"] = SlotState.CHARGING
		target_slot["since"] = turn_number
		target_slot["used"] = false
		target_slot["draft"] = []
		target_slot["upg_draft"] = []
		_append_slot_item_use(player, data, resolved_target, s, item_slot_target,
			source_uid, source_temporary)
		return true
	if data.item_id == "t1_jicun_pai":
		slots[player][s]["used"] = true
		_return_slot_item_to_backpack(player, item_slot_target)
		_gain_energy(player, int(data.params.get("energy", 2)))
		_append_slot_item_use(player, data, resolved_target, s, item_slot_target,
			source_uid, source_temporary)
		return true
	if data.item_id == "t2_huigou_quan":
		slots[player][s]["used"] = true
		add_item_to_battle_backpack(player, repurchased_data.item_id, true)
		_append_slot_item_use(player, data, resolved_target, s, item_slot_target,
			source_uid, source_temporary)
		return true
	if data.item_id == "t2_yingji_xiang":
		slots[player][s]["used"] = true
		var emergency_entry: Dictionary = _take_bag_entry(player, selected_bag_uid)
		if not _put_entry_in_slot(player, s, emergency_entry, true):
			return false
		_append_slot_item_use(player, data, resolved_target, s, item_slot_target,
			source_uid, source_temporary)
		return true
	if data.item_id == "t2_huanqian_tong":
		slots[player][s]["used"] = true
		var source: Dictionary = slots[player][s]
		var chosen_uid: int = selected_bag_uid
		var returned_entry: Dictionary = _return_slot_item_to_backpack(player, item_slot_target)
		var chosen_entry: Dictionary = returned_entry if chosen_uid < 0 \
			else _take_bag_entry(player, chosen_uid)
		if chosen_uid < 0:
			_take_bag_entry(player, int(returned_entry.get("uid", -1)))
		if not _put_entry_in_slot(player, item_slot_target, chosen_entry, false):
			return false
		_append_slot_item_use(player, data, resolved_target, s, item_slot_target,
			source_uid, source_temporary)
		return true
	slots[player][s]["used"] = true
	if bool(data.params.get("relic", false)):
		_register_relic(player, data)
		return true
	if data.effect.resolves_on_submit():
		_apply_submit_effect(player, resolved_target, data)
		if not data.effect.queues_after_submit():
			return true
	if data.item_id == "t2_mojing":
		_commit_magic_crystal(player, data)
	_append_slot_item_use(player, data, resolved_target, s, item_slot_target,
		source_uid, source_temporary)
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
		var pool: Array = _tier_pool_for_mode(item.tier + 1) if item != null else []
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
	return int(slots[player][s]["state"]) == SlotState.EMPTY \
		and usable_energy(player) >= ITEM_REFILL_COST \
		and (not battle_backpack_enabled or not battle_backpacks[player].is_empty())


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
	return _tier_pool_for_mode(1)


func _tier_pool_for_mode(tier: int) -> Array:
	var out: Array = []
	for item_variant in ItemCatalog.all_for_tier(tier):
		var data: ItemData = item_variant
		if battle_backpack_enabled or not bool(data.params.get("requires_backpack", false)):
			out.append(data)
	return out


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
				sl["draft"] = []
				sl["upg_draft"] = []
				sl["draft_entry_uids"] = []
				sl["instance_uid"] = -1
				sl["temporary"] = false


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
	c.energy_max = energy_max.duplicate()
	c.hp = hp.duplicate(true)
	c.max_hp = max_hp.duplicate(true)
	c.shield = shield.duplicate(true)
	c.pending_damage = pending_damage.duplicate(true)
	c.statuses = statuses.duplicate(true)
	c.team_statuses = team_statuses.duplicate(true)
	c.selected_action = selected_action.duplicate()
	c._empowered_wave = _empowered_wave.duplicate()
	c._split_big_wave = _split_big_wave.duplicate()
	c._blood_payment = _blood_payment.duplicate()
	c._blood_payment_source = _blood_payment_source.duplicate()
	c._energy_cap_discount = _energy_cap_discount.duplicate()
	c.free_switch_usage_turn = free_switch_usage_turn.duplicate()
	c.free_switch_uses = free_switch_uses.duplicate()
	c._pending_free_switches = _pending_free_switches.duplicate(true)
	c._switch_to = _switch_to.duplicate()
	c._forced_pull = _forced_pull.duplicate()
	c._active_target = _active_target.duplicate()
	c._attack_target = _attack_target.duplicate()
	c._second_action = _second_action.duplicate()
	c._second_attack_target = _second_attack_target.duplicate()
	c.pending_death_switch = pending_death_switch.duplicate()
	c._death_processed = _death_processed.duplicate(true)
	c._last_action = _last_action.duplicate()
	c._killer = _killer.duplicate(true)
	c.items = items.duplicate(true)
	c.item_uses = item_uses.duplicate(true)
	c.info_distortion = info_distortion.duplicate(true)
	c.item_buffs = item_buffs.duplicate(true)
	c.timed_item_effects = timed_item_effects.duplicate(true)
	c._imod = _imod.duplicate(true)
	c.relics = relics.duplicate(true)
	c.slots = slots.duplicate(true)
	c.battle_backpack_enabled = battle_backpack_enabled
	c.battle_backpacks = battle_backpacks.duplicate(true)
	c.used_item_history = used_item_history.duplicate(true)
	c.revealed_backpack_uids = revealed_backpack_uids.duplicate(true)
	c._next_backpack_uid = _next_backpack_uid
	c.turn_number = turn_number
	c.game_over = game_over
	c.winner = winner
	c.overtime_mode = overtime_mode
	c.action_lock_turn = action_lock_turn.duplicate()
	c.action_locked = action_locked.duplicate()
	c.energy_burn_turn = energy_burn_turn
	c.upgrade_next_wave = upgrade_next_wave.duplicate()
	c.retained_big_defend = retained_big_defend.duplicate()
	c.retained_big_defend_until_turn = retained_big_defend_until_turn.duplicate()
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

const SNAPSHOT_VERSION := 20
const HERO_RES_DIR := "res://assets/data/heroes/"
## 快照必需键（2026-07-17 终审修复·schema 门）：⚠新增引擎状态字段的"三处同步"升级为四处——
## clone() / to_snapshot()+from_snapshot() / 本表 / 快照测试。
const SNAP_REQUIRED_KEYS: Array[String] = ["v", "heroes", "active_index", "energy", "energy_max", "hp", "max_hp",
	"shield", "pending_damage", "statuses", "team_statuses", "selected_action", "switch_to", "forced_pull",
	"active_target", "attack_target", "second_action", "second_attack_target", "pending_death_switch", "death_processed", "empowered_wave", "split_big_wave", "blood_payment", "blood_payment_source", "energy_cap_discount", "free_switch_usage_turn", "free_switch_uses", "pending_free_switches", "killer",
	"last_action", "items", "item_uses", "info_distortion", "item_buffs", "timed_item_effects", "imod", "relics", "slots",
	"battle_backpack_enabled", "battle_backpacks", "used_item_history", "revealed_backpack_uids", "next_backpack_uid",
	"turn_number", "game_over", "winner", "overtime_mode", "action_lock_turn", "action_locked",
	"energy_burn_turn", "upgrade_next_wave", "retained_big_defend", "retained_big_defend_until_turn",
	"pve_no_econ", "rng_seed", "rng_state"]


## 导出全量战局快照（纯数据·与本局零共享·JSON 安全）。
func to_snapshot() -> Dictionary:
	return {
		v = SNAPSHOT_VERSION,
		heroes = [_snap_pack_team(0), _snap_pack_team(1)],
		active_index = active_index.duplicate(),
		energy = energy.duplicate(),
		energy_max = energy_max.duplicate(),
		hp = hp.duplicate(true),
		max_hp = max_hp.duplicate(true),
		shield = shield.duplicate(true),
		pending_damage = pending_damage.duplicate(true),
		statuses = statuses.duplicate(true),
		team_statuses = team_statuses.duplicate(true),
		selected_action = selected_action.duplicate(),
		switch_to = _switch_to.duplicate(),
		forced_pull = _forced_pull.duplicate(),
		active_target = _active_target.duplicate(),
		attack_target = _attack_target.duplicate(),
		second_action = _second_action.duplicate(),
		second_attack_target = _second_attack_target.duplicate(),
		pending_death_switch = pending_death_switch.duplicate(),
		death_processed = _death_processed.duplicate(true),
		empowered_wave = _empowered_wave.duplicate(),
		split_big_wave = _split_big_wave.duplicate(),
		blood_payment = _blood_payment.duplicate(),
		blood_payment_source = _blood_payment_source.duplicate(),
		energy_cap_discount = _energy_cap_discount.duplicate(),
		free_switch_usage_turn = free_switch_usage_turn.duplicate(),
		free_switch_uses = free_switch_uses.duplicate(),
		pending_free_switches = _pending_free_switches.duplicate(true),
		killer = _killer.duplicate(true),
		last_action = _last_action.duplicate(),
		items = [_snap_pack_items(items[0]), _snap_pack_items(items[1])],
		item_uses = [_snap_pack_uses(0), _snap_pack_uses(1)],
		info_distortion = info_distortion.duplicate(true),
		item_buffs = item_buffs.duplicate(true),
		timed_item_effects = timed_item_effects.duplicate(true),
		imod = _imod.duplicate(true),
		relics = [_snap_pack_relics(0), _snap_pack_relics(1)],
		slots = [_snap_pack_slots(0), _snap_pack_slots(1)],
		battle_backpack_enabled = battle_backpack_enabled,
		battle_backpacks = battle_backpacks.duplicate(true),
		used_item_history = used_item_history.duplicate(true),
		revealed_backpack_uids = revealed_backpack_uids.duplicate(true),
		next_backpack_uid = _next_backpack_uid,
		turn_number = turn_number,
		game_over = game_over,
		winner = winner,
		overtime_mode = overtime_mode,
		action_lock_turn = action_lock_turn.duplicate(),
		action_locked = action_locked.duplicate(),
		energy_burn_turn = energy_burn_turn,
		upgrade_next_wave = upgrade_next_wave.duplicate(),
		retained_big_defend = retained_big_defend.duplicate(),
		retained_big_defend_until_turn = retained_big_defend_until_turn.duplicate(),
		pve_no_econ = pve_no_econ,
		rng_seed = str(rng.seed),
		rng_state = str(rng.state),
	}


## 从快照恢复战局（覆盖本实例全部状态·技能组件重建）。版本不符返回 false 且不动现状。
func from_snapshot(d: Dictionary) -> bool:
	# 版本门先验类型（2026-07-17 终审修复）：v 为 Array/Dictionary 时旧 int() 直接脚本错误。
	var ver: Variant = d.get("v")
	if not (ver is int or ver is float) or int(ver) != SNAPSHOT_VERSION:
		push_warning("BattleCore.from_snapshot: 快照版本不符 %s（期望 %d）" % [d.get("v"), SNAPSHOT_VERSION])
		return false
	# schema 门（同批修复）：畸形快照原会在下方硬索引处炸脚本错误且半恢复污染现状——
	# 必需键全量核对·缺任何一个=拒绝且不动本实例（调用方检查返回值·battle_screen 同批接住）。
	for k: String in SNAP_REQUIRED_KEYS:
		if not d.has(k):
			push_warning("BattleCore.from_snapshot: 快照缺字段 '%s' → 拒绝恢复" % k)
			return false
	var s: Dictionary = _snap_norm(d)
	heroes = [_snap_unpack_team(s["heroes"][0]), _snap_unpack_team(s["heroes"][1])]
	active_index.assign(s["active_index"])
	energy.assign(s["energy"])
	energy_max.assign(s["energy_max"])
	hp = s["hp"]
	max_hp = s["max_hp"]
	shield = s["shield"]
	pending_damage = s["pending_damage"]
	statuses = s["statuses"]
	var restored_team_statuses: Array[Dictionary] = []
	restored_team_statuses.assign(s["team_statuses"])
	team_statuses = restored_team_statuses
	selected_action.assign(s["selected_action"])
	_switch_to.assign(s["switch_to"])
	_forced_pull.assign(s["forced_pull"])
	_active_target.assign(s["active_target"])
	_attack_target.assign(s["attack_target"])
	_second_action.assign(s["second_action"])
	_second_attack_target.assign(s["second_attack_target"])
	pending_death_switch.assign(s["pending_death_switch"])
	_death_processed = s["death_processed"]
	_empowered_wave.assign(s["empowered_wave"])
	_split_big_wave.assign(s["split_big_wave"])
	_blood_payment.assign(s["blood_payment"])
	_blood_payment_source.assign(s["blood_payment_source"])
	_energy_cap_discount.assign(s["energy_cap_discount"])
	free_switch_usage_turn.assign(s["free_switch_usage_turn"])
	free_switch_uses.assign(s["free_switch_uses"])
	_pending_free_switches = s["pending_free_switches"]
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
	timed_item_effects = s["timed_item_effects"]
	_imod = s["imod"]
	relics = [_snap_unpack_relics(s["relics"][0]), _snap_unpack_relics(s["relics"][1])]
	slots = [_snap_unpack_slots(s["slots"][0]), _snap_unpack_slots(s["slots"][1])]
	battle_backpack_enabled = bool(s["battle_backpack_enabled"])
	battle_backpacks = s["battle_backpacks"]
	used_item_history = s["used_item_history"]
	var reveals: Array[Dictionary] = []
	reveals.assign(s["revealed_backpack_uids"])
	revealed_backpack_uids = reveals
	_next_backpack_uid = int(s["next_backpack_uid"])
	turn_number = int(s["turn_number"])
	game_over = bool(s["game_over"])
	winner = int(s["winner"])
	overtime_mode = bool(s["overtime_mode"])
	action_lock_turn.assign(s["action_lock_turn"])
	action_locked.assign(s["action_locked"])
	energy_burn_turn = int(s["energy_burn_turn"])
	upgrade_next_wave.assign(s["upgrade_next_wave"])
	retained_big_defend.assign(s["retained_big_defend"])
	retained_big_defend_until_turn.assign(s["retained_big_defend_until_turn"])
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
		out.append({id = _snap_item_id(u["data"]), when = int(u["when"]), target = int(u["target"]),
			source_slot = int(u.get("source_slot", -1)), item_slot_target = int(u.get("item_slot_target", -1)),
			instance_uid = int(u.get("instance_uid", -1)), temporary = bool(u.get("temporary", false))})
	return out


static func _snap_unpack_uses(arr: Array) -> Array:
	var out: Array = []
	for u in arr:
		out.append({data = _snap_item_make(String(u["id"])), when = int(u["when"]), target = int(u["target"]),
			source_slot = int(u.get("source_slot", -1)), item_slot_target = int(u.get("item_slot_target", -1)),
			instance_uid = int(u.get("instance_uid", -1)), temporary = bool(u.get("temporary", false))})
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
		out.append({state = int(sl.get("state", SlotState.CHARGING)),
			item = _snap_item_id(sl.get("item", null)), since = int(sl.get("since", -1)),
			used = bool(sl.get("used", false)), draft = _snap_pack_items(sl.get("draft", [])),
			upg_draft = _snap_pack_items(sl.get("upg_draft", [])),
			draft_entry_uids = (sl.get("draft_entry_uids", []) as Array).duplicate(),
			instance_uid = int(sl.get("instance_uid", -1)), temporary = bool(sl.get("temporary", false))})
	return out


static func _snap_unpack_slots(arr: Array) -> Array:
	var out: Array = []
	for sl in arr:
		out.append({state = int(sl.get("state", SlotState.CHARGING)),
			item = _snap_item_make(String(sl.get("item", ""))), since = int(sl.get("since", -1)),
			used = bool(sl.get("used", false)), draft = _snap_unpack_items(sl.get("draft", [])),
			upg_draft = _snap_unpack_items(sl.get("upg_draft", [])),
			draft_entry_uids = (sl.get("draft_entry_uids", []) as Array).duplicate(),
			instance_uid = int(sl.get("instance_uid", -1)), temporary = bool(sl.get("temporary", false))})
	return out


## 枚举该玩家当前所有合法动作。返回
## Array[{action:int, target:int, empowered_wave?:bool, split_big_wave?:bool,
##        blood_payment?:bool, energy_cap_discount?:bool}]，
## target 于 SWITCH=己方替补槽、房日基础攻击=任一存活敌方槽、带目标 ACTIVE（枭阳 h21）=敌方替补槽，其余 -1。
## 亢金强化波、玄冥双波、蚩尤生命支付与并封减费均展开为显式 choice，供 AI/联机走同一白名单。
## CHARGE 恒合法 → 列表非空。
func legal_actions(player: int) -> Array:
	var out: Array = []
	var saved_selected: int = selected_action[player]
	var saved_empowered: bool = _empowered_wave[player]
	var saved_split: bool = _split_big_wave[player]
	var saved_blood: bool = _blood_payment[player]
	var saved_blood_source: int = _blood_payment_source[player]
	var saved_discount: bool = _energy_cap_discount[player]
	var saved_switch: int = _switch_to[player]
	var saved_active_target: int = _active_target[player]
	var saved_attack_target: int = _attack_target[player]
	for a in [ActionDef.Action.CHARGE, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND,
			ActionDef.Action.BIG_ATTACK, ActionDef.Action.BIG_DEFEND]:
		var targets: Array = living_heroes(1 - player) \
			if ActionDef.is_attack(a) and can_target_any_enemy_with_base_attack(player, a) else [-1]
		for target in targets:
			var forms: Array[Dictionary] = [{}]
			if a == ActionDef.Action.ATTACK and has_empowered_wave(player):
				forms.append({empowered_wave = true})
			if a == ActionDef.Action.BIG_ATTACK and has_split_big_wave(player):
				forms.append({split_big_wave = true})
			for form: Dictionary in forms:
				var empowered := bool(form.get("empowered_wave", false))
				var split := bool(form.get("split_big_wave", false))
				for blood_payment in [false, true]:
					for energy_cap_discount in [false, true]:
						if select_action(player, a, target, empowered, split,
								blood_payment, energy_cap_discount):
							var choice := {action = a, target = target}
							if empowered:
								choice["empowered_wave"] = true
							if split:
								choice["split_big_wave"] = true
							if blood_payment:
								choice["blood_payment"] = true
							if energy_cap_discount:
								choice["energy_cap_discount"] = true
							out.append(choice)
	# 枚举过程只可读；恢复选择态，避免调用 legal_actions 污染真局或 AI 克隆。
	selected_action[player] = saved_selected
	_empowered_wave[player] = saved_empowered
	_split_big_wave[player] = saved_split
	_blood_payment[player] = saved_blood
	_blood_payment_source[player] = saved_blood_source
	_energy_cap_discount[player] = saved_discount
	_switch_to[player] = saved_switch
	_active_target[player] = saved_active_target
	_attack_target[player] = saved_attack_target
	if can_afford(player, ActionDef.Action.SWITCH):
		for t in living_reserves(player):
			out.append({action = ActionDef.Action.SWITCH, target = t})
	var active_skill: HeroSkill = _skills[player][active_index[player]]
	if active_skill != null and active_skill.has_active():
		var active_targets: Array = living_reserves(1 - player) \
			if active_skill.active_needs_enemy_target() else [-1]
		for active_target in active_targets:
			for blood_payment in [false, true]:
				for energy_cap_discount in [false, true]:
					if not can_use_active(player, blood_payment, energy_cap_discount):
						continue
					var active_choice := {action = ActionDef.ACTIVE, target = active_target}
					if blood_payment:
						active_choice["blood_payment"] = true
					if energy_cap_discount:
						active_choice["energy_cap_discount"] = true
					out.append(active_choice)
	return out


## 按 {action,target,empowered_wave?,split_big_wave?,blood_payment?,energy_cap_discount?}
## 提交该玩家动作（封装 select_* 分派）。
func apply_choice(player: int, choice: Dictionary) -> bool:
	if bool(choice.get("double", false)):
		return false   # 旧 h16 双动作字段已退役；联机协议暂保留该字段但 true 必须拒绝
	var a: int = int(choice["action"])
	var primary_ok: bool = false
	if a == ActionDef.ACTIVE:
		primary_ok = select_active(player, int(choice.get("target", -1)),
			bool(choice.get("blood_payment", false)),
			bool(choice.get("energy_cap_discount", false)))
	elif a == ActionDef.Action.SWITCH:
		primary_ok = select_switch(player, int(choice["target"]))
	else:
		primary_ok = select_action(player, a, int(choice.get("target", -1)),
			bool(choice.get("empowered_wave", false)), bool(choice.get("split_big_wave", false)),
			bool(choice.get("blood_payment", false)), bool(choice.get("energy_cap_discount", false)))
	if not primary_ok:
		return false
	if int(choice.get("second_action", -1)) >= 0:
		return select_second_action(player, int(choice["second_action"]),
			int(choice.get("second_target", -1)))
	return true


func apply_second_choice(player: int, choice: Dictionary) -> bool:
	if choice.is_empty():
		return not has_lianhuan_gu_queued(player)
	return select_second_action(player, int(choice.get("action", -1)),
		int(choice.get("target", -1)))


# === resolve ===
#
# 保留 v3 同时独立结算（B-001/2/3）：双方攻击各自走一遍管线、不抵消。
# 切换采用【甲】时机（ADR-002 Q1 / 2026-05-25 Eddy 裁定）：切换先于伤害结算，
#   攻击打到换【上来】的新英雄 → 切换 = 可垫刀/调度的防御工具。

func resolve() -> Dictionary:
	var events: Array = []
	_pending_reserve_pursuit_source = [-1, -1]
	_pending_reserve_pursuit_target = [-1, -1]
	_active_transform_requested = [false, false]
	for p in [0, 1]:
		item_buffs[p]["actual_switches_this_turn"] = []

	# Phase IS.0：双方保护性 setup 与天罗裁定必须先于本回合任何持久状态推进。
	# 这样事务回滚恢复的是选择阶段快照，不会把已消费的力竭/下回合增益重新带回。
	_imod = [{}, {}]
	for p in [0, 1]:
		if item_uses[p].size() > 0:
			info_distortion[p] = {}
	for p in [0, 1]:
		for use_s in item_uses[p]:
			use_s["data"].effect.setup_pre(self, p, use_s["data"])
	var tianluo_affected: Array[bool] = _resolve_tianluo_requests(events)
	_resolve_single_item_rule(tianluo_affected, events)
	_settle_pending_free_switches(tianluo_affected, events)
	_discard_item_transactions()
	_flush_pending_item_events(events)
	_collect_item_insurance(events)
	_resolve_hostile_item_counters(events)
	# 天罗已完成首件道具裁定；剩余规则件在普通 apply_pre 前统一预设，避免点击顺序改变结果。
	for p in [0, 1]:
		for use_p in item_uses[p]:
			use_p["data"].effect.prepare_pre(
				self, p, int(use_p["target"]), use_p["data"])

	# Phase 0.3: 沉默换位（烛阴 h17【镇压】）——被沉默英雄(silenced>0)的技能槽临时置 null，
	#   借引擎全程 null-check 统一收口其【所有 hook】(=unique 失效)。resolve 末还原 + 递减时长。
	#   只递减本回合生效过的（cast 当回合 silenced 在本 swap 之后才写入 → 不计 → 恰好 2 个完整回合）。
	var _silenced_swap: Array = []
	var global_skill_silence: bool = bool(item_mod(0, "global_skill_silence", false)) \
		or bool(item_mod(1, "global_skill_silence", false))
	for sp in [0, 1]:
		for ss in range(_skills[sp].size()):
			if (global_skill_silence or int(get_status(sp, ss, "silenced", 0)) > 0) \
					and _skills[sp][ss] != null:
				_silenced_swap.append([sp, ss, _skills[sp][ss]])
				_skills[sp][ss] = null

	# Phase 0.4: 龙息力竭（上回合大波被大防挡下）→ 本回合强制 CHARGE（喘息·失这次动作选择）
	for p in [0, 1]:
		if bool(item_buffs[p].get("exhausted_next", false)) \
				or int(item_buffs[p].get("exhausted_turn", -1)) == turn_number:
			item_buffs[p].erase("exhausted_next")
			item_buffs[p].erase("exhausted_turn")
			selected_action[p] = ActionDef.Action.CHARGE
			_empowered_wave[p] = false
			_split_big_wave[p] = false
			_blood_payment[p] = false
			_blood_payment_source[p] = -1
			_energy_cap_discount[p] = false
			_second_action[p] = -1
			_second_attack_target[p] = -1
			events.append({id = "exhausted", player = p})

	# Phase 1: guard 未选动作 / 被禁动作 → CHARGE（延续 v3 B-004）
	for p in [0, 1]:
		if selected_action[p] < 0:
			push_warning("BattleCore.resolve(): P%d 未选动作，fallback CHARGE" % (p + 1))
			selected_action[p] = ActionDef.Action.CHARGE
			_empowered_wave[p] = false
			_split_big_wave[p] = false
			_blood_payment[p] = false
			_blood_payment_source[p] = -1
			_energy_cap_discount[p] = false

	var a: Array[int] = [selected_action[0], selected_action[1]]
	var second_actions: Array[int] = [_second_action[0], _second_action[1]]
	for p in [0, 1]:
		if a[p] != ActionDef.Action.ATTACK:
			_empowered_wave[p] = false
		if a[p] != ActionDef.Action.BIG_ATTACK:
			_split_big_wave[p] = false
		if blood_payment_source(p) < 0:
			_blood_payment[p] = false
	_retained_big_defend_in_use = [false, false]
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

	# Phase IS：天罗与免费切换已裁定；现在把跨回合 buff 落到最终出战英雄，再重验
	# 被天罗回滚即时资源或免费切换预览后的动作，最后进入普通道具 apply_pre。
	for p in [0, 1]:
		if item_buffs[p].has("next_atk_bonus"):
			add_item_mod(p, "atk_bonus", int(item_buffs[p]["next_atk_bonus"]))
			item_buffs[p].erase("next_atk_bonus")
		if item_buffs[p].has("next_atk_total_bonus"):
			add_item_mod(p, "base_attack_total_bonus", int(item_buffs[p]["next_atk_total_bonus"]))
			item_buffs[p].erase("next_atk_total_bonus")
		if item_buffs[p].has("next_armor"):
			shield[p][active_index[p]] += int(item_buffs[p]["next_armor"])
			item_buffs[p].erase("next_armor")
		if item_buffs[p].has("next_energy_penalty"):
			energy[p] = maxi(0, energy[p] - int(item_buffs[p]["next_energy_penalty"]))
			item_buffs[p].erase("next_energy_penalty")
	_revalidate_tianluo_actions(tianluo_affected, a, events)
	_retain_big_defend_candidate = [false, false]
	for p in [0, 1]:
		if a[p] == ActionDef.Action.BIG_DEFEND:
			var action_skill: HeroSkill = _skills[p][active_index[p]]
			_retain_big_defend_candidate[p] = \
				action_skill != null and action_skill.retains_unused_big_defend()
	for p in [0, 1]:
		for use_a in item_uses[p]:
			if int(use_a["when"]) == ItemData.Seq.PRE:
				use_a["data"].effect.apply_pre(self, p, int(use_a["target"]), use_a["data"])
	_resolve_item_wagers(events)
	# h07 免费切换在道具揭示前完成；新切换道具在此对已完成的切换补结算一次。
	_resolve_retroactive_switch_items(events)
	_flush_pending_item_events(events)
	_resolve_last_wishes(a, events)
	# 遗物·Phase IS：注入本回合被动修正器（_imod）。新激活的遗物本回合也在此生效。
	for p in [0, 1]:
		for relic in relics[p]:
			relic["data"].effect.relic_pre(self, p, relic["data"], relic["state"], events)

	# Phase IS.5: 结算 Phase 0 记下的到期延迟伤害（本回合道具新挂的债不在账上·下回合才生效）。
	for p in [0, 1]:
		for s in range(due_damage[p].size()):
			var owed: int = int(due_damage[p][s])
			if owed > 0:
				if damage_immune(p):   # 周天罡气：本回合到期的延迟伤害被免掉（不顺延）
					continue
				if _consume_fatal_damage_immunity(p, s, owed, events):
					continue
				hp[p][s] -= owed
				events.append({id = "deferred_damage", player = p, slot = s, amount = owed})

	# Phase 2: 扣能量 / 攒能量 / 主动技执行（道具：省力咒省能 / 分神铃铛削攒）
	for p in [0, 1]:
		var empowered_cost: int = EMPOWERED_WAVE_COST if _empowered_wave[p] else 0
		var resolved_cost: int = maxi(0, action_cost(p, a[p]) + empowered_cost)
		if _energy_cap_discount[p] and resolved_cost > 0:
			var reduced: int = reduce_energy_max(
				p, ENERGY_CAP_DISCOUNT_COST, ENERGY_CAP_DISCOUNT_FLOOR)
			if reduced == ENERGY_CAP_DISCOUNT_COST:
				resolved_cost = maxi(0, resolved_cost - ENERGY_CAP_DISCOUNT_AMOUNT)
				events.append({
					id = "h24_energy_cap_discount",
					player = p,
					amount = reduced,
					saved = ENERGY_CAP_DISCOUNT_AMOUNT,
					new_max = energy_max[p],
				})
		var energy_before_payment: int = usable_energy(p)
		var exact_energy_spend: bool = not _blood_payment[p] and resolved_cost > 0 \
			and energy_before_payment == resolved_cost
		_pay_action_cost(p, resolved_cost, events)
		if exact_energy_spend:
			set_item_mod(p, "exact_spend_refund_pending", int(item_mod(
				p, "exact_spend_refund", 0)))
		if a[p] == ActionDef.Action.BIG_ATTACK \
				and int(item_buffs[p].get("free_big_attack_until_turn", -1)) == turn_number:
			item_buffs[p].erase("free_big_attack_until_turn")
			events.append({id = "free_big_attack_consumed", player = p})
		if _empowered_wave[p]:
			events.append({id = "longyuji_empowered", player = p, amount = EMPOWERED_WAVE_DAMAGE})
		if a[p] == ActionDef.Action.CHARGE:
			var gain: int = ActionDef.BASE_ACTION_DEF[ActionDef.Action.CHARGE]["energy_gain"]
			gain = maxi(0, gain - int(item_mod(p, "charge_penalty", 0)))
			var gained: int = _gain_energy(p, gain)
			if gained > 0:
				events.append({id = "charge_gain", player = p, amount = gained})
		elif a[p] == ActionDef.ACTIVE:
			# 扣能由上面的 _get_cost 完成；cap 计数 + 事件在此；effect 执行延后到 Phase 2.6（切换之后）。
			var slot: int = active_index[p]
			var sk: HeroSkill = _skills[p][slot]
			if sk != null:
				set_status(p, slot, "active_uses", int(get_status(p, slot, "active_uses", 0)) + 1)
				events.append({id = "active_used", player = p, slot = slot})
	# 梦蝶在双方按提交时合法的动作完成扣费/攒能后统一交换，避免交换本身取消动作。
	_resolve_mengdie_requests(events)
	# 均能斗与梦蝶同属资源重排；固定先梦蝶再均分，使结果不依赖玩家编号或提交顺序。
	_resolve_energy_equalize_requests(events)
	# Phase 2.5: 切换（甲时机，先于伤害）→ 攻击将打到换上来的新英雄
	for p in [0, 1]:
		if a[p] == ActionDef.Action.SWITCH:
			if int(item_mod(p, "no_switch", 0)) > 0 or _turn_switch_locked(p):
				events.append({id = "switch_locked", player = p})
				continue
			_do_switch(p, events)

	# Phase 2.55: 打神鞭强制切换（forced_switch 由道具在 apply_pre 设·指向某存活替补槽）。
	#   仅当该方未主动切换、且未被定身（no_switch）时触发；走 _perform_switch → 触发娄金穷追。
	for p in [0, 1]:
		var fs: int = int(item_mod(p, "forced_switch", -1))
		if fs >= 0 and a[p] != ActionDef.Action.SWITCH and int(item_mod(p, "no_switch", 0)) == 0 \
				and not _turn_switch_locked(p) and fs < hp[p].size() and hp[p][fs] > 0:
			_perform_switch(p, active_index[p], fs, events)

	# Phase 2.6: 即时型主动技执行（在切换之后 → 命中对手 post-switch 出战位）
	for p in [0, 1]:
		if a[p] == ActionDef.ACTIVE:
			var sk: HeroSkill = _skills[p][active_index[p]]
			if sk != null and not sk.active_is_attack():
				sk.execute_active(self, p, active_index[p])

	# Phase 2.65: 烛阴转变。先完整拍下双方目标，再同时落地，避免双方烛阴同拍时后手读到前手改写后的英雄。
	# 复制英雄身份 + 当前/上限 HP + 护甲 + 延迟效果 + 局部状态（含主动技使用进度）；
	# 团队能量、道具、遗物与团队 buff 不属于英雄本体，不复制。
	var transform_snapshots: Array = [null, null]
	for p in [0, 1]:
		if _active_transform_requested[p]:
			var enemy: int = 1 - p
			var target_slot: int = active_index[enemy]
			if hp[enemy][target_slot] > 0:
				transform_snapshots[p] = _snapshot_hero_runtime(enemy, target_slot)
	for p in [0, 1]:
		var snapshot: Variant = transform_snapshots[p]
		if snapshot == null:
			continue
		var source_slot: int = active_index[p]
		var from_id: String = (heroes[p][source_slot] as HeroData).hero_id
		_apply_hero_runtime_snapshot(p, source_slot, snapshot as Dictionary)
		# Phase 0.3 已经过了；若复制来的英雄正处于沉默中，补入本拍的临时技能换位，
		# 保证它不会在后续命中/回合末 hook 中越过沉默，并沿用统一的回合末递减/还原。
		if (global_skill_silence or int(get_status(p, source_slot, "silenced", 0)) > 0) \
				and _skills[p][source_slot] != null:
			_silenced_swap.append([p, source_slot, _skills[p][source_slot]])
			_skills[p][source_slot] = null
		events.append({
			id = "h17_transform",
			player = p,
			slot = source_slot,
			from_hero_id = from_id,
			to_hero_id = (heroes[p][source_slot] as HeroData).hero_id,
		})

	# Phase 2.7: 枭阳 h21【调虎离山】强制揪人 —— execute_active 设的 _forced_pull[受害方]
	#   在此执行（切换之后、伤害之前）→ 被揪英雄成为对手出战、本回合攻击落它身上、原出战下场触发
	#   当前出战技能仍会收到 on_enemy_switch_out；枭阳施法时娄金不在场，因此不触发影狩。
	for p in [0, 1]:
		var pull: int = _forced_pull[p]
		if pull >= 0 and not _turn_switch_locked(p) and pull < hp[p].size() \
				and hp[p][pull] > 0 and pull != active_index[p]:
			_perform_switch(p, active_index[p], pull, events)
		_forced_pull[p] = -1

	# Phase 3+4: 同时独立结算（含道具伤害 hit·ADR-003 D3）。先把双方完整出伤 hit-list 对快照
	# 算好（动作前道具 hit → 动作攻击 → 动作后道具 hit），再一起施加 → 保持 B-001/2/3 跨玩家同时。
	var hitlists: Array = [[], []]
	var base_attack_contexts: Array = [
		{executed = false, source_slot = -1, target_slot = -1, connected = false,
			original_action = -1,
			raw_damage_total = 0, damage_total = 0, hp_damage_total = 0,
			blocked = false, blocked_by_big_defend = false, target_defeated = false,
			hit_effect_triggers = 1},
		{executed = false, source_slot = -1, target_slot = -1, connected = false,
			original_action = -1,
			raw_damage_total = 0, damage_total = 0, hp_damage_total = 0,
			blocked = false, blocked_by_big_defend = false, target_defeated = false,
			hit_effect_triggers = 1},
	]
	var attack_decoy_targets: Array[int] = [-1, -1]
	for p in [0, 1]:
		var aslot: int = active_index[p]
		if ActionDef.is_attack(a[p]):
			# 即使攻击随后被草人落空或对攻优先级取消，仍保留“本回合用了这次攻击”的来源槽；
			# 命中类回调会自行检查 connected，未击败类代价则仍需结算。
			base_attack_contexts[p]["source_slot"] = aslot
			base_attack_contexts[p]["original_action"] = a[p]
			# 道具附带效果按整次攻击只结算一次；双生／三花的额外触发只进入英雄技能 hook。
			base_attack_contexts[p]["hit_effect_triggers"] = 1
			var defender: int = 1 - p
			var decoy: int = int(item_mod(defender, "attack_decoy_target", -1))
			if is_living_reserve(defender, decoy):
				attack_decoy_targets[p] = decoy
				set_item_mod(defender, "attack_decoy_target", -1)
				events.append({id = "attack_redirected_to_reserve", player = defender,
					source_player = p, slot = decoy})
		# 1) 动作【前】道具自身伤害 hit（生锈飞镖/闪电/幸运四叶草）
		for use_h in item_uses[p]:
			if int(use_h["when"]) == ItemData.Seq.PRE:
				for ih in use_h["data"].effect.hits(self, p, int(use_h["target"]), use_h["data"]):
					hitlists[p].append(ih)
		# 2) 动作攻击（基础 / 攻击型主动技）。公共术语「攻击」仅指「波/大波」：
		# 总加减伤、穿防与命中骑乘不作用于攻击型主动技；h13 双波仍是一整次攻击。
		var nullified: bool = bool(item_mod(p, "atk_nullify", false))
		var true_damage_attack: bool = bool(item_mod(p, "next_base_attack_true_damage", false))
		var wave_upgraded: bool = a[p] == ActionDef.Action.ATTACK and upgrade_next_wave[p]
		if nullified and wave_upgraded:
			upgrade_next_wave[p] = false
		if nullified and ActionDef.is_attack(a[p]) and true_damage_attack:
			# 草人令整次攻击落空，但该攻击行动已经形成，仍消耗“下一次攻击”。
			set_item_mod(p, "next_base_attack_true_damage", false)
		if not nullified and ActionDef.is_attack(a[p]):
			# 玄金不动相：原选招始终保留为「波」（费用/历史/道具检查均读 a[p]）；
			# 只把本次 hit 的伤害、有效类型与基础穿透提升到「大波」。
			# 玄冥双波：原选招、费用和历史仍是「大波」，但两段各按普通「波」计算。
			var split_big_wave: bool = _split_big_wave[p] and a[p] == ActionDef.Action.BIG_ATTACK
			var damage_action: int = ActionDef.Action.ATTACK if split_big_wave \
				else (ActionDef.Action.BIG_ATTACK if wave_upgraded else a[p])
			var empowered_damage: int = EMPOWERED_WAVE_DAMAGE if _empowered_wave[p] else 0
			var per_hit_damage: int = maxi(_calc_outgoing(p, damage_action) + empowered_damage, 0)
			per_hit_damage *= maxi(1, int(item_mod(p, "atk_mult", 1)))
			var hit_damages: Array[int] = [per_hit_damage]
			if split_big_wave:
				hit_damages.append(per_hit_damage)
			# 旧 atk_bonus/atk_penalty 也统一收口为【整次基础攻击】总修正，避免双波逐段复制。
			var total_delta: int = int(item_mod(p, "atk_bonus", 0)) \
				+ int(item_mod(p, "base_attack_total_bonus", 0)) \
				+ int(item_mod(p, "turn_base_attack_total_bonus", 0)) \
				- int(item_mod(p, "atk_penalty", 0)) \
				- int(item_mod(p, "base_attack_total_penalty", 0))
			if a[p] == ActionDef.Action.BIG_ATTACK:
				total_delta += int(item_mod(1 - p, "enemy_big_wave_total_bonus", 0))
			if a[p] == ActionDef.Action.ATTACK:
				total_delta -= int(item_mod(p, "next_wave_target_penalty", 0))
			if total_delta >= 0:
				hit_damages[0] += total_delta
			else:
				var remaining_penalty: int = -total_delta
				for damage_index in range(hit_damages.size()):
					var reduced: int = mini(hit_damages[damage_index], remaining_penalty)
					hit_damages[damage_index] -= reduced
					remaining_penalty -= reduced
					if remaining_penalty <= 0:
						break
			var kind: int = ActionDef.Action.ATTACK if split_big_wave else a[p]
			var ksk: HeroSkill = _skills[p][aslot]
			if ksk != null and not split_big_wave:
				kind = ksk.override_attack_kind(a[p], self, p, aslot)
			if wave_upgraded:
				kind = ActionDef.Action.BIG_ATTACK
			var pen: int = ActionDef.base_penetration(kind)
			if ksk != null:
				pen = ksk.attack_penetration(ActionDef.base_penetration(kind), a[p], self, p, aslot)
			var ipen: int = int(item_mod(p, "atk_pen", -1))
			if ipen >= 0:
				pen = ipen
			if wave_upgraded:
				pen = maxi(pen, ActionDef.Pen.PIERCE_DEF)
				upgrade_next_wave[p] = false
			if true_damage_attack:
				pen = ActionDef.Pen.TRUE_DMG
			# 十方无次第：目标只在出手者此刻仍是有效房日时生效；被沉默/动作前被换下则回到标准出战位。
			var target_slot: int = attack_decoy_targets[p]
			if target_slot < 0:
				target_slot = int(item_mod(p, "bound_base_attack_target", -1))
			if target_slot < 0 and can_target_any_enemy_with_base_attack(p, a[p]):
				target_slot = _attack_target[p]
			for damage_index in range(hit_damages.size()):
				var hit_damage: int = hit_damages[damage_index]
				hitlists[p].append({damage = hit_damage, kind = kind, pen = pen,
					riders = item_mod(p, "riders", []), action = true, active = false,
					src_slot = aslot, target_slot = target_slot,
					force_zero_damage = a[p] == ActionDef.Action.ATTACK and bool(item_mod(
						1 - p, "enemy_wave_no_damage", false)),
					consume_true_damage = true_damage_attack and damage_index == 0,
					whole_attack_extra_hits = (int(item_mod(
						p, "whole_attack_extra_hit_effects", 0)) if damage_index == 0 else 0)})
			if split_big_wave:
				events.append({id = "h13_split_big_wave", player = p})
		elif a[p] == ActionDef.ACTIVE:
			var sk: HeroSkill = _skills[p][aslot]
			if sk != null and sk.active_is_attack():
				var akind: int = sk.active_attack_kind()
				var admg: int = maxi(_apply_team_outgoing(
					sk.active_attack_damage(self, p, aslot), akind, p, aslot), 0)
				var apen: int = sk.attack_penetration(ActionDef.base_penetration(akind), ActionDef.ACTIVE, self, p, aslot)
				if admg > 0:
					hitlists[p].append({damage = admg, kind = akind, pen = apen, riders = [],
						action = true, active = true, src_slot = aslot})
		# 3) 动作【后】道具自身伤害 hit（T1 暂无）
		for use_h2 in item_uses[p]:
			if int(use_h2["when"]) == ItemData.Seq.POST:
				for ih2 in use_h2["data"].effect.hits(self, p, int(use_h2["target"]), use_h2["data"]):
					hitlists[p].append(ih2)
	# 施加：值已对快照算好 → 跨玩家同时；己方 hit-list 按序施加（动作前道具 → 动作 → 动作后道具）。
	# 白额雷音：仅双方原选招均为基础攻击、且仅一方对攻优先级更高时，拆出双方基础 action hit：
	#   动作前道具照常 → 优先基础攻击 → 若实际击杀敌方攻击英雄则跳过其全部基础 action hit → 动作后道具照常。
	# 同优先级（含 h03 镜像）回退原同步独立结算；攻击型主动技/道具不参与，也永不被断招。
	var clash_groups: Array = [
		{pre = [], action = [], post = []},
		{pre = [], action = [], post = []},
	]
	for p in [0, 1]:
		var seen_base_action := false
		for hit in hitlists[p]:
			if bool(hit.get("action", false)) and not bool(hit.get("active", false)):
				clash_groups[p]["action"].append(hit)
				seen_base_action = true
			elif not seen_base_action:
				clash_groups[p]["pre"].append(hit)
			else:
				clash_groups[p]["post"].append(hit)

	var clash_first := -1
	if ActionDef.is_attack(a[0]) and ActionDef.is_attack(a[1]) \
			and not clash_groups[0]["action"].is_empty() and not clash_groups[1]["action"].is_empty():
		var clash_priority: Array[int] = [0, 0]
		for p in [0, 1]:
			var source_slot: int = int(clash_groups[p]["action"][0].get("src_slot", active_index[p]))
			var source_skill: HeroSkill = _skills[p][source_slot]
			if source_skill != null:
				clash_priority[p] = source_skill.base_attack_clash_priority()
		if clash_priority[0] != clash_priority[1]:
			clash_first = 0 if clash_priority[0] > clash_priority[1] else 1

	if clash_first >= 0:
		for p in [0, 1]:
			for hit in clash_groups[p]["pre"]:
				_apply_resolve_hit(p, hit, a, events, base_attack_contexts[p])

		var clash_other: int = 1 - clash_first
		var other_source_slot: int = int(clash_groups[clash_other]["action"][0].get(
			"src_slot", active_index[clash_other]))
		var other_was_alive: bool = hp[clash_other][other_source_slot] > 0
		for hit in clash_groups[clash_first]["action"]:
			_apply_resolve_hit(clash_first, hit, a, events, base_attack_contexts[clash_first])

		var other_attack_cancelled: bool = other_was_alive and hp[clash_other][other_source_slot] <= 0
		if other_attack_cancelled:
			events.append({id = "base_attack_cancelled", player = clash_other})
		else:
			for hit in clash_groups[clash_other]["action"]:
				_apply_resolve_hit(clash_other, hit, a, events, base_attack_contexts[clash_other])

		for p in [0, 1]:
			for hit in clash_groups[p]["post"]:
				_apply_resolve_hit(p, hit, a, events, base_attack_contexts[p])
	else:
		# 归因钉快照槽（src_slot·2026-07-17 审计修复）：即使结算中 active_index 发生变化，
		# on-hit/主动技回调也必须归给生成 hit 的出招英雄，否则先后手不对称。
		for p in [0, 1]:
			for hit in hitlists[p]:
				_apply_resolve_hit(p, hit, a, events, base_attack_contexts[p])

	# Phase 4.6: 广寒替补追击。双方主攻击已全部完成，故登场不会改写本回合既定攻击目标。
	_resolve_reserve_pursuits(events)

	# Phase 4.7: 整次基础攻击的结算后道具与后手护甲。
	# 双方主攻击均已落地后再回调，避免玩家0因先回治疗产生不对称。
	for p in [0, 1]:
		var context: Dictionary = base_attack_contexts[p]
		if ActionDef.is_attack(a[p]):
			for data in item_mod(p, "base_attack_aftereffects", []):
				(data as ItemData).effect.on_base_attack_resolved(self, p, context, data, events)
			_resolve_borrowed_marks(p, context, events)
			for relic in relics[p]:
				relic["data"].effect.relic_on_attack_resolved(
					self, p, context, relic["data"], relic["state"], events)
			var defender: int = 1 - p
			for relic in relics[defender]:
				relic["data"].effect.relic_on_defense_resolved(
					self, defender, context, relic["data"], relic["state"], events)
			var pressure_loss: int = int(item_mod(
				defender, "bigdef_blocks_wave_energy_loss", 0))
			if int(context.get("original_action", -1)) == ActionDef.Action.ATTACK \
					and a[defender] == ActionDef.Action.BIG_DEFEND \
					and bool(context.get("blocked_by_big_defend", false)) and pressure_loss > 0:
				energy[p] = maxi(0, energy[p] - pressure_loss)
				set_item_mod(defender, "bigdef_blocks_wave_energy_loss", 0)
				events.append({id = "pressure_energy_loss", player = p,
					amount = pressure_loss, source_player = defender})
			var blocked_wave_shield: int = int(item_mod(p, "blocked_wave_shield", 0))
			if a[p] == ActionDef.Action.ATTACK and bool(context.get("blocked", false)) \
					and blocked_wave_shield > 0:
				var source_slot: int = int(context.get("source_slot", active_index[p]))
				if source_slot >= 0 and source_slot < hp[p].size() and hp[p][source_slot] > 0:
					shield[p][source_slot] += blocked_wave_shield
				set_item_mod(p, "blocked_wave_shield", 0)
	for p in [0, 1]:
		if ActionDef.is_attack(a[p]):
			_resolve_dianjiang_after_hit(p, base_attack_contexts[p], events)
	for p in [0, 1]:
		_settle_exact_spend_refund(p, events)

	# 连环鼓第二行动在第一行动完整结算后执行；第二行动只读取自身阶段的攻防，
	# 因此第一阶段的「防」不会跨阶段挡第二阶段的「波」。
	_resolve_lianhuan_second_actions(a, second_actions, events)
	# 「后手」等整回合存活奖励必须等两个行动阶段都结束；否则只在第二行动攻击时会提前给盾。
	for p in [0, 1]:
		var after_shield: int = int(item_mod(p, "survive_attack_shield", 0))
		var active_slot: int = active_index[p]
		if after_shield > 0 and hp[p][active_slot] > 0:
			shield[p][active_slot] += after_shield

	# 妖火在指定的下一回合所有行动完成后检查“仍在场上”；离场即规避。
	_resolve_timed_item_effects(events)

	# Phase 4.8: 不坠神言——空放大防保留至下一回合结束；连续空放刷新唯一状态的期限。
	for p in [0, 1]:
		if _retain_big_defend_candidate[p]:
			retained_big_defend[p] = true
			retained_big_defend_until_turn[p] = turn_number + 1
			events.append({id = "buzhui_shenyan_retained", player = p})
		elif retained_big_defend[p] and retained_big_defend_until_turn[p] <= turn_number:
			retained_big_defend[p] = false
			retained_big_defend_until_turn[p] = -1
			events.append({id = "buzhui_shenyan_expired", player = p})

	# 力量的代价：所有行动与回合末效果完成后、统一死亡链开始前，处决当时出战英雄。
	for p in [0, 1]:
		if bool(item_mod(p, "strength_price_execution", false)):
			var doomed_slot: int = active_index[p]
			if hp[p][doomed_slot] > 0:
				if not _consume_fatal_damage_immunity(
						p, doomed_slot, hp[p][doomed_slot], events):
					hp[p][doomed_slot] = 0
					_killer[p][doomed_slot] = -1
					events.append({id = "strength_price_execution", player = p, slot = doomed_slot})

	# Phase 5: 死亡结算 + 强制切换 + 胜负
	_resolve_deaths(a, events)

	# Phase 5.5: 回合结算末 hook（on_resolve_end）
	for p in [0, 1]:
		var s: int = active_index[p]
		if hp[p][s] > 0:
			var sk: HeroSkill = _skills[p][s]
			if sk != null:
				sk.on_resolve_end(self, p, s)

	# Phase 6: cleanup
	# 罪已昭覆盖施加回合与紧接的下一回合；若下一回合再次命中，会在此之前刷新期限。
	_expire_h20_vulnerabilities(events)
	# 遗物·Phase 6：每回合末 tick（产出/计数/充能；读 selected_action 判断本回合是否攻击）。
	#   返回 false 的遗物移除（碎/耗尽）。在被动能量前结算，故遗物产能也享受不到/不影响被动。
	for p in [0, 1]:
		var kept_relics: Array = []
		for relic in relics[p]:
			if bool(relic["data"].effect.relic_end(
					self, p, relic["data"], relic["state"], events)):
				kept_relics.append(relic)
		relics[p] = kept_relics
	# 噬心钉等遗物可在回合末直接失去生命；其致死必须进入同一死亡/替补链。
	_resolve_deaths(a, events)
	# 候阵签：在本回合攻击、规则处决与遗物回合末效果全部完成后兑现预定登场。
	# 存活出战位走完整切换链；若原出战位已阵亡，则直接完成预定死亡补位，且不伪造切换触发。
	_resolve_end_turn_entries(a, events)
	# 清囊火盆在所有本回合道具/遗物结算后烧掉仍未使用的就绪件；收入仍属于主动得能。
	_resolve_bag_bonfire(events)
	# 被动能量 +1/回合（A2 引入·2026-06-24 去除·2026-07-03 恢复——sim 实锤攒-only 下最优解=互龟死锁）。
	for p in [0, 1]:
		_gain_energy(p, ActionDef.PASSIVE_ENERGY_GAIN, false, true)   # 回合被动能量不吃步虚无有乡加成（2026-07-04）
	# 焚天火兆：在预告的下一回合所有行动、道具、死亡收益、遗物与被动产能都完成后，
	# 同时清空双方共享能量。期限属于战局而非毕方本人，换人、阵亡与转变都不会取消。
	if energy_burn_turn == turn_number:
		events.append({
			id = "h22_energy_burn",
			p1_amount = energy[0],
			p2_amount = energy[1],
		})
		energy = [0, 0]
		energy_burn_turn = -1
	# 沉默还原 + 递减时长（烛阴 h17【镇压】；只递减本回合生效过的，见 Phase 0.3）。
	for sw in _silenced_swap:
		_skills[sw[0]][sw[1]] = sw[2]
		set_status(sw[0], sw[1], "silenced", maxi(0, int(get_status(sw[0], sw[1], "silenced", 0)) - 1))
	# T2 本回合规则件无论是否触发都在此过期；同时清理旧快照可能残留的同名状态。
	for p in [0, 1]:
		for s in range(statuses[p].size()):
			statuses[p][s].erase("marked")
			statuses[p][s].erase("broken_armor")
			statuses[p][s].erase("decoy_hp")
			statuses[p][s].erase("huanhun_ready")
		if int(item_buffs[p].get("switch_lock_until_turn", -1)) <= turn_number:
			item_buffs[p].erase("switch_lock_until_turn")
		item_buffs[p].erase("tianluo_switch_lock_turn")
		item_buffs[p].erase("actual_switches_this_turn")
		item_buffs[p].erase("used_item_slots_this_turn")
		item_buffs[p].erase("countered_item_slots_this_turn")
		item_buffs[p].erase("overflow_energy_to_heal_turn")
		item_buffs[p].erase("energy_overflow_turn")
		item_buffs[p].erase("unconverted_energy_overflow")
		if int(item_buffs[p].get("active_energy_gain_turn", -1)) <= turn_number:
			item_buffs[p].erase("active_energy_gain_turn")
		if int(item_buffs[p].get("energy_gain_lock_turn", -1)) <= turn_number:
			item_buffs[p].erase("energy_gain_lock_turn")
		if int(item_buffs[p].get("free_big_attack_until_turn", -1)) <= turn_number:
			item_buffs[p].erase("free_big_attack_until_turn")
	_resolve_use_or_lock_watches(events)
	_expire_due_item_seals()
	_econ_after_resolve()
	# 聚宝盆必须在已用槽正式清空后看最终空位；补入件从本回合锁定，下回合才可用。
	for p in [0, 1]:
		for relic in relics[p]:
			relic["data"].effect.relic_after_economy(
				self, p, relic["data"], relic["state"], events)
	_last_action = [a[0], a[1]]
	turn_number += 1
	_apply_due_energy_debts(events)
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
		# 标准事件补发（2026-07-17 审计修复）：直写 HP 原本不发 damage_taken/hero_died——
		# UI 演出全靠这两个事件驱动（A3a），缺了=血条突跳、无掉血/死亡演出（"零特判"注释不实）。
		# 不走 _apply_damage（骤死=无视防御/护甲/on-hit·语义就是直扣），只补事件落账。
		if drain > 0:
			events.append({id = "damage_taken", player = 0, slot = oa, amount = drain, src = "overtime", pen = ActionDef.Pen.TRUE_DMG})
			events.append({id = "damage_taken", player = 1, slot = ob, amount = drain, src = "overtime", pen = ActionDef.Pen.TRUE_DMG})
		if hp[0][oa] <= 0:
			events.append({id = "hero_died", player = 0, slot = oa})
		if hp[1][ob] <= 0:
			events.append({id = "hero_died", player = 1, slot = ob})
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
		p1_second_action = second_actions[0], p2_second_action = second_actions[1],
		events = events, game_over = game_over, winner = winner,
		turn = turn_number,
	}
	selected_action = [-1, -1]
	_switch_to = [-1, -1]
	_active_target = [-1, -1]
	_attack_target = [-1, -1]
	_second_action = [-1, -1]
	_second_attack_target = [-1, -1]
	_empowered_wave = [false, false]
	_split_big_wave = [false, false]
	_blood_payment = [false, false]
	_blood_payment_source = [-1, -1]
	_energy_cap_discount = [false, false]
	item_uses = [[], []]
	return result


func _resolve_end_turn_entries(actions: Array[int], events: Array) -> void:
	for player in [0, 1]:
		var entries: Array = item_mod(player, "end_turn_entries", [])
		for target_variant in entries:
			var target: int = int(target_variant)
			if not is_living_reserve(player, target):
				continue
			var from_slot: int = active_index[player]
			var entered: bool = false
			if hp[player][from_slot] <= 0 and pending_death_switch[player]:
				entered = execute_death_switch(player, target)
				if entered:
					# 死亡链已先记录过手选替补提示；候阵签自动完成补位后撤掉过期提示。
					for event_index in range(events.size() - 1, -1, -1):
						var event: Dictionary = events[event_index]
						if String(event.get("id", "")) == "force_switch_prompt" \
								and int(event.get("player", -1)) == player:
							events.remove_at(event_index)
			else:
				_perform_switch(player, from_slot, target, events, true)
				entered = active_index[player] == target
			if entered:
				events.append({id = "houzhen_entry", player = player,
					from = from_slot, to = target})
		set_item_mod(player, "end_turn_entries", [])
	# 登场/离场技能、换防扣、夜明珠或对手的切换惩罚都可能再制造死亡。
	_resolve_deaths(actions, events)


func _resolve_use_or_lock_watches(events: Array) -> void:
	for source_player in [0, 1]:
		for watch_variant in item_mod(source_player, "use_or_lock_watches", []):
			var watch: Dictionary = watch_variant
			var target_player: int = int(watch.get("target_player", -1))
			var slot_index: int = int(watch.get("slot", -1))
			if target_player < 0 or slot_index < 0 or slot_index >= slots[target_player].size():
				continue
			var used_slots: Array = item_buffs[target_player].get("used_item_slots_this_turn", [])
			if used_slots.has(slot_index):
				continue
			var slot: Dictionary = slots[target_player][slot_index]
			var current: ItemData = slot.get("item", null)
			if current == null or current.item_id != String(watch.get("item_id", "")):
				continue
			var watched_uid: int = int(watch.get("instance_uid", -1))
			if watched_uid >= 0 and int(slot.get("instance_uid", -1)) != watched_uid:
				continue
			slot["state"] = SlotState.CHARGING
			slot["since"] = turn_number + 1
			slot["used"] = false
			events.append({id = "item_use_or_locked", player = target_player,
				source_player = source_player, slot = slot_index,
				item_id = current.item_id})


## 把一个英雄槽位的“英雄本体状态”拍成独立快照。HeroData 深拷，避免转变方与敌方共享可变资源。
func _snapshot_hero_runtime(player: int, slot: int) -> Dictionary:
	return {
		hero = (heroes[player][slot] as HeroData).duplicate(true),
		hp = hp[player][slot],
		max_hp = max_hp[player][slot],
		shield = shield[player][slot],
		pending_damage = pending_damage[player][slot],
		statuses = (statuses[player][slot] as Dictionary).duplicate(true),
		death_processed = _death_processed[player][slot],
		killer = _killer[player][slot],
	}


## 将英雄本体快照写入既有槽位；不触发登场/离场 hook，因为“转变”不是切换。
func _apply_hero_runtime_snapshot(player: int, slot: int, snapshot: Dictionary) -> void:
	var copied_hero: HeroData = snapshot["hero"] as HeroData
	heroes[player][slot] = copied_hero
	hp[player][slot] = int(snapshot["hp"])
	max_hp[player][slot] = int(snapshot["max_hp"])
	shield[player][slot] = int(snapshot["shield"])
	pending_damage[player][slot] = int(snapshot["pending_damage"])
	statuses[player][slot] = (snapshot["statuses"] as Dictionary).duplicate(true)
	_death_processed[player][slot] = bool(snapshot["death_processed"])
	_killer[player][slot] = int(snapshot["killer"])
	_skills[player][slot] = _make_skill(copied_hero.hero_id)


## 英雄费用唯一结算口。血量支付是费用而非伤害：不吃护甲、不触发 damage/on-hit，
## 即使前置延迟伤害令生命不足，也最多扣至 0；已提交的本轮行动继续完成。
func _pay_action_cost(player: int, amount: int, events: Array) -> void:
	if amount <= 0:
		return
	if _blood_payment[player]:
		var slot: int = _blood_payment_source[player]
		if slot < 0 or slot >= hp[player].size():
			push_warning("BattleCore: h14 血量支付缺少合法付款槽，退回团队能量")
			energy[player] -= amount
			return
		var paid: int = mini(hp[player][slot], amount)
		if _consume_fatal_damage_immunity(player, slot, amount, events):
			paid = 0
		else:
			hp[player][slot] = maxi(0, hp[player][slot] - amount)
		events.append({id = "h14_blood_payment", player = player, slot = slot, amount = paid})
	else:
		energy[player] -= amount


func _do_switch(player: int, events: Array) -> void:
	_perform_switch(player, active_index[player], _switch_to[player], events, true)


## 执行切换：离场 hook → 对手 on_enemy_switch_out（h11 穷追）→ 改 active → 入场 hook。
## _do_switch（动作槽切换）与 free_switch（h07 免费切）共用。
func _perform_switch(player: int, from_slot: int, to_slot: int, events: Array,
		trigger_item_relics: bool = false) -> void:
	if _turn_switch_locked(player):
		events.append({id = "switch_locked", player = player})
		return
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
	clear_vulnerability(player, from_slot)   # 脆弱随出战英雄换下场清除，并同步清理罪已昭期限
	events.append({id = "switch", player = player, from_to = [from_slot, to_slot]})
	var switches: Array = item_buffs[player].get("actual_switches_this_turn", [])
	switches.append({from = from_slot, to = to_slot})
	item_buffs[player]["actual_switches_this_turn"] = switches
	_resolve_switch_item_effects(player, from_slot, to_slot, events)

	# 回马枪只认实际完成的「切换」：被定身取消的切换不触发；免费/强制/追击切换均触发。
	var return_spear_bonus: int = int(item_mod(player, "switch_next_atk_total_bonus", 0))
	if return_spear_bonus > 0:
		item_buffs[player]["next_atk_total_bonus"] = int(
			item_buffs[player].get("next_atk_total_bonus", 0)) + return_spear_bonus
		set_item_mod(player, "switch_next_atk_total_bonus", 0)
	# 替身草人只认实际完成的切换，并令敌方本回合整次基础攻击落空。
	if int(item_mod(player, "caoren_switch_guard", 0)) > 0:
		set_item_mod(player, "caoren_switch_guard", 0)
		set_item_mod(1 - player, "atk_nullify", true)

	var entering: HeroSkill = _skills[player][to_slot]
	if entering != null:
		entering.on_switch_in(self, player, to_slot)

	# 遗物·登场 hook：本方遗物在此响应"切换登场"（夜明珠 = 登场者攻击加成 + 登场冲撞）。A4：由 core 硬编码搬入遗物 effect。
	if trigger_item_relics:
		for relic in relics[player]:
			relic["data"].effect.relic_on_switch_in(
				self, player, to_slot, relic["data"], relic["state"], events)


func _resolve_switch_item_effects(player: int, from_slot: int, to_slot: int,
		events: Array) -> void:
	var armor: int = int(item_mod(player, "switch_in_shield", 0))
	if armor > 0 and hp[player][to_slot] > 0:
		shield[player][to_slot] += armor
	var trap: Dictionary = item_mod(player, "switch_out_trap", {})
	var trap_damage: int = int(trap.get("damage", 0))
	if trap_damage > 0 and hp[player][from_slot] > 0:
		var source_player: int = int(trap.get("source_player", 1 - player))
		_apply_damage(player, trap_damage, source_player, ActionDef.Action.ATTACK,
			ActionDef.Pen.NORMAL, ActionDef.Action.CHARGE, events, [], "item", -1,
			from_slot)
		events.append({id = "switch_out_trap", player = player, slot = from_slot,
			amount = trap_damage, source_player = source_player})
	var return_heal: int = int(item_buffs[player].get("return_camp_heal", 0))
	if return_heal > 0:
		item_buffs[player].erase("return_camp_heal")
		var healed: int = 0
		if hp[player][from_slot] > 0:
			healed = _heal(player, from_slot, return_heal)
		events.append({id = "return_camp_heal", player = player, slot = from_slot,
			amount = healed})


## 只处理道具揭示前已完成的免费切换；后续付费/强制/追击切换在 _perform_switch 即时处理。
func _resolve_retroactive_switch_items(events: Array) -> void:
	for player in [0, 1]:
		for switch_variant in item_buffs[player].get("actual_switches_this_turn", []):
			var switch_data: Dictionary = switch_variant
			_resolve_switch_item_effects(player, int(switch_data.get("from", -1)),
				int(switch_data.get("to", -1)), events)


## h07 千里自在风：每回合一次免费切换（不占动作槽）。在【选择阶段】调用。
## 选择期只登记 from→to 意图并更新 active_index 供 UI/动作合法性预览，不执行任何切换 hook；
## 双方保护性道具揭示后，未被天罗锁住才由 _settle_pending_free_switches 原子提交全部副作用。
## 二元设计："涉及马的切换"都免动作槽 = 起点（马在场→重定位下场）或终点（顶马上场）任一为星日即免费。

## 指定槽位的英雄当前能否提供免费切换（has_free_switch + 该英雄 cap 未满）。
func _grants_free_switch(player: int, slot: int) -> bool:
	var sk: HeroSkill = _skills[player][slot]
	if sk == null or not sk.has_free_switch():
		return false
	var cap: int = sk.free_switch_cap()
	var uses_this_turn: int = free_switch_uses[player] \
		if free_switch_usage_turn[player] == turn_number else 0
	if cap >= 0 and uses_this_turn >= cap:
		return false
	return true


## 切换到 target 是否免动作槽：起点（出战）或终点（target）任一英雄提供免费切换 → true 走 free_switch。
func is_free_switch_target(player: int, target: int) -> bool:
	if not _can_switch(player):
		return false
	if target < 0 or target >= hp[player].size() or target == active_index[player] or hp[player][target] <= 0:
		return false
	return _grants_free_switch(player, active_index[player]) or _grants_free_switch(player, target)


func free_switch(player: int, target: int) -> bool:
	if not is_free_switch_target(player, target):
		return false
	# cap 由提供免费切换的英雄决定，但次数记在本方回合状态上，避免多个复制体绕过“每回合一次”。
	var from_slot: int = active_index[player]
	var grantor: int = from_slot if _grants_free_switch(player, from_slot) else target
	var usage_turn_before: int = free_switch_usage_turn[player]
	var uses_before: int = free_switch_uses[player]
	var blood_payment_source_before: int = _blood_payment_source[player]
	if free_switch_usage_turn[player] != turn_number:
		free_switch_usage_turn[player] = turn_number
		free_switch_uses[player] = 0
	if _skills[player][grantor].free_switch_cap() >= 0:
		free_switch_uses[player] += 1
	_pending_free_switches[player].append({
		from = from_slot,
		to = target,
		usage_turn_before = usage_turn_before,
		uses_before = uses_before,
		blood_payment_source_before = blood_payment_source_before,
	})
	active_index[player] = target
	return true


## 星日登场冲撞：对敌方出战造成 0.5 独立伤害；走护甲/受伤管线，但不算命中。
## 用 PIERCE_BIGDEF 让冲撞无视防御直接连接（登场突袭）；事件用本地数组（不并入 resolve 事件流）。
func chongzhuang(attacker_player: int) -> void:
	var opp: int = 1 - attacker_player
	if hp[opp][active_index[opp]] <= 0:
		return
	var ev: Array = []
	_apply_damage(opp, CHONGZHUANG_DAMAGE, attacker_player, ActionDef.Action.ATTACK, ActionDef.Pen.PIERCE_BIGDEF, ActionDef.Action.CHARGE, ev)


## 返回除 excluded_slot 外当前生命最高的存活英雄。并列时保留槽位较小者，避免随机数导致
## 联机、录像与 AI 推演分歧。
func _highest_hp_living_other(player: int, excluded_slot: int) -> int:
	var target: int = -1
	var highest_hp: int = -1
	for slot in range(hp[player].size()):
		if slot == excluded_slot or hp[player][slot] <= 0:
			continue
		if hp[player][slot] > highest_hp:
			highest_hp = hp[player][slot]
			target = slot
	return target


## 施加一段已经完成增伤/减伤计算的转移伤害。它不再进入伤害修正管线，避免凭空增伤；
## 但仍单独经过目标护甲、致死免疫与受伤回调。
func _apply_exact_transferred_damage(target_player: int, target_slot: int, amount: int,
		attacker_player: int, events: Array, src: String) -> int:
	if amount <= 0 or target_slot < 0 or target_slot >= hp[target_player].size() \
			or hp[target_player][target_slot] <= 0:
		return 0
	var remaining: int = amount
	var projected_hp_damage: int = maxi(0, remaining - shield[target_player][target_slot])
	if _consume_fatal_damage_immunity(target_player, target_slot, projected_hp_damage, events):
		return 0
	var total_dealt: int = 0
	if shield[target_player][target_slot] > 0:
		var absorbed: int = mini(shield[target_player][target_slot], remaining)
		shield[target_player][target_slot] -= absorbed
		remaining -= absorbed
		total_dealt += absorbed
		events.append({id = "shield_absorb", player = target_player, slot = target_slot,
			amount = absorbed})
	# 兼容仍在旧快照中的旧还魂状态；与主伤害段保持同一结算语义。
	if remaining > 0 and remaining >= hp[target_player][target_slot] \
			and int(get_status(target_player, target_slot, "huanhun_ready", 0)) > 0:
		var leave_hp: int = mini(hp[target_player][target_slot], int(
			get_status(target_player, target_slot, "huanhun_ready", 0)))
		set_status(target_player, target_slot, "huanhun_ready", 0)
		remaining = maxi(0, hp[target_player][target_slot] - leave_hp)
		events.append({id = "huanhun_revive", player = target_player, slot = target_slot})
	if remaining <= 0:
		return total_dealt
	hp[target_player][target_slot] -= remaining
	total_dealt += remaining
	events.append({id = "damage_taken", player = target_player, slot = target_slot,
		amount = remaining, src = src, pen = ActionDef.Pen.NORMAL})
	var skill: HeroSkill = _skills[target_player][target_slot]
	if skill != null:
		skill.on_self_damaged(self, target_player, target_slot, remaining, attacker_player)
	if hp[target_player][target_slot] <= 0:
		_killer[target_player][target_slot] = attacker_player
	return total_dealt


## resolve Phase 3+4 的单条 hit 公共施加器：保留伤害来源、出手槽快照与攻击型主动技回调。
func _apply_resolve_hit(attacker_player: int, hit: Dictionary, actions: Array[int], events: Array,
		base_context: Dictionary = {}) -> int:
	var riders: Array = hit.get("riders", [])
	var source: String = "action" if bool(hit.get("action", false)) else "item"
	var is_base_attack: bool = bool(hit.get("action", false)) and not bool(hit.get("active", false))
	var source_slot: int = int(hit.get("src_slot", -1))
	var target_slot: int = int(hit.get("target_slot", -1))
	if is_base_attack:
		if bool(hit.get("consume_true_damage", false)):
			set_item_mod(attacker_player, "next_base_attack_true_damage", false)
		base_context["executed"] = true
		if int(base_context.get("source_slot", -1)) < 0:
			base_context["source_slot"] = source_slot
	var outcome: Dictionary = {}
	var dealt: int = _apply_damage(
		1 - attacker_player,
		int(hit["damage"]),
		attacker_player,
		int(hit["kind"]),
		int(hit["pen"]),
		actions[1 - attacker_player],
		events,
		riders,
		source,
		source_slot,
		target_slot,
		is_base_attack,
		outcome,
		int(hit.get("whole_attack_extra_hits", 0)),
		bool(hit.get("force_zero_damage", false)))
	if is_base_attack:
		base_context["target_slot"] = int(outcome.get("target_slot", target_slot))
		base_context["connected"] = bool(base_context.get("connected", false)) \
			or bool(outcome.get("connected", false))
		base_context["raw_damage_total"] = int(base_context.get("raw_damage_total", 0)) \
			+ int(outcome.get("raw_damage", hit.get("damage", 0)))
		base_context["damage_total"] = int(base_context.get("damage_total", 0)) \
			+ int(outcome.get("damage_total", dealt))
		base_context["hp_damage_total"] = int(base_context.get("hp_damage_total", 0)) + dealt
		base_context["blocked"] = bool(base_context.get("blocked", false)) \
			or bool(outcome.get("blocked", false))
		base_context["blocked_by_big_defend"] = bool(
			base_context.get("blocked_by_big_defend", false)) \
			or bool(outcome.get("blocked_by_big_defend", false))
		base_context["target_defeated"] = bool(base_context.get("target_defeated", false)) \
			or bool(outcome.get("defeated", false))
	if bool(hit.get("active", false)):
		var skill_slot: int = source_slot if source_slot >= 0 else active_index[attacker_player]
		var skill: HeroSkill = _skills[attacker_player][skill_slot]
		if skill != null and skill.active_is_attack():
			skill.on_active_attack_resolved(self, attacker_player, skill_slot, dealt)
	return dealt


## 计算 player 本次攻击的造成伤害（半点）。
## 出伤 = 基础 → 双方出战英雄的战场修正 → 出手英雄 modify_outgoing_damage
##   → 全队 modify_team_outgoing_damage（团队层 buff）。
func _calc_outgoing(player: int, action: int) -> int:
	var slot: int = active_index[player]
	var dmg: int = _apply_battlefield_base_attack_damage(
		ActionDef.get_base_damage(action), action, player, slot)
	var skill: HeroSkill = _skills[player][slot]
	if skill != null:
		dmg = skill.modify_outgoing_damage(dmg, action, self, player, slot)
	return _apply_team_outgoing(dmg, action, player, slot)


## 对称战场规则只读取当前出战位。resolve 的沉默阶段会把失效技能临时置 null；切换、
## 强制换位与转变均早于 hit-list 构建，因此这里自然读取最终出战快照，不新增局内状态。
func _apply_battlefield_base_attack_damage(dmg: int, action: int,
		attacker_player: int, attacker_slot: int) -> int:
	for field_player: int in [0, 1]:
		var field_slot: int = active_index[field_player]
		var field_skill: HeroSkill = _skills[field_player][field_slot]
		if field_skill != null and hp[field_player][field_slot] > 0:
			dmg = field_skill.modify_battlefield_base_attack_damage(
				dmg, action, self, attacker_player, attacker_slot, field_player, field_slot)
	return dmg


## 团队层出伤修正：扫攻击方全队（含替补），让团队 buff 源生效（modify_team_outgoing_damage hook）。
## 基础攻击与攻击型主动技命中前都会过本管线。attacker_slot = 发起攻击的出战英雄槽。
func _apply_team_outgoing(dmg: int, action: int, player: int, attacker_slot: int) -> int:
	for s in range(heroes[player].size()):
		var tsk: HeroSkill = _skills[player][s]
		if tsk != null:
			dmg = tsk.modify_team_outgoing_damage(dmg, action, self, player, attacker_slot, player, s)
	return dmg


## 技能/反击类「管线打击」公共入口：走完整 _apply_damage，但不算「波／大波」命中。
## def_action=CHARGE 视作不可挡；仍经过护甲与受伤链，不引爆毒素、不触发命中技能。
func strike(target_player: int, raw: int, attacker_player: int, pen: int, events: Array = []) -> int:
	return _apply_damage(target_player, raw, attacker_player, ActionDef.Action.ATTACK, pen, ActionDef.Action.CHARGE, events)


## 伤害管线 (§D4)：防御门 → 大波命中时引爆毒素 → 受伤 hook(平减) → 护甲 → 落 HP → on-hit 触发。
## 返回实际落在 HP 上的伤害（半点），供攻击型主动技回调使用。
## src = 本次伤害的来源标签（"action"=动作攻击/技能·"item"=独立道具伤害）。
## 只有 is_base_attack=true 的「波／大波」穿过防御门后才算命中并结算命中效果；
## 护甲吸收仍算命中，主动技、追击、反击和独立道具伤害均不算。
## attacker_slot = 出手英雄槽（hit 生成时的快照值·-1=用实时出战位）。结算期间 active_index
## 可能变化，on-hit 归因必须钉在出招英雄身上，否则先后手不对称（2026-07-17 审计修复）。
## 周天罡气（t3_yiqi·2026-07-04 重做）：该方本回合是否"无敌"——免疫一切【敌源】伤害
## （动作攻击/道具直伤/延迟灼烧/溅射/穷追/冲撞/死亡反击）。规则处决与自付代价
## （力量的代价、h14 生命支付）不算"受到伤害"、不拦。
func damage_immune(player: int) -> bool:
	return int(item_mod(player, "damage_immune", 0)) > 0


## 还魂丹是最低层保险：任何一次致命伤害、生命支付、失去生命或规则处决整次归零。
## 伤害路径仍通过命中阶段；本函数只消费已登记的一次保险。
func _consume_fatal_damage_immunity(target_player: int, slot: int, hp_damage: int,
		events: Array) -> bool:
	var charges: int = int(get_status(target_player, slot, "fatal_damage_immunity", 0))
	if hp[target_player][slot] <= 0 or hp_damage <= 0 \
			or hp_damage < hp[target_player][slot] or charges <= 0:
		return false
	set_status(target_player, slot, "fatal_damage_immunity", charges - 1)
	events.append({id = "huanhun_fatal_immunity", player = target_player, slot = slot})
	return true


func _apply_damage(target_player: int, raw: int, attacker_player: int, atk_action: int, pen: int,
		def_action: int, events: Array, item_riders: Array = [], src: String = "action",
		attacker_slot: int = -1, target_slot: int = -1, is_base_attack: bool = false,
		outcome: Dictionary = {}, whole_attack_extra_hits: int = 0,
		force_zero_damage: bool = false) -> int:
	outcome["connected"] = false
	outcome["defeated"] = false
	outcome["damage_total"] = 0
	outcome["raw_damage"] = maxi(raw, 0)
	outcome["blocked"] = false
	outcome["blocked_by_big_defend"] = false
	var slot: int = active_index[target_player]
	if target_slot >= 0:
		if target_slot >= hp[target_player].size() or hp[target_player][target_slot] <= 0:
			events.append({id = "attack_target_unavailable", player = target_player, slot = target_slot})
			return 0
		slot = target_slot
	outcome["target_slot"] = slot

	# 周天罡气：无敌方本回合所有指向性伤害事件整个不发生（含附带 on-hit·同"落空"语义）
	if damage_immune(target_player):
		events.append({id = "damage_immune", player = target_player, slot = slot})
		return 0

	# 分痛木牌：只分流敌源伤害；生命支付、失去生命与规则处决不经过本入口。
	# 分流发生在防御与护甲前，原目标仍按本次波/大波是否穿过防御来判定命中。
	var redirected_damage: int = 0
	var redirect_target: int = -1
	var redirect_pool: int = int(item_mod(target_player, "next_damage_redirect", 0))
	if raw > 0 and redirect_pool > 0:
		var highest_hp: int = -1
		for ally_slot in range(hp[target_player].size()):
			if ally_slot == slot or hp[target_player][ally_slot] <= 0:
				continue
			if hp[target_player][ally_slot] > highest_hp:
				highest_hp = hp[target_player][ally_slot]
				redirect_target = ally_slot
		if redirect_target >= 0:
			redirected_damage = mini(raw, redirect_pool)
			raw -= redirected_damage
	if force_zero_damage:
		redirected_damage = 0
		redirect_target = -1

	# Stage B4: 防御动作门（大防挡全部；防挡波，不挡大波/穿防攻击）
	var eff_def: int = def_action
	var defense_step_down: int = int(item_mod(target_player, "defense_step_down", 0))
	for _step in range(defense_step_down):
		if eff_def == ActionDef.Action.BIG_DEFEND:
			eff_def = ActionDef.Action.DEFEND
		elif eff_def == ActionDef.Action.DEFEND:
			eff_def = -1
	if defense_step_down > 0 and def_action in ActionDef.DEFEND_ACTIONS:
		events.append({id = "defense_step_down", player = target_player, slot = slot})
	var broken: int = int(get_status(target_player, slot, "broken_armor", 0))
	if broken > 0 and def_action in ActionDef.DEFEND_ACTIONS:
		set_status(target_player, slot, "broken_armor", broken - 1)
		eff_def = ActionDef.Action.DEFEND if def_action == ActionDef.Action.BIG_DEFEND else -1
		events.append({id = "armor_broken", player = target_player, slot = slot})
	# 魔法气泡：本回合"防"临时升级为可挡大波一次（条件=对手大波·已在 apply_pre 校验）
	if eff_def == ActionDef.Action.DEFEND and is_base_attack \
			and atk_action == ActionDef.Action.BIG_ATTACK \
			and int(item_mod(target_player, "def_upgrade", 0)) > 0:
		set_item_mod(target_player, "def_upgrade", int(item_mod(target_player, "def_upgrade", 0)) - 1)
		eff_def = ActionDef.Action.BIG_DEFEND
	var blocked: bool = false
	if pen == ActionDef.Pen.TRUE_DMG or pen == ActionDef.Pen.PIERCE_BIGDEF:
		blocked = false
	elif pen == ActionDef.Pen.PIERCE_DEF:
		blocked = eff_def == ActionDef.Action.BIG_DEFEND
	else:
		blocked = eff_def == ActionDef.Action.BIG_DEFEND or eff_def == ActionDef.Action.DEFEND
	# 当前行动的防御优先：鬼金本回合的大防已实际挡到基础攻击，就不转为团队状态。
	if blocked and is_base_attack and def_action == ActionDef.Action.BIG_DEFEND:
		_retain_big_defend_candidate[target_player] = false
	var retained_block: bool = false
	if not blocked and is_base_attack \
			and (has_retained_big_defend(target_player) or _retained_big_defend_in_use[target_player]) \
			and pen != ActionDef.Pen.TRUE_DMG and pen != ActionDef.Pen.PIERCE_BIGDEF:
		blocked = true
		eff_def = ActionDef.Action.BIG_DEFEND
		retained_block = true
		if retained_big_defend[target_player]:
			retained_big_defend[target_player] = false
			retained_big_defend_until_turn[target_player] = -1
			_retained_big_defend_in_use[target_player] = true
			events.append({id = "buzhui_shenyan_consumed", player = target_player, slot = slot})
	if blocked:
		# 被防御动作挡下时没有伤害发生，分痛木牌不消费。
		redirected_damage = 0
		outcome["blocked"] = true
		outcome["blocked_by_big_defend"] = eff_def == ActionDef.Action.BIG_DEFEND
		events.append({id = ("big_defend_block" if eff_def == ActionDef.Action.BIG_DEFEND else "defend_block"),
			player = target_player, slot = slot, kind = atk_action, src = src, retained = retained_block})
		# 魔力源泉：防御成功 → +能量（每回合一次）
		var be: int = int(item_mod(target_player, "block_energy", 0))
		if is_base_attack and be > 0:
			set_item_mod(target_player, "block_energy", 0)
			_gain_energy(target_player, be)
		# 不动明王甲：防御成功 → +HP（每回合一次）
		var bh: int = int(item_mod(target_player, "block_heal", 0))
		if bh > 0:
			set_item_mod(target_player, "block_heal", 0)
			_heal(target_player, slot, bh)
		# 暖玉严格只认「防/大防」完整挡住基础攻击；成功后治疗全队存活英雄一次。
		var warm_heal: int = int(item_mod(target_player, "t2_block_team_heal", 0))
		if is_base_attack and def_action in ActionDef.DEFEND_ACTIONS and warm_heal > 0:
			set_item_mod(target_player, "t2_block_team_heal", 0)
			for ally_slot in range(hp[target_player].size()):
				if hp[target_player][ally_slot] > 0:
					_heal(target_player, ally_slot, warm_heal)
		var dsk: HeroSkill = _skills[target_player][slot]
		if dsk != null:
			dsk.on_block(self, target_player, slot, attacker_player, atk_action, def_action, raw, src)
		return 0

	if redirected_damage > 0:
		set_item_mod(target_player, "next_damage_redirect", 0)
	outcome["connected"] = true
	var dmg := raw
	# Stage B3a: 毒素只由「大波」穿过防御门时引爆；波、独立道具、主动技与追击均不引爆。
	var poison: int = int(get_status(target_player, slot, "poison", 0))
	if poison > 0 and is_base_attack and atk_action == ActionDef.Action.BIG_ATTACK:
		dmg += poison
		# 遗物·毒爆 hook：本方遗物在此追加毒爆伤害（鹤顶红 = +1.0）。A4：由 core 硬编码搬入遗物 effect。
		for relic in relics[attacker_player]:
			dmg += relic["data"].effect.relic_poison_detonate_bonus(
				self, attacker_player, poison, relic["data"], relic["state"], events)
		statuses[target_player][slot].erase("poison")
		events.append({id = "poison_detonate", player = target_player, slot = slot, layers = poison})
	# 兼容旧消耗式攻击印记：只放大一次整次基础攻击，不作用主动技或独立道具伤害。
	var marks: Dictionary = item_mod(target_player, "base_attack_marks", {})
	var attack_mark: int = int(marks.get(slot, 0)) if is_base_attack else 0
	if attack_mark > 0:
		dmg += attack_mark
		marks.erase(slot)
		events.append({id = "marked_hit", player = target_player, slot = slot, amount = attack_mark})
	# 兼容旧快照中的消耗式 marked；回合末无论是否触发都会清理。
	var marked: int = int(get_status(target_player, slot, "marked", 0))
	if marked > 0:
		dmg += marked
		statuses[target_player][slot].erase("marked")
		events.append({id = "marked_hit", player = target_player, slot = slot, amount = marked})
	# 罪已昭（触邪 h20·限时脆弱）：目标受到的伤害 +N（不消耗；到期或换下场清）。
	var vuln: int = int(get_status(target_player, slot, "vuln", 0))
	if vuln > 0:
		dmg += vuln
		events.append({id = "vuln_hit", player = target_player, slot = slot, amount = vuln})

	# Stage B5: 受伤 hook（平减；沉默 h15 时跳过）
	var skill: HeroSkill = _skills[target_player][slot]
	if skill != null:
		dmg = skill.modify_incoming_damage(dmg, atk_action, self, target_player, slot, attacker_player)
	dmg = maxi(dmg, 0)
	# 偏锋甲不是防御：波仍穿过防御门并结算命中技能，但整次攻击最终不造成伤害。
	if force_zero_damage and is_base_attack:
		dmg = 0
	# 分寸尺按整次基础攻击共用一个预算；毒素、脆弱与英雄减伤都先结算，再封顶。
	if is_base_attack and int(item_mod(attacker_player, "base_attack_damage_cap", -1)) >= 0:
		var cap_remaining: int = maxi(0, int(item_mod(
			attacker_player, "base_attack_damage_cap_remaining", 0)))
		dmg = mini(dmg, cap_remaining)
		set_item_mod(attacker_player, "base_attack_damage_cap_remaining",
			maxi(0, cap_remaining - dmg))
	# 乌骓 h19：在所有增伤/减伤完成后拆分最终伤害，主目标封顶，余量守恒转移。
	# 出手槽使用命中快照；沉默或“禁用命中英雄技能”时不启用该接口。
	var aslot: int = attacker_slot if attacker_slot >= 0 else active_index[attacker_player]
	var atk_skill: HeroSkill = _skills[attacker_player][aslot]
	var suppress_hit_skills: bool = is_base_attack and bool(item_mod(
		attacker_player, "hit_hero_skills_suppressed", false))
	var excess_transfer_damage: int = 0
	var excess_transfer_target: int = -1
	if is_base_attack and not suppress_hit_skills and atk_skill != null:
		var transfer_threshold: int = atk_skill.base_attack_excess_transfer_threshold(
			atk_action, self, attacker_player, aslot)
		if transfer_threshold > 0 and dmg > transfer_threshold:
			excess_transfer_damage = dmg - transfer_threshold
			dmg = transfer_threshold
			excess_transfer_target = _highest_hp_living_other(target_player, slot)

	# Stage B6: 护甲。还魂丹在实际扣盾前按“本次会否致命”判定，触发时整次伤害归零。
	var shield_damage := 0
	var dealt: int = 0
	var was_alive: bool = hp[target_player][slot] > 0
	var share_attack: bool = is_base_attack and slot == active_index[target_player] \
		and bool(item_mod(target_player, "share_next_base_attack", false))
	if share_attack and dmg > 0:
		var shared: Dictionary = _apply_shared_attack_damage(
			target_player, dmg, attacker_player, pen, events, src, slot)
		shield_damage = int(shared.get("shield_damage", 0))
		dealt = int(shared.get("hp_damage", 0))
		outcome["defeated"] = bool(shared.get("primary_defeated", false))
	else:
		var ignores_shield: bool = pen == ActionDef.Pen.TRUE_DMG \
			or bool(item_mod(attacker_player, "pierce_armor", false))
		var projected_hp_damage: int = dmg if ignores_shield else maxi(
			0, dmg - shield[target_player][slot])
		if _consume_fatal_damage_immunity(target_player, slot, projected_hp_damage, events):
			dmg = 0
		if dmg > 0 and not ignores_shield and shield[target_player][slot] > 0:
			var absorbed: int = mini(shield[target_player][slot], dmg)
			shield[target_player][slot] -= absorbed
			dmg -= absorbed
			shield_damage = absorbed
			events.append({id = "shield_absorb", player = target_player, slot = slot,
				amount = absorbed})
		# 兼容仍在内存/旧测试夹具中的旧还魂状态；正式还魂丹只写 fatal_damage_immunity。
		if dmg > 0 and dmg >= hp[target_player][slot] \
				and int(get_status(target_player, slot, "huanhun_ready", 0)) > 0:
			var leave_hp: int = mini(hp[target_player][slot], int(
				get_status(target_player, slot, "huanhun_ready", 0)))
			set_status(target_player, slot, "huanhun_ready", 0)
			dmg = maxi(0, hp[target_player][slot] - leave_hp)
			events.append({id = "huanhun_revive", player = target_player, slot = slot})
		if dmg > 0:
			hp[target_player][slot] -= dmg
			dealt = dmg
			events.append({id = "damage_taken", player = target_player, slot = slot,
				amount = dmg, src = src, pen = pen})
			var dsk2: HeroSkill = _skills[target_player][slot]
			if dsk2 != null:
				dsk2.on_self_damaged(self, target_player, slot, dealt, attacker_player)
			if hp[target_player][slot] <= 0:
				_killer[target_player][slot] = attacker_player
				outcome["defeated"] = was_alive
	outcome["damage_total"] = shield_damage + dealt
	if excess_transfer_damage > 0 and excess_transfer_target >= 0:
		var transferred_dealt: int = _apply_exact_transferred_damage(
			target_player, excess_transfer_target, excess_transfer_damage,
			attacker_player, events, "h19_transfer")
		outcome["damage_total"] = int(outcome["damage_total"]) + transferred_dealt
		events.append({id = "h19_damage_transferred", player = target_player, from = slot,
			to = excess_transfer_target, amount = excess_transfer_damage,
			actual = transferred_dealt})
	if redirected_damage > 0 and hp[target_player][redirect_target] > 0:
		var redirected_outcome: Dictionary = {}
		_apply_damage(target_player, redirected_damage, attacker_player, atk_action, pen,
			ActionDef.Action.CHARGE, events, [], "item", attacker_slot, redirect_target,
			false, redirected_outcome)
		outcome["damage_total"] = int(outcome["damage_total"]) \
			+ int(redirected_outcome.get("damage_total", 0))
		events.append({id = "damage_redirected", player = target_player, from = slot,
			to = redirect_target, amount = redirected_damage})

	# Stage B10: on-hit 触发（穿过防御门即算命中，按 hit_count 次；含队友监听如鸡剑气）。
	# 出手槽优先用 hit 快照值（attacker_slot≥0），不随结算期间的实时出战位漂移。
	if is_base_attack and not suppress_hit_skills:
		_queue_reserve_pursuit(attacker_player, aslot, slot)
	if is_base_attack and not suppress_hit_skills and atk_skill != null:
		atk_skill.on_base_attack_damage_dealt(
			self, attacker_player, aslot, target_player, slot, dealt, atk_action, events)
	if is_base_attack and not suppress_hit_skills:
		var hc: int = 1
		if atk_skill != null:
			hc = maxi(1, atk_skill.hit_count(atk_action, self, attacker_player, aslot))
		# T3 聚鼎三花维持逐段 extra_hits；T2 双生只把整次攻击的额外次数放在第一段。
		hc += int(item_mod(attacker_player, "extra_hits", 0)) + whole_attack_extra_hits
		for _h in range(hc):
			if atk_skill != null:
				atk_skill.on_deal_hit(self, attacker_player, aslot, target_player, slot, dealt, atk_action)
			for s2 in range(heroes[attacker_player].size()):
				var tsk: HeroSkill = _skills[attacker_player][s2]
				if tsk != null:
					tsk.on_team_deal_hit(self, attacker_player, s2, aslot, target_player, slot, dealt)
	# 道具骑乘（扭曲的饥渴/充能护手）：使用者本回合基础攻击命中时触发。
	for rider in item_riders:
		rider.effect.on_attack_connect(self, attacker_player, target_player, slot, dealt, rider)
	return dealt


## 连心锁：把一段已经穿过防御、完成状态/减伤计算的基础攻击伤害，按半点轮流分给存活英雄。
## 双段攻击共用 cursor，故不可整除的半点会继续轮转，不会每段都偏向出战位。
func _apply_shared_attack_damage(target_player: int, total: int, attacker_player: int,
		pen: int, events: Array, src: String, primary_slot: int) -> Dictionary:
	var living: Array[int] = living_heroes(target_player)
	if living.is_empty() or total <= 0:
		return {shield_damage = 0, hp_damage = 0, primary_defeated = false}
	var allocations: Dictionary = {}
	var cursor: int = posmod(int(item_mod(target_player, "shared_damage_cursor", 0)), living.size())
	for unit in range(total):
		var slot: int = living[(cursor + unit) % living.size()]
		allocations[slot] = int(allocations.get(slot, 0)) + 1
	set_item_mod(target_player, "shared_damage_cursor", (cursor + total) % living.size())
	var shield_total: int = 0
	var hp_total: int = 0
	var primary_was_alive: bool = hp[target_player][primary_slot] > 0
	var ignores_shield: bool = pen == ActionDef.Pen.TRUE_DMG \
		or bool(item_mod(attacker_player, "pierce_armor", false))
	for slot_variant in allocations:
		var slot: int = int(slot_variant)
		var amount: int = int(allocations[slot_variant])
		var projected: int = amount if ignores_shield else maxi(
			0, amount - shield[target_player][slot])
		if _consume_fatal_damage_immunity(target_player, slot, projected, events):
			continue
		if not ignores_shield and shield[target_player][slot] > 0:
			var absorbed: int = mini(shield[target_player][slot], amount)
			shield[target_player][slot] -= absorbed
			amount -= absorbed
			shield_total += absorbed
			events.append({id = "shield_absorb", player = target_player, slot = slot,
				amount = absorbed})
		if amount <= 0:
			continue
		hp[target_player][slot] -= amount
		hp_total += amount
		events.append({id = "damage_taken", player = target_player, slot = slot,
			amount = amount, src = src, pen = pen})
		var skill: HeroSkill = _skills[target_player][slot]
		if skill != null:
			skill.on_self_damaged(self, target_player, slot, amount, attacker_player)
		if hp[target_player][slot] <= 0:
			_killer[target_player][slot] = attacker_player
	return {
		shield_damage = shield_total,
		hp_damage = hp_total,
		primary_defeated = primary_was_alive and hp[target_player][primary_slot] <= 0,
	}


## 结算到期的团队级定时道具效果。妖火只检查截止时是否仍为出战英雄；
## 失去生命不经过伤害/护甲管线，但保留敌方来源供“被敌方击败”判定。
func _resolve_timed_item_effects(events: Array) -> void:
	for target_player in [0, 1]:
		var kept: Array = []
		for effect_variant in timed_item_effects[target_player]:
			var effect: Dictionary = effect_variant
			var due_turn: int = int(effect.get("due_turn", -1))
			if due_turn > turn_number:
				kept.append(effect)
				continue
			if due_turn != turn_number or String(effect.get("id", "")) != "yaohuo":
				continue
			var slot: int = int(effect.get("target_slot", -1))
			if slot < 0 or slot >= hp[target_player].size() \
					or slot != active_index[target_player] or hp[target_player][slot] <= 0:
				continue
			var amount: int = int(effect.get("amount", 0))
			if amount <= 0:
				continue
			var lost: int = mini(hp[target_player][slot], amount)
			if _consume_fatal_damage_immunity(target_player, slot, amount, events):
				lost = 0
			else:
				hp[target_player][slot] -= amount
			var source_player: int = int(effect.get("source_player", -1))
			if hp[target_player][slot] <= 0:
				_killer[target_player][slot] = source_player
			events.append({id = "yaohuo_loss", player = target_player, slot = slot,
				amount = lost, source_player = source_player})
		timed_item_effects[target_player] = kept


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
				# 尾后针：绑定英雄本回合无论死因均触发；造成普通道具伤害。
				var retaliations: Dictionary = item_mod(p, "death_retaliations", {})
				var retaliation: int = int(retaliations.get(slot, 0))
				if retaliation > 0:
					retaliations.erase(slot)
					var enemy: int = 1 - p
					var enemy_slot: int = active_index[enemy]
					if hp[enemy][enemy_slot] > 0:
						_apply_damage(enemy, retaliation, p, ActionDef.Action.ATTACK,
							ActionDef.Pen.NORMAL, _a[enemy], events, [], "item", slot)
						events.append({id = "weihouzhen_sting", player = p,
							target_player = enemy, target_slot = enemy_slot, amount = retaliation})

	# 出战位阵亡 → 待玩家选替补（甲死亡换人）
	for p in [0, 1]:
		if hp[p][active_index[p]] <= 0 and living_reserves(p).size() > 0:
			var replacement_armor: int = int(item_mod(p, "death_replacement_shield", 0))
			if replacement_armor > 0:
				item_buffs[p]["pending_death_replacement_shield"] = int(
					item_buffs[p].get("pending_death_replacement_shield", 0)) + replacement_armor
				set_item_mod(p, "death_replacement_shield", 0)
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
