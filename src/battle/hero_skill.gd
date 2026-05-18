class_name HeroSkill
extends RefCounted

## 英雄技能组件极简基类。
##
## 设计原则（见 docs/architecture/battlecore-risk-notes.md §3）：
##   - 仅放当前迁移需要的 hook
##   - 每个 hook 为 no-op default，子类按需 override
##   - 不预设完整 hook 列表，避免过度设计
##
## 当前 hook：
##   on_attack_calc — h05 龙威迁移引入
## 未来新增 hook 时，更新 risk-notes.md §3 hook 表。


## 攻击伤害计算 hook。在 BattleCore._calc_attack_raw 内调用。
## 子类返回（可能修改后的）伤害值。
##
## 参数：
##   raw_dmg       - 当前已计算的伤害（base damage + 之前 hook 的累加修改）
##   action        - 攻击动作 (BattleCore.Action.ATTACK 或 BIG_ATTACK)
##   battle        - BattleCore 实例（只读使用，禁止修改 state）
##   player        - 攻击方 player index (0 或 1)
##   energy_before - resolve() 开始前的能量快照 Array[int]，长度 2
func on_attack_calc(raw_dmg: int, _action: int, _battle: BattleCore, _player: int, _energy_before: Array) -> int:
	return raw_dmg
