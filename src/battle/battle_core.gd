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
var form: Array = [[], []]                # form[player][slot]，0=默认形态（h26 变身）
var pending_damage: Array = [[], []]      # 半点，h27 延迟伤害队列
var statuses: Array = [[], []]            # statuses[player][slot]: Dictionary，per-slot 状态容器 (§D5)
var link: Array[Dictionary] = [{}, {}]    # link[player]: 绑定关系（h19 挚爱 / h28 契约）
var disabled_group: Array[int] = [-1, -1]   # 被禁动作系列（h17）：0=攻击系 1=防御系
var _disabled_on_turn: Array[int] = [-1, -1] # 该禁令生效的回合号（turn_number）

var selected_action: Array[int] = [-1, -1]
var selected_target: Array[int] = [-1, -1]
var _switch_to: Array[int] = [-1, -1]               # SWITCH 动作的目标槽位
var pending_death_switch: Array[bool] = [false, false]  # 出战阵亡待玩家选替补上场
var _death_processed: Array = [[], []]              # 每槽位死亡 hook 是否已触发（防重复）
var _dmg_dealt: Array[int] = [0, 0]                 # 本回合各方造成的实际伤害(半点)，h25 蓄势等用
var _energy_before: Array[int] = [0, 0]             # 本回合结算开始时的能量快照（倾力 h20 读取）
var _killer: Array = [[], []]                       # _killer[player][slot]=直接攻击致死该英雄的攻击方;-1=非攻击致死。on_kill 只对直接攻击触发(防 splash/AOE 连锁)

var turn_number: int = 0
var game_over: bool = false
var winner: int = WINNER_UNDECIDED

var rng := RandomNumberGenerator.new()    # 可 seed (§D7)：联机/录像/测试可复现
var _skills: Array = [[], []]             # _skills[player][slot]: HeroSkill 或 null

## 英雄技能组件注册表：hero_id → 组件脚本。未列入者 = 无技能（_skills 为 null）。
## 随实装逐个加入。swap 后此表与 v3 _HERO_SKILL_SCRIPTS 合并/替换。
const _HERO_SKILL_SCRIPTS := {
	"h01": preload("res://src/battle/skills/h01_qieyun.gd"),
	"h02": preload("res://src/battle/skills/h02_numu.gd"),
	"h03": preload("res://src/battle/skills/h03_kexue.gd"),
	"h04": preload("res://src/battle/skills/h04_sanku.gd"),
	"h05": preload("res://src/battle/skills/h05_tianwei.gd"),
	"h06": preload("res://src/battle/skills/h06_shetui.gd"),
	"h08": preload("res://src/battle/skills/h08_tizui.gd"),
	"h09": preload("res://src/battle/skills/h09_xiongshou.gd"),
	"h10": preload("res://src/battle/skills/h10_tixiao.gd"),
	"h11": preload("res://src/battle/skills/h11_qiongzhui.gd"),
	"h12": preload("res://src/battle/skills/h12_tunshi.gd"),
	"h13": preload("res://src/battle/skills/h13_guzhu.gd"),
	"h15": preload("res://src/battle/skills/h15_sanjian.gd"),
	"h16": preload("res://src/battle/skills/h16_zebei.gd"),
	"h17": preload("res://src/battle/skills/h17_junming.gd"),
	"h20": preload("res://src/battle/skills/h20_qingli.gd"),
	"h32": preload("res://src/battle/skills/h32_chiri.gd"),
	"h18": preload("res://src/battle/skills/h18_jiaohuang.gd"),
	"h19": preload("res://src/battle/skills/h19_lianren.gd"),
	"h21": preload("res://src/battle/skills/h21_xianglong.gd"),
	"h22": preload("res://src/battle/skills/h22_yinzhe.gd"),
	"h23": preload("res://src/battle/skills/h23_zhouerfushi.gd"),
	"h25": preload("res://src/battle/skills/h25_yituiweijin.gd"),
	"h27": preload("res://src/battle/skills/h27_yiroukegang.gd"),
	"h29": preload("res://src/battle/skills/h29_qingchao.gd"),
	"h30": preload("res://src/battle/skills/h30_beichen.gd"),
	"h33": preload("res://src/battle/skills/h33_shenpan.gd"),
	"h34": preload("res://src/battle/skills/h34_huanyu.gd"),
	"h07": preload("res://src/battle/skills/h07_dangxian.gd"),
	"h14": preload("res://src/battle/skills/h14_meikai.gd"),
	"h24": preload("res://src/battle/skills/h24_tianping.gd"),
	"h26": preload("res://src/battle/skills/h26_sishen.gd"),
	"h28": preload("res://src/battle/skills/h28_emo.gd"),
	"h31": preload("res://src/battle/skills/h31_yueliang.gd"),
}


