shader_type canvas_item;

// Retain opaque sprite bodies while suppressing the faint atlas matte.
void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	COLOR *= vec4(texel.rgb, smoothstep(0.46, 0.88, texel.a));
}
