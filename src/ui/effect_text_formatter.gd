extends RefCounted
class_name EffectTextFormatter

## 英雄图鉴与战斗说明共用的效果词排版规则。
## 只负责删去已由效果图鉴承担的百科行、识别效果词和提供同款粗体字体；
## 不改写技能/道具原文，也不通过换色表达强调。

const EffectCatalogScript := preload("res://src/battle/effect_catalog.gd")
const EMBOLDEN := 0.8
const KEYWORD_SIDE_GAP := 1.0
const META_LINE_ID := &"codex_effect_line_id"
const META_LINE_CENTER_X := &"codex_effect_line_center_x"
const META_RUN_ORDER := &"codex_effect_run_order"
const META_GAP_BEFORE := &"codex_effect_gap_before"
const META_GAP_AFTER := &"codex_effect_gap_after"


static func concise(text: String) -> String:
	var kept_lines: PackedStringArray = []
	for raw_line: String in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or _is_glossary_line(line):
			continue
		kept_lines.append(line)
	return "\n".join(kept_lines)


static func _is_glossary_line(line: String) -> bool:
	for entry: Dictionary in EffectCatalogScript.all():
		var effect_name := String(entry.name)
		if line.begins_with(effect_name + "：") or line.begins_with(effect_name + ":"):
			return true
	return false


## 返回互斥文本片段；任一字符只属于一个片段，调用方不得再把粗体片段叠到全文上。
static func split_runs(text: String) -> Array[Dictionary]:
	var keywords: Array[String] = []
	for entry: Dictionary in EffectCatalogScript.all():
		keywords.append(String(entry.name))
	var runs: Array[Dictionary] = []
	var cursor := 0
	while cursor < text.length():
		var next_index := -1
		var next_keyword := ""
		for keyword: String in keywords:
			var found := text.find(keyword, cursor)
			if found < 0:
				continue
			if next_index < 0 or found < next_index \
					or (found == next_index and keyword.length() > next_keyword.length()):
				next_index = found
				next_keyword = keyword
		if next_index < 0:
			_append_run(runs, text.substr(cursor), false)
			break
		if next_index > cursor:
			_append_run(runs, text.substr(cursor, next_index - cursor), false)
		_append_run(runs, next_keyword, true)
		cursor = next_index + next_keyword.length()
	return runs


static func _append_run(runs: Array[Dictionary], text: String, bold: bool) -> void:
	if text.is_empty():
		return
	if not runs.is_empty() and bool(runs[-1]["bold"]) == bold:
		var previous: Dictionary = runs[-1]
		previous["text"] = String(previous["text"]) + text
		runs[-1] = previous
	else:
		runs.append({"text": text, "bold": bold})


static func make_bold_font(base_font: Font) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = base_font
	font.variation_embolden = EMBOLDEN
	return font
