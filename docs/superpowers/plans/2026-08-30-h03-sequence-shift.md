# H03 Sequence Shift Implementation Plan

> **2026-08-30 落地状态：部分完成。** 已落地的纯调度器为
> `BattleResolutionTimeline`（`battle_resolution_timeline.gd`）；旧 H03 对攻先制已退役，
> 当前运行时已通过【连环鼓】第二行动验证同列完成、自动等待、提前防御与晚行动取消。
> 当前实际 hook 名为 `shifts_enemy_sequence_after_base_attack(...) -> bool`，H03 固定只生成一次等待。
> 任意道具 / 英雄行动统一提交、客户端防伪造等待与完整动作列表仍是本计划的后续迁移；
> 下文未勾选的 `TurnSequence` 接口和示例是迁移草案，不代表当前 API。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Work in the existing checkout only after re-reading the dirty diff. Do not create commits or push unless Eddy explicitly requests it.

**Goal:** Replace the old PRE / action / POST cross-player batch with a left-aligned column runner, then implement H03【白额雷音】so its first connected base attack each turn inserts one server-generated wait before the opponent's remaining submitted steps.

**Architecture:** Keep submitted player sequences immutable and put cursor / generated-wait state in a focused `TurnSequence` runner. `BattleCore` resolves one column at a time, lets both current steps complete, then applies deferred wait requests at the column boundary. H03 exposes a stateless post-base-attack hook; protocol, AI and UI may submit only real item / action steps and consume the authoritative column event stream.

**Tech Stack:** Godot 4.7.2, typed GDScript, GUT, versioned dictionary protocol, authoritative `BattleCore` snapshots and event replay.

## Global Constraints

- Design truth source: `docs/superpowers/specs/2026-08-30-h03-sequence-shift-design.md`.
- Internal names use `step`, `column` and `generated_wait`; final player-facing terminology remains unapproved and must not be invented during implementation.
- Sequences are left-aligned. Both steps in one column complete before any post-column sequence shift is applied.
- H03 triggers only from its first connected base `波` / `大波` each turn; blocked attacks do not consume the chance, and multi-hit plumbing cannot duplicate the wait.
- A generated wait never mutates the submitted sequence, never advances its cursor, and is not generated when the target has no real remaining step.
- Clients and AI cannot submit `generated_wait`; both protocol validation and `BattleCore` business validation reject it.
- Remove the old H03 clash-priority / lethal-cancel behavior from both the primary action path and `连环鼓` second-action path.
- Preserve current `damage_number_state`, H11 event, Scene9, UI and all unrelated dirty-worktree changes. Re-read `git diff` immediately before every overlapping patch; never replace an entire dirty file or broad function from a stale copy.
- Use `apply_patch` for hand edits. Do not run formatters or generated-file rewrites across unrelated files.
- Do not run `git add`, `git commit`, `git push`, `stash`, `reset`, `checkout --` or rebase unless Eddy separately authorizes that operation.

---

### Task 1: Pure Left-Aligned Column Runner

**Files:**
- Create: `src/battle/turn_sequence.gd`
- Create: `tests/unit/battle/v4/test_turn_sequence.gd`

**Interfaces:**
- Produces: `TurnSequence.STEP_ITEM`, `STEP_ACTION`, `STEP_GENERATED_WAIT`.
- Produces: `submit(player: int, steps: Array) -> String` where `""` means accepted and client-supplied wait returns `"generated_wait_forbidden"`.
- Produces: `begin_column() -> Array`, `finish_column(wait_requests: Array[int]) -> Array[int]`, `has_real_remaining(player: int) -> bool`, and `is_complete() -> bool`.
- Guarantees: submitted arrays are deep-copied once, cursors advance only for real steps, and `finish_column()` returns the effective generated waits after suppressing requests for players with no real remaining step.

- [ ] **Step 1: Write the failing runner contract**

