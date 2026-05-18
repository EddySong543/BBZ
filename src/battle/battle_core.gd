class_name BattleCore
extends RefCounted

## Battle logic — base actions + hero skills added incrementally.

enum Action {
	CHARGE, ATTACK, DEFEND, BIG_ATTACK, BIG_DEFEND, SWITCH,
	FAN_GE, BAI_SHOU, JIAO_TU, SHE_TUI, SHE_SHEN, SHEN_WAI, CAI_JIN, YU_ZHE
}

const BASE_ACTION_DEF := {
	Action.CHARGE:     {name="攒",   cost=0, damage=0, energy_gain=1},
	Action.ATTACK:     {name="波",   cost=1, damage=1, energy_gain=0},
	Action.DEFEND:     {name="防",   cost=0, damage=0, energy_gain=0},
	Action.BIG_ATTACK: {name="大波", cost=3, damage=2, energy_gain=0},
	Action.BIG_DEFEND: {name="大防", cost=2, damage=0, energy_gain=0},
	Action.SWITCH:     {name="切换", cost=1, damage=0, energy_gain=0},
}

const EXTRA_ACTION_DEF := {
	Action.FAN_GE:   {name="反戈", cost=2, damage=0},
	Action.BAI_SHOU: {name="百兽", cost=-1, damage=0},
	Action.JIAO_TU:  {name="狡兔三窟", cost=3, damage=0},
	Action.SHE_TUI:  {name="蛇蜕", cost=2, damage=0},
	Action.SHE_SHEN: {name="舍身", cost=0, damage=0},
	Action.SHEN_WAI: {name="身外化身", cost=3, damage=0},
	Action.CAI_JIN:  {name="财源广进", cost=0, damage=0},
	Action.YU_ZHE:   {name="不可知之权柄", cost=0, damage=0},
}

const MAX_ENERGY := 20
const BAI_SHOU_DAMAGE_CAP := 6
const BAI_SHOU_MIN_COST := 1

# Winner 取值常量（B-007 Resolved 2026-05-18）
const WINNER_UNDECIDED := -1
const WINNER_DRAW := 0
const WINNER_P1 := 1
const WINNER_P2 := 2

# 英雄技能注册中心 — 仅列已迁移到 HeroSkill 组件的英雄
# 未在此 dict 中的 hero_id 仍走 BattleCore 内 hardcoded if 分支（如 xugou/haizhu 等）
# 详见 docs/architecture/battlecore-risk-notes.md §3
const _HERO_SKILL_SCRIPTS := {
	"h05": preload("res://src/battle/skills/chenlong.gd"),
}

var energy := [0, 0]
var selected_action := [-1, -1]
var heroes: Array = []
var active_hero_index := [0, 0]
var hero_hp: Array = []
var hero_max_hp: Array = []

var turn_number: int = 0
var game_over: bool = false
var winner: int = -1
var last_result: Dictionary = {}
var switch_used: Array[bool] = [false, false]

var _baishou_spent: Array[int] = [0, 0]
var _jiaotu_immune: Array[bool] = [false, false]
var _jiaotu_free_switch: Array[bool] = [false, false]
var _jiaotu_used_count: Array[int] = [0, 0]
var _shetui_active: Array[bool] = [false, false]
var _shetui_owner: Array[int] = [-1, -1]
var _shetui_empowered: Array[bool] = [false, false]

var shield: Array = []
var _wuma_pending_shield: Array[bool] = [false, false]

# Clone system (身外化身)
var clone_count: Array[int] = [0, 0]
var clone_hp: Array = [[], []]
var clone_order: Array = [[], []]
var selected_target: Array[int] = [-1, -1]
var _shenwai_used: Array[bool] = [false, false]
var _fallen_teammates: Array[int] = [0, 0]
var _caijin_cooldown: Array[bool] = [false, false]
var _caijin_buff: Array[bool] = [false, false]
var _raw_dmg_to: Array[int] = [0, 0]
var pending_death_switch: Array[int] = [-1, -1]

