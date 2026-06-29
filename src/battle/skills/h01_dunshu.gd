extends HeroSkill

## h01 虚日【耀夜流晖】被动 · 能量
## 虚日出战时，己方获得的所有能量 +0.5（每个获得事件 +1 半能）。
## 引擎 _gain_energy() 统一读 energy_gain_bonus 应用——攒 / 被动 / 受伤转化等所有入口。
## （囤鼠每次得能 +0.5 为 2026-06-21 Eddy 由 +1 调整；h13 玄冥已改设计为【破绽】、不再与本被动对称。）

func energy_gain_bonus(_battle: BattleCore, _player: int, _slot: int) -> int:
	return 1   # +0.5 能 = 1 半能