```gdscript
extends GutTest

const TurnSequence := preload("res://src/battle/turn_sequence.gd")

func _step(label: String) -> Dictionary:
	return {kind = TurnSequence.STEP_ITEM, label = label}

func test_h03_wait_shifts_only_the_remaining_sequence() -> void:
	var runner := TurnSequence.new()
	var p0: Array = [_step("h03_attack"), _step("c")]
	var p1: Array = [_step("a"), _step("b"), _step("action")]
	assert_eq(runner.submit(0, p0), "")
	assert_eq(runner.submit(1, p1), "")
	assert_eq(runner.begin_column()[0]["label"], "h03_attack")
	assert_eq(runner.begin_column()[1]["label"], "a")
	assert_eq(runner.finish_column([0, 1]), [0, 1])
	var shifted: Array = runner.begin_column()
	assert_eq(shifted[0]["label"], "c")
	assert_eq(shifted[1]["kind"], TurnSequence.STEP_GENERATED_WAIT)
	runner.finish_column([0, 0])
	assert_eq(runner.begin_column()[1]["label"], "b")
	assert_eq(p1.map(func(step: Dictionary) -> String: return String(step["label"])),
		["a", "b", "action"], "runner must not splice the submitted array")

func test_wait_is_not_generated_after_the_target_sequence_ends() -> void:
	var runner := TurnSequence.new()
	assert_eq(runner.submit(0, [_step("h03_attack"), _step("c")]), "")
	assert_eq(runner.submit(1, [_step("a")]), "")
	runner.begin_column()
	assert_eq(runner.finish_column([0, 1]), [0, 0])
	assert_eq(runner.begin_column()[1], {})

func test_client_supplied_wait_is_rejected() -> void:
	var runner := TurnSequence.new()
	assert_eq(runner.submit(0, [{kind = TurnSequence.STEP_GENERATED_WAIT}]),
		"generated_wait_forbidden")
```

Add two more explicit cases in the same file:

- both players receive one wait after a mirror column and both cursors remain stationary for that generated column;
- two pending generated waits execute in two distinct columns without changing the order of real steps.

- [ ] **Step 2: Run the focused test and confirm RED**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/battle/v4/test_turn_sequence.gd' -TimeoutSeconds 120
```

Expected: FAIL because `res://src/battle/turn_sequence.gd` does not exist.

- [ ] **Step 3: Implement the immutable cursor runner**

Create `src/battle/turn_sequence.gd` with this public shape and algorithm:

```gdscript
class_name TurnSequence
extends RefCounted

const STEP_ITEM: StringName = &"item"
const STEP_ACTION: StringName = &"action"
const STEP_GENERATED_WAIT: StringName = &"generated_wait"

var _submitted: Array = [[], []]
var _cursor: Array[int] = [0, 0]
var _pending_waits: Array[int] = [0, 0]
var _current: Array = [{}, {}]

func submit(player: int, steps: Array) -> String:
	if player < 0 or player > 1:
		return "bad_player"
	var normalized: Array = []
	for step_variant: Variant in steps:
		if not step_variant is Dictionary:
			return "bad_step"
		var step: Dictionary = (step_variant as Dictionary).duplicate(true)
		var kind := StringName(step.get("kind", &""))
		if kind == STEP_GENERATED_WAIT:
			return "generated_wait_forbidden"
		if kind != STEP_ITEM and kind != STEP_ACTION:
			return "bad_step_kind"
		normalized.append(step)
	_submitted[player] = normalized
	_cursor[player] = 0
	_pending_waits[player] = 0
	return ""

func begin_column() -> Array:
	_current = [{}, {}]
	for player: int in [0, 1]:
		if _pending_waits[player] > 0 and has_real_remaining(player):
			_current[player] = {kind = STEP_GENERATED_WAIT, generated = true}
		elif has_real_remaining(player):
			_current[player] = (_submitted[player][_cursor[player]] as Dictionary).duplicate(true)
	return _current.duplicate(true)

func finish_column(wait_requests: Array[int]) -> Array[int]:
	for player: int in [0, 1]:
		var kind := StringName((_current[player] as Dictionary).get("kind", &""))
		if kind == STEP_GENERATED_WAIT:
			_pending_waits[player] = maxi(0, _pending_waits[player] - 1)
		elif kind == STEP_ITEM or kind == STEP_ACTION:
			_cursor[player] += 1
	var effective: Array[int] = [0, 0]
	for player: int in [0, 1]:
		var requested: int = maxi(0, int(wait_requests[player]))
		if requested > 0 and has_real_remaining(player):
			_pending_waits[player] += requested
			effective[player] = requested
	_current = [{}, {}]
	return effective

func has_real_remaining(player: int) -> bool:
	return _cursor[player] < (_submitted[player] as Array).size()

func is_complete() -> bool:
	return not has_real_remaining(0) and not has_real_remaining(1)
```

