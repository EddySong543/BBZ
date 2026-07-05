extends HeroSkill

## h17 烛阴【阖眸成夜】主动技 · 干扰 · HP6（君临肉龙·控制位）
## 主动技（占动作 · 费 1 能 · 每局 cap 2）：【下回合敌方无法使用能量】——
##   敌方能量冻结一整拍（usable_energy=0·引擎单点收口）：波/大波/大防/主动技/道具补·升全部不可支付，
##   只剩 防/攒/切换/免费道具；能量【收入】照常（被动/攒入池·解冻即可用）。
##
## 2026-07-05 全面重设计（Eddy 批 B 案·验收卷两连败后弃沉默）：
##   旧【镇压·沉默】死因=不产生盘面+价值押在对手被动上（降价✗ 2026-07-04·扩全队✗ 2026-07-05·
##   用后率 1.4+ 但胜率 25.7 纹丝不动=每按期望≈0 实锤）。
##   新机制=原语字典 §5.1【能量冻结】空位落地（呼为冬·烛阴闭眼寒夜封江）：
##   产出=我方【安全蓄爆拍】——冻结拍敌方零攻击可能（道具攻击除外·免费使用不受冻），
##   我方全队免风险攒/蓄势/换人 = 共享时机原语（combo 引擎铁律 ✓）；
##   博弈=施放当拍明牌（结算可见）→ 对手知道下拍被冻 → 抢在冻结前花能量/摆防守（一拍反应窗）；
##   撞检查=h09 紫火碎能是【删存量】、本技是【锁使用权】（存量无损·只冻一拍）——同维不同杠杆。
##   cap：占动作 + 费 1 能 + 每局 2 次；可连拍链冻（两次贴着放=冻两拍·耗尽全部次数·允许）。
##   ⚠ UI 观察位：冻结拍的敌方能量条置灰/冰霜演出待美术期（引擎侧按钮置灰已自动生效）。
## 沉默机制溯源：引擎 Phase 0.3 / _eff_skill 的沉默基建保留（现无英雄使用者·远征怪/道具候选）。

const COST := 2              # 2 半能 = 1 能
const FREEZE_TURNS := 1      # 冻结持续拍数（恰下一拍·按回合号比对零记账）


func has_active() -> bool:
	return true


func active_cost(_battle: BattleCore, _player: int, _slot: int) -> int:
	return COST


func active_per_game_cap() -> int:
	return 2


func can_use_active(battle: BattleCore, player: int, _slot: int) -> bool:
	return battle.hp[1 - player][battle.active_index[1 - player]] > 0   # 敌方出战存活才有冻的对象


func execute_active(battle: BattleCore, player: int, _slot: int) -> void:
	battle.energy_frozen_turn[1 - player] = battle.turn_number + 1   # 下一拍敌方能量冻结
