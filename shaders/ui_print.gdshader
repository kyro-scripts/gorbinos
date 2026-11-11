// The menus get the same cheap-print treatment as the game: drawn at low
// resolution, colour plates a little off and twitching, colour depth cut
// down with ordered dithering, a crawl of grain. Keeps transparency, so it
// can sit over the paused game.
shader_type canvas_item;
render_mode blend_premul_alpha;

uniform vec2 src_size = vec2(640.0, 360.0);
uniform float levels = 24.0;
uniform float zine = 1.0;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[i] / 16.0 - 0.5;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 texel = 1.0 / src_size;
	float step_t = floor(TIME * 6.0);
	vec2 jit = vec2(hash(vec2(step_t, 1.3)), hash(vec2(step_t, 7.1))) - 0.5;
	vec2 off = texel * (vec2(0.9, 0.35) + jit * 0.7) * zine;
	vec4 c = texture(TEXTURE, UV);
	vec4 cr = texture(TEXTURE, UV + off);
	vec4 cb = texture(TEXTURE, UV - off);
	c.r = mix(c.r, cr.r, zine);
	c.b = mix(c.b, cb.b, zine);
	c.a = max(c.a, max(cr.a, cb.a) * zine);
	vec2 px = floor(UV * src_size);
	c.rgb += (hash(px + floor(TIME * 24.0) * 7.13) - 0.5) * 0.04 * c.a;
	if (levels < 255.0) {
		float lv = levels - 1.0;
		c.rgb = floor(c.rgb * lv + 0.5 + bayer4(px) * 0.9) / lv;
	}
	c.rgb = clamp(c.rgb, 0.0, c.a);
	COLOR = c;
}
