extends HeroSkill

## h13 黑暗子鼠【封窟】被动 · 干扰 · HP4
## 黑暗子鼠出战时，封住敌方 0.5 能（= 1 半能）：敌方【可用】能量 = 能量池 − 0.5（最低 0），
## 被锁进暗窟、不可动用；不消耗 / 不入己池（纯削敌·干扰单标签）；黑暗子鼠下场 / 阵亡即解封。
## 与 h01 子鼠【囤鼠】对称（囤鼠增己 0.5 / 暗鼠封敌 0.5）。引擎在 BattleCore.usable_energy() 统一应用封印。
##
## 设计依据（heroes-redesign / build-design-framework）：暗鼠 = 把"囤"扭曲成"夺 / 锁"——
##   能量冻结原语（heroes-schools §5.1 空槽首用）。区别于申猴 h09"碎存量能(蒸发·命中触发)"——
##   暗鼠是"在场常驻封锁(存量可用性)"；不碰流量(堵被动回能 = 道具 / §15 系统操作层地盘)。

const FENGKU_LOCK := 1   # 封印 0.5 能 = 1 半能（主旋钮）


func enemy_energy_lock(_battle: BattleCore, _player: int, _slot: int) -> int:
	return FENGKU_LOCK
