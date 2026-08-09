shader_type canvas_item;
render_mode blend_mix;

// 晴风稻田正式地形资产上方的迷雾遮罩。
// map_data: R=墙标记（保留接口），G=已探明，B=探明时刻。
uniform sampler2D map_data : filter_nearest, repeat_disable;
uniform vec2 grid_size = vec2(18.0, 14.0);
uniform float cell_px = 216.0;
uniform float block_px = 4.0;
uniform float tile_inset_px = 4.0;
uniform float corner_cut_px = 16.0;
uniform float anim_time = 0.0;
uniform float seed_f = 0.0;

uniform vec3 fog_base : source_color = vec3(0.038, 0.028, 0.017);
uniform vec3 fog_edge_tint : source_color = vec3(0.16, 0.105, 0.052);
uniform float fog_flow_amp : hint_range(0.0, 1.2) = 0.25;
uniform float fog_flow_speed : hint_range(0.0, 2.0) = 0.30;
uniform float edge_glow_amt : hint_range(0.0, 1.0) = 0.55;
uniform float reveal_dur : hint_range(0.1, 1.5) = 0.35;


float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


float pixel_cut_box(vec2 p, vec2 size, float cut) {
	float inside = step(0.0, p.x) * step(p.x, size.x)
			* step(0.0, p.y) * step(p.y, size.y);
	float corners = step(cut, p.x + p.y)
			* step(cut, (size.x - p.x) + p.y)
			* step(cut, p.x + (size.y - p.y))
			* step(cut, (size.x - p.x) + (size.y - p.y));
	return inside * corners;
}


void fragment() {
	vec2 px = UV * grid_size * cell_px;
	vec2 tile = floor(px / cell_px);
	vec2 local_px = px - tile * cell_px;
	vec2 block = floor(px / block_px);
	vec4 data = texture(map_data, (tile + 0.5) / grid_size);
	float revealed = step(0.5, data.g);

	vec2 body_p = local_px - vec2(tile_inset_px);
	vec2 body_size = vec2(cell_px - tile_inset_px * 2.0);
	float body_mask = pixel_cut_box(body_p, body_size, corner_cut_px);

	float flow = sin(block.x * 0.55 + anim_time * fog_flow_speed)
			* sin(block.y * 0.47 - anim_time * fog_flow_speed * 0.8)
			+ 0.6 * sin((block.x + block.y) * 0.31 + anim_time * fog_flow_speed * 0.7);
	float flow_quantized = floor((flow * 0.31 + 0.5) * 3.0) / 3.0;
	vec3 fog_color = fog_base * (0.88 + flow_quantized * fog_flow_amp);

	float right_revealed = step(0.5, texture(map_data, (tile + vec2(1.5, 0.5)) / grid_size).g)
			* step(tile.x, grid_size.x - 1.5);
	float left_revealed = step(0.5, texture(map_data, (tile + vec2(-0.5, 0.5)) / grid_size).g)
			* step(0.5, tile.x);
	float down_revealed = step(0.5, texture(map_data, (tile + vec2(0.5, 1.5)) / grid_size).g)
			* step(tile.y, grid_size.y - 1.5);
	float up_revealed = step(0.5, texture(map_data, (tile + vec2(0.5, -0.5)) / grid_size).g)
			* step(0.5, tile.y);
	float glow = right_revealed * smoothstep(cell_px * 0.35, cell_px, local_px.x)
			+ left_revealed * smoothstep(cell_px * 0.65, 0.0, local_px.x)
			+ down_revealed * smoothstep(cell_px * 0.35, cell_px, local_px.y)
			+ up_revealed * smoothstep(cell_px * 0.65, 0.0, local_px.y);
	float frontier = clamp(glow, 0.0, 1.0);
	fog_color = mix(fog_color, fog_edge_tint, frontier * edge_glow_amt);

	float reveal_progress = clamp((anim_time - data.b) / reveal_dur, 0.0, 1.0);
	float visible_block = step(hash21(block + vec2(seed_f + 51.0)), reveal_progress) * revealed;
	float fog_alpha = (0.42 + frontier * 0.34) * (1.0 - visible_block) * body_mask;
	COLOR = vec4(fog_color, fog_alpha);
}
