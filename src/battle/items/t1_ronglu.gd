extends ItemEffect

## 随身熔炉的选槽、烧毁与立即产能由 BattleCore.use_slot 原子处理。
## 保留空组件，使使用记录仍进入统一 item_uses / 信息清理 / 回合末消费管线。
