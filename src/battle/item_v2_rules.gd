class_name ItemV2Rules
extends RefCounted

## 冻结20件道具的公共规则解释器。它只认识 ItemData.effect_key，避免为20个简单效果
## 再建立20个私有脚本。列内效果先从同一快照生成可交换的 delta，再统一落账，玩家编号
## 只影响事件显示顺序，不影响数值结果。

const HP := 2
const ENERGY := ActionDef.ENERGY_UNIT

const PENDING_KEYS: Array[String] = [
	"wave_bonus",
	"big_wave_bonus",
	"item_discount",
	"defend_upgrade",
	"attack_bonus",
	"attack_penalty",
	"attack_any_target",
	"hit_thorns",
]


static func submission_target_is_valid(battle, player: int,
		data: ItemData, target: int) -> bool:
	if battle == null or data == null or not data.is_prototype_v2():
		return false
	match String(data.target_key):
		"friendly_reserve":
			if not battle.is_living_reserve(player, target):
				return false
		"friendly_dead":
			if not battle.is_dead_reserve(player, target):
				return false
		_:
			if target >= 0:
				return false

	var pending: Dictionary = battle.item_v2_pending[player]
	match String(data.effect_key):
		"armor_to_energy":
			return battle.shield[player][battle.active_index[player]] >= HP
		"next_defend_upgrade":
			return int(pending.get("defend_upgrade", 0)) <= 0
		"next_attack_any_target":
			return int(pending.get("attack_any_target", 0)) <= 0
	return true


static func execution_operation(snapshot, player: int,
		data: ItemData, target: int) -> Dictionary:
	var op := {
		"player": player,
		"item_id": data.item_id,
		"effect": String(data.effect_key),
		"shield_delta": {},
		"hp_delta": {},
		"energy_gain": {},
		"pending_add": [],
		"pending_set": [],
		"pending_clear": [],
		"switch_to": -1,
		"revive": [],
		"countered": false,
	}
	var active: int = snapshot.active_index[player]
	var opponent: int = 1 - player
	var enemy_active: int = snapshot.active_index[opponent]
	match String(data.effect_key):
		"next_wave_bonus":
			_pending_add(op, player, "wave_bonus", HP)
		"gain_active_armor":
			_add_delta(op["shield_delta"], Vector2i(player, active), 2 * HP)
		"heal_active":
			_add_heal_delta(snapshot, op, player, active, 2 * HP)
		"next_item_discount":
			_pending_set(op, player, "item_discount", 1)
		"swap_active":
			op["switch_to"] = target
		"next_big_wave_bonus":
			_pending_add(op, player, "big_wave_bonus", HP)
		"next_defend_upgrade":
			_pending_set(op, player, "defend_upgrade", 1)
		"gain_energy":
			op["energy_gain"][player] = 2 * ENERGY
		"break_enemy_armor":
			var removed: int = mini(snapshot.shield[opponent][enemy_active], 2 * HP)
			_add_delta(op["shield_delta"], Vector2i(opponent, enemy_active), -removed)
		"heal_teammate":
			_add_heal_delta(snapshot, op, player, target, 2 * HP)
		"next_attack_bonus":
			_pending_add(op, player, "attack_bonus", HP)
		"enemy_next_attack_penalty":
			_pending_add(op, opponent, "attack_penalty", HP)
		"next_attack_any_target":
			_pending_set(op, player, "attack_any_target", 1)
		"next_hit_thorns":
			_pending_add(op, player, "hit_thorns", HP)
		"swap_armor":
			if target >= 0 and target < snapshot.shield[player].size():
				var active_armor: int = snapshot.shield[player][active]
				var target_armor: int = snapshot.shield[player][target]
				_add_delta(op["shield_delta"], Vector2i(player, active), target_armor - active_armor)
				_add_delta(op["shield_delta"], Vector2i(player, target), active_armor - target_armor)
		"armor_to_energy":
			if snapshot.shield[player][active] >= HP:
				_add_delta(op["shield_delta"], Vector2i(player, active), -HP)
				op["energy_gain"][player] = ENERGY
			else:
				op["countered"] = true
		"steal_enemy_armor":
			var stolen: int = mini(snapshot.shield[opponent][enemy_active], HP)
			_add_delta(op["shield_delta"], Vector2i(opponent, enemy_active), -stolen)
			_add_delta(op["shield_delta"], Vector2i(player, active), stolen)
		"clear_active_armor":
			for side: int in [0, 1]:
				var slot: int = snapshot.active_index[side]
				_add_delta(op["shield_delta"], Vector2i(side, slot), -snapshot.shield[side][slot])
		"clear_pending_item_effects":
			for side: int in [0, 1]:
				for key: String in PENDING_KEYS:
					if snapshot.item_v2_pending[side].has(key):
						op["pending_clear"].append({"player": side, "key": key})
		"revive_teammate":
			if snapshot.is_dead_reserve(player, target):
				op["revive"].append({"player": player, "slot": target, "hp": HP})
			else:
				op["countered"] = true
	return op


