class_name BattleEval
extends RefCounted

## 战局启发式评估 —— AI 决策用。从 player 视角返回分数，越大越有利。
##
## v1 权重（2026-05-30 锁定）。单位 = 半点（1 HP = 2 半点）。
## 设计依据：杀一人 = 去一具身体 + 一套 kit，故 W_ALIVE 远超其残血价值；
##   能量按"2 能 ≈ 一记大波(4 半点伤)"折现 tempo；护盾约半个 HP 价值。
## 仅 1-ply 评估（看一回合后局面），后续按 batch 平衡数据调权重。

const W_WIN := 1000000.0     # 终局胜/负（绝对优先）
const W_ALIVE := 600.0       # 每多存活 1 英雄
const W_HP := 10.0           # 每半点 HP 差（1 HP = 2 半点 = 20 分）
const W_SHIELD := 6.0        # 每半点护盾差
const W_ACTIVE_HP := 4.0     # 出战位 HP 差额外加权（前线存活更重要）
const W_BURN := 30.0         # 出战位燃烧（易伤 +1.0 / 禁回血）

## 能量边际递减：前 ENERGY_FULL_CAP 能（够一记大波）满价 W_ENERGY，
## 之后每点仅 W_ENERGY_EXTRA → 抑制 1-ply 短视下的"无意义屯能不出手"。
const W_ENERGY := 12.0       # 前 2 能每点价值
const W_ENERGY_EXTRA := 3.0  # 超过 2 能后每点价值（边际递减）
const ENERGY_FULL_CAP := 2   # 满价能量上限（= 大波费用）


static func score(b: BattleCore, player: int) -> float:
	var opp: int = 1 - player

	# 终局：压倒一切
	if b.game_over:
		if b.winner == player + 1:
			return W_WIN
		if b.winner == opp + 1:
			return -W_WIN
		return 0.0  # 平局

	var s := 0.0
	s += W_ALIVE * float(b.alive_count(player) - b.alive_count(opp))
	s += W_HP * float(_hp_sum(b, player) - _hp_sum(b, opp))
	s += _energy_value(b.energy[player]) - _energy_value(b.energy[opp])
	s += W_SHIELD * float(_shield_sum(b, player) - _shield_sum(b, opp))
	s += W_ACTIVE_HP * float(_active_hp(b, player) - _active_hp(b, opp))

	# 燃烧：对手出战中烧 = 利好；自己出战中烧 = 不利
	if int(b.get_status(opp, b.active_index[opp], "burn", 0)) > 0:
		s += W_BURN
	if int(b.get_status(player, b.active_index[player], "burn", 0)) > 0:
		s -= W_BURN

	return s


## 能量的边际递减价值：前 2 能满价，之后廉价。
static func _energy_value(e: int) -> float:
	var full: int = mini(e, ENERGY_FULL_CAP)
	var extra: int = maxi(e - ENERGY_FULL_CAP, 0)
	return W_ENERGY * float(full) + W_ENERGY_EXTRA * float(extra)


static func _hp_sum(b: BattleCore, p: int) -> int:
	var t := 0
	for v in b.hp[p]:
		t += maxi(int(v), 0)   # 溢杀负血不放大对方亏空
	return t


static func _shield_sum(b: BattleCore, p: int) -> int:
	var t := 0
	for v in b.shield[p]:
		t += int(v)
	return t


static func _active_hp(b: BattleCore, p: int) -> int:
	return maxi(b.hp[p][b.active_index[p]], 0)
