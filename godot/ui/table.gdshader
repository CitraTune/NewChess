shader_type canvas_item;
uniform bool reduced_motion = false;
void fragment() {
	vec2 uv = UV;
	float t = reduced_motion ? 0.0 : TIME * 0.045;
	float mist = sin(uv.x * 5.0 + t) * cos(uv.y * 4.0 - t) * 0.5 + 0.5;
	vec3 a = vec3(0.055,0.056,0.086);
	vec3 b = vec3(0.135,0.078,0.111);
	vec3 col = mix(a,b,mist*0.7);
	float vignette = smoothstep(0.75,0.15,distance(uv,vec2(0.5)));
	float grain = fract(sin(dot(floor(FRAGCOORD.xy),vec2(12.9898,78.233)))*43758.5453);
	COLOR = vec4(col*(0.65+vignette*0.35)+(grain-0.5)*0.012,1.0);
}
