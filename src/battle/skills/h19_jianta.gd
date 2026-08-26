extends HeroSkill

## h19 乌骓【奔雷】被动 · 进攻 · HP5
## 乌骓的基础攻击穿过防御门后，主目标至多承受 1.0 HP；最终伤害超过 1.0 HP 的部分
## 转移给当前生命最高的另一名存活敌方英雄。并列时按固定槽位顺序选择，保证结算确定性。
## 转移是真正的伤害守恒，不在主目标吃满后复制伤害；没有另一名存活敌人时余量丢失。
## 两段伤害分别经过各自目标的护甲，转移段不重复计算增伤、脆弱或英雄减伤。


func base_attack_excess_transfer_threshold(_action: int, _battle: BattleCore,
		_player: int, _slot: int) -> int:
	return ActionDef.HP_UNIT
