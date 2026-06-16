extends HeroSkill

## h01 子鼠【囤鼠】被动 · 能量
## 子鼠出战时，己方获得的所有能量 +1（每个获得事件 +ENERGY_UNIT 半能）。
## 引擎 _gain_energy() 统一读 energy_gain_bonus 应用——攒 / 被动 / 受伤转化等所有入口。

func energy_gain_bonus(_battle: BattleCore, _player: int, _slot: int) -> int:
	return ActionDef.ENERGY_UNIT