- [ ] **Step 4: Run the focused test and confirm GREEN**

Run the Task 1 command again.

Expected: all `test_turn_sequence.gd` cases pass; no parse errors.

- [ ] **Step 5: Inspect only this task's diff**

```powershell
$Repo = 'D:\Game\BoBoZan\Claude-Code-Game-Studios-cn-localization'
git -c safe.directory=$Repo -C $Repo diff --check -- src/battle/turn_sequence.gd tests/unit/battle/v4/test_turn_sequence.gd
git -c safe.directory=$Repo -C $Repo diff --stat -- src/battle/turn_sequence.gd tests/unit/battle/v4/test_turn_sequence.gd
```

Expected: no whitespace errors. Do not stage or commit.

---

### Task 2: BattleCore Column Resolution and H03 Hook

**Files:**
- Modify: `src/battle/battle_core.gd:54-89,613-736,1574-1620,2371-2555,3338-3555,3786-4405,4791-5215`
- Modify: `src/battle/hero_skill.gd:136-164`
- Modify: `src/battle/skills/h03_leiyin.gd:3-8`
- Modify: `tests/unit/battle/v4/test_heroes_zodiac_v4.gd:261-480`
- Modify: `tests/unit/battle/v4/test_battle_snapshot.gd`
- Modify: `tests/unit/battle/v4/test_items_t1.gd`

**Interfaces:**
- Consumes: `TurnSequence` from Task 1.
- Produces: `BattleCore.submit_sequence(player: int, steps: Array) -> String` and a single canonical column-based `resolve()` path.
- Produces: `HeroSkill.opponent_sequence_waits_after_base_attack(context: Dictionary) -> int`, default `0`.
- Produces authoritative events `sequence_step`, `sequence_wait_inserted`, `sequence_wait_skipped`, and `sequence_wait_executed`, each with a zero-based `column`.
- Preserves: `_apply_resolve_hit()` aggregate `base_context.connected`; current “命中” remains the defense-gate result, not `hp_damage_total > 0`.

- [ ] **Step 1: Replace old H03 tests with RED sequence tests**

Retire assertions for `base_attack_clash_priority` and `base_attack_cancelled`. Add helpers that give each side ready test items and submit exact step arrays. The primary contract must include:

```gdscript
func test_h03_first_connected_attack_waits_before_enemy_remaining_steps() -> void:
	var b := _battle_team(["h03", "test_p0_1", "test_p0_2"],
		["test_p1_0", "test_p1_1", "test_p1_2"], 5, 20)
	_ready_item(b, 0, 0, "t1_feibiao")
	_ready_item(b, 1, 0, "t1_feibiao")
	_ready_item(b, 1, 1, "t1_jiudun")
	assert_eq(b.submit_sequence(0, [
		_action_step(ActionDef.Action.ATTACK), _item_step(0)]), "")
	assert_eq(b.submit_sequence(1, [
		_item_step(0), _item_step(1), _action_step(ActionDef.Action.CHARGE)]), "")
	var result: Dictionary = b.resolve()
	assert_true(_has_sequence_event(result, "sequence_wait_inserted", 1, 0))
	assert_true(_has_sequence_event(result, "sequence_wait_executed", 1, 1))
	assert_eq(_real_step_labels(result, 1), ["t1_feibiao", "t1_jiudun", "action:0"],
		"enemy real steps keep their submitted order")
```

Add separate tests for all approved boundaries:

- `防` / `大防` fully blocks H03 and does not consume first-connect eligibility;
- armor absorbs all post-gate damage but the wait is still generated;
- an item or active attack from H03 does not generate a wait;
- multi-hit / riders generate at most one request for the whole base attack;
- a connected first attack with no enemy remainder emits `sequence_wait_skipped` and consumes the once-per-turn chance;
- H03 mirror inserts and executes one wait for both sides in the same next column;
- same-column lethal attacks both complete and can still produce a draw;
- a later extra base action triggers only if every earlier H03 base attack was blocked.