# 每个英雄槽位对应的 HeroSkill 实例（null = 未迁移到组件，走旧 if 分支）
var _hero_skills: Array = [[null, null, null], [null, null, null]]


func setup(p1_heroes: Array, p2_heroes: Array) -> void:
	heroes = [p1_heroes, p2_heroes]
	hero_hp = []
	hero_max_hp = []
	for player_heroes in heroes:
		var hps := []
		var max_hps := []
		for h in player_heroes:
			hps.append(h.max_hp)
			max_hps.append(h.max_hp)
		hero_hp.append(hps)
		hero_max_hp.append(max_hps)
	shield = [[0, 0, 0], [0, 0, 0]]
	# 愚者 HP randomization (8-14)
	for player in [0, 1]:
		for i in range(heroes[player].size()):
			if heroes[player][i].hero_id == "h13":
				var rng_hp := randi_range(8, 14)
				hero_hp[player][i] = rng_hp
				hero_max_hp[player][i] = rng_hp
	_wuma_pending_shield = [false, false]
	clone_count = [0, 0]
	clone_hp = [[], []]
	clone_order = [[], []]
	selected_target = [-1, -1]
	_shenwai_used = [false, false]
	_fallen_teammates = [0, 0]
	_jiaotu_free_switch = [false, false]
	_jiaotu_used_count = [0, 0]
	_shetui_empowered = [false, false]
	_shetui_owner = [-1, -1]
	_caijin_cooldown = [false, false]
	_caijin_buff = [false, false]
	_raw_dmg_to = [0, 0]
	energy = [0, 0]
	selected_action = [-1, -1]
	switch_used = [false, false]
	pending_death_switch = [-1, -1]
	active_hero_index = [0, 0]
	game_over = false
	winner = WINNER_UNDECIDED
	turn_number = 0
	# B-006 Accepted as Canonical 2026-05-18:
	#   _baishou_spent / _jiaotu_immune / _shetui_active 三个 transient 标志
	#   故意不在 setup() 重置 — 它们由 resolve() Phase 1 开头重置（见下）。
	#   当前 UI 每场新建 BattleCore，所以即使首次 setup 后这三个保留 var 声明初值
	#   也无可见影响。详见 tests/BEHAVIOR_NOTES.md B-006。
	_build_hero_skills()


func _build_hero_skills() -> void:
	_hero_skills = [[], []]
	for p in [0, 1]:
		for h in heroes[p]:
			var script: Script = _HERO_SKILL_SCRIPTS.get(h.hero_id, null)
			_hero_skills[p].append(script.new() if script else null)


func active_hero(player: int) -> HeroData:
	return heroes[player][active_hero_index[player]]


func current_hp(player: int) -> int:
	return hero_hp[player][active_hero_index[player]]


func current_max_hp(player: int) -> int:
	return hero_max_hp[player][active_hero_index[player]]


func alive_hero_count(player: int) -> int:
	var count := 0
	for hp_val in hero_hp[player]:
		if hp_val > 0:
			count += 1
	return count


# === Read-only views (P1-5f UI decoupling) ===

func get_energy(player: int) -> int:
	return energy[player]

func get_active_slot(player: int) -> int:
	return active_hero_index[player]

func get_hero_at(player: int, slot: int) -> HeroData:
	return heroes[player][slot]

func get_hero_hp(player: int, slot: int) -> int:
	return hero_hp[player][slot]

func get_hero_max_hp(player: int, slot: int) -> int:
	return hero_max_hp[player][slot]

func get_hero_shield(player: int, slot: int) -> int:
	return shield[player][slot]

func get_clone_count(player: int) -> int:
	return clone_count[player]

func get_clone_order_array(player: int) -> Array:
	return clone_order[player]

func get_clone_hp_array(player: int) -> Array:
	return clone_hp[player]

func get_turn_number() -> int:
	return turn_number

func is_game_over() -> bool:
	return game_over

func get_winner() -> int:
	return winner

