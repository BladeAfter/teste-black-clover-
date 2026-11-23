shader_type canvas_item;
render_mode unshaded;
uniform vec2 box_size = vec2(76.0);
varying vec2 mask_uv;
void vertex() {
	mask_uv = VERTEX / box_size;
}
void fragment() {
	float circle = 1.0 - smoothstep(0.475, 0.5, distance(mask_uv, vec2(0.5)));
	COLOR.a *= circle;
}
