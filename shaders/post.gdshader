// Screen post-process: colour depth reduction with ordered dithering,
// plus damage / pickup palette flashes. Applied to the low-res world view.
shader_type canvas_item;

uniform vec2 src_size = vec2(640.0, 360.0);
uniform float levels = 24.0;      // colour levels per channel; >= 255 disables
uniform vec4 flash_color : source_color = vec4(0.0);
uniform float gamma = 1.0;
uniform float invuln = 0.0;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[i] / 16.0 - 0.5;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb = pow(max(c.rgb, vec3(0.0)), vec3(1.0 / gamma));
	if (invuln > 0.0) {
		float g = dot(c.rgb, vec3(0.3, 0.59, 0.11));
		c.rgb = mix(c.rgb, vec3(1.0 - g) * vec3(0.9, 1.0, 0.8), invuln);
	}
	c.rgb = mix(c.rgb, flash_color.rgb, flash_color.a);
	if (levels < 255.0) {
		vec2 px = floor(UV * src_size);
		float b = bayer4(px);
		float n = levels - 1.0;
		c.rgb = floor(c.rgb * n + 0.5 + b * 0.9) / n;
	}
	COLOR = vec4(clamp(c.rgb, 0.0, 1.0), 1.0);
}
