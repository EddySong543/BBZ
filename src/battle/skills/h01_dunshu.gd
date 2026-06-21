extends HeroSkill

## h01 子鼠【囤鼠】被动 · 能量
## 子鼠出战时，己方获得的所有能量 +0.5（每个获得事件 +1 半能）。
## 引擎 _gain_energy() 统一读 energy_gain_bonus 应用——攒 / 被动 / 受伤转化等所有入口。
## 与 h13 黑暗子鼠【封窟】对称（囤鼠增己 0.5 能 / 暗鼠封敌 0.5 能·2026-06-21 Eddy 由 +1 调为 +0.5）。

func energy_gain_bonus(_battle: BattleCore, _player: int, _slot: int) -> int:
	return 1   # +0.5 能 = 1 半能