static func apply_column_operations(battle, operations: Array,
		events: Array, column: int) -> void:
	var shield_delta: Dictionary = {}
	var hp_delta: Dictionary = {}
	var energy_gain: Dictionary = {}
	var pending_clears: Array = []
	var pending_adds: Array = []
	var pending_sets: Array = []
	var revives: Array = []
	var switches: Array = []
	for op_variant: Variant in operations:
		var op: Dictionary = op_variant
		_merge_delta(shield_delta, op.get("shield_delta", {}))
		_merge_delta(hp_delta, op.get("hp_delta", {}))
		_merge_delta(energy_gain, op.get("energy_gain", {}))
		pending_clears.append_array(op.get("pending_clear", []))
		pending_adds.append_array(op.get("pending_add", []))
		pending_sets.append_array(op.get("pending_set", []))
		revives.append_array(op.get("revive", []))
		if int(op.get("switch_to", -1)) >= 0:
			switches.append({"player": int(op["player"]), "target": int(op["switch_to"])})
		events.append({
			"id": "item_v2_effect",
			"player": int(op["player"]),
			"item_id": String(op["item_id"]),
			"effect": String(op["effect"]),
			"column": column,
			"countered": bool(op.get("countered", false)),
		})

	for key_variant: Variant in shield_delta:
		var pos: Vector2i = key_variant
		if pos.x >= 0 and pos.x < battle.shield.size() \
				and pos.y >= 0 and pos.y < battle.shield[pos.x].size():
			battle.shield[pos.x][pos.y] = maxi(0,
				int(battle.shield[pos.x][pos.y]) + int(shield_delta[pos]))
	for key_variant: Variant in hp_delta:
		var pos: Vector2i = key_variant
		if pos.x >= 0 and pos.x < battle.hp.size() \
				and pos.y >= 0 and pos.y < battle.hp[pos.x].size() \
				and battle.hp[pos.x][pos.y] > 0:
			battle.hp[pos.x][pos.y] = clampi(
				battle.hp[pos.x][pos.y] + int(hp_delta[pos]), 0, battle.max_hp[pos.x][pos.y])
	for revive_variant: Variant in revives:
		var revive: Dictionary = revive_variant
		var side: int = int(revive["player"])
		var slot: int = int(revive["slot"])
		if battle.is_dead_reserve(side, slot):
			battle.hp[side][slot] = mini(int(revive["hp"]), battle.max_hp[side][slot])
			battle.shield[side][slot] = 0
			events.append({"id": "item_v2_revived", "player": side, "slot": slot,
				"amount": battle.hp[side][slot], "column": column})
	for side_variant: Variant in energy_gain:
		var side: int = int(side_variant)
		var gained: int = battle._gain_energy(side, int(energy_gain[side_variant]))
		if gained > 0:
			events.append({"id": "item_v2_energy_gained", "player": side,
				"amount": gained, "column": column})

	# 清除只作用于列开始时已经存在的状态；同列另一件新建立的状态随后正常留下。
	for clear_variant: Variant in pending_clears:
		var clear: Dictionary = clear_variant
		battle.item_v2_pending[int(clear["player"])].erase(String(clear["key"]))
	for set_variant: Variant in pending_sets:
		var pending_set: Dictionary = set_variant
		battle.item_v2_pending[int(pending_set["player"])][String(pending_set["key"])] = \
			int(pending_set["amount"])
	for add_variant: Variant in pending_adds:
		var pending_add: Dictionary = add_variant
		var side: int = int(pending_add["player"])
		var key: String = String(pending_add["key"])
		battle.item_v2_pending[side][key] = int(battle.item_v2_pending[side].get(key, 0)) \
			+ int(pending_add["amount"])
	for switch_variant: Variant in switches:
		var request: Dictionary = switch_variant
		var side: int = int(request["player"])
		var target: int = int(request["target"])
		if battle.is_living_reserve(side, target):
			battle._perform_switch(side, battle.active_index[side], target, events, true)


