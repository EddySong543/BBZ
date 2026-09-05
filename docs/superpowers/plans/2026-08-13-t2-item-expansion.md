# Rare Item Expansion Implementation Plan

> **For agentic workers:** Execute inline in this task. The user has already approved all nine mechanics; do not reopen design or rebalance them.

**Goal:** Add nine approved Tier-2 items as complete, playable items across BattleCore, UI, AI, catalog, art placeholders, localization, documentation, and regression tests.

**Architecture:** Each item keeps its own stateless `ItemEffect` script. BattleCore gains only the reusable hooks required by the approved mechanics: a post-Tianluo rule-preparation pass, friendly-hero item targeting, whole-attack damage capping, team damage sharing, healing conversion/blocking, bound attack targeting, and hero-hit-hook suppression. The existing item secondary-target value is routed to either an item slot or a friendly hero slot according to the source item.

**Tech Stack:** Godot 4, typed GDScript, GUT, existing `tools/run_godot.ps1` launcher.

## Global Constraints

- Preserve the existing dirty worktree and all passed battle/UI behavior.
- Use half-point integer units internally; player copy remains in displayed point units.
- An attack means only `波` or `大波`; independent item damage is not a hit.
- Use placeholder item icons only; do not generate final art.
- Do not commit or push.

---

### Task 1: Lock core behavior with regression tests

**Files:**
- Create: `tests/unit/battle/v4/test_items_t2_expansion.gd`

**Interfaces:**
- Consumes: `BattleCore.use_item`, `BattleCore.use_slot`, `BattleCore.resolve`.
- Produces: executable specifications for all nine items and their cross-item boundaries.

- [ ] Write failing GUT tests for the exact approved descriptions, including multi-segment attacks, shield absorption, hero-hook suppression, friendly target validation, and healing conversion under healing lock.
- [ ] Run only this GUT file and confirm failure because the nine catalog IDs are absent.

### Task 2: Implement reusable BattleCore boundaries and item scripts

**Files:**
- Modify: `src/battle/item_effect.gd`
- Modify: `src/battle/battle_core.gd`
- Create: `src/battle/items/t2_difeng_kou.gd`
- Create: `src/battle/items/t2_fuying_suo.gd`
- Create: `src/battle/items/t2_ningxue_gao.gd`
- Create: `src/battle/items/t2_zhenwen_zhen.gd`
- Create: `src/battle/items/t2_lianxin_suo.gd`
- Create: `src/battle/items/t2_fencun_chi.gd`
- Create: `src/battle/items/t2_yijia_huan.gd`
- Create: `src/battle/items/t2_huzhen_ding.gd`
- Create: `src/battle/items/t2_fengmai_zhen.gd`

**Interfaces:**
- Produces: `ItemEffect.prepare_pre(...)`, `BattleCore.set_item_mod(...)` rule flags, friendly hero target validation through `can_use`, and authoritative resolution.

- [ ] Add `prepare_pre` after Tianluo cancellation and before ordinary `apply_pre`, so symmetric rules are order-independent and cancellable.
- [ ] Route bound targets, suppress only hero hit hooks, cap the final pre-mitigation damage of a whole base attack, and distribute linked damage in half-point units across living heroes.
- [ ] Make `_heal` convert to shield before applying the “cannot heal” rule, allowing 凝血膏 and 封脉针 to form a deliberate combo.
- [ ] Implement the nine stateless effect scripts and rerun the core test file to green.

### Task 3: Add catalog, sorting, placeholders, localization, and design truth sources

**Files:**
- Modify: `src/battle/item_catalog.gd`
- Modify: `design/items-firstrelease.md`
- Modify: `design/items-list.md`
- Modify: `design/items.md`
- Modify: `design/build-design-framework.md`
- Modify: `design/gdd/game-concept.md`
- Modify: `assets/i18n/strings_zh.csv`
- Modify: `assets/sprites/items/README.md`
- Modify: `assets/sprites/items/_name_id_map.md`
- Add: nine placeholder PNGs and generated `.import` metadata under `assets/sprites/items/`.

**Interfaces:**
- Produces: 77 formal items = T1 30 / T2 30 / T3 17, with T2 sorted by full toneless pinyin.

- [ ] Add nine `ev_half=4` catalog records with the approved one-sentence copy and explicit roles/dimensions.
- [ ] Insert all nine IDs into `DISPLAY_ORDER` by full toneless pinyin and update count assertions.
- [ ] Copy the established placeholder icon source, run Godot import, rebuild the item-name map, and rescan i18n.
- [ ] Update current-pool and all-candidate counts without rewriting historical rejected entries.

### Task 4: Complete friendly-target UI and local authority

**Files:**
- Modify: `src/ui/battle_screen.gd`
- Modify: `tests/unit/ui/test_battle_item_target_selection.gd`

**Interfaces:**
- Produces: friendly portrait selection for 移甲环/护阵钉 and BattleCore validation of the selected hero slot.

- [ ] Keep item-slot targets and hero targets in separate local dictionaries so item-slot dependency highlighting remains correct.
- [ ] Reuse the existing per-item secondary-target array in the local submission; validate `-1..2` and route by the source item ID in BattleCore.
- [ ] Add local-core tests for valid reserve/any-living targets, invalid active/dead targets, cancellation, and preview parity.
- [ ] Run a 1920x1080 interaction probe: select item, select friendly portrait, cancel, and submit.

### Task 5: Teach AI and evaluators not to waste the items

**Files:**
- Modify: `src/battle/ai/battle_ai.gd`
- Modify: `src/battle/ai/battle_eval.gd`
- Modify: `src/battle/ai/battle_eval_v2.gd`
- Modify: `tests/unit/battle/ai/test_battle_ai_items.gd`

**Interfaces:**
- Produces: legal friendly targets, action-gated use for attack items, duplicate suppression for non-stacking rules, and state-aware defensive use.

- [ ] Add deterministic target choice for 移甲环 and 护阵钉.
- [ ] Gate attack-only items on the selected base attack and avoid spending redundant copies of one-turn global rules.
- [ ] Add item-state value for concentrated shield, linked damage, healing conversion/blocking, and opponent hit-hook suppression.
- [ ] Run AI tests and a short simulation smoke test.

### Task 6: Final verification and review

**Files:**
- Add memory note under `C:/Users/Edzzz/.codex/memories/extensions/ad_hoc/notes/` as explicitly requested by the user.

- [ ] Run fresh Godot import, targeted GUT groups, full GUT, icon audit, i18n scan, simulation smoke, and `git diff --check`.
- [ ] Compare failures against the pre-existing Scene5 baseline and report actual counts without hiding unrelated failures.
- [ ] Record the lesson that future item batches must cover the full action/resource/target/status/position matrix before adding multiple shield connectors, and must reject mediocre filler instead of padding a long list.
- [ ] Report implemented items, verification evidence, shield-density conclusion, 均命秤 tier judgment, and concise revisions for 锁泉塞/回照镜.