func get_pending_death_switch(player: int) -> int:
	return pending_death_switch[player]

func get_team_size(player: int) -> int:
	return heroes[player].size()


func _get_action_cost(player: int, action: int) -> int:
	if action == Action.BAI_SHOU:
		# B-005 Resolved 2026-05-18: 与 resolve() 内 spent = clampi(...) 保持一致，cap 到 6
		return clampi(energy[player], BAI_SHOU_MIN_COST, BAI_SHOU_DAMAGE_CAP)
	if action in EXTRA_ACTION_DEF:
		return EXTRA_ACTION_DEF[action]["cost"]
	if action == Action.SWITCH and _jiaotu_free_switch[player]:
		return 0
	return BASE_ACTION_DEF[action]["cost"]


func _get_action_damage(player: int, action: int) -> int:
	if action in EXTRA_ACTION_DEF:
		return EXTRA_ACTION_DEF[action]["damage"]
	return BASE_ACTION_DEF[action]["damage"]


func can_afford(player: int, action: int) -> bool:
	if action == Action.BAI_SHOU:
		return energy[player] >= BAI_SHOU_MIN_COST
	if action == Action.SHE_SHEN:
		return current_hp(player) > 2
	if action == Action.SHEN_WAI:
		return energy[player] >= 3 and clone_count[player] < 2
	if action == Action.CAI_JIN:
		return not _caijin_cooldown[player]
	if action == Action.JIAO_TU:
		return _jiaotu_used_count[player] < 3 and energy[player] >= _get_action_cost(player, action)
	return energy[player] >= _get_action_cost(player, action)


func get_available_actions(player: int) -> Array:
	var actions := [
		Action.CHARGE, Action.ATTACK, Action.DEFEND,
		Action.BIG_ATTACK, Action.BIG_DEFEND
	]
	var h := active_hero(player)

	if h.has_skill_type(HeroData.SkillType.EXTRA_ACTION):
		var eid := _hero_extra_action_id(h)
		if eid >= 0 and can_afford(player, eid):
			actions.append(eid)

	if energy[player] >= _get_action_cost(player, Action.SWITCH) and alive_hero_count(player) > 1:
		actions.append(Action.SWITCH)

	for act in actions.duplicate():
		if not can_afford(player, act):
			actions.erase(act)

	return actions


func _hero_extra_action_id(h: HeroData) -> int:
	match h.hero_id:
		"h01": return Action.CAI_JIN
		"h02": return Action.FAN_GE
		"h03": return Action.BAI_SHOU
		"h04": return Action.JIAO_TU
		"h05": return -1
		"h06": return Action.SHE_TUI
		"h08": return Action.SHE_SHEN
		"h09": return Action.SHEN_WAI
		"h13": return Action.YU_ZHE
	return h.extra_action_id


func select_action(player: int, action: int) -> bool:
	if not action in get_available_actions(player):
		return false
	selected_action[player] = action
	return true


func select_attack_target(player: int, target: int) -> void:
	selected_target[player] = target


func select_switch_target(player: int, hero_slot: int) -> bool:
	if switch_used[player]:
		return false
	if hero_slot == active_hero_index[player]:
		return false
	if hero_hp[player][hero_slot] <= 0:
		return false
	var cost := _get_action_cost(player, Action.SWITCH)
	if energy[player] < cost:
		return false
	var leaving_hero := active_hero(player)
	if leaving_hero.hero_id == "h07":
		_wuma_pending_shield[player] = true
	if leaving_hero.hero_id == "h09":
		_clear_clones(player)
	energy[player] -= cost
	if _jiaotu_free_switch[player]:
		_jiaotu_free_switch[player] = false
	active_hero_index[player] = hero_slot
	switch_used[player] = true
	if _wuma_pending_shield[player]:
		shield[player][hero_slot] = 1
		_wuma_pending_shield[player] = false
	elif active_hero(player).hero_id == "h07":
		shield[player][hero_slot] = 1
	return true


