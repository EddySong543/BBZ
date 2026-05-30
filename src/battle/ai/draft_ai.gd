class_name DraftAI
extends RefCounted

## 选人策略 AI（v1 最终版骨架，2026-05-30）。
##
## 流程对齐 bp_screen：BAN（盲选 3 禁，取并集）→ PICK（盲选 3 出战，允许镜像）。盲选 = 不看对手。
## 操作 Array[HeroData] 池，返回**池索引**（与 bp_screen 的 idx 语义一致，未来可替换其随机 _ai_choose）。
##
## 策略（结构化、无 per-hero meta 偏见 → 不污染平衡测量）：
##   - 角色按 HP 派生：坦克(HP≥6) / 灵活(HP5) / 脆皮(HP≤4)。
##   - PICK：按"坦克+灵活+脆皮"目标 HP 曲线组队（连接件英雄因此总有 carry/前排队友），
##           角色内**加权随机（温度）**→ 维持全英雄覆盖、不只挑固定几个。
##   - BAN：偏向高 HP（结构化"威胁"=耐久强势原型），带温度。
##   ⚠️ 不含具体 combo 配对（如 h28+carry）→ 那会注入 meta 偏见；深层成对协同留作后续
##      （authored 流派标签 / 经验先验）。
##   ⚠️ 当前用 HP 派生角色（主动/被动暂不接入，避免耦合技能注册表）。

enum Role { TANK, FLEX, FRAGILE }

const TANK_HP := 6
const FRAGILE_HP := 4
const BAN_HP_BIAS := 0.5    # BAN 偏高 HP 的强度（0=均匀；越大越偏坦克）
const PICK_TEMP_BONUS := 1.0  # 角色内基础权重（均匀覆盖）

var rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	rng.seed = seed_value if seed_value != 0 else randi()


## 盲选 count 个禁用。返回池索引（去重）。偏向高 HP 威胁。
func choose_bans(pool: Array, count: int) -> Array:
	var all: Array = []
	for i in range(pool.size()):
		all.append(i)
	return _weighted_sample(pool, all, count, true)


## 从池中盲选 count 个出战（排除 banned，允许镜像，队内去重）。按 HP 曲线组均衡队。
func choose_picks(pool: Array, banned: Array, count: int) -> Array:
	var avail: Array = []
	for i in range(pool.size()):
		if not i in banned:
			avail.append(i)

	var picks: Array = []
	var want := [Role.TANK, Role.FLEX, Role.FRAGILE]
	for r in want:
		if picks.size() >= count:
			break
		var cand: Array = []
		for i in avail:
			if not i in picks and _role(pool[i].max_hp) == r:
				cand.append(i)
		if cand.is_empty():
			continue   # 该角色无人 → 跳过，后面补足
		var one: Array = _weighted_sample(pool, cand, 1, false)
		if not one.is_empty():
			picks.append(one[0])

	# 补足（角色稀缺 / count>3）：从剩余可用里加权随机
	while picks.size() < count:
		var rest: Array = []
		for i in avail:
			if not i in picks:
				rest.append(i)
		if rest.is_empty():
			break
		var one: Array = _weighted_sample(pool, rest, 1, false)
		picks.append(one[0])

	return picks


# === 内部 ===

func _role(hp: int) -> int:
	if hp >= TANK_HP:
		return Role.TANK
	if hp <= FRAGILE_HP:
		return Role.FRAGILE
	return Role.FLEX


## 从 indices 里加权无放回抽 count 个。ban_mode=true 偏高 HP，否则角色内近均匀（覆盖）。
func _weighted_sample(pool: Array, indices: Array, count: int, ban_mode: bool) -> Array:
	var remaining: Array = indices.duplicate()
	var out: Array = []
	while out.size() < count and not remaining.is_empty():
		var weights: Array = []
		var total := 0.0
		for idx in remaining:
			var w: float = _ban_weight(pool[idx].max_hp) if ban_mode else PICK_TEMP_BONUS
			weights.append(w)
			total += w
		var r := rng.randf() * total
		var acc := 0.0
		var chosen := 0
		for k in range(remaining.size()):
			acc += weights[k]
			if r <= acc:
				chosen = k
				break
		out.append(remaining[chosen])
		remaining.remove_at(chosen)
	return out


func _ban_weight(hp: int) -> float:
	return 1.0 + BAN_HP_BIAS * float(maxi(hp - FRAGILE_HP, 0))
