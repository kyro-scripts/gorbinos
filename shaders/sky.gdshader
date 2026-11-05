// Cylindrical "painted backdrop" sky, the way old shooters did it.
shader_type sky;

uniform sampler2D sky_tex : source_color, filter_nearest, repeat_enable;
uniform float repeats = 2.0;
uniform float horizon = 0.78;
uniform float height = 0.9;
uniform vec4 bottom_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float drift = 0.004;

void sky() {
	vec3 d = normalize(EYEDIR);
	float u = atan(d.x, -d.z) / 6.2831853 * repeats + TIME * drift;
	float el = asin(clamp(d.y, -1.0, 1.0)) / 1.5707963;
	float v = horizon - el / height;
	vec3 c = texture(sky_tex, vec2(u, clamp(v, 0.002, 0.998))).rgb;
	if (v > 1.0) {
		c = mix(c, bottom_color.rgb, clamp((v - 1.0) * 4.0, 0.0, 1.0));
	}
	COLOR = c;
}