func both_ready() -> bool:
	return selected_action[0] >= 0 and selected_action[1] >= 0

func can_switch(player: int) -> bool:
	return not switch_used[player] and energy[player] >= _get_action_cost(player, Action.SWITCH) and alive_hero_count(player) > 1


func opponent_has_clones(player: int) -> bool:
	return clone_count[1 - player] > 0

func get_clone_order(player: int) -> Array:
	return clone_order[player]

func get_clone_hp(player: int) -> Array:
	return clone_hp[player]


func resolve() -> Dictionary:
	# B-004 Resolved 2026-05-18: 防御性 guard — 若调用方未先用 select_action() 设置动作
	# (selected_action[p] == -1)，下游 _get_action_cost(p, -1) 会查 BASE_ACTION_DEF[-1] 崩溃。
	# 此处 fallback 到 CHARGE 是安全选择（cost=0, +1能量），让对局继续而非崩溃。
	# UI 当前会兜底，但联网/AI 接入后调用方多样化，此 guard 是必要保护。
	for _p in [0, 1]:
		if selected_action[_p] < 0:
			push_warning("BattleCore.resolve(): P%d 未选择动作，fallback 到 CHARGE" % (_p + 1))
			selected_action[_p] = Action.CHARGE

	var events: Array = []
	var p1_dmg := 0
	var p2_dmg := 0

	var a1: int = selected_action[0]
	var a2: int = selected_action[1]

	_baishou_spent = [0, 0]
	_jiaotu_immune = [false, false]
	_shetui_active = [false, false]
	_raw_dmg_to = [0, 0]

	var energy_before := energy.duplicate()

	# === Phase 1: Apply costs & energy gains ===
	for p in [0, 1]:
		var a: int = selected_action[p]
		# 愚者: random basic action
		var yuzhe_used := false
		if a == Action.YU_ZHE:
			var pool := [Action.CHARGE, Action.ATTACK, Action.DEFEND, Action.BIG_ATTACK, Action.BIG_DEFEND]
			a = pool[randi_range(0, 4)]
			selected_action[p] = a
			yuzhe_used = true
			events.append({id="yuzhe_random", player=p, action_name=get_action_name(a)})

		if a == Action.JIAO_TU:
			_jiaotu_immune[p] = true
		if a == Action.SHE_TUI:
			_shetui_owner[p] = active_hero_index[p]
			_shetui_active[p] = true
		if a == Action.SHEN_WAI:
			_shenwai_used[p] = true

		if a == Action.BAI_SHOU:
			var spent := clampi(energy[p], BAI_SHOU_MIN_COST, BAI_SHOU_DAMAGE_CAP)
			energy[p] -= spent
			_baishou_spent[p] = spent
			events.append({id="baishou_spent", player=p, amount=spent})
		elif not yuzhe_used:
			var cost := _get_action_cost(p, a)
			energy[p] -= cost

		if a == Action.CHARGE:
			var gain: int = BASE_ACTION_DEF[Action.CHARGE]["energy_gain"]
			if _caijin_buff[p]:
				gain *= 2
				_caijin_buff[p] = false
				events.append({id="caijin_triggered", player=p})
			energy[p] = mini(energy[p] + gain, MAX_ENERGY)
			events.append({id="charge_gain", player=p, amount=gain})

		if a == Action.SHE_SHEN:
			hero_hp[p][active_hero_index[p]] -= 2
			energy[p] = mini(energy[p] + 3, MAX_ENERGY)
			events.append({id="sheshen_used", player=p})
		# 财源广进: set buff for next charge
		if a == Action.CAI_JIN:
			_caijin_buff[p] = true
			events.append({id="caijin_buff_set", player=p})


	a1 = selected_action[0]
	a2 = selected_action[1]
	# === Phase 2: Resolve attacks + specials ===
	if _is_attack(a1):
		var dmg := _calc_attack_raw(0, a1, a2, events, energy_before)
		if _resolve_target(0, 1) == 1:
			_raw_dmg_to[1] = dmg
			dmg = _apply_defense(dmg, a1, _effective_defense(1, a2), events, 0)
		p2_dmg += _route_damage(0, 1, dmg, events, "attack")
	if _is_attack(a2):
		var dmg := _calc_attack_raw(1, a2, a1, events, energy_before)
		if _resolve_target(1, 0) == 1:
			_raw_dmg_to[0] = dmg
			dmg = _apply_defense(dmg, a2, _effective_defense(0, a1), events, 1)
		p1_dmg += _route_damage(1, 0, dmg, events, "attack")

	# 百兽 damage — multihit: 1 damage per hit, random target per hit
	for p in [0, 1]:
		if selected_action[p] == Action.BAI_SHOU:
			var opp: int = 1 - p
			var hits: int = _baishou_spent[p]
			var hero_dmg := 0
			var clone_kills := 0
			for _h in range(hits):
				var valid: Array = _get_valid_targets(opp)
				if valid.size() == 0:
					break
				var chosen: int = valid[randi_range(0, valid.size() - 1)]
				if chosen == 1:
					if selected_action[opp] == Action.BIG_DEFEND:
						continue
					hero_dmg += 1
				else:
					var ci: int = 0 if chosen == 0 else 1
					if ci < clone_hp[opp].size() and clone_hp[opp][ci] > 0:
						clone_hp[opp][ci] = 0
						clone_count[opp] -= 1
						_rebuild_clone_order(opp)
						clone_kills += 1
			if clone_kills > 0:
				events.append({id="baishou_destroy_clones", player=p, count=clone_kills})
			if hero_dmg == 0 and clone_kills == 0:
				events.append({id="baishou_blocked", player=p})
			elif hero_dmg > 0:
				if p == 0:
					p2_dmg += hero_dmg
				else:
					p1_dmg += hero_dmg
				events.append({id="baishou_hits", player=p, count=hero_dmg})

	# 反戈 reflect — raw damage, pierces defense (cannot pierce 无敌)
	for p in [0, 1]:
		if selected_action[p] == Action.FAN_GE:
			var raw_taken := _raw_dmg_to[p]
			if raw_taken > 0:
				var opp: int = 1 - p
				if not _jiaotu_immune[opp]:
					hero_hp[opp][active_hero_index[opp]] -= raw_taken
					events.append({id="fange_reflect", player=p, amount=raw_taken})
				else:
					events.append({id="fange_immune", player=p})

	# 身外化身 — after all attacks resolved
	for p in [0, 1]:
		if _shenwai_used[p]:
			_create_clones(p, events)

	# === Phase 3: Apply damage (shield + immunity check) ===
	if not _jiaotu_immune[0]:
		var s0: int = shield[0][active_hero_index[0]]
		if active_hero(0).passive_id == "xugou":
			s0 += _fallen_teammates[0]
		if s0 > 0 and p1_dmg > 0:
			var absorbed0 := mini(s0, p1_dmg)
			shield[0][active_hero_index[0]] = maxi(0, shield[0][active_hero_index[0]] - absorbed0)
			p1_dmg -= absorbed0
			events.append({id="shield_absorb", player=0, amount=absorbed0})
		hero_hp[0][active_hero_index[0]] -= p1_dmg
	if not _jiaotu_immune[1]:
		var s1: int = shield[1][active_hero_index[1]]
		if active_hero(1).passive_id == "xugou":
			s1 += _fallen_teammates[1]
		if s1 > 0 and p2_dmg > 0:
			var absorbed1 := mini(s1, p2_dmg)
			shield[1][active_hero_index[1]] = maxi(0, shield[1][active_hero_index[1]] - absorbed1)
			p2_dmg -= absorbed1
			events.append({id="shield_absorb", player=1, amount=absorbed1})
		hero_hp[1][active_hero_index[1]] -= p2_dmg

	if p1_dmg > 0:
		if _jiaotu_immune[0]:
			events.append({id="jiaotu_immune", player=0, amount=p1_dmg})
		else:
			events.append({id="damage_taken", player=0, amount=p1_dmg})
			if active_hero(0).passive_id == "haizhu":
				energy[0] = mini(energy[0] + p1_dmg, MAX_ENERGY)
				events.append({id="haizhu_energy_gain", player=0, amount=p1_dmg})
	if p2_dmg > 0:
		if _jiaotu_immune[1]:
			events.append({id="jiaotu_immune", player=1, amount=p2_dmg})
		else:
			events.append({id="damage_taken", player=1, amount=p2_dmg})
			if active_hero(1).passive_id == "haizhu":
				energy[1] = mini(energy[1] + p2_dmg, MAX_ENERGY)
				events.append({id="haizhu_energy_gain", player=1, amount=p2_dmg})

	# 蛇蜕: if dead, revive with 1HP, permanently upgrade 波/防
	for p in [0, 1]:
		var idx: int = _shetui_owner[p]
		if idx >= 0 and _shetui_active[p] and hero_hp[p][idx] <= 0:
			hero_hp[p][idx] = 1
			_shetui_empowered[p] = true
			events.append({id="shetui_revive", player=p})

	# === Phase 4: Game over check ===
	# B-007 Resolved 2026-05-18: 使用 WINNER_* 常量代替魔法数字
	if alive_hero_count(0) == 0 and alive_hero_count(1) == 0:
		game_over = true
		winner = WINNER_DRAW
		events.append({id="draw"})
	elif alive_hero_count(0) == 0:
		game_over = true
		winner = WINNER_P2
		events.append({id="victory", winner=WINNER_P2})
	elif alive_hero_count(1) == 0:
		game_over = true
		winner = WINNER_P1
		events.append({id="victory", winner=WINNER_P1})

	# === Phase 5: Force-switch dead hero ===
	if not game_over:
		for p in [0, 1]:
			if hero_hp[p][active_hero_index[p]] <= 0:
				_fallen_teammates[p] += 1
				_clear_clones(p)
				_force_switch(p, events)

	# === Phase 6: Cleanup ===
	for p in [0, 1]:
		if selected_action[p] == Action.JIAO_TU:
			_jiaotu_used_count[p] += 1
			_jiaotu_free_switch[p] = true
			events.append({id="jiaotu_free_switch", player=p})
		else:
			_jiaotu_free_switch[p] = false

	turn_number += 1
	selected_action = [-1, -1]
	switch_used = [false, false]
	selected_target = [-1, -1]
	_shenwai_used = [false, false]
	_caijin_cooldown[0] = a1 == Action.CAI_JIN
	_caijin_cooldown[1] = a2 == Action.CAI_JIN

	last_result = {
		p1_hp=current_hp(0), p2_hp=current_hp(1),
		p1_max_hp=current_max_hp(0), p2_max_hp=current_max_hp(1),
		p1_energy=energy[0], p2_energy=energy[1],
		p1_action=a1, p2_action=a2,
		p1_hero_name=active_hero(0).hero_name,
		p2_hero_name=active_hero(1).hero_name,
		events=events,
		game_over=game_over,
		winner=winner,
		turn=turn_number,
	}
	return last_result