## seed_value = 0 时用随机 seed（单机）；联机/测试传入确定 seed。
func setup(p1_heroes: Array, p2_heroes: Array, seed_value: int = 0) -> void:
	heroes = [p1_heroes, p2_heroes]
	rng.seed = seed_value if seed_value != 0 else randi()

	hp = [[], []]
	max_hp = [[], []]
	shield = [[], []]
	form = [[], []]
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
			form[p].append(0)
			pending_damage[p].append(0)
			statuses[p].append({})
			_death_processed[p].append(false)
			_killer[p].append(-1)

	active_index = [0, 0]
	energy = [ActionDef.INITIAL_ENERGY, ActionDef.INITIAL_ENERGY]
	link = [{}, {}]
	disabled_group = [-1, -1]
	_disabled_on_turn = [-1, -1]
	selected_action = [-1, -1]
	selected_target = [-1, -1]
	_switch_to = [-1, -1]
	pending_death_switch = [false, false]
	_dmg_dealt = [0, 0]
	turn_number = 0
	game_over = false
	winner = WINNER_UNDECIDED

	_build_skills()
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


# === 只读视图（UI / 测试用；半点 → 显示）===

func hp_display(half: int) -> float:
	return float(half) / float(HP_UNIT)

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


func can_afford(player: int, action: int) -> bool:
	return energy[player] >= _get_cost(player, action)


func select_action(player: int, action: int) -> bool:
	if is_action_disabled(player, action):
		return false
	if not can_afford(player, action):
		return false
	selected_action[player] = action
	return true


## 该动作本回合是否被禁（h17 君命）。攒/切换/主动不可禁。
func is_action_disabled(player: int, action: int) -> bool:
	if _disabled_on_turn[player] != turn_number:
		return false
	match disabled_group[player]:
		0:
			return action == ActionDef.Action.ATTACK or action == ActionDef.Action.BIG_ATTACK
		1:
			return action == ActionDef.Action.DEFEND or action == ActionDef.Action.BIG_DEFEND
	return false


## 出战英雄被沉默（h15）：本回合其被动 hook 失效。
func _is_silenced(player: int, slot: int) -> bool:
	return int(get_status(player, slot, "silenced_turn", -1)) == turn_number


## 统一回血入口：燃烧(h32)期间禁回血。返回实际回复量（半点）。
func _heal(player: int, slot: int, amount: int) -> int:
	if int(get_status(player, slot, "burn", 0)) > 0:
		return 0
	var before: int = hp[player][slot]
	hp[player][slot] = mini(hp[player][slot] + amount, max_hp[player][slot])
	return hp[player][slot] - before


## 当前出战英雄的主动技是否可用（has_active + cap 未满 + 能量够 + 组件自定前置）。
func can_use_active(player: int) -> bool:
	var slot: int = active_index[player]
	var sk: HeroSkill = _skills[player][slot]
	if sk == null or not sk.has_active():
		return false
	var cap: int = sk.active_per_game_cap()
	if cap >= 0 and int(get_status(player, slot, "active_uses", 0)) >= cap:
		return false
	if energy[player] < sk.active_cost(self, player, slot):
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


