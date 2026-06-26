extends ItemEffect

## 命运的骰子：随机 +1.0 伤 / 甲 / 能 之一，"可重抛一次"——掷两次，
## 若重抛能落到对当前局势更有利的一面则采纳（命运大方·但仍随机、不保证 → 维持 gamble）。
## 取向：对手攻→护甲保命 / 自己攻→加伤推进 / 否则→屯能（呼应算命铜钱 t1_tongqian 的自适应）。
const FACE_ATK := 0
const FACE_SHIELD := 1
const FACE_ENERGY := 2


func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	var n: int = int(data.params.get("amount", 2))
	var prefer: int = _preferred_face(battle, player)
	var face: int = battle.rng.randi() % 3
	# 可重抛一次：首掷不是更有利的面、而重抛恰好掷中它 → 采用重抛结果（两次机会）。
	if face != prefer and (battle.rng.randi() % 3) == prefer:
		face = prefer
	match face:
		FACE_ATK:
			battle.add_item_mod(player, "atk_bonus", n)
		FACE_SHIELD:
			battle.shield[player][target] += n
		_:
			battle._gain_energy(player, n)


## 本回合局势下"更想要的一面"（决定重抛取向）。
func _preferred_face(battle: BattleCore, player: int) -> int:
	if ActionDef.is_attack(battle.selected_action[1 - player]):
		return FACE_SHIELD   # 对手出击 → 护甲保命
	if ActionDef.is_attack(battle.selected_action[player]):
		return FACE_ATK      # 自己出击 → 加伤推进
	return FACE_ENERGY       # 双方都不攻 → 屯能
