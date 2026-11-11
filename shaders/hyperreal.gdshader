// Hyperreal cut-outs (FISH collage): photo-real bits pasted onto the
// cartoon world. Smooth, mipmapped sampling (unlike the crunchy world
// textures) so they read as a photo stuck on, but lit by the same sector
// light, dynamic lights and fog as everything else so they sit in the
// level. Atlases are a row of frames; `frame` picks one. With billboard
// on, the quad turns to face the camera (flying gibs).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float frames = 1.0;
uniform float frame = 0.0;
uniform float billboard = 0.0;
uniform float spin = 0.0;
uniform vec4 tint : source_color = vec4(1.0);

global uniform sampler2D level_light : filter_nearest;
global uniform vec4 level_info;
global uniform vec4 fog_color;
global uniform vec4 fog_params;
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
varying float vdepth;

vec3 pl(vec3 p, vec4 P, vec4 C) {
	float a = clamp(1.0 - distance(p, P.xyz) / P.w, 0.0, 1.0);
	return C.rgb * (a * a * C.a);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	if (billboard > 0.5) {
		float sx = length(MODEL_MATRIX[0].xyz);
		float sy = length(MODEL_MATRIX[1].xyz);
		vec3 right = INV_VIEW_MATRIX[0].xyz;
		vec3 up = INV_VIEW_MATRIX[1].xyz;
		float c = cos(spin);
		float s = sin(spin);
		vec3 r2 = right * c + up * s;
		vec3 u2 = up * c - right * s;
		wpos = MODEL_MATRIX[3].xyz + r2 * VERTEX.x * sx + u2 * VERTEX.y * sy;
		vec4 vp = VIEW_MATRIX * vec4(wpos, 1.0);
		vdepth = -vp.z;
		POSITION = PROJECTION_MATRIX * vp;
	} else {
		wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		vdepth = -vp.z;
		// writing POSITION in one branch means it's used for every vertex
		POSITION = PROJECTION_MATRIX * vp;
	}
}

void fragment() {
	vec4 c = texture(tex, vec2((UV.x + frame) / frames, UV.y));
	if (c.a < 0.6) {
		discard;
	}
	vec3 sp = MODEL_MATRIX[3].xyz;
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
	float lit = clamp(light * fog_params.z * 1.08 - vdepth * fog_params.w, light * 0.25, 1.05);
	vec3 dyn = pl(wpos, dl_p0, dl_c0) + pl(wpos, dl_p1, dl_c1) + pl(wpos, dl_p2, dl_c2)
		+ pl(wpos, dl_p3, dl_c3) + pl(wpos, dl_p4, dl_c4) + pl(wpos, dl_p5, dl_c5);
	vec3 col = c.rgb * tint.rgb * (lit + min(dyn, vec3(1.2)));
	float f = clamp((vdepth - fog_params.x) / max(fog_params.y - fog_params.x, 0.01), 0.0, 1.0) * fog_color.a;
	ALBEDO = mix(col, fog_color.rgb, f);
}