- [ ] **Step 2: Run the focused hero test and confirm RED**

```powershell
& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/battle/v4/test_heroes_zodiac_v4.gd' -TimeoutSeconds 180
```

Expected: new sequence submission and wait-event assertions fail; old runtime still emits clash-priority behavior.

- [ ] **Step 3: Add the stateless hero hook and retire priority**

In `hero_skill.gd` replace `base_attack_clash_priority()` with:

```gdscript
## 整次基础攻击所在 column 完成后，请求令敌方后续真实序列先等待几次。
## context.first_base_attack_connect_this_turn 只在本英雄本回合第一次成功命中时为 true。
func opponent_sequence_waits_after_base_attack(_context: Dictionary) -> int:
	return 0
```

In `h03_leiyin.gd` use:

```gdscript
extends HeroSkill

## h03 尾火【白额雷音】被动 · 进攻 · HP5
## 本回合第一次基础攻击命中后，令敌方剩余序列先等待一次。

func opponent_sequence_waits_after_base_attack(context: Dictionary) -> int:
	return 1 if bool(context.get("first_base_attack_connect_this_turn", false)) else 0
```

Delete both primary and `连环鼓` callers of `base_attack_clash_priority()` and all lethal `base_attack_cancelled` branches. Do not remove or overwrite adjacent uncommitted `damage_number_state` logic.

- [ ] **Step 4: Introduce canonical submitted-step state**

Add `_submitted_sequences: Array = [[], []]` and implement:

```gdscript
func submit_sequence(player: int, steps: Array) -> String:
	var runner := TurnSequence.new()
	var structural_error: String = runner.submit(player, steps)
	if structural_error != "":
		return structural_error
	var semantic_error: String = _validate_submitted_steps(player, steps)
	if semantic_error != "":
		return semantic_error
	_submitted_sequences[player] = steps.duplicate(true)
	return ""
```

`_validate_submitted_steps()` must enforce, with explicit error strings:

- only item and action kinds;
- item source slot `0..SLOT_COUNT-1`, no repeated instance in one sequence, legal target and current ownership;
- one normal action, with one additional action only when `连环鼓` is legally queued;
- `ActionDef` action, target and all empowered / split / blood-payment / discount flags use the same checks currently centralized in `legal_actions()` and `apply_choice()`;
- no direct generated wait, no unknown dictionary fields that affect execution, and no mutation of battle state during validation.

Keep `select_action()`, `use_slot()` and `apply_choice()` as compatibility builders during this task, but make `resolve()` canonicalize their queued PRE / action / POST state into the same immutable step schema before entering the runner. There must be only one damage/settlement implementation after canonicalization; do not retain a second H03 behavior in the legacy path.

- [ ] **Step 5: Resolve one complete column before applying deferred waits**

Extract the current action-pair and item execution machinery into column-scoped helpers:

```gdscript
func _resolve_sequence_column(column_index: int, steps: Array, events: Array,
		first_connect_counts: Array[Dictionary]) -> Array[int]

func _resolve_item_step(player: int, step: Dictionary, column_index: int,
		events: Array) -> void

func _resolve_action_column(steps: Array, column_index: int, events: Array) -> Array
```

The implementation order is normative:

1. append one `sequence_step` event per non-empty side, marking generated waits separately;
2. take the column-boundary state used by both real steps;
3. execute both current real steps under the existing simultaneous pair contract so P1/P2 iteration order cannot cancel the other current step;
4. finish all damage, on-hit, after-attack, death and same-column item effects belonging to those steps;
5. aggregate each H03 base attack into one `base_context` and set `first_base_attack_connect_this_turn` from a per-source-slot connected count; retain the action-start `src_slot` and skill reference so a same-column death cannot erase an attack that already completed;
6. collect, but do not yet apply, `opponent_sequence_waits_after_base_attack()` results;
7. call `TurnSequence.finish_column(wait_requests)` once; emit `sequence_wait_inserted` only for effective requests and `sequence_wait_skipped` for a valid H03 request with no real remainder;
8. enter the next column.

