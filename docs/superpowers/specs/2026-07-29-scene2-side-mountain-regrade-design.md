# Scene2 左右山体重新调色设计

## 目标

将 `MountainLeft` 与 `MountainRight` 从当前偏绿的表现调整到接近瀑布
ridge 的灰岩体系，同时保留明确的前后景差异。

## 设计

- 仅修改 `src/ui/scenes/scene2.tscn` 中两个山体各自的
  `ShaderMaterial` 参数与 `self_modulate`。
- `MountainLeft` 使用较实、较清晰的中性灰岩色；保留原有桃枝摆动和
  桃花色彩辨识度。
- `MountainRight` 使用更冷、更低对比的灰蓝岩色，使其退入背景，但不再
  使用明显的灰绿色 atmosphere tint。
- 不修改两座山的位置、大小、层级、视差、贴图、遮罩或动画参数。
- 不修改瀑布 ridge 材质；ridge 仅作为色彩关系参考。

## 验收

- 肉眼不再首先将左右山体识别为绿色。
- 两座山与 ridge 属于同一灰岩色彩家族。
- 左山仍比右山更实、更清晰，右山仍有景深退后感。
- 桃花不因调色变灰，像素边缘保持清晰。
- Scene2 正常运行，相关测试通过。
