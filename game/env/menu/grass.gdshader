shader_type spatial;
render_mode cull_disabled;

uniform vec3 color : source_color;
uniform vec3 color2 : source_color;
uniform sampler2D noise;
uniform float noiseScale = 20.0;
uniform float wind_speed = 1.0;
uniform float wind_strength = 0.4;
uniform float wind_horizontal_scale = 1.0;

varying vec3 worldPos;

void vertex() {
	worldPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Creiamo un'oscillazione basata sul tempo e sulla posizione nel mondo
	// Usiamo worldPos.xz per far sì che fili d'erba vicini si muovano in sincronia
	float wave = sin(TIME * wind_speed + (worldPos.x + worldPos.z) * wind_horizontal_scale);
	
	// Applichiamo il movimento solo alla parte superiore (dove UV.y è vicino a 0)
	// Nota: in Godot le mesh standard hanno spesso UV.y = 0 in cima e 1 alla base.
	// Se l'erba si muove alla base invece che in punta, usa (1.0 - UV.y)
	float mask = (1.0 - UV.y); 
	
	VERTEX.x += wave * wind_strength * mask;
	VERTEX.z += wave * wind_strength * mask;
}

void fragment() {
	vec3 noiseLevel = texture (noise, worldPos.xz / noiseScale).rgb;
	ALBEDO = mix(color,color2,UV.y) * mix(color,color2,noiseLevel.r) ;
	if (!FRONT_FACING){
		NORMAL=-NORMAL;
	}
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
