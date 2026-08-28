extends GutTest


func test_line_break_protection_preserves_visible_copy_and_binds_punctuation() -> void:
	var original := "获得2点能量（回合被动除外）。下一次「大波」伤害+1。"
	var protected := EffectTextFormatter.protect_cjk_line_breaks(original)
	assert_eq(EffectTextFormatter.strip_line_break_controls(protected), original,
			"换行保护不得改写任何玩家可见文案")
	assert_true(protected.contains("量（%s回" % EffectTextFormatter.WORD_JOINER))
	assert_true(protected.contains("外%s）%s。" % [
			EffectTextFormatter.WORD_JOINER, EffectTextFormatter.WORD_JOINER]))


func test_fixed_width_descriptions_never_orphan_brackets_or_stops() -> void:
	var wrapped := EffectTextFormatter.wrap_fixed_cjk(
			"甲乙丙丁（回合被动除外）。下一次攻击生效。", 5)
	assert_eq(wrapped.replace("\n", ""), "甲乙丙丁（回合被动除外）。下一次攻击生效。")
	for line: String in wrapped.split("\n"):
		assert_false(EffectTextFormatter.line_starts_with_forbidden(line),
				"固定字数说明的行首不得出现闭合标点：%s" % line)
		assert_false(EffectTextFormatter.line_ends_with_forbidden(line),
				"固定字数说明的行尾不得留下开放标点：%s" % line)
