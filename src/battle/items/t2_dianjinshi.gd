extends ItemEffect

## 点金石在 use_slot 阶段按显式槽位目标即时升级；S 相位不得重复处理。
func apply_pre(_battle: BattleCore, _player: int, _target: int, _data: ItemData) -> void:
	pass
