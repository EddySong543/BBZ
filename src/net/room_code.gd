extends RefCounted

## 房号短码（好友开房准备批·2026-07-14·ADR-004）：IPv4 ↔ 8 位可读口令，语音报号代替念 IP。
## 编码：4 字节 IP → 35 位 Crockford Base32（7 字符·字母表去易混 I/L/O/U）+ 1 位校验和 → "XXXX-XXXX"。
## 端口不进码（恒 NetSession.DEFAULT_PORT）；解码容错：大小写/连字符/空格/易混字符（O→0、I/L→1、U→V）。
## 纯逻辑零依赖（GUT 可测）。⚠ 只覆盖 IPv4——IPv6 场景直接输原始地址。

const ALPHABET := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"   # Crockford Base32
const CODE_CHARS := 7    # 7×5=35 bit ≥ 32 bit IPv4
const GROUP := 4         # 展示分组："XXXX-XXXX"


## IPv4 → 房号（非法 IP 返回 ""）。
static func encode(ip: String) -> String:
	var parts := ip.split(".")
	if parts.size() != 4:
		return ""
	var n := 0
	for p in parts:
		if not (p as String).is_valid_int():
			return ""
		var b := int(p)
		if b < 0 or b > 255:
			return ""
		n = (n << 8) | b
	var chars := ""
	var sum := 0
	for i in CODE_CHARS:
		var v := (n >> ((CODE_CHARS - 1 - i) * 5)) & 31
		chars += ALPHABET[v]
		sum += v
	chars += ALPHABET[sum % 32]
	return chars.substr(0, GROUP) + "-" + chars.substr(GROUP)


## 房号 → IPv4（校验和不合/字符非法/长度不对返回 ""）。
static func decode(code: String) -> String:
	var s := normalize(code)
	if s.length() != CODE_CHARS + 1:
		return ""
	var n := 0
	var sum := 0
	for i in CODE_CHARS:
		var v := ALPHABET.find(s[i])
		if v < 0:
			return ""
		n = (n << 5) | v
		sum += v
	var check := ALPHABET.find(s[CODE_CHARS])
	if check != sum % 32:
		return ""
	if n > 0xFFFFFFFF:
		return ""
	return "%d.%d.%d.%d" % [(n >> 24) & 255, (n >> 16) & 255, (n >> 8) & 255, n & 255]


## 归一化：去边距/连字符/空格·大写·易混字符映射（O→0、I/L→1、U→V）。
static func normalize(code: String) -> String:
	var s := code.strip_edges().to_upper().replace("-", "").replace(" ", "")
	return s.replace("O", "0").replace("I", "1").replace("L", "1").replace("U", "V")
