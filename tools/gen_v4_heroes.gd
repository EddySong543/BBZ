extends SceneTree

## v4 英雄数据生成器（一次性工具）。
## 按 ADR-002 / hero-mechanics-hook-matrix 的 HP 与角色名，生成 34 个 HeroData .tres。
## 放 assets/data/heroes_v4/（不动 v3 的 assets/data/heroes/）。
## 运行：godot --headless --path <proj> --script res://tools/gen_v4_heroes.gd
##
## [hero_id, 角色名, 技能名, HP]
const ROWS := [
	["h01", "子鼠", "窃运", 4], ["h02", "丑牛", "怒目", 6], ["h03", "寅虎", "渴血", 5],
	["h04", "卯兔", "三窟", 4], ["h05", "辰龙", "天威", 6], ["h06", "巳蛇", "蛇蜕", 4],
	["h07", "午马", "当先", 5], ["h08", "未羊", "替罪", 5], ["h09", "申猴", "凶兽", 4],
	["h10", "酉鸡", "啼晓", 5], ["h11", "戌狗", "穷追", 5], ["h12", "亥猪", "吞噬", 6],
	["h13", "愚者", "孤注一掷", 5], ["h14", "魔术师", "梅开二度", 5], ["h15", "女祭司", "三缄其口", 4],
	["h16", "皇后", "泽被苍生", 5], ["h17", "皇帝", "君命难违", 6], ["h18", "教皇", "万民归心", 6],
	["h19", "恋人", "至死不渝", 6], ["h20", "战车", "倾力一击", 5], ["h21", "力量", "降龙伏虎", 7],
	["h22", "隐者", "遗世独立", 5], ["h23", "命运之轮", "周而复始", 5], ["h24", "正义", "天平归衡", 6],
	["h25", "倒吊人", "以退为进", 5], ["h26", "死神", "向死而生", 4], ["h27", "节制", "以柔克刚", 4],
	["h28", "恶魔", "灵魂契约", 6], ["h29", "塔", "倾巢之下", 5], ["h30", "星星", "北辰守望", 6],
	["h31", "月亮", "阴晴圆缺", 5], ["h32", "太阳", "赤日流金", 4], ["h33", "审判", "最后审判", 5],
	["h34", "世界", "寰宇同寂", 4],
]

const OUT_DIR := "res://assets/data/heroes_v4/"


func _initialize() -> void:
	var abs_dir := ProjectSettings.globalize_path(OUT_DIR)
	if not DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.make_dir_recursive_absolute(abs_dir)

	var ok := 0
	for r in ROWS:
		var id: String = r[0]
		var h := HeroData.new()
		h.hero_id = id
		h.hero_name = r[1]
		h.skill_description = r[2]
		h.max_hp = r[3]
		h.portrait_path = "res://assets/sprites/heroes/%s/%s_portrait.png" % [id, id]
		h.sprite_frames_path = "res://assets/sprites/heroes/%s/%s_idle.tres" % [id, id]
		var err := ResourceSaver.save(h, OUT_DIR + id + ".tres")
		if err == OK:
			ok += 1
		else:
			push_error("保存失败 %s: err %d" % [id, err])
	print("[gen_v4_heroes] 生成 %d / %d 个 .tres → %s" % [ok, ROWS.size(), OUT_DIR])
	quit()
