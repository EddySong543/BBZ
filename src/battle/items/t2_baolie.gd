extends ItemEffect

## 爆裂卷轴：本回合「大波」少耗能；费用预览与最终扣费共用纯查询接口。
func action_cost_delta(_battle: BattleCore, _player: int, action: int, data: ItemData) -> int:
	if action == ActionDef.Action.BIG_ATTACK:
		return -int(data.params.get("save", 4))
	return 0
