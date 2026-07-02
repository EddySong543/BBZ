extends HeroSkill

## h22 毕方【引而后发】主动技 · 节奏 · HP4（引弓蓄力 → 一发强弓·以小博大）
## 主动技「引而后发」(占动作·费 2 能·每局 2 次)：打出一记【穿防的大波】(2.0HP·被大防挡)。
## = 用少于大波(3 能)的能量、每局 2 次投出一发大波级穿防强攻 → 节奏维度「以小动作的费用打出大动作」。
##
## 引擎：攻击型主动技（active_is_attack=true）走 _apply_damage 全管线——能被大防挡、触发 on-hit /
##   罪已昭易伤 / 蛇毒引爆 / 破甲等；不走 execute_active（见 hero_skill.gd 攻击接口）。
##
## 设计依据（design/heroes-dark-h21-h24.md）：维度=节奏·共享原语=能量-tempo 强击（以小博大·punch above weight）。
##   2026-07-01 Eddy 重设计：旧【引而后发·空过存行动→双动作】与暗兔疾风 payoff 同质(都双动作) +
##     STORE 机制 clunky(专用 ActionDef.STORE + 蓄势按钮) → 改主动技「引弓蓄力→一发穿防强弓」。
##   区别暗兔疾风(被动·同回合做两次)：这是主动·单发升级(一发更重、非两个动作)——"多" vs "准"。
##   agency/yomi：每局 2 次珍贵·何时拔弓；对手算你哪回合强弓、备大防(穿防被大防挡)。
##   combo：便宜穿防大波 配龙破甲(压穿大防窗)/罪已昭易伤(放大)/清残血替补；早期能量不足也能突袭强击。
##   旋钮：COST(现 2 能·仅省大波 1 能) / DMG(现 2.0) / active_attack_kind(现穿防) / cap(现 2)。
##   旧 STORE 引擎/UI 机制已于 2026-07-02 全拆（battle_core stored_action/can_store + ActionDef.STORE +
##   hero_skill.grants_action_store + battle_screen 蓄势键），此处仅留设计溯源。

const COST := 4    # 4 半能 = 2 能（比大波 3 能省 1·「引而后发·省去大波部分能量」）
const DMG := 4     # 4 半点 = 2.0HP（大波级）
const CAP := 2     # 每局可用次数（珍贵·何时拔弓的 yomi）


func has_active() -> bool:
	return true

func active_action_id() -> String:
	return "yinfa"

func active_cost(_battle: BattleCore, _player: int, _slot: int) -> int:
	return COST

func active_per_game_cap() -> int:
	return CAP

func can_use_active(battle: BattleCore, player: int, _slot: int) -> bool:
	return battle.hp[1 - player][battle.active_index[1 - player]] > 0   # 敌方出战存活才好放

func active_is_attack() -> bool:
	return true

func active_attack_damage(_battle: BattleCore, _player: int, _slot: int) -> int:
	return DMG

func active_attack_kind() -> int:
	return ActionDef.Action.BIG_ATTACK   # 大波级 = 穿防·被大防挡
