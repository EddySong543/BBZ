extends SceneTree

## 星座组 h35–h46 占位数据生成器（一次性）。
## 技能稍后设计 → 此处仅生成"白板" HeroData：真实星座 hero_name + 占位 HP/技能。
## 不进 battle_core._HERO_SKILL_SCRIPTS → 无技能，只有基础动作（白板）。
## ⚠️ 已存在的 .tres 会跳过（保护已设计数据），可安全重跑。
## 运行：godot --headless --path <proj> --script res://tools/gen_constellation_stubs.gd
##
## [hero_id, 星座名, 占位HP] —— 西方黄道十二宫顺序 白羊 → 双鱼。
const ROWS := [
	["h35", "白羊", 5], ["h36", "金牛", 5], ["h37", "双子", 5],
	["h38", "巨蟹", 5], ["h39", "狮子", 5], ["h40", "处女", 5],
	["h41", "天秤", 5], ["h42", "天蝎", 5], ["h43", "射手", 5],
	["h44", "摩羯", 5], ["h45", "水瓶", 5], ["h46", "双鱼", 5],
]

const OUT_DIR := "res://assets/data/heroes/"
const PLACEHOLDER_SKILL := "待设计"


func _initialize() -> void:
	var ok := 0
	for r in ROWS:
		var id: String = r[0]
		var path := OUT_DIR + id + ".tres"
		if FileAccess.file_exists(ProjectSettings.globalize_path(path)):
			print("[stub] %s 已存在，跳过（保护已设计数据）" % id)
			ok += 1
			continue
		var h := HeroData.new()
		h.hero_id = id
		h.hero_name = r[1]
		h.max_hp = r[2]
		h.skill_description = PLACEHOLDER_SKILL
		h.portrait_path = "res://assets/sprites/heroes/%s/%s_portrait.png" % [id, id]
		h.sprite_frames_path = "res://assets/sprites/heroes/%s/%s_idle.tres" % [id, id]
		var err := ResourceSaver.save(h, path)
		if err == OK:
			ok += 1
		else:
			push_error("保存失败 %s: err %d" % [id, err])
	print("[gen_constellation_stubs] 完成 %d / %d → %s" % [ok, ROWS.size(), OUT_DIR])
	quit()
