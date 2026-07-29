extends Node

## 斜切分段血条探针（2026-07-18·任务13 血量 UI 改版取证）：直改 BattleCore 的 hp/shield
## 半点值 → _update_all 刷新 → 逐态抓帧，把 P1(LTR)/P2(RTL) 两条血条裁切放大上下拼一张。
## 覆盖：满血 / 掉血露空槽 / 半点(奇数半点=末尾少一小块) / 护盾银灰覆盖 / 低血警示闪。
##   godot --path . res://tools/hp_bar_probe.tscn
## 输出：D:/Game/BoBoZan/_probe_output/hpbar_*.png（仓库外·勿入库）

const OUT := "D:/Game/BoBoZan/_probe_output/"
const ZOOM := 4
const CROP_P1 := Rect2i(105, 22, 470, 50)     # P1 血条带（左起·宽度按满盾 10 格 416px 留够）
const CROP_P2 := Rect2i(1345, 22, 470, 50)    # P2 血条带（右起·与 P1 关于屏幕中线对称）

var _screen: Node
var _battle: Variant


func _ready() -> void:
	_screen = load("res://src/ui/battle_screen1.tscn").instantiate()
	add_child(_screen)
	await get_tree().create_timer(2.2).timeout
	_battle = _screen.get("battle")
	_report_maxhp()

	await _snap("hpbar_full.png")                       # ① 满血（P1 4 格 / P2 7 格·一格一滴血）

	_set_hp(0, 5)                                       # ② 掉血：P1 2.5/4 → 2 整格 + 半格 + 1.5 空
	_set_hp(1, 9)                                       #    P2 4.5/7 → 4 整格 + 半格 + 2.5 空
	await _snap("hpbar_damaged.png")

	_set_shield(1, 4)                                   # ③ 覆盖式：P2 4.5血+2盾 → [2银][2.5红][2.5空]·不加长
	await _snap("hpbar_shield_cover.png")

	_set_hp(1, 14)                                      # ④ 盖满+接长：P2 7满血+9盾 → 盖满 7 格再往外接 2 格 = 9 格全银
	_set_shield(1, 18)
	await _snap("hpbar_shield_extend.png")

	_set_shield(1, 24)                                  # ⑤ 顶格：7血+12盾 → 封顶 10 格（max_cells）
	await _snap("hpbar_shield_cap.png")

	_set_shield(1, 0)
	_set_hp(0, 2)                                       # ⑥ 低血：P1 1/4=0.25 ≤ 阈值 0.5 → 警示闪
	_set_hp(1, 3)                                       #    P2 1.5/7
	await _snap("hpbar_low_a.png")
	await get_tree().create_timer(0.5).timeout          #    半拍后再抓一张 = 闪烁相位对照
	await _snap("hpbar_low_b.png")

	get_tree().quit()


## HP 直写（半点制整数：hp_half=5 → 显示 2.5）。UI 只读铁律的例外=探针，仅本工具。
func _set_hp(player: int, hp_half: int) -> void:
	_battle.hp[player][_battle.active_index[player]] = hp_half
	_screen.call("_update_all")


func _set_shield(player: int, sh_half: int) -> void:
	_battle.shield[player][_battle.active_index[player]] = sh_half
	_screen.call("_update_all")


func _report_maxhp() -> void:
	for p in [0, 1]:
		var idx: int = _battle.active_index[p]
		print("P%d 出战 max_hp(半点)=%d → 显示 %.1f / 小块数(0.5一块)=%d"
			% [p + 1, _battle.max_hp[p][idx], _battle.max_hp[p][idx] / 2.0, _battle.max_hp[p][idx]])


## 整屏抓帧 + 两条血条裁切放大上下拼图（一张读完双方）。
## ⚠先等 0.45s：改 HP 会触发 _flinch_heart_row 的 modulate 脉冲（0.06 冲 + 0.30 回），
## 不等它落定抓到的就是"整条被提亮"的假色（红看着发橘、银看着纯白·踩过）。
func _snap(fname: String) -> void:
	await get_tree().create_timer(0.45).timeout
	await RenderingServer.frame_post_draw
	var full := get_viewport().get_texture().get_image()
	full.save_png(OUT + "raw_" + fname)

	var a := full.get_region(CROP_P1)
	var b := full.get_region(CROP_P2)
	var stack := Image.create_empty(CROP_P1.size.x, CROP_P1.size.y * 2, false, full.get_format())
	stack.blit_rect(a, Rect2i(Vector2i.ZERO, CROP_P1.size), Vector2i.ZERO)
	stack.blit_rect(b, Rect2i(Vector2i.ZERO, CROP_P2.size), Vector2i(0, CROP_P1.size.y))
	stack.resize(stack.get_width() * ZOOM, stack.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
	stack.save_png(OUT + fname)
	print("saved: ", OUT + fname)
