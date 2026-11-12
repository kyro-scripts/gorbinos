// Screen post-process for the low-res world view.
//  - zine (0..1): the collage / cheap-print look: ink lines where colours
//    break, print misregistration that jitters a few times a second,
//    halftone dots in the shadows, cream paper in the highlights, paper
//    grain and punched-up colour
//  - frenzy (0..1): hue cycling, strobing, wilder misregistration
//  - fever (episode 2): a hard two-tone colour grade per level, and the
//    view bulging out and the colour plates splitting apart toward the
//    edges the faster you go
//  - colour depth reduction with ordered dithering, damage / pickup
//    flashes, vignette, dread, crawling film grain
shader_type canvas_item;

uniform vec2 src_size = vec2(640.0, 360.0);
uniform float levels = 24.0;      // colour levels per channel; >= 255 disables
uniform vec4 flash_color : source_color = vec4(0.0);
uniform float gamma = 1.0;
uniform float invuln = 0.0;
uniform float vignette = 0.55;     // dark, rounded edges
uniform float dread = 0.0;         // 0..1: drains colour and pulls the dark in
uniform float grain = 0.05;
uniform float zine = 1.0;
uniform float frenzy = 0.0;
uniform vec4 grade_lo : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 grade_hi : source_color = vec4(1.0);
uniform float grade = 0.0;       // 0..1: how hard the two-tone grade bites
uniform float warp = 0.0;        // barrel bulge at rest
uniform float speed = 0.0;       // 0..1: how fast the player is moving

const vec3 INK = vec3(0.13, 0.02, 0.16);
const vec3 PAPER = vec3(0.98, 0.94, 0.84);

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

float luma(vec3 c) {
	return dot(c, vec3(0.3, 0.59, 0.11));
}

vec3 hue_rotate(vec3 c, float a) {
	const vec3 k = vec3(0.57735);
	float ca = cos(a);
	return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}