Every content event appended while a step executes must inherit its `column` before being returned. A generated wait emits `sequence_wait_executed` and no item/action cost, durability, hero hook or history entry.

- [ ] **Step 6: Preserve clone compatibility and keep transient execution out of snapshots**

Copy `_submitted_sequences` deeply in `clone()` so AI and legality probes never share pending dictionaries with the source battle. Keep `TurnSequence`, its cursors and pending generated waits local to the synchronous `resolve()` call. `MatchRoom._pending` remains the sole owner of player submissions before both sides are ready, so do not add any of these transient fields to `SNAP_REQUIRED_KEYS`, `to_snapshot()` or `from_snapshot()`, and do not bump `SNAPSHOT_VERSION` for this feature.

Add tests in `test_battle_snapshot.gd` that prove:

- cloning after one `submit_sequence()` produces an independent pending array;
- `resolve()` returns the complete `sequence_step` / wait trace before the post-resolution snapshot is produced;
- the snapshot contains no `submitted_sequences`, cursor or pending-wait key;
- replaying the returned authoritative events does not mutate or reinsert waits into the restored final snapshot.

- [ ] **Step 7: Run battle-core regression suites**

```powershell
& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/battle/v4/test_turn_sequence.gd' -TimeoutSeconds 120
& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/battle/v4/test_heroes_zodiac_v4.gd' -TimeoutSeconds 180
& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/battle/v4/test_battle_snapshot.gd' -TimeoutSeconds 180
& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/battle/v4/test_items_t1.gd' -TimeoutSeconds 180
```

Expected: all four files pass; no `base_attack_clash_priority` or `base_attack_cancelled` event remains in current H03 tests.

- [ ] **Step 8: Audit the overlapping dirty diff without committing**

```powershell
$Repo = 'D:\Game\BoBoZan\Claude-Code-Game-Studios-cn-localization'
git -c safe.directory=$Repo -C $Repo diff --check -- src/battle/battle_core.gd src/battle/hero_skill.gd src/battle/skills/h03_leiyin.gd tests/unit/battle/v4/test_heroes_zodiac_v4.gd tests/unit/battle/v4/test_battle_snapshot.gd
git -c safe.directory=$Repo -C $Repo diff -- src/battle/battle_core.gd src/battle/hero_skill.gd
```

Expected: no whitespace error; the diff still contains the pre-existing `damage_number_state` and H11 event work intact. Do not stage or commit.

---

### Task 3: Versioned Unified-Sequence Protocol

**Files:**
- Modify: `src/net/net_protocol.gd:7-43,47-210,218-239`
- Modify: `src/net/match_room.gd:7-16,116-244,262-275`
- Modify: `src/net/match_client.gd:3-23,46-76,112-123,178-188`
- Modify: `tests/unit/net/test_net_protocol.gd`
- Modify: `tests/unit/net/test_match_room.gd`

**Interfaces:**
- Produces: protocol v2 `submit_turn {v, kind, turn, steps:Array[Dictionary]}`.
- Produces: `NetProtocol.msg_submit_turn(turn: int, steps: Array) -> Dictionary`.
- Produces: `MatchClient.submit(steps: Array) -> void`.
- Consumes: `BattleCore.submit_sequence()` and authoritative column events from Task 2.

- [ ] **Step 1: Write protocol RED tests**

Add explicit cases:

```gdscript
func test_submit_turn_preserves_order_and_rejects_generated_wait() -> void:
	var steps: Array = [
		{kind = "item", slot = 0, target = -1},
		{kind = "action", action = ActionDef.Action.ATTACK, target = -1},
		{kind = "item", slot = 2, target = 1},
	]
	var msg: Dictionary = NetProtocol.msg_submit_turn(4, steps)
	assert_eq(msg["steps"], steps)
	assert_eq(NetProtocol.validate_c2s(msg), "")
	var forged: Dictionary = NetProtocol.msg_submit_turn(4, [
		{kind = "generated_wait"},
	])
	assert_eq(NetProtocol.validate_c2s(forged), "generated_wait_forbidden")
```

Also assert malformed dictionaries, excessive step count, duplicate item slots, invalid action/targets and old v1 `{action,item_slots}` messages are rejected without reaching `MatchRoom`.