# --- Clone helpers ---

func _create_clones(player: int, events: Array) -> void:
	if clone_count[player] >= 2:
		return
	if clone_count[player] == 0:
		clone_hp[player] = [0, 0]
	for ci in range(2):
		if clone_hp[player][ci] == 0:
			clone_hp[player][ci] = 1
			clone_count[player] += 1
			break
	_rebuild_clone_order(player)
	events.append({id="shenwai_create", player=player, total=clone_count[player]})


func _clear_clones(player: int) -> void:
	clone_count[player] = 0
	clone_hp[player] = []
	clone_order[player] = []


func _get_valid_targets(player: int) -> Array:
	if clone_count[player] == 0:
		return [1]
	return clone_order[player].duplicate()


func _rebuild_clone_order(player: int) -> void:
	var entries: Array = [1]
	for ci in range(2):
		if ci < clone_hp[player].size() and clone_hp[player][ci] > 0:
			entries.append(0 if ci == 0 else 2)
	entries.shuffle()
	clone_order[player] = entries


func _route_damage(attacker: int, defender: int, dmg: int, events: Array, source_id: String) -> int:
	if dmg <= 0:
		return 0
	if clone_count[defender] == 0:
		return dmg
	var target: int = selected_target[attacker]
	if target < 0 or target >= clone_order[defender].size():
		target = 0
	var actual: int = clone_order[defender][target]
	if actual == 1:
		return dmg
	var ci: int = 0 if actual == 0 else 1
	if ci < clone_hp[defender].size() and clone_hp[defender][ci] > 0:
		clone_hp[defender][ci] = 0
		clone_count[defender] -= 1
		_rebuild_clone_order(defender)
		events.append({id="clone_destroyed", player=defender, source=source_id})
	return 0


