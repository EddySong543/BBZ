extends Node

## Autoload — passes hero lineups between scenes.

var p1_heroes: Array[HeroData] = []
var p2_heroes: Array[HeroData] = []
var overtime := false   # 加时赛局（Q5·2026-07-03）：白板 1v1（阵容=overtime_roster 组的 3 人·板凳 0 血）·无道具经济

# ── 远征 PvE 交接（任务 D·2026-07-06）──
# 去程（expedition_screen 设 → battle_screen 消费）：
var pve_mode := false                 # 本局 = 远征 PvE（怪物驾驶员对手·明牌·可脱离·无 PvP 道具经济）
var pve_monster: Dictionary = {}      # 怪物完整 JSON 定义（assets/data/expedition/monsters.json 条目·驾驶员用）
var pve_monster_hp: int = 0           # 怪物当前 HP（半点·遭遇结算尺 D 强化后·可带上次逃跑残血）
var pve_team: Array = []              # 远征队伍快照：[{name:String, hp:int(半点), hp_max:int(半点)}]（存活者在前）
var pve_equipment: Array = []         # 装备栏战斗道具 id 列表（ItemCatalog id·上限 SLOT_COUNT=3 生效）
# 回程（battle_screen 设 → expedition_screen 消费）：
var pve_result: Dictionary = {}       # {outcome:"win"|"lose"|"flee", beats:int, team_hp:Array[int 半点], monster_hp:int}
# 远征跑动状态（跨场景寄存·battle_screen 不碰·expedition_screen 存取）：
var expedition_state: Dictionary = {} # {map, bp, pending, log, seed, tile:Vector2i, wanderer:bool, flee_from:Vector2i}


## 清空阵容。被 battle_screen 消费后 / 一局结束 / 返回菜单时调用，
## 防止下一局（未重新走 BP）复用上一局残留的阵容。
## ⚠ 不清 pve_result / expedition_state——那是远征回程通道，由 expedition_screen 消费后自清。
func reset() -> void:
	p1_heroes = []
	p2_heroes = []
	overtime = false
	pve_mode = false
	pve_monster = {}
	pve_monster_hp = 0
	pve_team = []
	pve_equipment = []
