extends HeroSkill

## h17 烛阴【阖眸成夜】主动技 · 干扰 · HP6（君临肉龙·控制位）
## 主动技「镇压」(占动作·费 1 能·每局 cap 2)：沉默对手【全队】英雄（含替补·存活者）——
##   unique 完全失效（所有被动 hook 不触发 / 主动技不可用），持续 2 回合（下回合起算）。
## 2026-07-05 平衡批②（Eddy 批 A 案）：作用域 出战单体 → 全队。验收卷 25.7% 垫底且用后率 1.10
##   （AI 会用·驾驶混杂已排除）→ 病根 = 单体沉默每按价值太看对手、还能被切换洗掉；全队沉默罩住
##   替补席被动（护主/回春/纳福）、价值不再看脸——"阖眸成夜"=全场入夜。历史：07-04 费 2→1 能（无效刀）。
##
## 引擎实现（沉默 = 全 hook 统一收口）：
##   execute_active 给敌方全部存活 slot 写 "silenced" = SILENCE_TURNS；
##   BattleCore.resolve() 开头把 silenced>0 的英雄 _skills 槽临时【置 null】（引擎全程 null-check=无 unique），
##     resolve 末还原 + 递减（只递减本回合生效过的；cast 当回合 silenced 在 swap 之后才写入 → 不计 → 恰好 2 个完整回合）；
##   主动技不可用 / 防·切换 选择门 由 BattleCore._eff_skill() 在选择阶段统一 gate。
##
## 设计依据（heroes-redesign / build-design-framework）：
##   维度 = 干扰（"锁能力"赛道 · roster 全新共享原语【沉默】）。弃旧【逼战】(依赖被动能量·2026-06-24 去被动后报废)。
##   不撞：紫火=锁能量(碎能·蒸发存量) / 暗蛇=锁机动(锁切换) / 光龙=破甲(降防级)——三条不同杠杆、可叠成暗系控制流派。
##   combo（控制/保护型，非"产原语乘算"·Eddy 2026-06-24 选 A 接受此定位）：沉默对手反应/安全网
##     (娄金护主 / 牛金反震 / 任意关键被动) → 我方布毒/破甲/切人收割不被干扰；配暗蛇(全锁死)/娄金(逼切换→真伤钳形)。
##     坦诚短板：价值看对手带啥(对被动越依赖越值)、且【与道具不 combo】(沉默只碰英雄 unique)。
##   博弈：我挑何时镇压谁(对手亮威胁时按下)；对手可切换把被沉默英雄换下(吃 tempo / 撞暗蛇锁切换)。
##   cap：占动作 + 费 1 能(2026-07-04 降价) + 每局 2 次；作用敌方全队(2026-07-05 起·原"只作用当前出战"废)；延迟 1 回合起效(对手有一拍预判窗口)。HP6 肉龙=控制位身份自洽。

const COST := 2              # 2 半能 = 1 能（2026-07-04 平衡 2→1 能·Eddy 批：510 局 27.6% 垫底+0.26 次/局=太贵没人按；cap 2 兜上限）
const SILENCE_TURNS := 2     # 沉默持续回合数（下回合起算的完整回合数）


func has_active() -> bool:
	return true


func active_cost(_battle: BattleCore, _player: int, _slot: int) -> int:
	return COST


func active_per_game_cap() -> int:
	return 2


func can_use_active(battle: BattleCore, player: int, _slot: int) -> bool:
	return battle.hp[1 - player][battle.active_index[1 - player]] > 0   # 敌方出战存活才好镇压


func execute_active(battle: BattleCore, player: int, _slot: int) -> void:
	var e: int = 1 - player
	for s in range(battle.hp[e].size()):
		if battle.hp[e][s] > 0:
			battle.set_status(e, s, "silenced", SILENCE_TURNS)   # 沉默敌方全队（含替补·2026-07-05 起）
