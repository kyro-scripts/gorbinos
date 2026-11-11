// Behind the menus: murky deep water. Light ripples (caustics) wander over
// it, faint shafts come down from the surface, specks drift up through it.
shader_type canvas_item;

uniform float opacity = 1.0;
uniform vec4 shallow : source_color = vec4(0.06, 0.24, 0.22, 1.0);
uniform vec4 deep : source_color = vec4(0.008, 0.045, 0.06, 1.0);
uniform vec2 aspect = vec2(1.78, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// the classic tileable water caustic: a few rounds of warping sines
float caustic(vec2 p, float t) {
	vec2 i = p;
	float c = 1.0;
	float inten = 0.005;
	for (int n = 0; n < 4; n++) {
		float tt = t * (1.0 - (3.5 / float(n + 1)));
		i = p + vec2(cos(tt - i.x) + sin(tt + i.y), sin(tt - i.y) + cos(tt + i.x));
		c += 1.0 / length(vec2(p.x / (sin(i.x + tt) / inten), p.y / (cos(i.y + tt) / inten)));
	}
	c /= 4.0;
	c = 1.17 - pow(c, 1.4);
	return clamp(pow(abs(c), 8.0), 0.0, 1.0);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.3;
	vec3 col = mix(shallow.rgb, deep.rgb, smoothstep(-0.1, 1.0, uv.y));
	// ripples of light, strongest near the surface
	float c = caustic(uv * aspect * 3.2 + vec2(t * 0.2, 0.0), t);
	col += vec3(0.22, 0.42, 0.36) * c * (1.0 - uv.y) * 0.55;
	// shafts of light slanting down
	float ray = 0.5 + 0.5 * sin(uv.x * 11.0 - uv.y * 4.0 + sin(TIME * 0.15) * 2.0);
	col += vec3(0.06, 0.12, 0.1) * pow(ray, 8.0) * (1.0 - uv.y) * 1.2;
	// specks drifting up
	vec2 g = vec2(uv.x * aspect.x * 22.0, uv.y * 22.0 + TIME * 0.6);
	vec2 cell = floor(g);
	vec2 f = fract(g) - 0.5 - (vec2(hash(cell), hash(cell + 7.1)) - 0.5) * 0.7;
	float speck = smoothstep(0.06, 0.0, length(f)) * step(0.82, hash(cell + 3.3));
	col += vec3(0.4, 0.55, 0.5) * speck * 0.35;
	// vignette and a little grain
	float v = length((uv - 0.5) * vec2(1.3, 1.0));
	col *= 1.0 - smoothstep(0.3, 0.95, v) * 0.75;
	col += (hash(floor(FRAGCOORD.xy / 2.0) + floor(TIME * 20.0)) - 0.5) * 0.025;
	COLOR = vec4(col, opacity);
}
