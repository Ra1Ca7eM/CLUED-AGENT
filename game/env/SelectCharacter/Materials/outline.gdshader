shader_type spatial;
// Usiamo blend_add per un effetto di pura luminosità che si somma allo sfondo
render_mode blend_add, unshaded;

uniform vec4 glow_color : source_color = vec4(1.0, 0.9, 0.0, 1.0); // Colore dell'aura
uniform float glow_power = 3.0; // Più è alto, più la sfumatura è sottile e confinata ai bordi estremi
uniform float glow_intensity = 1.5; // Moltiplicatore di luminosità

void fragment() {
	// Calcola l'angolo tra la telecamera (VIEW) e la superficie del modello (NORMAL)
	float dot_product = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	
	// Applica la curva di sfumatura
	float fresnel = pow(1.0 - dot_product, glow_power);

	ALBEDO = glow_color.rgb * glow_intensity;
	
	// La trasparenza è massima al centro (0.0) e opaca sui bordi, creando il gradiente morbido
	ALPHA = fresnel * glow_color.a;
}