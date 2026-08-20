# 第三方组件与许可声明（Third-Party Notices）

> 2026-07-17 建（发行审计⑤）：本文件随发行物分发（export_presets include_filter 已强制打包）。
> 新增第三方资产/库时必须在此登记——发布清单核对项。

## 随发行物分发（运行时依赖）

| 组件 | 用途 | 许可证 | 许可文本 |
|------|------|--------|----------|
| Z工坊像素黑体 12px M CN / Z Labs Pixel 12px M CN | 全游戏 UI 字体 | SIL Open Font License 1.1 | 随包 `assets/font/ZLabsPixel-OFL.txt`（上游 https://github.com/Astro-2539/ZLabs-Pixel-12px） |
| Ark Pixel Font（方舟像素字体·12px/16px proportional zh_cn） | 保留的旧版回退字体 | SIL Open Font License 1.1 | 随包 `assets/font/`（OFL 全文见 fusion-pixel-OFL.txt 同款条款·上游 https://github.com/TakWolf/ark-pixel-font） |
| Fusion Pixel Font（缝合像素字体·10px proportional zh_hans） | 小号 UI 字体 | SIL Open Font License 1.1 | 随包 `assets/font/fusion-pixel-OFL.txt`（上游 https://github.com/TakWolf/fusion-pixel-font） |

OFL 1.1 要点：允许商用与随软件捆绑分发；不得单独出售字体本体；须保留版权与许可声明。

## 仅开发期依赖（不进发行包·导出排除在案）

| 组件 | 用途 | 许可证 |
|------|------|--------|
| GUT — Godot Unit Test 9.6.0（addons/gut） | 单元测试框架 | MIT（addons/gut/LICENSE.md） |

## 引擎

- Godot Engine 4.7 — MIT License（https://godotengine.org/license）；导出模板随官方分发。
