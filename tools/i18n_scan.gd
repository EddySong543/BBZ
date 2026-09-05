extends SceneTree
## i18n 键表扫描器（M4·2026-07-12·「原文即键」方案，见 ADR-004 Migration M4）。
##
## 收集全库面向玩家的中文串 → 生成翻译键表 CSV（键=中文原文；en 列空待翻译）。
## 可重复跑：文案变动后重跑即再生键表（生成物勿手改）。
##
## 用法：godot --headless --path . -s tools/i18n_scan.gd
## 输出：assets/i18n/strings_zh.csv（目录带 .gdignore=Godot 不导入；
##       翻译启用时：移除 .gdignore + 去掉 context 列 + project.godot 注册 translations）。
##
## 采集面（与包裹批口径一致）：
##   1. src/**/*.gd 里的 tr("...") 字面量实参
##   2. src/ui 里未包裹但经动态汇点显示的中文字面量
##      （工厂函数实参/常量表值/默认参数——汇点已 tr(变量)）
##   3. assets/data/heroes/*.tres 的 hero_name / skill_description / skill_detail
##   4. src/battle/item_catalog.gd 的 name / desc / flavor 数据字段
##   5. src/ui/**/*.tscn 的 text / tooltip_text / placeholder_text / card_* 属性
## 排除面：注释、push_*/printerr/assert（dev 向）、@export_group/enum（编辑器向）、
##   作字典键的维度色表（"进攻": Color(...)）、src/ui/debug、title_logo/pixel_glyphs（字形美术）、
##   src/expedition（占位内容·缓办，见 active.md 后续）。

const OUT_CSV := "res://assets/i18n/strings_zh.csv"
const LINE_EXCLUDE := "push_error|push_warning|printerr|assert\\(|@export_group|@export_enum"
const FILE_EXCLUDE: Array[String] = ["/ui/debug/", "title_logo.gd", "pixel_glyphs.gd"]

var _re_han := RegEx.new()
var _re_str := RegEx.new()
var _re_line_excl := RegEx.new()
var _re_tres := RegEx.new()
var _re_item := RegEx.new()
var _re_item_flavor := RegEx.new()
var _re_tscn := RegEx.new()
var _keys := {}   # 原文 -> Array[String] 出处（file:line，最多记 3 处）


func _init() -> void:
	_re_han.compile("\\p{Han}")
	_re_str.compile("\"((?:[^\"\\\\]|\\\\.)*)\"")
	_re_line_excl.compile(LINE_EXCLUDE)
	_re_tres.compile("^(hero_name|skill_description|skill_detail)\\s*=\\s*\"(.*)\"")
	_re_item.compile("\\b(name|desc|flavor)\\s*=\\s*\"((?:[^\"\\\\]|\\\\.)*)\"")
	# ItemCatalog 的 flavor 位于 _FLAVOR 的 `"显示名": "风味"` 字典，而非 flavor = 字段。
	_re_item_flavor.compile("^\\s*\"(?:[^\"\\\\]|\\\\.)+\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)\"")
	_re_tscn.compile("^(text|tooltip_text|placeholder_text|card_title|card_subtitle|card_caption)\\s*=\\s*\"(.*)\"")

	# ① tr() 实参（全 src）＋ ② ui 动态汇点字面量
	for f in _walk("res://src", ".gd"):
		_scan_gd(f, f.contains("/ui/"))
	# ③ 英雄数据
	for f in _walk("res://assets/data/heroes", ".tres"):
		_scan_by_regex(f, _re_tres, 2)
	# ④ 道具目录
	_scan_by_regex("res://src/battle/item_catalog.gd", _re_item, 2)
	_scan_by_regex("res://src/battle/item_catalog.gd", _re_item_flavor, 1)
	# ⑤ 场景文本属性
	for f in _walk("res://src/ui", ".tscn"):
		_scan_by_regex(f, _re_tscn, 2)

	_write_csv()
	print("i18n_scan: %d keys -> %s" % [_keys.size(), OUT_CSV])
	quit()


func _walk(dir_path: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		var p := dir_path + "/" + f
		if d.current_is_dir():
			if not f.begins_with("."):
				out.append_array(_walk(p, ext))
		elif f.ends_with(ext):
			var skip := false
			for pat in FILE_EXCLUDE:
				if p.contains(pat):
					skip = true
			if p.contains("/expedition/"):
				skip = true
			if not skip:
				out.append(p)
		f = d.get_next()
	return out


## .gd 逐行扫：tr("...") 恒收；display_pass=true 时额外收未包裹的中文字面量。
func _scan_gd(path: String, display_pass: bool) -> void:
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return
	var lines := fa.get_as_text().split("\n")
	for i in lines.size():
		var line := lines[i]
		if line.strip_edges().begins_with("#"):
			continue
		if _re_line_excl.search(line) != null:
			continue
		for m in _re_str.search_all(line):
			var raw := m.get_string(1)
			if _re_han.search(raw) == null:
				continue
			var end := m.get_end()
			# 维度色表等「中文作字典键」：`"进攻": Color(` → 逻辑键不进表
			if line.substr(end).strip_edges().begins_with(": Color("):
				continue
			var wrapped := m.get_start() >= 4 and line.substr(m.get_start() - 3, 3) == "tr("
			if wrapped or display_pass:
				_add(raw.c_unescape(), "%s:%d" % [path.trim_prefix("res://"), i + 1])
	fa.close()


func _scan_by_regex(path: String, re: RegEx, group: int) -> void:
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return
	var lines := fa.get_as_text().split("\n")
	for i in lines.size():
		for m in re.search_all(lines[i]):
			var raw := m.get_string(group)
			if _re_han.search(raw) != null:
				_add(raw.c_unescape(), "%s:%d" % [path.trim_prefix("res://"), i + 1])
	fa.close()


func _add(key: String, ctx: String) -> void:
	if key.is_empty():
		return
	if not _keys.has(key):
		_keys[key] = []
	var arr: Array = _keys[key]
	if arr.size() < 3 and not arr.has(ctx):
		arr.append(ctx)


func _write_csv() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/i18n")
	var fa := FileAccess.open(OUT_CSV, FileAccess.WRITE)
	var sorted: Array = _keys.keys()
	sorted.sort()
	fa.store_line("keys,en,context")
	for k: String in sorted:
		fa.store_line("%s,,%s" % [_csv(k), _csv(", ".join(_keys[k]))])
	fa.close()


func _csv(s: String) -> String:
	return "\"%s\"" % s.replace("\"", "\"\"")
