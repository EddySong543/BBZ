extends GutTest

## UI 只读边界守卫（联机准备批③·2026-07-12）：src/ui 不得对引擎战局状态做字段赋值
## （含 +=/-= 等复合赋值），状态变更一律走 BattleCore 命令面（select_action/use_slot/
## pick_draft/execute_death_switch/...）。联机后 UI=纯展示端，此边界即"客户端不可信"的本地版。
## 白名单：src/ui/debug/（开发调试面·体检 A2 拆出·联机时整体禁用）。
## 规则源=.claude/rules/ui-code.md + 体检 A2「拆出后 UI 只读可一条 grep 断言」——本测试即那条断言。
## 已知盲区：嵌套下标写法（battle.hp[battle.active_index[p]] = x）不在简式正则覆盖内·守卫是绊索非证明。

const UI_DIR := "res://src/ui"
const WHITELIST_PREFIX := "res://src/ui/debug"
# 引擎实例常用局部名 battle/_battle/clone 后跟字段（可带下标）+（复合）赋值；[^=] 排除 ==。
const WRITE_PATTERN := "(?:^|[^\\w.])(?:_?battle|clone)\\.\\w+(?:\\[[^\\]]*\\])*\\s*[-+*/%]?=[^=]"


func test_ui_files_do_not_write_engine_state() -> void:
	# Arrange
	var re := RegEx.new()
	assert_eq(re.compile(WRITE_PATTERN), OK)
	var offenders: Array[String] = []
	# Act：逐文件逐行扫（去掉行内注释部分再匹配）
	var files := _gd_files(UI_DIR)
	assert_gt(files.size(), 5, "src/ui 扫描不应为空（目录结构变了须同步本守卫）")
	for path in files:
		if path.begins_with(WHITELIST_PREFIX):
			continue
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var code: String = lines[i].get_slice("#", 0)
			if re.search(code) != null:
				offenders.append("%s:%d: %s" % [path, i + 1, lines[i].strip_edges()])
	# Assert
	assert_eq(offenders.size(), 0,
		"UI 直写引擎状态（改走 BattleCore 命令面·调试功能挪 src/ui/debug/）:\n" + "\n".join(offenders))


func _gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	da.list_dir_begin()
	var fname := da.get_next()
	while fname != "":
		var p := dir + "/" + fname
		if da.current_is_dir():
			if not fname.begins_with("."):
				out.append_array(_gd_files(p))
		elif fname.ends_with(".gd"):
			out.append(p)
		fname = da.get_next()
	da.list_dir_end()
	return out