In `test_match_room.gd`, submit the same H03 sequence from both player seats and require identical mirrored column traces on both clients.

- [ ] **Step 2: Run network tests and confirm RED**

```powershell
& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/net/test_net_protocol.gd' -TimeoutSeconds 120
& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/net/test_match_room.gd' -TimeoutSeconds 180
```

Expected: v2 step-schema tests fail against the old top-level action/item arrays.

- [ ] **Step 3: Replace the wire schema atomically**

- Increment `NetProtocol.PROTO_VERSION` from `1` to `2`.
- Set `MAX_SUBMITTED_STEPS` to `6`: three item slots, one H07 free switch action, one primary action and one legal `连环鼓` second action.
- Validate every dictionary field by kind. Reject `generated_wait` with that exact error before business logic.
- Preserve target and special-action flags inside the action step; preserve item source slot, hero target, item-slot target and private choice inside the item step.
- Do not accept both old and new schemas under v2. Old clients receive `version_mismatch`, avoiding an ambiguous compatibility branch.

Use this constructor shape:

```gdscript
static func msg_submit_turn(turn: int, steps: Array) -> Dictionary:
	return {
		v = PROTO_VERSION,
		kind = "submit_turn",
		turn = turn,
		steps = steps.duplicate(true),
	}
```

- [ ] **Step 4: Make MatchRoom validate and replay the exact sequence**

Replace `_apply_payload()`'s “all items first, then action” loop with one `core.submit_sequence(player, d["steps"])` call. Keep the current clone preflight and immutable `_pending` payload. When both submissions arrive, submit both exact arrays to the real core, resolve once, and broadcast the returned authoritative events.

Server timeout must submit exactly one real action step:

```gdscript
_on_submit(player, NetProtocol.msg_submit_turn(turn, [
	{kind = "action", action = ActionDef.Action.CHARGE, target = -1},
]))
```

The server must never copy generated waits into `_pending`; they exist only in the resolve event stream.

- [ ] **Step 5: Update client submission and event flipping**

Replace `MatchClient.submit(...)` with:

```gdscript
func submit(steps: Array) -> void:
	transport.send(NetProtocol.msg_submit_turn(turn, steps))
```

Extend `flip_events()` to mirror both `player` and `source_player` when present, so `sequence_wait_inserted` has the same local meaning for host and joiner. Add a double-flip equality assertion.

- [ ] **Step 6: Run network tests and confirm GREEN**

Run the Task 3 focused commands again.

Expected: protocol and room tests pass; forged waits are rejected at both layers; both clients receive the same authoritative columns after perspective flipping.

---

### Task 4: Client Sequence Builder, Playback and Action History Data

**Files:**
- Modify: `src/ui/battle_screen.gd:301-354,1322-1585,1691-1745,1885-1955,2086-2160,4350-4665,5270-5490`
- Create: `tests/unit/ui/test_battle_sequence_submission.gd`
- Modify: `tests/unit/ui/test_battle_resolution_bubble.gd:209-255`

**Interfaces:**
- Produces: `pending_sequence_steps: Array[Dictionary]` as the sole local planning order.
- Produces: `_append_item_step()`, `_set_action_step()`, `_preview_pending_sequence()` and `_group_resolution_events_by_column()`.
- Consumes: `MatchClient.submit(steps)` and Task 2's `sequence_step` / wait events.
- Does not produce final player-facing names for step, column or generated wait.

- [ ] **Step 1: Write UI RED tests for exact order and forbidden wait**

Create tests that append item A, select `波`, append item B and assert the outgoing message contains `[item A, action, item B]` in exactly that order. Changing `波` to `大波` must replace the existing action dictionary in place rather than move it to the end. Add a direct guard test proving `_append_local_step({kind="generated_wait"})` returns false.

In `test_battle_resolution_bubble.gd`, replace the old H03 serial priority trace with:

```gdscript
assert_eq(screen._resolution_phase_trace, [
	"column_begin:0",
	"step_begin:0:0", "step_begin:0:1",
	"step_end:0:0", "step_end:0:1",
	"column_end:0",
	"column_begin:1",
	"step_begin:1:0", "generated_wait:1:1",
	"step_end:1:0",
	"column_end:1",
])
```

