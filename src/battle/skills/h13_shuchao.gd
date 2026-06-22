extends HeroSkill

## h13 黑暗子鼠【鼠潮】被动 · 能量 · HP4（脆）
## 暗鼠在场（含替补·存活）时，己方【每触发一次 combo 效果】→ 团队能量 +0.5（每回合封顶 1.5 能）。
## 战场越乱、鼠群越肥：把"全队 combo 活动"翻译成"全队燃料"，再循环放大更多 combo。
##
## 计入的 combo proc（引擎在各结算点调 BattleCore._note_combo_proc）：
##   毒爆(蛇) / 易伤 marked(猎物印记) / 破甲(龙) / 碎能(猴) / 剑意(鸡) / 反震(牛) / 冲撞(马) / 溢杀(暗牛)。
##   纯白板波（无任何附加效果的普通命中）不计 —— 奖励的是【combo 密度】，不是攻击次数。
##   寅虎双段 = 自动喂两份（hc=2 让 on-hit 派发翻倍 → 破甲/碎能/剑意 各触发两次）。
##
## 设计依据（heroes-redesign / build-design-framework）：
##   维度 = 能量（继承子鼠光版「囤鼠」的能量维度·镜维度强制·2026-06-22 Eddy 定）。
##     与囤鼠（每次得能 +0.5）/ 纳福（受伤→能）触发面全不同：鼠潮 = combo→能量。
##   定位 = 泛连携引擎（§7）：自身平庸（HP4·单出战几乎不产能），强度全在队友的 combo 上。
##     共享原语 = 「combo → 能量」—— 挂在全队每一个 combo proc 的下游，连通度最高的那种。
##     系间乘算（§6）：combo 越密 → 经济越快 → 部署更多 combo 件 → 又触发更多 proc。
##   agency / yomi：你主动编排"高 proc 回合"滚能量；对手被逼掐链（抢在引爆前换人 / 优先点掉脆皮鼠 = 关引擎）。
##   §4.4：低标泛连携（放宽）；回路（combo→能→combo）已显式标注 + 装刹车（每回合封顶 1.5 能·见 §6）；
##     PvE 远征可解封顶（§10：回路在 PvE 可指数放飞）。
##   二元铁则无涉（不碰护甲 / 穿透）；纯被动 0 代价（被动优先·快节奏）。
##
## 【实现注记】鼠潮 = 团队级在场光环，必须监听【他人】的 combo（不限暗鼠是否出战），
##   故不走单英雄 per-hit hook，而由 BattleCore._note_combo_proc 在各 combo 结算点统一收口、
##   扫队伍存活英雄的 combo_proc_energy() 求和（本组件唯一 override 的 hook）。

const PROC_ENERGY := 1   # 每次 combo proc 返还 1 半能 = +0.5 能（cap 由 BattleCore.SHUCHAO_CAP_PER_TURN 控）


func combo_proc_energy() -> int:
	return PROC_ENERGY
