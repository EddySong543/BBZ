extends HeroSkill

## h24 黑暗亥猪【饕餮 / 食腐】被动 · 能量 · HP6（死亡产能·配击杀节奏）
## 在场（含替补·存活）时，战场上【任一】英雄阵亡（敌我皆可）→ 你方【团队】+2.0 能（从死亡盛宴暴食）。
##
## 引擎：BattleCore._resolve_deaths 每个死亡点扫双方存活英雄的 death_energy_bonus() 累计、_gain_energy 入账
##   （死者已 hp≤0 自动不计 = 尸不自食；敌我死亡皆喂）。
##
## 设计依据（design/heroes-dark-h21-h24.md）：维度=能量·共享原语=死亡产能（roster 唯一空触发面）。
##   配断罪处决/践踏踏死/戌狗真伤/集火清场 → 死亡 → 暴食 → 能量回头喂大波/道具再压。敌我皆吃 = 残局反转。
##   平衡：绑"死亡"低频高代价事件 → 爆发式非稳产、空窗期不产能（即便能量警戒最高的维度也安全）。2.0 能/死可调。

const FEAST_ENERGY := 4   # 4 半能 = 2.0 能/死（旋钮·可调 1.0/1.5/2.0）


func death_energy_bonus() -> int:
	return FEAST_ENERGY
