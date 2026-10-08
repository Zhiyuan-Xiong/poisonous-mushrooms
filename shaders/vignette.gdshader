shader_type canvas_item;
render_mode unshaded;
void fragment(){
	vec2 p = UV;
	float corner = exp(-dot(p,p)*11.0)+exp(-dot(p-vec2(1.0,0.0),p-vec2(1.0,0.0))*11.0)
		+exp(-dot(p-vec2(0.0,1.0),p-vec2(0.0,1.0))*11.0)+exp(-dot(p-vec2(1.0,1.0),p-vec2(1.0,1.0))*11.0);
	float edge = pow(abs(p.x-0.5)*2.0,4.0)*0.07;
	COLOR = vec4(0.016,0.044,0.059,clamp(corner*0.38+edge,0.0,0.47));
}