# === resolve ===
#
# 保留 v3 同时独立结算（B-001/2/3）：双方攻击各自走一遍管线、不抵消。
# 切换采用【甲】时机（ADR-002 Q1 / 2026-05-25 Eddy 裁定）：切换先于伤害结算，
#   攻击打到换【上来】的新英雄 → 切换 = 可垫刀/调度的防御工具。

func resolve() -> Dictionary:
	var events: Array = []

	# Phase 1: guard 未选动作 / 被禁动作 → CHARGE（延续 v3 B-004）
	for p in [0, 1]:
		if selected_action[p] < 0:
			push_warning("BattleCore.resolve(): P%d 未选动作，fallback CHARGE" % (p + 1))
			selected_action[p] = ActionDef.Action.CHARGE
		elif is_action_disabled(p, selected_action[p]):
			push_warning("BattleCore.resolve(): P%d 选了被禁动作，fallback CHARGE" % (p + 1))
			selected_action[p] = ActionDef.Action.CHARGE

	var a: Array[int] = [selected_action[0], selected_action[1]]
	_dmg_dealt = [0, 0]
	_energy_before = energy.duplicate()
	for p in [0, 1]:
		for s in range(_killer[p].size()):
			_killer[p][s] = -1

	# h14 梅开二度：本回合动作是否执行 2 次（仅基础非切换非主动；消耗 meikai。切换/主动不消耗不复制）
	var dbl: Array[bool] = [false, false]
	for p in [0, 1]:
		var act: int = a[p]
		var dupable: bool = act == ActionDef.Action.CHARGE or act == ActionDef.Action.ATTACK \
			or act == ActionDef.Action.DEFEND or act == ActionDef.Action.BIG_ATTACK \
			or act == ActionDef.Action.BIG_DEFEND
		if dupable and get_status(p, active_index[p], "meikai", false):
			dbl[p] = true
			set_status(p, active_index[p], "meikai", false)

	# Phase 0: 结算上回合延迟伤害 (h27 节制；直接扣，不再经节制 cap → "不再平滑")
	for p in [0, 1]:
		for s in range(hp[p].size()):
			if pending_damage[p][s] > 0:
				hp[p][s] -= pending_damage[p][s]
				events.append({id = "deferred_damage", player = p, slot = s, amount = pending_damage[p][s]})
				pending_damage[p][s] = 0

	# Phase 2: 扣能量 / 攒能量 / 主动技执行
	for p in [0, 1]:
		energy[p] -= _get_cost(p, a[p])
		if a[p] == ActionDef.Action.CHARGE:
			var gain: int = ActionDef.BASE_ACTION_DEF[ActionDef.Action.CHARGE]["energy_gain"]
			if dbl[p]:
				gain *= 2   # 梅开二度：攒 ×2
			energy[p] = mini(energy[p] + gain, ActionDef.MAX_ENERGY)
			events.append({id = "charge_gain", player = p, amount = gain})
		elif a[p] == ActionDef.ACTIVE:
			# 扣能由上面的 _get_cost 完成；cap 计数 + 事件在此；effect 执行延后到 Phase 2.6（切换之后）。
			var slot: int = active_index[p]
			var sk: HeroSkill = _skills[p][slot]
			if sk != null:
				set_status(p, slot, "active_uses", int(get_status(p, slot, "active_uses", 0)) + 1)
				events.append({id = "active_used", player = p, slot = slot})

	# Phase 2.5: 切换（甲时机，先于伤害）→ 攻击将打到换上来的新英雄
	for p in [0, 1]:
		if a[p] == ActionDef.Action.SWITCH:
			_do_switch(p, events)

	# Phase 2.6: 即时型主动技执行（在切换之后 → 审判/太阳/三缄 命中对手 post-switch 出战位）
	for p in [0, 1]:
		if a[p] == ActionDef.ACTIVE:
			var sk: HeroSkill = _skills[p][active_index[p]]
			if sk != null and not sk.active_is_attack():
				sk.execute_active(self, p, active_index[p])

	# Phase 3: 计算双方造成伤害（快照；含攻击型主动技 h12/h13/h20）
	var out: Array[int] = [0, 0]
	var out_kind: Array[int] = [-1, -1]   # 防御门判定用的攻击类型
	for p in [0, 1]:
		if ActionDef.is_attack(a[p]):
			out[p] = _calc_outgoing(p, a[p])
			out_kind[p] = a[p]
		elif a[p] == ActionDef.ACTIVE:
			var sk: HeroSkill = _skills[p][active_index[p]]
			if sk != null and sk.active_is_attack():
				out[p] = sk.active_attack_damage(self, p, active_index[p])
				out_kind[p] = sk.active_attack_kind()

	# Phase 4: 施加伤害（打到 post-switch 出战英雄）；攻击型主动技命中后回调（吞噬吸血）
	# 梅开二度 dbl：基础攻击执行 2 次（dbl 只对基础动作为真，主动攻击不翻倍）。
	for p in [0, 1]:
		if out[p] <= 0:
			continue
		var hits: int = 2 if dbl[p] else 1
		for _i in range(hits):
			var dealt: int = _apply_damage(1 - p, out[p], p, out_kind[p], a[1 - p], events)
			if a[p] == ActionDef.ACTIVE:
				var sk2: HeroSkill = _skills[p][active_index[p]]
				if sk2 != null and sk2.active_is_attack():
					sk2.on_active_attack_resolved(self, p, active_index[p], dealt)

	# Phase 5: 死亡结算 + 强制切换 + 胜负
	_resolve_deaths(a, events)

	# Phase 5.5: 回合结算末 hook（连段 h09 / 蓄势 h25；沉默时跳过）
	for p in [0, 1]:
		var s: int = active_index[p]
		if hp[p][s] > 0:
			var sk: HeroSkill = _skills[p][s]
			if sk != null and not _is_silenced(p, s):
				sk.on_resolve_end(self, p, s)

	# Phase 6: cleanup
	# 燃烧 duration tick（每回合 -1，归 0 移除）
	for p in [0, 1]:
		for s in range(hp[p].size()):
			var bn: int = int(get_status(p, s, "burn", 0))
			if bn > 0:
				if bn <= 1:
					statuses[p][s].erase("burn")
				else:
					statuses[p][s]["burn"] = bn - 1
	turn_number += 1
	var result := {
		p1_hp = current_hp(0), p2_hp = current_hp(1),
		p1_energy = energy[0], p2_energy = energy[1],
		p1_action = a[0], p2_action = a[1],
		events = events, game_over = game_over, winner = winner,
		turn = turn_number,
	}
	selected_action = [-1, -1]
	selected_target = [-1, -1]
	_switch_to = [-1, -1]
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


