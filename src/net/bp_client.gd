extends RefCounted

## BP 客户端端（2026-07-17 打地基批·BP 联机化逻辑层）：吃 bp_* S2C 维护本端 BP 视图·产 C2S 提交。
## 不含任何 UI/场景依赖——bp_screen 联机接线（任务12 风格定案后）挂这上面：
##   对手席盖牌演出 ← opp_progress（真信号·替代本地 AI 随机盖牌时刻）；
##   我方选牌增减 → send_progress(手牌数)；确认 → confirm(picks)；
##   REVEAL 仪式 ← phase=="done" 时 my_picks()/opp_picks()。
##
## ⚠ 不自己 poll 传输层——同一 transport 上 MatchClient 也在收包，双消费者会互抢；
##   由 net_session.pump_bp() 统一收包按 kind 路由 feed() 进来（bp_*→这里·其余→MatchClient）。

const NetProtocol := preload("res://src/net/net_protocol.gd")

var transport: Variant = null      # 仅发送用（收包走 feed·见上）
var you: int = -1                  # 本端玩家位（bp_start 分配·0=房主）
var phase := "waiting"             # waiting / draft / done
var pool: Array = []               # hero_id 池（bp_start 快照·UI 建牌库用）
var opp_progress: int = 0          # 对方已亮张数（盖牌演出信号）
var picks: Array = [[], []]        # bp_reveal 落定（绝对视角·[房主队, 加入方队]）
var errors: Array[String] = []     # 服务器拒绝记录（UI 提示/调试）


func _init(t: Variant = null) -> void:
	transport = t


## 单包注入（net_session.pump_bp 按 kind 路由进来）。
func feed(d: Dictionary) -> void:
	match String(d.get("kind", "")):
		"bp_start":
			you = int(d["you"])
			pool = d.get("pool", [])
			phase = "draft"
			opp_progress = 0
		"bp_progress":
			opp_progress = clampi(int(d.get("n", 0)), 0, NetProtocol.TEAM_SIZE)
		"bp_reveal":
			picks = d.get("picks", [[], []])
			phase = "done"
		"error":
			var detail := String(d.get("detail", ""))
			errors.append(String(d.get("code", "")) + ("" if detail.is_empty() else ":" + detail))


# —— 玩家操作面 ——

## 我方已亮张数变化（选入/退回手牌时调·只报数不报内容）。
func send_progress(n: int) -> void:
	if transport != null:
		transport.send(NetProtocol.msg_bp_progress(n))


## 最终盲选提交（确认钮）。服务器二道门校验·拒绝走 errors。
func confirm(sel: Array) -> void:
	if transport != null:
		transport.send(NetProtocol.msg_bp_confirm(sel))


func my_picks() -> Array:
	return [] if you < 0 or phase != "done" else (picks[you] as Array)


func opp_picks() -> Array:
	return [] if you < 0 or phase != "done" else (picks[1 - you] as Array)
