// Paper cut-out border for creatures and pickups (drawn as a material
// overlay): the back faces of a slightly fattened copy of the mesh, flat
// off-white, so things look snipped out of a magazine and pasted into the
// world. The border boils a little, like it was cut by hand, and fades into
// the level's fog like everything else.
shader_type spatial;
render_mode unshaded, cull_front, world_vertex_coords, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.96, 0.93, 0.84, 1.0);
uniform float width = 0.02;
uniform float px_width = 0.014;     // per metre of distance (about two crunchy pixels)

global uniform vec4 fog_color;
global uniform vec4 fog_params;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float dist = distance(VERTEX, cam);
	float boil = floor(TIME * 8.0);
	float j = 0.7 + 0.6 * hash3(floor(VERTEX * 8.0) + boil);
	// grows with distance, so it stays a couple of pixels thick on screen
	VERTEX += normalize(NORMAL) * (width + dist * px_width) * j;
}

void fragment() {
	float depth = -VERTEX.z;
	float f = clamp((depth - fog_params.x) / max(fog_params.y - fog_params.x, 0.01), 0.0, 1.0) * fog_color.a;
	ALBEDO = mix(color.rgb, fog_color.rgb, f);
}
