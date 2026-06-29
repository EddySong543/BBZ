extends HeroSkill

## h23 天狗【护主 / 忠犬】被动 · 防御 · HP6（替死守护·解放激进打法）
## 在替补席存活时，出战队友受【致命一击】→ 娄金冲上替它挡下：这一击完全免除、娄金碎掉下场、
##   出战 carry 留前线续战（每局一次）。与鬼金【致死救援】区别 = 自我牺牲、carry 不退场不打断节奏/蓄势。
##
## 引擎：BattleCore._apply_damage 致死前查 _find_protect_guardian（is_protect_guardian + huzhu_uses<HUZHU_CAP）
##   → 狗 hp 置 0(替补位阵亡·Phase 5 正常结算·触发室火饕餮等) + 计 huzhu_uses + 这一击 return 0(完全免除)。
##
## 设计依据（design/heroes-dark-h21-h24.md）：维度=防御·共享原语=安全网（使能暗虎血勇/暗鸡蓄势/脆皮
##   over-extend）。⚠ 接手原鬼金 h08"守护"定位（鬼金 h08 已转【牧养】h08_muyang）。对手 yomi=先点死替补席的狗破保险。

func is_protect_guardian() -> bool:
	return true
