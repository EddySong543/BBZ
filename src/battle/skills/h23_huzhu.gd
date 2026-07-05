extends HeroSkill

## h23 天狗【御凶】被动 · 防御 · HP6（顶替守护·解放激进打法）
## 在替补席存活时，我方英雄受【致命伤害】→ 天狗立刻登场顶替：原 carry 退居替补获救、
##   这一击改落到天狗身上（天狗吃这下·可能被这下打死）+ 登场 1.0 护盾垫伤（2026-07-04）
##   + 对攻击者【反击 1.0 真伤】（2026-07-05 批③·走管线打击可喂原语）。【每局两次】（批③ 1→2）。
##   （2026-07-01 Eddy 改：旧「完全免除 + 天狗自我碎掉·carry 留前线」→「顶替登场承伤·carry 退场获救」。）
## 批③诊断（三轮垫底 26.8/30.2/28.6·Eddy 批 C 案=次数+反击双刀）：每局一次的纯保险期望增值太小、
##   骗掉一次即失效；次数 2 = 常设威慑（对手集火策略被迫改变），反击 = 救场变"救场+复仇"。
##
## 引擎：BattleCore._apply_damage 致死前查 _find_lethal_guardian（is_lethal_guardian + huzhu_uses<HUZHU_CAP）
##   → _perform_switch 让天狗登场(carry 退替补) + 计 huzhu_uses + 这一击改落天狗(走正常落 HP·天狗可能阵亡)。
##
## 设计依据（design/heroes-dark-h21-h24.md）：维度=防御·共享原语=安全网（使能暗虎血勇/暗鸡蓄势/脆皮
##   over-extend）。⚠ 接手原鬼金 h08"守护"定位（鬼金 h08 已转【牧养】h08_muyang）。对手 yomi=先点死替补席的天狗破保险。

func is_lethal_guardian() -> bool:
	return true