The test must prove both column-0 animations finish before column 1 begins; it must not require a P1-before-P2 order inside column 0.

- [ ] **Step 2: Run UI tests and confirm RED**

```powershell
& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/ui/test_battle_sequence_submission.gd' -TimeoutSeconds 150
& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/ui/test_battle_resolution_bubble.gd' -TimeoutSeconds 180
```

Expected: submission still serializes item slots separately and the battle UI still expects `base_attack_clash_priority`.

- [ ] **Step 3: Replace split selection state with one local sequence**

- When an item is legally released/confirmed, append its exact item step.
- Keep at most one primary action step and update it in place when the player changes action.
- Place a legal `连环鼓` second action as a second action step at the user's chosen position under the existing two-different-actions rule.
- Derive item highlights and action-button state from `pending_sequence_steps`; do not maintain a second order in `selected_item_slots`.
- Build preview by cloning `BattleCore`, submitting the exact sequence and reading the same legality result used by the server.
- `_net_submit_turn()` sends only a deep copy of `pending_sequence_steps` and then clears local planning state after accepted submission.
- No button, drag target, keyboard shortcut or timeout code may append `generated_wait`.

- [ ] **Step 4: Play authoritative events column by column**

Group the received events by `column`. For each column:

1. start both real step animations from that column without awaiting one player before launching the other;
2. consume all content events assigned to that column;
3. await both sides' column work;
4. record generated waits as neutral authoritative history data without inventing final display copy;
5. then advance to the next column.

Delete `_play_h03_priority_clash()` and its handoff pause after all callers are gone. Preserve unrelated H11 bite, H19 transfer and `damage_number_state` timing by keeping their events inside their originating column.

- [ ] **Step 5: Run UI tests and confirm GREEN**

Run the Task 4 commands again.

Expected: exact outgoing order, action replacement, forged-wait guard and column playback tests all pass; old H03 priority trace no longer exists.

---

### Task 5: AI Generates and Evaluates Real Sequences

**Files:**
- Modify: `src/battle/ai/battle_ai.gd:56-78,427-1015,1201-1231`
- Modify: `src/battle/ai/README.md:11-28`
- Modify: `tests/unit/battle/ai/test_battle_ai.gd`
- Modify: `tests/unit/battle/ai/test_battle_ai_items.gd`
- Modify: `tests/unit/battle/ai/test_ai_async_equivalence.gd`

**Interfaces:**
- Produces: `choose_sequence(battle: BattleCore, player: int) -> Array[Dictionary]`.
- Keeps: `choose_action()` only as a compatibility wrapper that extracts the primary action dictionary from `choose_sequence()` until every caller is migrated.
- Consumes: `BattleCore.submit_sequence()` for all rollouts.

- [ ] **Step 1: Add AI RED contracts**

Add tests requiring that:

- every generated sequence contains legal real steps and no `generated_wait`;
- item-before-action and action-before-item candidates are both enumerated when both are legal;
- the rollout for H03 uses the authoritative wait shift rather than the retired clash priority;
- swapping AI player seats mirrors the chosen payoff matrix and does not change a deterministic result;
- synchronous and asynchronous shortlist evaluation return the same sequence for a fixed seed.

- [ ] **Step 2: Run AI tests and confirm RED**

```powershell
& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/battle/ai/test_battle_ai.gd' -TimeoutSeconds 180
& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/battle/ai/test_battle_ai_items.gd' -TimeoutSeconds 180
& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/battle/ai/test_ai_async_equivalence.gd' -TimeoutSeconds 180
```

Expected: old AI commits attack items before `apply_choice()` and cannot represent action-before-item.

- [ ] **Step 3: Migrate candidate generation and rollout**

- Reuse the current legal-action and item-shortlist filters; do not enumerate all factorial permutations.
- For each shortlisted item set, generate the distinct legal positions around the primary action and optional second action, deduplicate identical dictionaries, and cap using the existing shortlist budget.
- Replace `commit_attack_items()` plus `apply_choice()` in `_rollout_once()` with `submit_sequence()` for both players, then call the same `resolve()` as PvP.
- Preserve blind simultaneous evaluation: the AI may enumerate opponent legal sequences but cannot inspect the opponent's actual pending submission.
- Update `README.md` from “动作组合” to “有序序列组合” and document that generated waits are outcome events, never candidate steps.

