extends Node2D

## A 方案视觉测试 —— 验证"静态立绘 + Juice + 占位斩击特效"是否显得假。
## 一次性原型，与 src/ 隔离。
##
## 运行方式：在 Godot 编辑器打开本场景 → 按 F6（运行当前场景）。
##
## 每次"攻击"演示：
##   待机呼吸 → 攻击者蓄力后撤 → 前冲 → 命中瞬间(白闪+斩击光+震屏+目标后退+伤害数字) → 复位
## 操作：空格 / 点"攻击"按钮触发；默认自动循环（按 A 切换）。

const HERO_TEX_PATH := "res://assets/sprites/heroes/h01/h01.png"
const FLASH_SHADER := preload("res://prototypes/juice_test/hit_flash.gdshader")
const SlashVFXScript := preload("res://prototypes/juice_test/slash_vfx.gd")
const IDLE_FRAMES := preload("res://assets/sprites/heroes/h01/h01_idle.tres")

## true = 用现有 16 帧 idle 动画；false = 用静态立绘 + 呼吸浮动（上一版）。
## 改这一行重新运行即可对比两种待机。
const USE_ANIMATED_IDLE := true

const FIGURE_SCALE := 5.0      # 静态立绘 (128px) 缩放
const IDLE_SCALE := 2.5        # idle 帧 (256px) 缩放 — 让屏上尺寸与静态一致
const STAGE_Y := 540.0

var _camera: Camera2D
var _attacker: Node2D      # 锚点（攻击的前冲/复位 tween 作用在锚点上）
var _target: Node2D
var _attacker_spr: Node2D    # Sprite2D 或 AnimatedSprite2D（取决于 USE_ANIMATED_IDLE）
var _target_spr: Node2D
var _attacker_home: Vector2
var _target_home: Vector2

var _busy: bool = false
var _auto: bool = true
var _auto_timer: float = 0.0
var _time: float = 0.0
var _shake_amount: float = 0.0
var _shake_decay: float = 0.0
var _status: Label


func _ready() -> void:
	var tex: Texture2D = load(HERO_TEX_PATH)
	if tex == null:
		push_error("找不到立绘: " + HERO_TEX_PATH)
		return

	_build_stage()

	_camera = Camera2D.new()
	_camera.position = Vector2(960, 540)
	add_child(_camera)
	_camera.make_current()

	_attacker_home = Vector2(680, STAGE_Y)
	_target_home = Vector2(1240, STAGE_Y)

	var atk := _make_fighter(tex, _attacker_home, false)
	_attacker = atk[0] as Node2D
	_attacker_spr = atk[1] as Node2D
	var tgt := _make_fighter(tex, _target_home, true)
	_target = tgt[0] as Node2D
	_target_spr = tgt[1] as Node2D

	_build_ui()


func _build_stage() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.11, 0.14)
	bg.size = Vector2(1920, 1080)
	bg.z_index = -100
	add_child(bg)
	var ground := ColorRect.new()
	ground.color = Color(0.16, 0.17, 0.21)
	ground.position = Vector2(0, STAGE_Y + 150)
	ground.size = Vector2(1920, 1080)
	ground.z_index = -99
	add_child(ground)


## 返回 [锚点 Node2D, 立绘 Sprite2D]。锚点放在 home，立绘是其子节点（本地原点）。
func _make_fighter(tex: Texture2D, home: Vector2, flip: bool) -> Array:
	var anchor := Node2D.new()
	anchor.position = home
	add_child(anchor)

	var mat := ShaderMaterial.new()
	mat.shader = FLASH_SHADER
	mat.set_shader_parameter("flash_amount", 0.0)

	var visual: Node2D
	if USE_ANIMATED_IDLE:
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = IDLE_FRAMES
		anim.scale = Vector2(IDLE_SCALE, IDLE_SCALE)
		anim.flip_h = flip
		anim.centered = true
		anim.material = mat
		anim.play(&"idle")
		anim.frame = 6 if flip else 0   # 两边错开起始帧，避免机械同步
		visual = anim
	else:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.scale = Vector2(FIGURE_SCALE, FIGURE_SCALE)
		spr.flip_h = flip
		spr.centered = true
		spr.material = mat
		visual = spr

	anchor.add_child(visual)
	return [anchor, visual]


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.position = Vector2(40, 40)
	panel.add_theme_constant_override("separation", 12)
	layer.add_child(panel)

	var title := Label.new()
	title.text = "A 方案视觉测试：静态立绘 + Juice"
	title.add_theme_font_size_override("font_size", 36)
	panel.add_child(title)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 24)
	panel.add_child(_status)

	var btn := Button.new()
	btn.text = "攻击 (空格)"
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(240, 60)
	btn.pressed.connect(_do_attack)
	panel.add_child(btn)

	var btn_auto := Button.new()
	btn_auto.text = "切换自动循环 (A)"
	btn_auto.focus_mode = Control.FOCUS_NONE
	btn_auto.custom_minimum_size = Vector2(240, 60)
	btn_auto.pressed.connect(_toggle_auto)
	panel.add_child(btn_auto)

	_update_status()


