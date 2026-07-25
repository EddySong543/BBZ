# Scene1 左右竹景装饰设计

## 目标

把 `assets/import/left bamboo.png` 与 `right bamboo.png` 规范化为 Scene1 正式环境素材，在午夜屋顶战斗场景两侧形成不遮挡角色和 HUD 的近景框景。

## 素材与命名

- 正式路径：`assets/scenes/scene1/`
- 正式文件名：`scene1_bamboo_left.png`、`scene1_bamboo_right.png`
- 不裁切、不重采样原像素，只移动并改名；Scene1 通过正式路径引用，不引用暂存目录。
- Godot 使用 Lossless、无 mipmap、项目级 Nearest 过滤。

## 场景处理

- 两个 `TextureRect` 分别命名为 `BambooLeft`、`BambooRight`。
- 两张素材统一按整数 `2×` 显示。
- 放在 `LightShaft` 之后、`closeRf1` 之前，属于近景装饰但低于最前层屋檐、雾和粒子。
- 视差系数统一为 `1.25`。
- 左右主要贴屏幕边缘，底部接近屋顶层，不占用两名角色的战斗负空间。

## 融合处理

新增独立 `canvas_env_night_foliage.gdshader`，只负责保留 alpha、降低饱和度、压暗并染入靛蓝月色；不模糊、不改变 UV、不产生时间动画。两个竹景共享 Shader，使用各自本地 ShaderMaterial。

## 验证

- 回归测试锁定正式路径、原始纹理尺寸、整数显示尺寸、节点顺序和视差。
- Godot 导入后运行完整 GUT。
- 生成 Scene1 必要截图，检查角色/UI 遮挡、透明边缘、像素清晰度与夜色融合。
- 生成 Scene2 必要截图，仅确认没有被接入竹景或发生视觉污染。