# --- Attack helpers ---

func _is_attack(action: int) -> bool:
	return action == Action.ATTACK or action == Action.BIG_ATTACK


func _effective_attack(player: int, action: int) -> int:
	if action == Action.ATTACK and active_hero(player).passive_id == "sichen" and (turn_number + 1) % 3 == 0:
		return Action.BIG_ATTACK
	if action == Action.ATTACK and _shetui_empowered[player] and active_hero(player).hero_id == "h06":
		return Action.BIG_ATTACK
	return action


func _effective_defense(player: int, action: int) -> int:
	if action == Action.DEFEND and _shetui_empowered[player] and active_hero(player).hero_id == "h06":
		return Action.BIG_DEFEND
	return action


func _calc_attack_raw(player: int, atk: int, def: int, events: Array, energy_before: Array) -> int:
	atk = _effective_attack(player, atk)
	var dmg := _get_action_damage(player, atk)
	# h05 chenlong 已迁移至 HeroSkillChenlong (skills/chenlong.gd)
	# 通过 _hero_skills 数组在下方 hook 调用中生效
	var skill: HeroSkill = _hero_skills[player][active_hero_index[player]]
	if skill:
		dmg = skill.on_attack_calc(dmg, atk, self, player, energy_before)
	if active_hero(player).passive_id == "xugou":
		dmg += _fallen_teammates[player]
	return dmg


