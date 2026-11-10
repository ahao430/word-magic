// Vertically scrolling waterfall: the texture repeats along Y with a
// seamless 64px period, so a constant TIME offset reads as falling
// water. Kept as the single custom shader in the project so far.
shader_type canvas_item;

void fragment() {
	vec2 scrolled = UV;
	scrolled.y = fract(scrolled.y + TIME * 0.35);
	COLOR = texture(TEXTURE, scrolled);
}
