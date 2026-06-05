extends HeroSkill

## h12 亥猪【吞噬】主动 0 能 · cap 3 · 单英雄（buff 型吸血）
## 发动挂「吞噬」buff（占动作槽、本身不攻击）→ 之后【下一次攻击】（波/大波，无论方式）发起即消耗 buff：
##   若该次成功造成伤害，按实际造成量回等量 HP；被格挡 / 未造成伤害则 buff 白费（也消耗）。
## buff 跟随亥猪槽位（切下场再上场仍有效）；回血走 _heal（含燃烧禁疗判定）。

func has_active() -> bool:
	return true

func active_action_id() -> String:
	return "tunshi"

func active_cost(_battle: BattleCore, _player: int, _slot: int) -> int:
	return 0

func active_per_game_cap() -> int:
	return 3

func execute_active(battle: BattleCore, player: int, slot: int) -> void:
	battle.set_status(player, slot, "tunshi_buff", true)   # 挂吸血 buff，待下次攻击兑现

func on_resolve_end(battle: BattleCore, player: int, slot: int) -> void:
	# 下一次攻击发起即消耗 buff（被挡也消耗）；本回合成功造成伤害才回等量血。
	if not battle.get_status(player, slot, "tunshi_buff", false):
		return
	var act: int = battle.selected_action[player]
	if act == ActionDef.Action.ATTACK or act == ActionDef.Action.BIG_ATTACK:
		battle.set_status(player, slot, "tunshi_buff", false)
		var dealt: int = battle.get_dmg_dealt(player)
		if dealt > 0:
			battle._heal(player, slot, dealt)
