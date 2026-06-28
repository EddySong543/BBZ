// HD-2D 原型：2D 像素立绘的"无法线贴图"伪光照（spatial）
// 三招组合（调研来源见 prototypes/hd2d/README.md）：
//  1. 伪体积法线 —— 把平面立绘当竖直圆柱体，按 UV 距中心弯曲法线（Broken Age 包围盒法的简化）
//  2. alpha 边缘梯度 rim —— 采样邻域 alpha 求轮廓朝向，朝光一侧勾亮边（无需任何额外贴图）
//  3. 色阶量化 + 亮度代理高光 —— 保像素风的同时让金属铠甲吃高光
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D tex_albedo : source_color, filter_nearest;
uniform vec2 frame_scale = vec2(0.25, 0.5);
uniform vec2 frame_offset = vec2(0.0, 0.0);
uniform float flip_sign = 1.0;  // -1 = 水平镜像（rim 边缘向量需同步翻转）

uniform float curve_x : hint_range(0.0, 1.5) = 0.55;  // 水平圆柱弯曲强度
uniform float curve_y : hint_range(0.0, 1.0) = 0.22;  // 垂直轻微弯曲（头顶受光）
uniform int cel_steps : hint_range(2, 6) = 3;          // 漫反射色阶数
uniform float base_lift : hint_range(0.0, 1.0) = 0.42; // 暗部抬升（保立绘可读性）
uniform float rim_strength : hint_range(0.0, 4.0) = 1.2;
uniform float spec_strength : hint_range(0.0, 3.0) = 1.0;
uniform float spec_shininess : hint_range(4.0, 128.0) = 36.0;

varying vec2 v_edge;     // 轮廓外向（视空间 xy 近似），fragment 写入 → light 读取
varying float v_edge_w;  // 边缘权重（0=内部，>0=轮廓附近）

void fragment() {
	vec2 uv = UV * frame_scale + frame_offset;
	vec4 tex = texture(tex_albedo, uv);
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;

	// 1) 伪体积法线
	float nx = (UV.x - 0.5) * 2.0;
	float ny = (UV.y - 0.5) * 2.0;
	NORMAL = normalize(NORMAL + normalize(TANGENT) * nx * curve_x
		- normalize(BINORMAL) * ny * curve_y);

	// 2) alpha 边缘梯度（2 texel 步长，对像素图取宽一点防断线）
	vec2 texel = 2.0 / vec2(textureSize(tex_albedo, 0));
	float a_l = texture(tex_albedo, uv - vec2(texel.x, 0.0)).a;
	float a_r = texture(tex_albedo, uv + vec2(texel.x, 0.0)).a;
	float a_u = texture(tex_albedo, uv - vec2(0.0, texel.y)).a;
	float a_d = texture(tex_albedo, uv + vec2(0.0, texel.y)).a;
	v_edge = vec2(a_l - a_r, a_d - a_u);  // 指向"实体→空"的外向；纹理 v 轴下 → 视空间 y 轴上已翻转
	v_edge_w = length(v_edge);
	if (v_edge_w > 1e-4) {
		v_edge /= v_edge_w;
		v_edge.x *= flip_sign;
	}
}

void light() {
	// half-lambert 包裹，背光面不死黑（环境光之外仍有体积感）
	float wrap = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = wrap * wrap;
	// 3) 色阶量化
	float band = clamp(floor(lit * float(cel_steps)) / float(cel_steps - 1), 0.0, 1.0);
	band = mix(base_lift, 1.0, band);

	// 2) rim：轮廓朝光的一侧勾边
	float rim = 0.0;
	if (v_edge_w > 0.02) {
		vec2 ldir = normalize(LIGHT.xy + vec2(1e-5));
		float facing = max(dot(ldir, v_edge), 0.0);
		rim = pow(facing, 2.0) * rim_strength * smoothstep(0.02, 0.3, v_edge_w);
	}

	DIFFUSE_LIGHT += (ALBEDO * band / PI + ALBEDO * rim) * ATTENUATION * LIGHT_COLOR;

	// 亮度作金属度代理：铠甲亮部吃高光、暗部/布料不吃
	float lum = dot(ALBEDO, vec3(0.299, 0.587, 0.114));
	float metal = smoothstep(0.45, 0.75, lum);
	vec3 h = normalize(VIEW + LIGHT);
	float spec = pow(max(dot(NORMAL, h), 0.0), spec_shininess) * metal * spec_strength;
	SPECULAR_LIGHT += spec * ATTENUATION * LIGHT_COLOR;
}
