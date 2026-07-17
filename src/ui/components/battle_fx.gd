extends Node

## 战斗演出原语库（2026-07-17 battle_screen 拆分批①·从 battle_screen 原文迁入·零行为变化）。
## 职责=纯演出原语：飘字（伤害/治疗/被挡/事件注解）/斩击弧光/火花/脚下尘/能量飞粒/
## 冲击帧黑白闪/受击 scale-pop——全部池化（并发上限=常量区·复用前 kill 在飞 tween）。
## ⛔铁律：本组件绝不读写 battle 状态（ui-readonly）——输入只有玩家位/数值/文本。
## 宿主=battle_screen（setup 注入）：读角色位（p1/p2_char_display）/HUD 行（coin_row）/
## post_fx 节点/`_fmt_hp`；顿帧走宿主 `_hitstop`（时钟域=hitstop/time_scale 归编排层·不迁）。
## 编排层（_play_battle_anims/_play_finisher/_impact/_act_juice）留 battle_screen——
## 探针契约（pooled_fx_probe 直调 _impact）不动。
## 挂载：battle_screen._ready → BattleFx.new()+add_child+setup(self)（池节点挂本组件下·
## 本组件为纯 Node → 子 CanvasItem 的 z 序仍相对 battle_screen=原行为等价）。

const FX_POOL_SIZE := 4                       # 斩击并发上限
const FLOAT_POOL_SIZE := 12                   # 飘字并发上限（伤害×2+治疗+被挡+A3b 注解×6 同拍可共存）
const EVENT_TAG_MAX := 3                      # A3b 同拍同侧注解上限（再多=糊屏·溢出时救场金 pr=0 优先保留）
const TAG_STAGGER := 0.14                     # A3b 同侧多条注解的逐条弹出间隔（秒）
const MOTE_POOL_SIZE := 8                     # 能量飞粒并发上限（双方同拍攒也够用）
const DUST_POOL_SIZE := 4                     # ⑦ 尘土并发上限（双方同拍前冲=起步+落定×2 刚好）

# —— 飘字/特效配色（伤害阶梯/治疗/格挡·编排层组 tag 时经 BattleFx.COL_* 静态取用）——
const COL_DMG_BIG := Color(1.0, 0.82, 0.5)        # 重击（≥2HP）炽黄白
const COL_DMG_SMALL := Color(1.0, 0.55, 0.42)     # 轻击橙红
const COL_DMG_PIERCE := Color(0.8, 0.62, 1.0)     # ⑧ 穿防/穿大防伤害=靛紫（阶梯可读）
const COL_DMG_TRUE := Color(1.0, 0.96, 0.88)      # ⑧ 真伤=白热字（配绯红描边·最凶一档）
const COL_HEAL := Color(0.62, 0.92, 0.55)         # ③ 治疗绿
const COL_BLOCK_TEXT := Color(0.78, 0.82, 0.88)   # ② 被挡=银灰（"没打进"的冷反馈）
const COL_BLOCK_SPARK := Color(0.62, 0.78, 1.0)   # ② 格挡火花=钢蓝（与命中暖白火星区分）
const COL_SPARK_WARM := Color(1.0, 0.92, 0.62)    # 命中火花默认暖白（原配方）

var _h: Control = null                        # 宿主 battle_screen

var _dmg_pool: Array[Label] = []              # 飘字池（伤害/治疗/被挡 共用·_pop_float 单一出口）
var _dmg_pool_idx: int = 0
var _slash_pool: Array[SlashVFX] = []         # 斩击弧光池（pooled 模式·播完隐藏不自毁）
var _slash_pool_idx: int = 0
var _spark_pool_big: Array[CPUParticles2D] = []    # 重击火花池（amount 等参数固定=避免改 amount 重分配缓冲）
var _spark_pool_small: Array[CPUParticles2D] = []  # 轻击火花池
var _spark_idx_big: int = 0
var _spark_idx_small: int = 0
var _mote_pool: Array[TextureRect] = []       # ③ 能量飞粒池（攒→金币飞向 HUD 金币行）
var _mote_idx: int = 0
var _dust_pool: Array[CPUParticles2D] = []    # ⑦ 脚下尘土池（前冲起步/回位落定·屋脊灰瓦色）
var _dust_idx: int = 0


