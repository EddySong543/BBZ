extends GutTest

## ============================================================================
## DraftAI —— 选人策略 AI
##   BAN：3 个去重合法索引 ｜ PICK：3 个去重、排除 banned、HP 曲线角色均衡 ｜ 覆盖性
## ============================================================================

func _hero(id: String, hp: int) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.hero_name = id
	h.max_hp = hp
	return h


## 角色齐全的池：2 坦克(6/7) + 2 灵活(5) + 2 脆皮(4/3) + 余量
func _pool() -> Array:
	return [
		_hero("tank_a", 6), _hero("tank_b", 7),
		_hero("flex_a", 5), _hero("flex_b", 5),
		_hero("frag_a", 4), _hero("frag_b", 3),
		_hero("x_a", 5), _hero("x_b", 6), _hero("x_c", 4), _hero("x_d", 5),
	]


func _role_of(hp: int) -> int:
	if hp >= 6:
		return DraftAI.Role.TANK
	if hp <= 4:
		return DraftAI.Role.FRAGILE
	return DraftAI.Role.FLEX


# ---- BAN ----

func test_choose_bans_returns_distinct_valid() -> void:
	# Arrange
	var pool := _pool()
	var d := DraftAI.new(42)

	# Act
	var bans: Array = d.choose_bans(pool, 3)

	# Assert
	assert_eq(bans.size(), 3, "应禁 3 个")
	assert_eq(bans, _unique(bans), "禁用索引去重")
	for idx in bans:
		assert_true(idx >= 0 and idx < pool.size(), "禁用索引合法")


# ---- PICK ----

func test_choose_picks_excludes_banned_and_distinct() -> void:
	# Arrange
	var pool := _pool()
	var d := DraftAI.new(7)
	var banned: Array = [0, 1, 2]

	# Act
	var picks: Array = d.choose_picks(pool, banned, 3)

	# Assert
	assert_eq(picks.size(), 3, "应选 3 个")
	assert_eq(picks, _unique(picks), "出战索引去重")
	for idx in picks:
		assert_false(idx in banned, "不得选已禁用英雄")
		assert_true(idx >= 0 and idx < pool.size(), "出战索引合法")


func test_choose_picks_balances_role_curve() -> void:
	# Arrange：角色齐全 → 应坦克/灵活/脆皮各一
	var pool := _pool()
	var d := DraftAI.new(123)

	# Act
	var picks: Array = d.choose_picks(pool, [], 3)

	# Assert
	var roles: Array = []
	for idx in picks:
		roles.append(_role_of(pool[idx].max_hp))
	assert_true(DraftAI.Role.TANK in roles, "含坦克")
	assert_true(DraftAI.Role.FLEX in roles, "含灵活")
	assert_true(DraftAI.Role.FRAGILE in roles, "含脆皮")


func test_picks_cover_pool_over_many_drafts() -> void:
	# Arrange：温度探索应让多数英雄都被选到（覆盖性）
	var pool := _pool()
	var seen := {}

	# Act
	for s in range(200):
		var d := DraftAI.new(s + 1)
		for idx in d.choose_picks(pool, [], 3):
			seen[idx] = true

	# Assert
	assert_gte(seen.size(), int(pool.size() * 0.7), "200 次选人应覆盖 ≥70% 池（避免只挑固定几个）")


func _unique(a: Array) -> Array:
	var out: Array = []
	for x in a:
		if not x in out:
			out.append(x)
	return out
