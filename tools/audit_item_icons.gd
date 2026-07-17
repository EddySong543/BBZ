extends SceneTree

## 道具图标缺图盘点（2026-07-17 技术债#6·可重复跑·只报告不改动）：
## 遍历 ItemCatalog 全部现役 id → icon_path 源文件存在性 → 缺图按 tier 分组列名+计数。
##   godot --headless --path . --script res://tools/audit_item_icons.gd

const ItemCatalogRef := preload("res://src/battle/item_catalog.gd")


func _initialize() -> void:
	var all: Array = ItemCatalogRef.ids()
	var have: int = 0
	var missing: Dictionary = {1: [], 2: [], 3: []}
	for id: String in all:
		var it: ItemData = ItemCatalogRef.make(id)
		if it == null:
			print("[audit] ⚠ make 失败: %s" % id)
			continue
		var path: String = ItemCatalogRef.icon_path(id)
		if FileAccess.file_exists(ProjectSettings.globalize_path(path)):
			have += 1
		else:
			(missing[int(it.tier)] as Array).append(id)
	print("=== 道具图标盘点：共 %d 件·有图 %d·缺图 %d ===" % [all.size(), have, all.size() - have])
	for t: int in [1, 2, 3]:
		var m: Array = missing[t]
		if m.is_empty():
			print("T%d: 全齐" % t)
		else:
			print("T%d 缺 %d: %s" % [t, m.size(), "、".join(m)])
	quit(0)
