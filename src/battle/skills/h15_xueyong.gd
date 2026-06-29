extends HeroSkill

## h15 穷奇【凌云蔽日】被动 · 进攻 · HP7（厚血狂战）
## 穷奇嗜杀红温、有进无退：
##   ① 无法使用「防 / 大防」（can_defend → false；引擎在 can_afford gate 掉，下场即恢复）；
##   ② 作为补偿，其「波」穿防（attack_penetration：波 → PIERCE_DEF）——对手须用「大防」才挡得下；
##      大波保持原穿防不变（不升穿大防：穿大防是铁则保留给「公开慢蓄 payoff」，禁便宜常驻）。
##
## 设计依据（heroes-redesign / build-design-framework）：
##   暗镜 = 明虎 h03【连扑】(脆皮 HP4·章法连扑·放大队友命中次数·上游放大器)
##         → 暗虎【血勇】(厚血 HP7·失控狂暴·把自己的防御一并烧了换穿透·硬穿对手盾)。
##         明=收着打的群体放大(产 procs)，暗=不要命的破坏者(穿防保送·防不掉必中)。
##   维度 = 进攻(由角色形象「力量/狂战士」出发·2026-06-22 Eddy 定 B1)。整体避开 HP 阈值
##         (处决线/阈值狂化血量数值难调·已弃)，改「常驻取舍」表达力量——永远成立、不吃血线。
##   §4.4 偏移规则：波穿防 = 超标 → 由「彻底不能防御」这一巨大负面买单(超标必带负面)。
##   铁则：波穿防 = 穿透一档(PIERCE_DEF·防挡不住/大防挡得住)，clean；不能防御 = 二元自限(WHETHER)。
##   combo：波穿防 = 保送命中 → 必中地喂全队 on-hit 收割端(蛇毒爆/鸡剑气/龙破甲)；
##         不能防御(玻璃坦克) → 配室火(受伤转能)/娄金(护主替死)护住 = 系间乘算。
##   博弈：对手「防」对你失效 → 只能掏贵的大防/换人/对拼；你不能龟 → 必须算 race。
##   旋钮：穿透档(波穿防 vs 仅大波) / HP7。不撞现役英雄(碎能=猴/破甲=龙/穿透升级=鸡 各不同)。


func can_defend() -> bool:
	return false   # 血勇：嗜杀红温·彻底放弃防御


func attack_penetration(base_pen: int, action: int, _battle: BattleCore, _player: int, _slot: int) -> int:
	if action == ActionDef.Action.ATTACK:
		return ActionDef.Pen.PIERCE_DEF   # 波穿防：防挡不住、需大防
	return base_pen   # 大波等保持原穿透档
