class_name BattleCore
extends RefCounted

## Battle logic — 5 base actions + switch. Hero skills added later.

enum Action {
	CHARGE, ATTACK, DEFEND, BIG_ATTACK, BIG_DEFEND, SWITCH
}

const BASE_ACTION_DEF := {
	Action.CHARGE:     {name="攒",   cost=0, damage=0, energy_gain=1},
	Action.ATTACK:     {name="波",   cost=1, damage=1, energy_gain=0},
	Action.DEFEND:     {name="防",   cost=0, damage=0, energy_gain=0},
	Action.BIG_ATTACK: {name="大波", cost=3, damage=2, energy_gain=0},
	Action.BIG_DEFEND: {name="大防", cost=2, damage=0, energy_gain=0},
	Action.SWITCH:     {name="切换", cost=1, damage=0, energy_gain=0},
}

const MAX_ENERGY := 20

# --- Public state ---
var energy: Array[int] = [0, 0]
var selected_action: Array[int] = [-1, -1]
var heroes: Array = []          # [[HeroData, ...], [HeroData, ...]]
var active_hero_index: Array[int] = [0, 0]
var hero_hp: Array = []         # [[int, ...], [int, ...]]
var hero_max_hp: Array = []     # [[int, ...], [int, ...]]

var turn_number: int = 0
var game_over: bool = false
var winner: int = -1
var last_result: Dictionary = {}


func setup(p1_heroes: Array, p2_heroes: Array) -> void:
	heroes = [p1_heroes, p2_heroes]
	hero_hp = []
	hero_max_hp = []
	for player_heroes in heroes:
		var hps: Array[int] = []
		var max_hps: Array[int] = []
		for h in player_heroes:
			hps.append(h.max_hp)
			max_hps.append(h.max_hp)
		hero_hp.append(hps)
		hero_max_hp.append(max_hps)
	energy = [0, 0]
	selected_action = [-1, -1]
	active_hero_index = [0, 0]
	game_over = false
	winner = -1
	turn_number = 0


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


func _get_action_cost(player: int, action: int) -> int:
	return BASE_ACTION_DEF[action]["cost"]


func _get_action_damage(player: int, action: int) -> int:
	return BASE_ACTION_DEF[action]["damage"]


func can_afford(player: int, action: int) -> bool:
	return energy[player] >= _get_action_cost(player, action)


func get_available_actions(player: int) -> Array[int]:
	var actions: Array[int] = [
		Action.CHARGE, Action.ATTACK, Action.DEFEND,
		Action.BIG_ATTACK, Action.BIG_DEFEND
	]

	if energy[player] >= _get_action_cost(player, Action.SWITCH) and alive_hero_count(player) > 1:
		actions.append(Action.SWITCH)

	for act in actions.duplicate():
		if not can_afford(player, act):
			actions.erase(act)

	return actions


func select_action(player: int, action: int) -> bool:
	if not action in get_available_actions(player):
		return false
	selected_action[player] = action
	return true


func select_switch_target(player: int, hero_slot: int) -> bool:
	if hero_slot == active_hero_index[player]:
		return false
	if hero_hp[player][hero_slot] <= 0:
		return false
	var cost := _get_action_cost(player, Action.SWITCH)
	energy[player] -= cost
	active_hero_index[player] = hero_slot
	selected_action[player] = Action.SWITCH
	return true


func both_ready() -> bool:
	return selected_action[0] >= 0 and selected_action[1] >= 0


