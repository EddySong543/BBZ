extends GutTest

## 架构护栏：UI 层【只读】引擎状态 —— 绝不直接改写 BattleCore 的 hp / energy / shield / max_hp / heroes。
## UI 只能通过命令 / 信号请求引擎改状态；直写 = 联机时的作弊面。
## 唯一允许改写处 = src/ui/debug/battle_debug_panel.gd（DEBUG 作弊面板·联机不启用·本测试排除）。
## 体检 A2（2026-07-02）：debug 块从 battle_screen 拆出后立此断言防回归（之前 battle_screen 有 8 处直写）。

const UI_ROOT := "res://src/ui"

## 匹配「battle.<字段>[...] （可多层下标） = / += / -=」的写操作；\b 排除 _battle（debug 面板用 _battle）；
## =[^=] 排除 == 比较、只抓赋值。
const WRITE_PATTERN := "\\bbattle\\.(hp|energy|shield|max_hp|heroes)(\\[[^\\]]*\\])+\\s*(=[^=]|\\+=|-=)"


func test_ui_layer_does_not_write_engine_state() -> void:
	# Arrange
	var re := RegEx.new()
	assert_eq(re.compile(WRITE_PATTERN), OK, "写操作正则应编译成功")

	# Act：遍历 src/ui 全部 .gd（排除 debug/ 作弊面板），收集直写引擎状态的文件与行
	var offenders: Array[String] = []
	for path in _gd_scripts(UI_ROOT):
		if path.contains("/debug/"):
			continue
		var src := FileAccess.get_file_as_string(path)
		var m := re.search(src)
		if m != null:
			offenders.append("%s → %s" % [path, m.get_string().strip_edges()])

	# Assert
	assert_true(offenders.is_empty(),
		"UI 层不得直写引擎状态（应只读·改写请走命令/信号，或隔离到 debug 面板）：\n  %s" % "\n  ".join(offenders))


## 递归收集目录下所有 .gd 脚本路径。
func _gd_scripts(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if d.current_is_dir():
			out.append_array(_gd_scripts(full))
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = d.get_next()
	d.list_dir_end()
	return out