## h07 当先：免费切换（不占动作槽），cap 2。在【选择阶段】调用：立即换人 + 计 cap，不设 selected_action，
## 之后玩家照常为新出战英雄选一个动作。
func can_free_switch(player: int) -> bool:
	var slot: int = active_index[player]
	var sk: HeroSkill = _skills[player][slot]
	if sk == null or not sk.has_free_switch():
		return false
	if int(get_status(player, slot, "dangxian_uses", 0)) >= 2:
		return false
	return living_reserves(player).size() > 0


func free_switch(player: int, target: int) -> bool:
	if not can_free_switch(player):
		return false
	if target < 0 or target >= hp[player].size() or target == active_index[player] or hp[player][target] <= 0:
		return false
	set_status(player, active_index[player], "dangxian_uses", int(get_status(player, active_index[player], "dangxian_uses", 0)) + 1)
	var ev: Array = []
	_perform_switch(player, active_index[player], target, ev)
	return true


## 计算 player 本次攻击的造成伤害（半点）。
## 出伤 = 基础 → 出战英雄 modify_outgoing_damage → 全队 modify_team_outgoing_damage（团队层 buff）。
func _calc_outgoing(player: int, action: int) -> int:
	var slot: int = active_index[player]
	var dmg := ActionDef.get_base_damage(action)
	var skill: HeroSkill = _skills[player][slot]
	if skill != null and not _is_silenced(player, slot):
		dmg = skill.modify_outgoing_damage(dmg, action, self, player, slot)
	# 团队层出伤修正：扫攻击方全队（含替补），让团队 buff 源生效（h03 渴血）
	for s in range(heroes[player].size()):
		var tsk: HeroSkill = _skills[player][s]
		if tsk != null and not _is_silenced(player, s):
			dmg = tsk.modify_team_outgoing_damage(dmg, action, self, player, slot, player, s)
	return dmg