## 注入宿主并建池（battle_screen._ready 调·一次性）。
func setup(host: Control) -> void:
	_h = host
	_setup_fx_pools()


func _cd(player: int) -> CharacterDisplay:
	return _h.p1_char_display if player == 0 else _h.p2_char_display


func _setup_fx_pools() -> void:
	for i in FLOAT_POOL_SIZE:
		var lbl := Label.new()
		lbl.visible = false
		lbl.z_index = 100
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lbl)
		_dmg_pool.append(lbl)
	for i in FX_POOL_SIZE:
		var slash := SlashVFX.new()
		slash.pooled = true
		slash.visible = false
		slash.z_index = 60
		slash.set_process(false)
		add_child(slash)
		_slash_pool.append(slash)
	for i in 2:
		_spark_pool_big.append(_make_spark(16, 460.0, 4.5))
		_spark_pool_small.append(_make_spark(10, 300.0, 3.0))
	for i in DUST_POOL_SIZE:
		_dust_pool.append(_make_dust())
	# ③ 能量飞粒：专属能量珠资产（Eddy 2026-07-10 出图）·小尺寸 TextureRect 必须 IGNORE_SIZE（godot-ui-render-quirks）
	var coin_tex: Texture2D = load("res://assets/ui/icons/energy_mote.png")
	for i in MOTE_POOL_SIZE:
		var m := TextureRect.new()
		m.texture = coin_tex
		m.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		m.stretch_mode = TextureRect.STRETCH_SCALE
		m.size = Vector2(45, 45)
		m.pivot_offset = Vector2(22.5, 22.5)
		m.visible = false
		m.z_index = 90
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(m)
		_mote_pool.append(m)


