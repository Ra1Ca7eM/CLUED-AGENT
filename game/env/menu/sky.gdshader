
ader_type sky;

uniform vec3 sky_color : source_color = vec3(0.02, 0.04, 0.05);
uniform vec3 horizon_color : source_color = vec3(0.1, 0.15, 0.15);
uniform vec3 moon_color : source_color = vec3(0.8, 0.9, 1.0);

uniform vec3 moon_direction = vec3(0.0, 0.5, -1.0); // Direzione della luna
uniform float moon_size : hint_range(0.01, 0.2) = 0.05;
uniform float moon_blur : hint_range(0.01, 0.5) = 0.1;

uniform sampler2D noise_tex; // Usa un FastNoiseLite

// Funzione per creare nubi spettrali
float cloud_noise(vec2 uv, float time) {
    float n = texture(noise_tex, uv + time * 0.01).r;
    n *= texture(noise_tex, uv * 2.0 - time * 0.015).r;
    return n;
}

void sky() {
    float eyedir_y = EYEDIR.y;
    
    // 1. Gradiente di base (Orizzonte spettrale)
    vec3 final_color = mix(horizon_color, sky_color, smoothstep(-0.2, 0.5, eyedir_y));
    
    // 2. La Luna procedurale
    float d = distance(EYEDIR, normalize(moon_direction));
    float moon = smoothstep(moon_size + moon_blur, moon_size, d);
    float glow = smoothstep(0.5, 0.0, d) * 0.4; // Alone lunare
    
    final_color += (moon * moon_color * 2.0); // Nucleo luna
    final_color += (glow * moon_color);       // Bagliore nebbioso della luna

    // 3. Nubi ectoplasmiche (si muovono nel tempo)
    float clouds = cloud_noise(EYEDIR.xz / (EYEDIR.y + 0.1), TIME);
    float cloud_mask = smoothstep(0.4, 0.7, clouds) * smoothstep(0.0, 0.3, eyedir_y);
    
    final_color = mix(final_color, horizon_color * 0.5, cloud_mask * 0.6);

    COLOR = final_color;
}