func _toggle_auto() -> void:
	_auto = not _auto
	_update_status()


func _update_status() -> void:
	if _status:
		_status.text = "自动循环: %s    空格=攻击   A=切换自动" % ("开" if _auto else "关")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_SPACE:
			_do_attack()
		elif key.keycode == KEY_A:
			_toggle_auto()


func _process(delta: float) -> void:
	_time += delta

	# 待机呼吸：仅静态立绘模式需要（动画 idle 自带动作，不叠加浮动）。
	if not USE_ANIMATED_IDLE:
		var amp := 4.0
		if is_instance_valid(_attacker_spr):
			_attacker_spr.position.y = roundf(sin(_time * 2.3) * amp)
		if is_instance_valid(_target_spr):
			_target_spr.position.y = roundf(sin(_time * 2.3 + 1.0) * amp)

	# 震屏衰减
	if _shake_amount > 0.0:
		_camera.offset = Vector2(
			randf_range(-_shake_amount, _shake_amount),
			randf_range(-_shake_amount, _shake_amount))
		_shake_amount = maxf(0.0, _shake_amount - _shake_decay * delta)
		if _shake_amount <= 0.0:
			_camera.offset = Vector2.ZERO

	# 自动循环
	if _auto and not _busy:
		_auto_timer -= delta
		if _auto_timer <= 0.0:
			_auto_timer = 1.6
			_do_attack()


func _do_attack() -> void:
	if _busy:
		return
	_busy = true
	var lunge := _attacker_home + Vector2(400, 0)
	var tw := create_tween()
	# 蓄力后撤
	tw.tween_property(_attacker, "position", _attacker_home + Vector2(-45, 0), 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 前冲
	tw.tween_property(_attacker, "position", lunge, 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 命中
	tw.tween_callback(_on_impact)
	tw.tween_interval(0.06)
	# 复位
	tw.tween_property(_attacker, "position", _attacker_home, 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _busy = false)


func _on_impact() -> void:
	# 斩击光（占位）
	var slash := SlashVFXScript.new()
	slash.position = _target_home + Vector2(-50, -30)
	slash.z_index = 20
	add_child(slash)
	slash.play()

	# 目标白闪
	_flash(_target_spr)

	# 目标后退 + 弹回
	var recoil := create_tween()
	recoil.tween_property(_target, "position", _target_home + Vector2(55, 0), 0.05)
	recoil.tween_property(_target, "position", _target_home, 0.20) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# 震屏
	_shake(11.0, 0.22)

	# 伤害数字
	_spawn_damage_number(_target_home + Vector2(0, -260), 3)


func _flash(spr: Node2D) -> void:
	if not is_instance_valid(spr):
		return
	var mat := spr.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("flash_amount", 1.0)
	var tw := create_tween()
	tw.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("flash_amount", v),
		1.0, 0.0, 0.18).set_trans(Tween.TRANS_SINE)


func _shake(amount: float, duration: float) -> void:
	_shake_amount = amount
	_shake_decay = amount / maxf(duration, 0.001)


func _spawn_damage_number(pos: Vector2, amount: int) -> void:
	var lbl := Label.new()
	lbl.text = "-%d" % amount
	lbl.add_theme_font_size_override("font_size", 72)
	lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.position = pos
	lbl.z_index = 50
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", pos + Vector2(0, -130), 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.7).set_delay(0.25)
	get_tree().create_timer(0.95).timeout.connect(lbl.queue_free)