## 火花粒子工厂：径向飞溅 + 重力下坠的一次性 explosive 爆发（参数见 _spawn_spark 原配方）。
func _make_spark(amount: int, vel_max: float, scale_max: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.38
	p.spread = 180.0
	p.initial_velocity_min = 160.0
	p.initial_velocity_max = vel_max
	p.gravity = Vector2(0, 700)
	p.scale_amount_min = 2.0
	p.scale_amount_max = scale_max
	p.color = Color(1.0, 0.92, 0.62)   # 暖白火星
	p.z_index = 95
	add_child(p)
	return p


## 冲击帧（动画 impact frame·A/A/A）：硬切三段——正片（墨黑纸白+受击点锯齿白炸开）→ 负片一闪
## （黑白互换=PV 张力核心）→ 恢复。全程无渐变；计时 ignore_time_scale 不被慢放拖长；
## 切场景时 await 后节点可能已离树 → 先查再写（宿主 _exit_tree 已兜底关闭）。UI 在 PostFX 之上不受染。
func _bw_flash(center_uv: Vector2) -> void:
	var mat := _h.post_fx.material as ShaderMaterial
	mat.set_shader_parameter("impact_center", center_uv)
	mat.set_shader_parameter("impact_invert", 0.0)
	mat.set_shader_parameter("impact_strength", 1.0)
	await get_tree().create_timer(_h.FINISHER_BW_POS, true, false, true).timeout
	if not is_inside_tree():
		return
	mat.set_shader_parameter("impact_invert", 1.0)
	await get_tree().create_timer(_h.FINISHER_BW_NEG, true, false, true).timeout
	if is_inside_tree():
		mat.set_shader_parameter("impact_strength", 0.0)


## ⑦ 尘土粒子工厂：脚下一小撮灰瓦色尘（前冲起步/回位落定的接地感·Dead Cells 式廉价质感件）。
func _make_dust() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 7
	p.lifetime = 0.34
	p.direction = Vector2(0, -1)
	p.spread = 75.0
	p.initial_velocity_min = 36.0
	p.initial_velocity_max = 110.0
	p.gravity = Vector2(0, 180)
	p.damping_min = 60.0
	p.damping_max = 120.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.4
	p.color = Color(0.56, 0.62, 0.72, 0.5)   # 屋脊灰瓦色·半透（尘非火花）
	p.z_index = 55                            # 立绘（60 斩击）之下贴地
	add_child(p)
	return p


## ⑦ 脚下起尘（池化）：player 脚底位置一撮（脚底锚=size.y×0.67·与终结演出同一锚点）。
func _spawn_dust(player: int) -> void:
	var p := _dust_pool[_dust_idx]
	_dust_idx = (_dust_idx + 1) % DUST_POOL_SIZE
	var cd := _cd(player)
	p.global_position = cd.global_position + cd.size * Vector2(0.5, 0.67)
	p.restart()


## 复用池节点前必调：kill 其在飞 tween（复用旧节点=先终止残留动画，防把属性写回旧值）。
func _fx_kill_tweens(n: CanvasItem) -> void:
	if n.has_meta(&"fx_tweens"):
		for tw in n.get_meta(&"fx_tweens"):
			if tw is Tween and tw.is_valid():
				tw.kill()
		n.remove_meta(&"fx_tweens")


## A3：受击 scale-pop（绕立绘中心快速放大再回弹）。pivot 每次按当前尺寸取中心，稳健。
func _char_pop(player: int, amount: float) -> void:
	var cd := _cd(player)
	cd.pivot_offset = cd.size * 0.5
	var tw := create_tween()
	tw.tween_property(cd, "scale", Vector2(1.0 + amount, 1.0 + amount), 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(cd, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 命中火花(c)：受击点爆一簇短命粒子（径向飞溅 + 重力下坠），重击更多更快。
## 一次性 explosive 爆发 → "一帧火花"的脆感。无贴图=小方块火星，足够。
## 池化：重/轻两池各 2 发环形复用（参数在 _make_spark 钉死），复用只挪位置/着色 + restart()。
## tint：命中=暖白火星（默认）/ ② 格挡=钢蓝（改 color 属性不触发缓冲重分配）。
func _spawn_spark(target_player: int, big: bool, tint: Color = COL_SPARK_WARM) -> void:
	var cd := _cd(target_player)
	var p: CPUParticles2D
	if big:
		p = _spark_pool_big[_spark_idx_big]
		_spark_idx_big = (_spark_idx_big + 1) % _spark_pool_big.size()
	else:
		p = _spark_pool_small[_spark_idx_small]
		_spark_idx_small = (_spark_idx_small + 1) % _spark_pool_small.size()
	p.color = tint
	p.global_position = cd.global_position + cd.size * Vector2(0.5, 0.42)
	p.restart()


func _spawn_slash(target_player: int) -> void:
	var slash := _slash_pool[_slash_pool_idx]
	_slash_pool_idx = (_slash_pool_idx + 1) % FX_POOL_SIZE
	var cd := _cd(target_player)
	var s := 2.0
	slash.scale = Vector2(-s, s) if target_player == 0 else Vector2(s, s)  # 打左侧的镜像
	slash.global_position = cd.global_position + cd.size * 0.5
	slash.play()


## 伤害飘字（数字重量 b）：受击处弹 -N，按伤害量缩放大小/配色 → punch-in 过冲 → 抛物上浮淡出。
## 大伤(≥2HP)更大更炽、描边更粗；起点偏击退方向 + 小随机，防多发叠死。
func _pop_damage(player: int, amount: float, pen: int = 0) -> void:
	var big := amount >= 2.0
	# ⑧ 伤害阶梯分级配色（Pen 枚举有序）：真伤=白热字+绯红描边（最凶·强制大字）/穿透=靛紫/普通=原两档。
	var col := COL_DMG_BIG if big else COL_DMG_SMALL
	var outline := Color(0.12, 0.02, 0.02, 0.95)
	var outline_px := 9 if big else 6
	match pen:
		ActionDef.Pen.TRUE_DMG:
			col = COL_DMG_TRUE
			outline = Color(0.55, 0.05, 0.08, 0.98)
			outline_px = 11
			big = true
		ActionDef.Pen.PIERCE_DEF, ActionDef.Pen.PIERCE_BIGDEF:
			col = COL_DMG_PIERCE
			outline = Color(0.16, 0.06, 0.28, 0.95)
	_pop_float(player, "-%s" % _h._fmt_hp(amount), 60 if big else 44, col, outline, outline_px,
		1.28 if big else 1.12, 104.0 if big else 78.0)


## ③ 治疗飘字：绿 +N。生成点比伤害字高一档且反向漂（同拍受伤+回血时两字不叠死）。
func _pop_heal(player: int, amount: float) -> void:
	_pop_float(player, "+%s" % _h._fmt_hp(amount), 44, COL_HEAL, Color(0.03, 0.14, 0.05, 0.95), 6,
		1.12, 88.0, 0.18, -34.0)


## ② 被挡演出：防守方钢蓝格挡火花 + 银灰「被挡」飘字 + 盾感 rim；大防挡大波=重火花+短顿帧更隆重。
func _block_fx(player: int, big_atk: bool) -> void:
	var cd := _cd(player)
	cd.pulse_rim(1.3 if big_atk else 0.8, 0.28)
	_spawn_spark(player, big_atk, COL_BLOCK_SPARK)
	_pop_float(player, tr("被挡"), 36, COL_BLOCK_TEXT, Color(0.06, 0.08, 0.12, 0.95), 5,
		1.1, 62.0, 0.38)
	if big_atk:
		_h._hitstop(0.04)   # 挡下大波值得一拍定格（比命中定格 0.075 轻·时钟域在宿主）


## A3b 事件注解批量弹出：同侧多条按 TAG_STAGGER 逐条错时，上限 EVENT_TAG_MAX 条防糊屏；
## 溢出裁剪时救场级注解（pr=0·护主/还魂/免疫）优先保留，其余按事件发生顺序。
## 延时用 tween（绑本节点·离场自动清）而非 SceneTreeTimer——防战斗屏销毁后回调打到空引用。
func _pop_tags(player: int, tag_list: Array, base_delay: float = 0.08) -> void:
	var list: Array = tag_list
	if list.size() > EVENT_TAG_MAX:
		list = []
		for t in tag_list:
			if int(t.get("pr", 1)) == 0:
				list.append(t)
		for t in tag_list:
			if int(t.get("pr", 1)) != 0:
				list.append(t)
	for i in mini(list.size(), EVENT_TAG_MAX):
		var t: Dictionary = list[i]
		var d := base_delay + TAG_STAGGER * i
		if d <= 0.0:
			_pop_tag(player, t)
		else:
			var tw := create_tween()
			tw.tween_interval(d)
			tw.tween_callback(_pop_tag.bind(player, t))


## A3b 单条事件注解：默认腹位（y_frac 0.52·避开胸口伤害字）小一号字；
## 延迟伤害借道此出口弹 -N 大字（size/y/outline 均可被条目覆盖）。
func _pop_tag(player: int, t: Dictionary) -> void:
	_pop_float(player, String(t.get("text", "")), int(t.get("size", 30)), t.get("col", Color.WHITE),
		t.get("outline", Color(0.09, 0.07, 0.05, 0.95)), 5, 1.08, 58.0, float(t.get("y", 0.52)))


## 通用飘字（伤害/治疗/被挡 单一出口·池化）：punch-in 过冲 → 抛物上浮淡出 → 隐藏归池。
## y_frac=生成高度（角色身位比例·0.30=胸口）；x_off=额外横移（错开同拍多字）。
func _pop_float(player: int, text: String, font_size: int, col: Color, outline: Color,
		outline_px: int, peak: float, rise: float, y_frac: float = 0.30, x_off: float = 0.0) -> void:
	var cd := _cd(player)
	# 池化取号：先 kill 该格在飞 tween，再重置全部会被动画改写的属性（透明度/缩放）。
	var lbl := _dmg_pool[_dmg_pool_idx]
	_dmg_pool_idx = (_dmg_pool_idx + 1) % FLOAT_POOL_SIZE
	_fx_kill_tweens(lbl)
	lbl.text = text
	FontManager.apply(lbl, font_size)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", outline)
	lbl.add_theme_constant_override("outline_size", outline_px)
	lbl.visible = true
	lbl.modulate.a = 1.0
	lbl.reset_size()
	lbl.pivot_offset = lbl.size * 0.5   # 绕中心缩放
	var dir := 1.0 if player == 0 else -1.0   # 击退方向（P0 打右侧敌→数字往右）
	var start: Vector2 = cd.global_position + cd.size * Vector2(0.5, y_frac) - lbl.size * 0.5 \
		+ Vector2(dir * (16.0 + x_off) + randf_range(-10.0, 10.0), randf_range(-6.0, 6.0))
	lbl.global_position = start
	# punch-in：0.45 → 过冲 → 落定
	lbl.scale = Vector2(0.45, 0.45)
	var st := create_tween()
	st.tween_property(lbl, "scale", Vector2(peak, peak), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	st.tween_property(lbl, "scale", Vector2(peak, peak) * 0.86, 0.10).set_trans(Tween.TRANS_SINE)
	# 抛物上浮（横向带一点击退漂移）+ 末段淡出，收尾隐藏归池（取代原 create_timer+queue_free）
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position", start + Vector2(dir * 26.0, -rise), 0.66).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.40).set_delay(0.52)
	tw.chain().tween_callback(lbl.hide)
	lbl.set_meta(&"fx_tweens", [st, tw])


## 数字重量(b)：HP 变化时给出战心条一个 modulate flinch（掉血偏红 / 回血偏绿），
## 用 modulate 而非 scale → 不受 RTL 心条(右起左排)的布局影响、稳健。
func _flinch_heart_row(row: IconPipRow, is_loss: bool) -> void:
	_pulse_pip_row(row, Color(1.7, 1.35, 1.35) if is_loss else Color(1.35, 1.7, 1.4))


## pip 行 modulate 脉冲（心条 flinch / ③ 金币行收能）单一出口。
func _pulse_pip_row(row: IconPipRow, peak: Color) -> void:
	var tw := create_tween()
	tw.tween_property(row, "modulate", peak, 0.06).set_trans(Tween.TRANS_SINE)
	tw.tween_property(row, "modulate", Color.WHITE, 0.30).set_trans(Tween.TRANS_SINE)


## ③ 能量获得反馈：金币小粒从角色胸口散开 → 弧线飞进 HUD 金币行 → 末粒到位时金币行金色脉冲。
## 粒数随获得量（半能→整能换算）2~5 粒；池化环形复用（复用前 kill 在飞 tween）。
func _fly_energy_motes(player: int, egain_half: int) -> void:
	var cd := _cd(player)
	var row: IconPipRow = _h.p1_coin_row if player == 0 else _h.p2_coin_row
	var from: Vector2 = cd.global_position + cd.size * Vector2(0.5, 0.35)
	var to: Vector2 = row.global_position + row.size * 0.5
	var count := clampi(1 + egain_half / 2, 2, 5)
	for i in count:
		var m := _mote_pool[_mote_idx]
		_mote_idx = (_mote_idx + 1) % MOTE_POOL_SIZE
		_fx_kill_tweens(m)
		m.visible = true
		m.scale = Vector2.ONE
		m.modulate = Color(1, 1, 1, 0)
		m.global_position = from - m.size * 0.5
		var burst := from + Vector2(randf_range(-52.0, 52.0), randf_range(-70.0, -20.0)) - m.size * 0.5
		var tw := create_tween()
		var delay := i * 0.12
		# 尺寸对齐 HUD 金币 pip 45px+节奏微回快（Eddy 2026-07-11 二调）：浮出 0.38·飞行 0.58 → 单粒全程 ≈1.06s
		tw.tween_interval(maxf(delay, 0.001))
		tw.tween_property(m, "modulate:a", 1.0, 0.1)
		tw.parallel().tween_property(m, "global_position", burst, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(m, "global_position", to - m.size * 0.5, 0.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(m, "scale", Vector2(0.65, 0.65), 0.58)
		tw.tween_callback(m.hide)
		if i == count - 1:
			tw.tween_callback(_pulse_pip_row.bind(row, Color(1.8, 1.6, 1.0)))   # 末粒到位=金币行收能脉冲
		m.set_meta(&"fx_tweens", [tw])
