extends Node

## Autoload — passes hero lineups between scenes.

var p1_heroes: Array[HeroData] = []
var p2_heroes: Array[HeroData] = []


## 清空阵容。被 battle_screen 消费后 / 一局结束 / 返回菜单时调用，
## 防止下一局（未重新走 BP）复用上一局残留的阵容。
func reset() -> void:
	p1_heroes = []
	p2_heroes = []
