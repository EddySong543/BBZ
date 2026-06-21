class_name BattleEvalV3
extends RefCounted

## v3「熟练优秀卡牌玩家」评估（2026-05-30）。
##
## 在 BattleEval(基础: HP/能量/存活/护盾) 之上叠加「牌感」项：
##   - 致命威胁压力（对手出战在斩杀线内 → 我占主动）。
##   - 延迟伤害（道具妖火/藤蔓挂在对手头上的债·PENDING_W）。
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


## w（可选）= 权重覆盖，透传给基础评估校准（T1）；v3 自身项首轮暂用默认。
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
	if b.hp[defender][ds] > 0 and b.hp[defender][ds] <= THREAT_HP_LINE and b.energy[attacker] >= THREAT_MIN_ENERGY:
		return THREAT_W
	return 0.0


static func _pending(b: BattleCore, p: int) -> int:
	var t := 0
	for v in b.pending_damage[p]:
		t += int(v)
	return t