func _apply_defense(dmg: int, atk: int, def: int, events: Array, player: int) -> int:
	if def == Action.BIG_DEFEND:
		events.append({id="big_defend_block", player=player})
		return 0
	if def == Action.DEFEND and atk == Action.ATTACK:
		events.append({id="defend_block", player=player})
		return 0
	events.append({id="attack_hit", player=player, amount=dmg})
	return dmg


func _resolve_target(attacker: int, defender: int) -> int:
	if clone_count[defender] == 0:
		return 1
	var target: int = selected_target[attacker]
	if target < 0 or target >= clone_order[defender].size():
		target = 0
	return clone_order[defender][target]

func _force_switch(player: int, events: Array) -> void:
	if get_living_reserves(player).size() > 0:
		pending_death_switch[player] = 1
		events.append({id="force_switch_prompt", player=player})
	else:
		events.append({id="no_switch_available", player=player})


func get_living_reserves(player: int) -> Array:
	var result: Array = []
	for i in range(hero_hp[player].size()):
		if hero_hp[player][i] > 0 and i != active_hero_index[player]:
			result.append(i)
	return result


func execute_death_switch(player: int, slot: int) -> bool:
	if pending_death_switch[player] <= 0:
		return false
	if hero_hp[player][slot] <= 0:
		return false
	if slot == active_hero_index[player]:
		return false
	active_hero_index[player] = slot
	pending_death_switch[player] = -1
	return true


func get_action_name(action: int) -> String:
	if action in BASE_ACTION_DEF:
		return BASE_ACTION_DEF[action]["name"]
	if action in EXTRA_ACTION_DEF:
		return EXTRA_ACTION_DEF[action]["name"]
	return "未知"