void fragment() {
	vec2 texel = 1.0 / src_size;
	vec2 uv = UV;
	// fever: the picture bulges out from the middle, more at speed, and the
	// red and blue plates slide apart toward the edges
	float bulge = warp * (0.55 + 0.9 * speed);
	vec2 cc = uv - 0.5;
	float rr = dot(cc, cc);
	if (bulge > 0.0) {
		uv = 0.5 + cc * (1.0 - bulge * 0.35 + bulge * rr * 1.2);
	}
	vec2 split = cc * rr * (warp * 0.05 + speed * warp * 0.11);
	// cheap print: the colour plates never quite line up, and they shift a
	// few times a second
	float step_t = floor(TIME * 6.0);
	vec2 jit = vec2(hash(vec2(step_t, 1.3)), hash(vec2(step_t, 7.1))) - 0.5;
	vec2 off = texel * (vec2(0.9, 0.35) + jit * 0.8) * (zine + frenzy * 2.5);
	vec4 c = texture(TEXTURE, uv);
	c.r = mix(c.r, texture(TEXTURE, uv + off).r, min(zine + frenzy, 1.0));
	c.b = mix(c.b, texture(TEXTURE, uv - off).b, min(zine + frenzy, 1.0));
	if (warp > 0.0) {
		c.r = texture(TEXTURE, uv + split).r;
		c.b = texture(TEXTURE, uv - split).b;
	}
	c.rgb = pow(max(c.rgb, vec3(0.0)), vec3(1.0 / gamma));
	if (invuln > 0.0) {
		float g = luma(c.rgb);
		c.rgb = mix(c.rgb, vec3(1.0 - g) * vec3(0.9, 1.0, 0.8), invuln);
	}
	if (zine > 0.0) {
		// punch: more saturation, an S-curve on contrast
		float l = luma(c.rgb);
		c.rgb = mix(vec3(l), c.rgb, 1.0 + 0.35 * zine);
		c.rgb = mix(c.rgb, c.rgb * c.rgb * (3.0 - 2.0 * c.rgb), 0.45 * zine);
		// ink lines where the picture breaks hard (like a cut-out's edge)
		float lx = luma(texture(TEXTURE, uv + vec2(texel.x, 0.0)).rgb) - luma(texture(TEXTURE, uv - vec2(texel.x, 0.0)).rgb);
		float ly = luma(texture(TEXTURE, uv + vec2(0.0, texel.y)).rgb) - luma(texture(TEXTURE, uv - vec2(0.0, texel.y)).rgb);
		float edge = smoothstep(0.22, 0.5, length(vec2(lx, ly)));
		c.rgb = mix(c.rgb, INK, edge * 0.5 * zine);
		// halftone dots in the shadows, on a 45 degree screen in real pixels
		float cell = 4.0 / max(SCREEN_PIXEL_SIZE.y * 720.0, 0.25);
		vec2 hp = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * FRAGCOORD.xy / cell;
		float d = length(fract(hp) - 0.5);
		l = luma(c.rgb);
		float rad = sqrt(clamp(1.0 - l * 2.4, 0.0, 1.0)) * 0.55;
		float dotm = smoothstep(rad + 0.06, rad - 0.06, d);
		c.rgb = mix(c.rgb, c.rgb * 0.45 + INK * 0.08, dotm * 0.5 * zine);
		// highlights go to cream paper, with a little fibre in it
		c.rgb = mix(c.rgb, PAPER * max(l, 0.0) * 1.08, smoothstep(0.78, 1.0, l) * 0.5 * zine);
		vec2 pp = floor(FRAGCOORD.xy / max(cell * 0.5, 1.0));
		float fibre = hash(pp) * 0.6 + hash(floor(pp / 7.0)) * 0.4;
		c.rgb *= 1.0 - (fibre - 0.5) * 0.08 * zine;
	}
	if (grade > 0.0) {
		// two-tone: the shadows go one colour, the lights another, with a
		// hard S-curve between so everything reads as flat bright shapes
		float l = luma(c.rgb);
		float k = smoothstep(0.08, 0.85, l);
		vec3 duo = mix(grade_lo.rgb, grade_hi.rgb, k);
		// keep a little of the original hue so things stay readable
		c.rgb = mix(c.rgb, duo * (0.55 + 0.6 * k) + c.rgb * 0.25, grade);
	}
	if (frenzy > 0.0) {
		c.rgb = mix(c.rgb, hue_rotate(c.rgb, TIME * 4.0), frenzy * 0.8);
		float l = luma(c.rgb);
		c.rgb = mix(vec3(l), c.rgb, 1.0 + frenzy * 0.8);
		float strobe = step(0.82, fract(TIME * 7.0)) * frenzy;
		c.rgb = mix(c.rgb, vec3(1.0) - c.rgb, strobe * 0.25);
	}
	// creeping dark at the edges, tighter when dread rises
	vec2 dv = (uv - 0.5) * vec2(1.25, 1.0);
	float r = length(dv);
	float v = vignette + dread * 0.35;
	c.rgb *= 1.0 - v * smoothstep(0.28 - dread * 0.1, 0.78, r);
	if (dread > 0.0) {
		float g = luma(c.rgb);
		c.rgb = mix(c.rgb, vec3(g) * vec3(1.05, 0.9, 0.85), dread * 0.6);
	}
	// film grain that crawls
	vec2 gp = floor(UV * src_size);
	float n = hash(gp + floor(TIME * 24.0) * 7.13);
	c.rgb += (n - 0.5) * grain;
	c.rgb = mix(c.rgb, flash_color.rgb, flash_color.a);
	if (levels < 255.0) {
		vec2 px = floor(UV * src_size);
		float b = bayer4(px);
		float lv = levels - 1.0;
		c.rgb = floor(c.rgb * lv + 0.5 + b * 0.9) / lv;
	}
	COLOR = vec4(clamp(c.rgb, 0.0, 1.0), 1.0);
}
