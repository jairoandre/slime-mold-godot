shader_type canvas_item;

uniform sampler2D agents;

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    col.g = 0.;
    COLOR = col;
	// Place fragment code here.
}