- [ ] **Step 4: Run AI tests and confirm GREEN**

Run the Task 5 commands again.

Expected: all AI sequence legality, symmetry and async-equivalence tests pass within the existing timeout budget.

---

### Task 6: Published Data, Truth Sources and Full Verification

**Files:**
- Verify: `assets/data/heroes/h03.tres`
- Verify: `assets/i18n/strings_zh.csv`
- Verify/Modify: `design/heroes.md:105-113`
- Verify/Modify: `design/heroes-redesign.md:91-101`
- Modify: `docs/superpowers/specs/2026-08-28-item-sequence-interaction-design.md`
- Modify: `docs/superpowers/specs/2026-08-30-item-system-current-standard.md:36-54,75-87`
- Modify: `design/build-design-framework.md:90-102`
- Modify: `docs/superpowers/plans/2026-07-30-h03-clash-priority.md` header only

**Interfaces:**
- Produces one consistent current rule across hero data, sequence specifications and implementation comments.
- Preserves the approved natural-language H03 description while leaving formal player-facing system terminology unapproved.

- [ ] **Step 1: Verify the already-approved H03 publication values**

Require exactly:

```text
hero_name = "尾火【虎】"
max_hp = 5
skill_description = "白额雷音"
skill_detail = "尾火【虎】每回合首次攻击命中后，敌方行动序列中立刻获得一个空的行动位。"
```

Do not rewrite `h03.tres` or the CSV if the current dirty-worktree version already matches. Preserve line endings in `strings_zh.csv`.

- [ ] **Step 2: Align the three general sequence truth sources**

Replace the obsolete “each player manages only their own order / cross-player always independent” explanation with:

- sequences left-align into columns;
- both steps in a column complete;
- post-column effects can delay only real remaining steps;
- clients submit no generated waits;
- link to `2026-08-30-h03-sequence-shift-design.md` for the approved first consumer.

Do not broaden this edit into item-content redesign or final UI terminology.

- [ ] **Step 3: Mark the old H03 plan as historical**

Add one status line directly below its title:

```markdown
> **历史计划，已被 2026-08-30 H03 序列延后设计取代；不得作为当前实现依据。**
```

Keep the old body intact for archaeology.

- [ ] **Step 4: Scan for stale current semantics**

```powershell
rg -n "base_attack_clash_priority|base_attack_cancelled|对攻先制|击杀断招|优先攻击|优先结算" src tests assets/data assets/i18n design docs/superpowers/specs
```

Expected: runtime current paths and current hero descriptions have no old H03 behavior. Matches are allowed only in explicitly marked historical/rejected sections and the migration explanation in the new spec.

- [ ] **Step 5: Import and run the complete GUT suite**

```powershell
& .\tools\run_godot.ps1 -Mode Import -TimeoutSeconds 180
& .\tools\run_godot.ps1 -Mode Test -TimeoutSeconds 420
```

Expected: import exits 0 and the complete GUT suite passes. If an unrelated dirty-worktree test already failed before this implementation, report its exact test name and reproduce the same failure against the pre-task baseline; do not change unrelated files to hide it.

- [ ] **Step 6: Final dirty-worktree and scope audit**

```powershell
$Repo = 'D:\Game\BoBoZan\Claude-Code-Game-Studios-cn-localization'
git -c safe.directory=$Repo -C $Repo diff --check
git -c safe.directory=$Repo -C $Repo status --short
git -c safe.directory=$Repo -C $Repo diff --stat
git -c safe.directory=$Repo -C $Repo diff --name-status
```

Expected: no whitespace errors; every changed path is either listed in this plan or was already dirty before execution. Report pre-existing unrelated paths separately. Do not stage, commit or push.

---

## Execution Handoff

The plan is intentionally not executed by this documentation task. When implementation is explicitly authorized, use a test-first task runner, re-read the live dirty diff before each overlapping patch, and stop before any commit or push unless Eddy separately requests Git closeout.
