extends SceneTree

## 道具图标导入 / 分配（B·2026-06-20·2026-06-27 改：正式目录图标 = 中文道具名.png，与游戏内名同步）。
## 把 assets/import/ 里【按中文名命名】的图标，同名拷入正式目录 assets/sprites/items/。
## 运行：<godot> --headless --path <proj> --script res://tools/import_item_art.gd
##
## 设计：
## - 校验：源文件中文名须是已实装道具名（ItemCatalog 实时·永不过时）；也容旧 id 命名（向后兼容）。
## - 目标文件名 = ItemCatalog.icon_path(id) = <中文道具名>.png（与显示名一致·便于按名更新美术）。
## - 未匹配（打错字 / 简写 / 该道具还没实装）只报告、不瞎猜。
## - 非破坏式：copy（保留 import 源文件）；确认无误后用户自行清空暂存区。
## - 顺带生成 assets/sprites/items/_name_id_map.md（「中文名 ↔ 代码 id」对照表）。
## - 注：图标现已是中文名，你也可直接把 <中文名>.png 丢进正式目录、跳过本工具。

const SRC := "res://assets/import/"
const MAP_DOC := "res://assets/sprites/items/_name_id_map.md"


func _initialize() -> void:
	_write_map_doc()   # 总是刷新对照表（哪怕没图可导，也产出参考）

	var dir := DirAccess.open(SRC)
	if dir == null:
		push_error("暂存区不存在：%s（请先创建并放入图标）" % SRC)
		quit()
		return

	var name2id: Dictionary = ItemCatalog.name_to_id()
	var known_ids := {}
	for id in ItemCatalog.ids():
		known_ids[id] = true

	var matched := 0
	var unmatched: Array[String] = []
	for f in dir.get_files():
		if not f.to_lower().ends_with(".png"):
			continue   # 跳过 .import / README 等
		var key := f.substr(0, f.length() - 4).strip_edges()   # 去 ".png" + 首尾空白
		var id := ""
		if name2id.has(key):
			id = name2id[key]
		elif known_ids.has(key):
			id = key   # 源文件已按 id 命名 → 原样放行
		if id == "":
			unmatched.append(f)
			continue
		var g_from := ProjectSettings.globalize_path(SRC + f)
		var g_to := ProjectSettings.globalize_path(ItemCatalog.icon_path(id))
		var err := DirAccess.copy_absolute(g_from, g_to)
		if err == OK:
			matched += 1
			print("[导入] %s → %s" % [f, ItemCatalog.icon_path(id).get_file()])
		else:
			push_error("[失败] 复制 %s → %s（err=%d）" % [f, id, err])

	print("\n=== 道具图标导入完成：成功 %d 件 ===" % matched)
	if unmatched.is_empty():
		print("（无未匹配文件）")
	else:
		print("⚠ 未匹配 %d 件（名字对不上·只报告不瞎猜，请对照 %s 核名）：" % [unmatched.size(), MAP_DOC])
		for f in unmatched:
			print("    - %s" % f)
	print("\n提示：matched 文件已【复制】到 assets/sprites/items/；import 源文件保留，确认后可自行清空。")
	print("      再到 Godot 编辑器导入一次（或 --import），游戏里即显示。")
	quit()


## 生成 / 刷新「中文名 ↔ id」对照表（从 ItemCatalog 实时取，按 tier→完整无声调拼音排）。
func _write_map_doc() -> void:
	var items: Array[ItemData] = ItemCatalog.all()   # 已按玩家显示顺序
	var lines: Array[String] = []
	lines.append("# 道具「中文名 ↔ 代码 id」对照表")
	lines.append("")
	lines.append("> 由 `tools/import_item_art.gd` 从 `ItemCatalog` 实时生成，**勿手改**（改了会被覆盖）。")
	lines.append("> **图标文件名 = 中文道具名**（与游戏内显示名一致·按名更新美术）；下表 id 仅代码内部用。")
	lines.append("> ⚠ id 拼音是历史化石、≠ 显示名（如 `t1_siyecao`=最后一箭）；命名美术只看「中文名」列。")
	lines.append("> 当前实装 %d 件，表内各 tier 按显示名全拼排序（设计全集见 design/items-list.md）。" % items.size())
	lines.append("")
	for t in [1, 2, 3]:
		lines.append("## T%d" % t)
		lines.append("")
		lines.append("| 中文名（= 图标文件名） | 代码 id（仅代码内部） | 维度 |")
		lines.append("|---|---|---|")
		for it in items:
			if it.tier == t:
				lines.append("| %s | `%s` | %s |" % [it.item_name, it.item_id, it.dimension])
		lines.append("")
	var fa := FileAccess.open(MAP_DOC, FileAccess.WRITE)
	if fa == null:
		push_error("无法写对照表 %s" % MAP_DOC)
		return
	fa.store_string("\n".join(lines))
	fa.close()
	print("[对照表] 已刷新 %s（%d 件）" % [MAP_DOC, items.size()])
