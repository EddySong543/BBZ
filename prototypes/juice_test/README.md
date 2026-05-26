# juice_test — A 方案视觉验证原型

**状态**：✅ 已验收并**生产化进 `src/`**（2026-05-26）。本目录保留作参考，不再维护。

## 这是什么

验证"**静态立绘 + 代码 Juice + 占位斩击特效**"（美术 A 方案，剪纸绑定否决后的方向）在像素立绘上是否显得"假"的一次性视觉原型。结论：手感成立，方案通过。

运行：Godot 编辑器打开 `juice_test.tscn` → F6。

## 内容

| 文件 | 作用 |
|------|------|
| `juice_test.tscn` / `juice_test.gd` | 演示台：攻击蓄力前冲、命中白闪、斩击弧光、伤害数字、震屏 |
| `slash_vfx.gd` | 程序化斩击弧光（原型版） |
| `hit_flash.gdshader` | 命中白闪着色器（原型版） |

## ⚠️ 已被生产版取代——改 Juice 请改 src，勿改这里

原型里的 juice 已按生产标准重写进正式代码，**不引用本目录**：

- `src/ui/components/slash_vfx.gd`（`class_name SlashVFX`，正式版斩击弧光）
- `assets/shaders/hit_flash.gdshader`（正式版命中白闪）
- 调用方 `src/ui/battle_screen.gd::_play_battle_anims`（攻防攒/命中/死亡全套手感）

本目录与 `src/` 隔离（见 `.claude/docs/directory-structure.md`：prototypes/ = 一次性原型）。
