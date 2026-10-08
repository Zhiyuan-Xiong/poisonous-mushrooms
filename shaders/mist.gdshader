shader_type canvas_item;
render_mode unshaded;
uniform vec4 mist_color : source_color = vec4(0.16,0.32,0.36,1.0);
void fragment() {
	float band = exp(-pow((UV.y-0.406)/0.044,2.0));
	float drift = 0.86+0.14*sin(UV.x*8.0+TIME*0.17);
	COLOR = vec4(mist_color.rgb,band*0.14*drift);
}
