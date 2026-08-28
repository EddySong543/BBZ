extends RefCounted
class_name EffectTextFormatter

## 英雄图鉴与战斗说明共用的效果词排版规则。
## 只负责删去已由效果图鉴承担的百科行、识别效果词和提供同宽字体片段；
## 不改写技能/道具原文。强调统一使用右上角星芒与小幅加粗，不再改变字色。

const EffectCatalogScript := preload("res://src/battle/effect_catalog.gd")
const EMBOLDEN := 0.32
## 星芒是覆盖绘制，不参与 Label 自身宽度：前侧不得插空，否则中文短语会被拆开；
## 后侧必须完整预留“词尾外移 1px + 7px 星芒 + 1px 呼吸位”。
const KEYWORD_GAP_BEFORE := 0.0
const KEYWORD_GAP_AFTER := 9.0
const KEYWORD_SPARK_OFFSET := Vector2(1.0, -3.0)
## RichTextLabel 无法给覆盖子节点参与排流；字宽由 EN SPACE 提供，两侧 WORD JOINER 禁止在角标内换行。
const KEYWORD_TRAILING_SPACER_GLYPH := "\u2002"
const KEYWORD_TRAILING_SPACER := "\u2060" + KEYWORD_TRAILING_SPACER_GLYPH + "\u2060"
const UNEMPHASIZED_EFFECTS: Array[String] = [
	"附加效果",
	"护甲",
	"穿防",
	"穿大防",
]
const META_LINE_ID := &"codex_effect_line_id"
const META_LINE_CENTER_X := &"codex_effect_line_center_x"
const META_RUN_ORDER := &"codex_effect_run_order"
const META_GAP_BEFORE := &"codex_effect_gap_before"
const META_GAP_AFTER := &"codex_effect_gap_after"
const META_IS_KEYWORD := &"codex_effect_is_keyword"

## 中文禁则统一入口。闭合标点不得出现在行首，开放标点不得停在行尾。
## U+2060 WORD JOINER 只参与塑形和断行，不产生可见字形。
const WORD_JOINER := "\u2060"
const FORBIDDEN_LINE_START := "。，、！？；：）》】」』〉］〕〗〙〛’”…—·+×÷％‰℃°.,!?;:%)]}"
const FORBIDDEN_LINE_END := "（《【「『〈［〔〖〘〚‘“([{"


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
		_append_run(runs, next_keyword, not UNEMPHASIZED_EFFECTS.has(next_keyword))
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


## 为所有说明正文提供同一套中文禁则保护；不锁死普通词组，因此不会扩大行尾留白。
static func protect_cjk_line_breaks(text: String) -> String:
	var protected_text := ""
	for index: int in text.length():
		var glyph := text.substr(index, 1)
		if is_forbidden_line_start(glyph) \
				and not protected_text.is_empty() \
				and not protected_text.ends_with("\n") \
				and not protected_text.ends_with(WORD_JOINER):
			protected_text += WORD_JOINER
		protected_text += glyph
		if is_forbidden_line_end(glyph) \
				and index + 1 < text.length() \
				and text.substr(index + 1, 1) != "\n":
			protected_text += WORD_JOINER
	return protected_text


static func strip_line_break_controls(text: String) -> String:
	return text.replace(WORD_JOINER, "")


static func is_forbidden_line_start(glyph: String) -> bool:
	return not glyph.is_empty() and FORBIDDEN_LINE_START.contains(glyph)


static func is_forbidden_line_end(glyph: String) -> bool:
	return not glyph.is_empty() and FORBIDDEN_LINE_END.contains(glyph)


static func line_starts_with_forbidden(text: String) -> bool:
	var visible := strip_line_break_controls(text)
	return not visible.is_empty() and is_forbidden_line_start(visible.substr(0, 1))


static func line_ends_with_forbidden(text: String) -> bool:
	var visible := strip_line_break_controls(text)
	return not visible.is_empty() \
			and is_forbidden_line_end(visible.substr(visible.length() - 1, 1))


## 固定字数卡片也遵守禁则：遇到闭合符号时将前一个字连同符号推到下一行，
## 遇到开放符号时则把开放符号移到下一行，避免人工换行绕过 TextServer 规则。
static func wrap_fixed_cjk(text: String, characters_per_line: int) -> String:
	var width := maxi(characters_per_line, 1)
	var logical_lines: Array[String] = []
	for source_line_variant: Variant in text.split("\n", true):
		var source_line := String(source_line_variant)
		if source_line.is_empty():
			logical_lines.append("")
			continue
		var cursor := 0
		while cursor < source_line.length():
			var take := mini(width, source_line.length() - cursor)
			var line := source_line.substr(cursor, take)
			cursor += take
			if cursor < source_line.length() \
					and is_forbidden_line_start(source_line.substr(cursor, 1)) \
					and line.length() > 1:
				cursor -= 1
				line = line.left(line.length() - 1)
			while line_ends_with_forbidden(line) and line.length() > 1:
				cursor -= 1
				line = line.left(line.length() - 1)
			logical_lines.append(line)
	return "\n".join(logical_lines)