func resolve() -> Dictionary:
	var events: Array[String] = []
	var p1_dmg := 0
	var p2_dmg := 0

	var a1 := selected_action[0]
	var a2 := selected_action[1]

	# === Phase 1: Apply costs & energy gains ===
	for p in [0, 1]:
		var a := selected_action[p]
		var cost := _get_action_cost(p, a)
		energy[p] -= cost
		if a == Action.CHARGE:
			energy[p] = mini(energy[p] + 1, MAX_ENERGY)
			events.append("P%d 攒 +1能量" % (p + 1))

	# === Phase 2: Mutual attack cancellation ===
	var a1_negated := false
	var a2_negated := false

	if _is_attack(a1) and _is_attack(a2):
		if a1 == Action.ATTACK and a2 == Action.ATTACK:
			a1_negated = true
			a2_negated = true
			events.append("双方波互相抵消")
		elif a1 == Action.BIG_ATTACK and a2 == Action.BIG_ATTACK:
			a1_negated = true
			a2_negated = true
			events.append("双方大波互相抵消")
		elif a1 == Action.ATTACK and a2 == Action.BIG_ATTACK:
			a1_negated = true
		elif a2 == Action.ATTACK and a1 == Action.BIG_ATTACK:
			a2_negated = true

	# === Phase 3: Resolve non-negated attacks ===
	if _is_attack(a1) and not a1_negated:
		p2_dmg += _resolve_attack(0, a1, a2, events, "P1", "P2")
	if _is_attack(a2) and not a2_negated:
		p1_dmg += _resolve_attack(1, a2, a1, events, "P2", "P1")

	# === Phase 4: Apply damage ===
	hero_hp[0][active_hero_index[0]] -= p1_dmg
	hero_hp[1][active_hero_index[1]] -= p2_dmg

	if p1_dmg > 0:
		events.append("P1 受到 %d 伤害" % p1_dmg)
	if p2_dmg > 0:
		events.append("P2 受到 %d 伤害" % p2_dmg)

	# === Phase 5: Game over check ===
	if alive_hero_count(0) == 0 and alive_hero_count(1) == 0:
		game_over = true
		winner = 0
		events.append("双方全灭 — 平局！")
	elif alive_hero_count(0) == 0:
		game_over = true
		winner = 2
		events.append("P1 全灭，P2 获胜！")
	elif alive_hero_count(1) == 0:
		game_over = true
		winner = 1
		events.append("P2 全灭，P1 获胜！")

	# === Phase 6: Force-switch dead hero ===
	if not game_over:
		for p in [0, 1]:
			if hero_hp[p][active_hero_index[p]] <= 0:
				_force_switch(p, events)

	# === Phase 7: Cleanup ===
	turn_number += 1
	selected_action = [-1, -1]

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


# --- Attack helpers ---

func _is_attack(action: int) -> bool:
	return action == Action.ATTACK or action == Action.BIG_ATTACK


func _resolve_attack(player: int, atk: int, def: int, events: Array, atk_name: String, def_name: String) -> int:
	var dmg := _get_action_damage(player, atk)
	var big := atk == Action.BIG_ATTACK

	if def == Action.BIG_DEFEND:
		events.append("%s 被大防格挡" % atk_name)
		return 0
	if not big and def == Action.DEFEND:
		events.append("%s 被防格挡" % atk_name)
		return 0
	if big and def == Action.DEFEND:
		events.append("%s 穿透防御！%d 伤害" % [atk_name, dmg])
		return dmg
	if big and def == Action.ATTACK:
		events.append("%s 大波压制 %s 波，造成 1 伤害" % [atk_name, def_name])
		return 1
	events.append("%s 命中，%d 伤害" % [atk_name, dmg])
	return dmg


func _force_switch(player: int, events: Array) -> void:
	var pname := "P1" if player == 0 else "P2"
	for i in range(hero_hp[player].size()):
		if hero_hp[player][i] > 0 and i != active_hero_index[player]:
			active_hero_index[player] = i
			events.append("%s 英雄阵亡，强制切换至 %s" % [pname, heroes[player][i].hero_name])
			return
	events.append("%s 无存活英雄可切换" % pname)


func get_action_name(action: int) -> String:
	if action in BASE_ACTION_DEF:
		return BASE_ACTION_DEF[action]["name"]
	return "未知"
