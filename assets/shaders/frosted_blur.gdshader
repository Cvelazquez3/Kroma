shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_radius : hint_range(0.0, 12.0) = 5.5;
uniform vec4 tint_color : source_color = vec4(0.04, 0.05, 0.08, 0.58);

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * blur_radius;
	vec4 sum = texture(screen_texture, SCREEN_UV) * 0.20;

	sum += texture(screen_texture, SCREEN_UV + vec2( px.x,  0.0)) * 0.12;
	sum += texture(screen_texture, SCREEN_UV + vec2(-px.x,  0.0)) * 0.12;
	sum += texture(screen_texture, SCREEN_UV + vec2( 0.0,  px.y)) * 0.12;
	sum += texture(screen_texture, SCREEN_UV + vec2( 0.0, -px.y)) * 0.12;

	sum += texture(screen_texture, SCREEN_UV + vec2( px.x,  px.y)) * 0.08;
	sum += texture(screen_texture, SCREEN_UV + vec2(-px.x,  px.y)) * 0.08;
	sum += texture(screen_texture, SCREEN_UV + vec2( px.x, -px.y)) * 0.08;
	sum += texture(screen_texture, SCREEN_UV + vec2(-px.x, -px.y)) * 0.08;

	// Viñeta sutil para dar profundidad hacia el centro
	vec2 centered = SCREEN_UV - vec2(0.5);
	float vignette = clamp(dot(centered, centered) * 0.75, 0.0, 0.35);

	vec3 col = mix(sum.rgb, tint_color.rgb, tint_color.a + vignette);
	COLOR = vec4(col, 1.0);
}