## 读取并消费一次“实际结算攻击”状态。H02升级波传 BIG_ATTACK；H13两段分别传 ATTACK，
## 第一段消费后第二段自然读不到旧状态。
static func take_attack_modifiers(battle, player: int,
		actual_action: int, requested_target: int) -> Dictionary:
	var pending: Dictionary = battle.item_v2_pending[player]
	var bonus: int = int(pending.get("attack_bonus", 0))
	var penalty: int = int(pending.get("attack_penalty", 0))
	pending.erase("attack_bonus")
	pending.erase("attack_penalty")
	if actual_action == ActionDef.Action.ATTACK:
		bonus += int(pending.get("wave_bonus", 0))
		pending.erase("wave_bonus")
	elif actual_action == ActionDef.Action.BIG_ATTACK:
		bonus += int(pending.get("big_wave_bonus", 0))
		pending.erase("big_wave_bonus")
	var target: int = -1
	if int(pending.get("attack_any_target", 0)) > 0:
		pending.erase("attack_any_target")
		var opponent: int = 1 - player
		if requested_target >= 0 and requested_target < battle.hp[opponent].size() \
				and battle.hp[opponent][requested_target] > 0:
			target = requested_target
	return {"bonus": bonus, "penalty": penalty, "target": target}


static func take_defense_action(battle, player: int, chosen_action: int) -> int:
	if chosen_action != ActionDef.Action.DEFEND:
		return chosen_action
	if int(battle.item_v2_pending[player].get("defend_upgrade", 0)) <= 0:
		return chosen_action
	battle.item_v2_pending[player].erase("defend_upgrade")
	return ActionDef.Action.BIG_DEFEND


static func has_any_target(battle, player: int) -> bool:
	return battle != null and int(battle.item_v2_pending[player].get(
		"attack_any_target", 0)) > 0


static func take_thorns_after_connected_hit(battle, defender: int,
		attacker: int, events: Array, column: int) -> void:
	var amount: int = int(battle.item_v2_pending[defender].get("hit_thorns", 0))
	if amount <= 0:
		return
	battle.item_v2_pending[defender].erase("hit_thorns")
	var dealt: int = battle.strike(attacker, amount, defender, ActionDef.Pen.NORMAL, events)
	events.append({"id": "item_v2_thorns", "player": defender,
		"target_player": attacker, "amount": dealt, "column": column})


static func item_cost_units(battle, player: int, data: ItemData,
		consume_discount: bool) -> int:
	var discount: int = int(battle.item_v2_pending[player].get("item_discount", 0))
	if consume_discount and discount > 0:
		battle.item_v2_pending[player].erase("item_discount")
	return maxi(0, data.use_cost - discount)


static func _add_heal_delta(snapshot, op: Dictionary,
		player: int, slot: int, amount: int) -> void:
	if slot < 0 or slot >= snapshot.hp[player].size() or snapshot.hp[player][slot] <= 0:
		op["countered"] = true
		return
	var healed: int = mini(amount, snapshot.max_hp[player][slot] - snapshot.hp[player][slot])
	_add_delta(op["hp_delta"], Vector2i(player, slot), healed)


static func _pending_add(op: Dictionary, player: int, key: String, amount: int) -> void:
	op["pending_add"].append({"player": player, "key": key, "amount": amount})


static func _pending_set(op: Dictionary, player: int, key: String, amount: int) -> void:
	op["pending_set"].append({"player": player, "key": key, "amount": amount})


static func _add_delta(target: Dictionary, key: Variant, amount: int) -> void:
	target[key] = int(target.get(key, 0)) + amount


static func _merge_delta(target: Dictionary, source: Dictionary) -> void:
	for key: Variant in source:
		_add_delta(target, key, int(source[key]))
