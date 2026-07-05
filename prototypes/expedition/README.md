# 远征模式原型（prototypes 隔离区·可丢弃代码）

> 设计真相源：`design/gdd/expedition-mode.md` + 子文档 A `design/expedition-monsters.md`。
> 本目录代码**不进 src/**，验证通过后按项目标准重写正式实装。

## 文件

| 文件 | 作用 |
|------|------|
| `expedition_monsters.json` | 首发 10 只怪定义（数据驱动·schema 见下） |
| `monster_policy.gd` | 怪物驾驶员：odds/cycle/turtleRule/multiTable/phased 五种策略·含可支付归一化（§5.1） |
| `run_expedition_sim.gd` | headless 校准：明牌真实性 ≤2pp / 遭遇拍数带 / 玩家胜率 / fallback 计数 |
| `out_calibration.md` | 校准报告（跑一次刷新一次） |

## 跑校准

```bash
godot --headless --path <项目根> --script res://prototypes/expedition/run_expedition_sim.gd
```

## JSON schema（camelCase）

- 公共：`name`（中文名·占位可换）`series`（gamble/exam）`tier`（1/2/3）`hp`（点数）`kind`
- `kind: "odds"`：`tables[]` = `{id, trigger:{type: base|energyGe|hpLe, value}, odds:{attack|defend|charge|bigAttack|bigDefend: 权重}}`——触发器从上到下首命中生效，base 放末位
- `kind: "cycle"`：`cycle[]` = 动作名固定循环；付不起 → 改攒并计 fallback
- `kind: "turtleRule"`：能量 ≥2 能必大防、否则防（铁壳龟专用）
- `kind: "multiTable"`：`tables[]`/`enragedTables[]`（无 trigger）+ `enrageHpLe`——每拍明牌抽 1 张
- `kind: "phased"`：`phases[]` = 各带可选 `hpLe` 的子定义（取最后一个满足项·首项默认）
- `deferred`：该怪暂不完整实现的说明（如 k5 被动需引擎 hook）

## 已知边界（本轮校准的口径）

- 玩家 = 白板 HP5 单英雄 + BattleAI v1（depth2），**无道具无技能**——纯动作层；正式实装后带技能/道具重校
- k5 缠杀藤只跑本体（被动"同目标连击 +1 伤"需引擎 hook + 多英雄队伍，标 deferred）
- 怪物走与玩家完全相同的动作合法性（can_afford）与能量经济（GDD §3.1 规则层锁死）
