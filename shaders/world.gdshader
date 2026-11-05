// Gorbino's Quest world shader.
// Sector lighting comes from a per-cell light texture (DOOM-style), with
// distance diminishing, coloured fog and a handful of dynamic point lights.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D tex : source_color, filter_nearest, repeat_enable;
uniform vec2 scroll = vec2(0.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float fullbright = 0.0;
uniform float alpha_cut = 0.0;
uniform float origin_light = 0.0;   // 1 = sample light at the object's origin
uniform float wobble = 0.0;         // liquids: UV warp
uniform float flash = 0.0;          // hit flash (enemies)
uniform vec2 uv_scale = vec2(1.0);

global uniform sampler2D level_light : filter_nearest;
global uniform vec4 level_info;   // x: cell size, y: grid w, z: grid h
global uniform vec4 fog_color;    // rgb + strength
global uniform vec4 fog_params;   // start, end, light boost, diminish per metre
global uniform vec4 dl_p0;
global uniform vec4 dl_p1;
global uniform vec4 dl_p2;
global uniform vec4 dl_p3;
global uniform vec4 dl_p4;
global uniform vec4 dl_p5;
global uniform vec4 dl_c0;
global uniform vec4 dl_c1;
global uniform vec4 dl_c2;
global uniform vec4 dl_c3;
global uniform vec4 dl_c4;
global uniform vec4 dl_c5;

varying vec3 wpos;
varying vec3 wnrm;

vec3 pl(vec3 p, vec4 P, vec4 C) {
	float a = clamp(1.0 - distance(p, P.xyz) / P.w, 0.0, 1.0);
	return C.rgb * (a * a * C.a);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = UV * uv_scale + scroll * TIME;
	if (wobble > 0.0) {
		uv += vec2(sin(uv.y * 6.0 + TIME * 1.7), cos(uv.x * 6.0 + TIME * 1.3)) * 0.03 * wobble;
	}
	vec4 c = texture(tex, uv) * tint;
	if (c.a < alpha_cut) {
		discard;
	}
	vec3 sp = mix(wpos + wnrm * 0.2, MODEL_MATRIX[3].xyz, origin_light);
	vec2 cellp = floor(sp.xz / level_info.x);
	vec4 L = texture(level_light, (cellp + 0.5) / level_info.yz);
	float light = L.r;
	float ft = floor(L.g * 4.0 + 0.5);
	float h = hash(cellp);
	if (ft == 1.0) {
		light *= hash(vec2(floor(TIME * 9.0 + h * 13.0), h)) > 0.35 ? 1.0 : 0.45;
	} else if (ft == 2.0) {
		light *= 0.65 + 0.35 * sin(TIME * 3.0 + h * 6.28);
	} else if (ft == 3.0) {
		light *= fract(TIME * 1.5 + h) < 0.5 ? 1.0 : 0.3;
	}
	float depth = -VERTEX.z;
	float lit = clamp(light * fog_params.z - depth * fog_params.w, light * 0.22, 1.0);
	lit = mix(lit, 1.0, fullbright);
	vec3 dyn = pl(wpos, dl_p0, dl_c0) + pl(wpos, dl_p1, dl_c1) + pl(wpos, dl_p2, dl_c2)
		+ pl(wpos, dl_p3, dl_c3) + pl(wpos, dl_p4, dl_c4) + pl(wpos, dl_p5, dl_c5);
	vec3 col = c.rgb * (lit + min(dyn, vec3(1.2)));
	col = mix(col, vec3(1.0, 1.0, 1.0), flash);
	float f = clamp((depth - fog_params.x) / max(fog_params.y - fog_params.x, 0.01), 0.0, 1.0) * fog_color.a;
	col = mix(col, fog_color.rgb, f * (1.0 - fullbright * 0.5));
	ALBEDO = col;
}
