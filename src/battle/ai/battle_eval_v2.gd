class_name BattleEvalV2
extends RefCounted

## v2「进阶·熟练优秀卡牌玩家」评估（2026-05-30）。
##
## 在 BattleEval(v1 基础: HP/能量/存活/护甲) 之上叠加「牌感」项：
##   - 致命威胁压力（对手出战在斩杀线内 → 我占主动）。
##   - 延迟伤害（旧延迟队列 + 妖火截止账目·PENDING_W）。
##
## 定位：强在「牌感」而非算力——非大师(不靠深搜穷举)，更接近读盘老练的优秀玩家。
## 零和：所有项均 own−opp，保持与 BattleEval 一致的反对称（双方各解同一矩阵自洽）。
##
## ⚠ 早期还含 铺垫叠层(连段/蓄势/梅开)/变身形态/禁招/契约 等项，已随 h13–h46 弃用一并移除
##    （那些状态在 12 生肖 + 道具体系下无任何产出者 → 评估项恒 0，属死码）。

const HP_UNIT := 2

const THREAT_W := 80.0   # 对手出战在斩杀线内（≤2HP）且我有 ≥1 能（能出波）→ 致命威胁压力
const PENDING_W := 8.0   # 延迟伤害（将落在某方头上）/半点
const THREAT_HP_LINE := 2 * HP_UNIT  # 斩杀威胁线：守方出战 ≤2HP（半点）
const THREAT_MIN_ENERGY := 2         # 攻方至少 1 能（半能·够出一记波）


## w（可选）= 权重覆盖，透传给基础评估校准（T1）；v2 自身项首轮暂用默认。
static func score(b: BattleCore, player: int, w: Dictionary = {}) -> float:
	if b.game_over:
		return BattleEval.score(b, player, w)   # 终局与基础一致
	var opp: int = 1 - player
	var s := BattleEval.score(b, player, w)
	s += _threat(b, player, opp) - _threat(b, opp, player)
	s += PENDING_W * float(_pending(b, opp) - _pending(b, player))
	return s


## attacker 对 defender 出战英雄的斩杀威胁压力。
static func _threat(b: BattleCore, attacker: int, defender: int) -> float:
	var ds: int = b.active_index[defender]
	# 一次致命伤害会被整次免除，受保护目标不属于“下一拍可斩杀”状态。
	if int(b.get_status(defender, ds, "fatal_damage_immunity", 0)) > 0:
		return 0.0
	var has_attack_resource: bool = b.energy[attacker] >= THREAT_MIN_ENERGY \
		or int(b.item_buffs[attacker].get("free_big_attack_until_turn", -1)) == b.turn_number
	if b.hp[defender][ds] > 0 and b.hp[defender][ds] <= THREAT_HP_LINE and has_attack_resource:
		return THREAT_W
	return 0.0


static func _pending(b: BattleCore, p: int) -> int:
	var t := 0
	for v in b.pending_damage[p]:
		t += int(v)
	for effect_variant in b.timed_item_effects[p]:
		var effect: Dictionary = effect_variant
		var slot: int = int(effect.get("target_slot", -1))
		if String(effect.get("id", "")) == "yaohuo" and slot == b.active_index[p] \
				and slot >= 0 and slot < b.hp[p].size() and b.hp[p][slot] > 0:
			t += int(effect.get("amount", 0))
	return t
