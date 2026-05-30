class_name BattleEvalV3
extends RefCounted

## v3「熟练优秀卡牌玩家」评估（2026-05-30）。
##
## 在 BattleEval(基础: HP/能量/存活/护盾/燃烧) 之上叠加「牌感」项：
##   - 铺垫/叠层状态价值（连段/蓄势/梅开/团队叠层）→ 让 depth-2 在浅层也「懂」
##     主动技与铺垫的潜在收益（基础 eval 看不到 → v2 几乎不用这些）。
##   - 变身形态（h26 收割）standing buff。
##   - 致命威胁压力（对手出战在斩杀线内 → 我占主动）。
##   - 延迟伤害（h27 已挂在对手头上的债）。
##
## 定位：强在「牌感」而非算力——非大师(不靠深搜穷举)，更接近读盘老练的优秀玩家。
## 零和：所有项均 own−opp，保持与 BattleEval 一致的反对称（双方各解同一矩阵自洽）。

const HP_UNIT := 2

## 铺垫/叠层状态价值（己方 + / 对手 −）。代表「已攒下的潜在收益」，按势打折（< 已实现伤害）。
const SETUP_W := {
	"meikai": 16.0,      # 下个动作 ×2（h14 梅开二度）
	"charge_up": 12.0,   # 下次攻击 +1（h25 蓄势）
	"xuexue": 14.0,      # 全队波 +1/层（h03 渴血）
	"combo": 10.0,       # 连段累进（h09 凶兽）
	"ku": 8.0,           # 减伤层（h04 三窟）
	"yinzhe_atk": 10.0,  # 攻 buff（h22 隐者）
	"yinzhe_def": 8.0,   # 防 buff（h22 隐者）
	"wheel_atk": 8.0,    # 攻 buff（h23 命运之轮）
	"wheel_def": 8.0,    # 防 buff（h23 命运之轮）
}
const FORM_W := 50.0     # h26 收割形态（所有伤害 +1，永久不可逆）
const THREAT_W := 80.0   # 对手出战在大波斩杀线内（≤2HP）且我有 2 能 → 致命威胁压力
const PENDING_W := 8.0   # 延迟伤害（将落在某方头上）/半点


static func score(b: BattleCore, player: int) -> float:
	if b.game_over:
		return BattleEval.score(b, player)   # 终局与基础一致
	var opp: int = 1 - player
	var s := BattleEval.score(b, player)
	s += _setup(b, player) - _setup(b, opp)
	s += _form(b, player) - _form(b, opp)
	s += _threat(b, player, opp) - _threat(b, opp, player)
	s += PENDING_W * float(_pending(b, opp) - _pending(b, player))
	return s


static func _setup(b: BattleCore, p: int) -> float:
	var v := 0.0
	for sl in range(b.hp[p].size()):
		if b.hp[p][sl] <= 0:
			continue
		for key in SETUP_W:
			v += SETUP_W[key] * _as_num(b.get_status(p, sl, key, 0))
	return v


static func _form(b: BattleCore, p: int) -> float:
	var v := 0.0
	for sl in range(b.hp[p].size()):
		if b.hp[p][sl] > 0 and int(b.form[p][sl]) == 1:
			v += FORM_W
	return v


## attacker 对 defender 出战英雄的斩杀威胁压力。
static func _threat(b: BattleCore, attacker: int, defender: int) -> float:
	var ds: int = b.active_index[defender]
	if b.hp[defender][ds] > 0 and b.hp[defender][ds] <= 2 * HP_UNIT and b.energy[attacker] >= 2:
		return THREAT_W
	return 0.0


static func _pending(b: BattleCore, p: int) -> int:
	var t := 0
	for v in b.pending_damage[p]:
		t += int(v)
	return t


static func _as_num(v: Variant) -> float:
	if v is bool:
		return 1.0 if v else 0.0
	return float(v)
