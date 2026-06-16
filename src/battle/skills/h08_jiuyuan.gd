extends HeroSkill

## h08 未羊【替罪·致死救援】被动 · 防御
## 出战队友将受致死伤害、且未羊在替补席存活时，未羊自动顶上承受这次伤害（救下原队友）；每局限 2 次。
## 引擎在 _apply_damage 致死前检测 is_lethal_guardian → 强制换人(原 carry 下场触发狗)+ 伤害改落羊身上。

func is_lethal_guardian() -> bool:
	return true
