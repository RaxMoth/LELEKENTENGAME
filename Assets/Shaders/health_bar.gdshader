// A health bar on one quad that always faces the camera (billboard in the
// vertex stage, no per-frame script work): the filled share from the left
// in fill_color, the rest in empty_color, framed by a thin dark border.
// Used by HealthBar3D.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform vec4 fill_color : source_color = vec4(0.898, 0.282, 0.302, 1.0);
uniform vec4 empty_color : source_color = vec4(0.141, 0.169, 0.243, 1.0);
uniform vec4 border_color : source_color = vec4(0.051, 0.063, 0.090, 1.0);
// Border thickness as a share of the bar's height.
uniform float border = 0.22;
// Width / height of the quad, so the side borders are as thick as the top.
uniform float aspect = 8.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 edge = vec2(border / aspect, border);
	bool is_border = UV.x < edge.x || UV.x > 1.0 - edge.x || UV.y < edge.y || UV.y > 1.0 - edge.y;
	float inner_x = (UV.x - edge.x) / (1.0 - 2.0 * edge.x);
	ALBEDO = is_border ? border_color.rgb : (inner_x <= fill ? fill_color.rgb : empty_color.rgb);
}
