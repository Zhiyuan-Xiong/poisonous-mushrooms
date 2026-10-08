shader_type canvas_item;
render_mode unshaded;
uniform float blur_radius = 6.0;
uniform float fog_blend = 0.22;
uniform vec3 fog_tone = vec3(0.18,0.32,0.34);
varying vec4 tint;
void vertex(){ tint = COLOR; }
void fragment(){
	vec2 d = TEXTURE_PIXEL_SIZE * blur_radius;
	vec4 sum = vec4(0.0);
	for(int i=-2;i<=2;i++){
		for(int j=-2;j<=2;j++){
			float w = exp(-float(i*i+j*j)*0.65);
			vec4 c = texture(TEXTURE,UV+vec2(float(i),float(j))*d*0.55);
			sum += vec4(c.rgb*c.a,c.a)*w;
		}
	}
	float norm = 4.8226;
	float a = sum.a/norm;
	vec3 rgb = sum.rgb/max(sum.a,0.00001);
	COLOR = vec4(mix(rgb,fog_tone,fog_blend)*tint.rgb,a*tint.a);
}

