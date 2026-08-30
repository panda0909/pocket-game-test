shader_type canvas_item;

// red_bull_tiers / gecko_tiers were generated with a visible checkerboard.
// Remove only pixels that still have neutral checkerboard neighbours, so white
// costume highlights and bellies remain intact.
void fragment() {
	vec4 current = texture(TEXTURE, UV);
	float neutral = 1.0 - step(0.055, max(abs(current.r - current.g), abs(current.g - current.b)));
	float light = step(0.72, current.r) * step(0.72, current.g) * step(0.72, current.b);
	vec2 offset_x = vec2(TEXTURE_PIXEL_SIZE.x * 8.0, 0.0);
	vec2 offset_y = vec2(0.0, TEXTURE_PIXEL_SIZE.y * 8.0);
	vec4 x_pos = texture(TEXTURE, UV + offset_x);
	vec4 x_neg = texture(TEXTURE, UV - offset_x);
	vec4 y_pos = texture(TEXTURE, UV + offset_y);
	vec4 y_neg = texture(TEXTURE, UV - offset_y);
	float neighbours = 1.0;
	neighbours *= 1.0 - step(0.055, max(abs(x_pos.r - x_pos.g), abs(x_pos.g - x_pos.b)));
	neighbours *= 1.0 - step(0.055, max(abs(x_neg.r - x_neg.g), abs(x_neg.g - x_neg.b)));
	neighbours *= 1.0 - step(0.055, max(abs(y_pos.r - y_pos.g), abs(y_pos.g - y_pos.b)));
	neighbours *= 1.0 - step(0.055, max(abs(y_neg.r - y_neg.g), abs(y_neg.g - y_neg.b)));
	if (neutral * light * neighbours > 0.5) {
		COLOR = vec4(current.rgb, 0.0);
	} else {
		COLOR = current;
	}
}