## 伤害管线 (§D4)。已实现相位：防御门 → 受伤 hook(平减) → 护盾 → 落 HP。
## 转移(h30) / 延迟(h27) / 穿透 / 易伤·月相 等相位待 Step 2.2c+ 接入。
## 返回实际落在 HP 上的伤害（半点），供攻击型主动技回调（吞噬吸血）使用。
func _apply_damage(target_player: int, raw: int, attacker_player: int, atk_action: int, def_action: int, events: Array) -> int:
	var slot: int = active_index[target_player]

	# Stage B4: 防御动作门（大防挡全部；防挡波，不挡大波/穿防攻击）
	if def_action == ActionDef.Action.BIG_DEFEND:
		events.append({id = "big_defend_block", player = target_player})
		return 0
	if def_action == ActionDef.Action.DEFEND and atk_action == ActionDef.Action.ATTACK:
		events.append({id = "defend_block", player = target_player})
		return 0

	# Stage B3: 易伤（燃烧 h32：受到攻击 +1.0）
	var dmg := raw
	if int(get_status(target_player, slot, "burn", 0)) > 0:
		dmg += ActionDef.HP_UNIT
		events.append({id = "vulnerable", player = target_player})

	# Stage B5: 受伤 hook（平减；沉默 h15 时跳过）
	var skill: HeroSkill = _skills[target_player][slot]
	if skill != null and not _is_silenced(target_player, slot):
		dmg = skill.modify_incoming_damage(dmg, atk_action, self, target_player, slot, attacker_player)
	dmg = maxi(dmg, 0)

	# Stage B6: 护盾
	if dmg > 0 and shield[target_player][slot] > 0:
		var absorbed: int = mini(shield[target_player][slot], dmg)
		shield[target_player][slot] -= absorbed
		dmg -= absorbed
		events.append({id = "shield_absorb", player = target_player, amount = absorbed})

	# Stage B7: 后排参战转移 (h30 星星：替补分担一半)
	if dmg > 0:
		for s in range(heroes[target_player].size()):
			if s != slot:
				var bsk: HeroSkill = _skills[target_player][s]
				if bsk != null:
					dmg = bsk.on_ally_take_damage(dmg, slot, self, target_player, s)

	# Stage B9: 落 HP（半点）
	if dmg > 0:
		hp[target_player][slot] -= dmg
		_dmg_dealt[attacker_player] += dmg
		events.append({id = "damage_taken", player = target_player, amount = dmg})
		if hp[target_player][slot] <= 0:
			_killer[target_player][slot] = attacker_player   # 标记直接攻击致死（供 on_kill 归因）
		return dmg
	return 0


## 死亡结算（§D8 基础版）：扫全场，新死亡触发 hook 链；出战位死且有替补 → 待玩家切换。
## 参数 a = 本回合双方动作（cleanup 前缓存，用于判定击杀者）。
func _resolve_deaths(_a: Array[int], events: Array) -> void:
	# 连锁死亡（§D8）：死亡 hook（殉情 h19 / 溢出 h29 等）可能造成新死亡 → 反复扫到稳定。
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
				# 致死拦截（h06 蛇蜕重生；组件自管"每局1次"）
				if skill != null and skill.on_before_death(self, p, slot):
					continue
				_death_processed[p][slot] = true
				changed = true
				var overkill: int = maxi(-hp[p][slot], 0)
				# 击杀者 on_kill：仅【直接攻击致死】触发（_killer 标记）。
				# splash(h29)/AOE(h34)/殉情(h19)/延迟(h27)/处决(h33) 不归因 → 不触发 → 防连锁。
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
