shader_type canvas_item;
// Déformation d'un FANZZY dessiné en une seule image.
// Le maillage est une grille (voir FanzzyAnime._grille) dont l'origine est
// entre les pieds : y = 0 aux pieds, y = -hauteur en haut de l'image.
// Les pieds restent donc fixes et le haut du corps se plie, s'écrase ou ondule.

uniform float hauteur = 945.0;     // hauteur de l'image en pixels
uniform float penche = 0.0;        // flexion du buste (fraction de la hauteur, + = droite)
uniform vec2 ecrase = vec2(1.0);   // étirement (x, y) autour des pieds
uniform float onde_amp = 0.0;      // ondulation du haut du corps (fraction de la largeur)
uniform float onde_phase = 0.0;    // phase de l'ondulation, avancée par le script
uniform float onde_freq = 2.5;     // nombre de vagues sur la hauteur
uniform float eclat = 0.0;         // 0..1 éclaircit (célébration)
uniform float terne = 0.0;         // 0..1 désature et assombrit (dépit)

void vertex() {
	float t = clamp(-VERTEX.y / hauteur, 0.0, 1.0); // 0 aux pieds, 1 en haut
	float t2 = t * t;
	VERTEX.x += penche * hauteur * t2;
	// garde à peu près la longueur du corps quand il se penche
	VERTEX.y += abs(penche) * hauteur * t2 * 0.25;
	VERTEX.x += sin(onde_phase + t * onde_freq * 6.2831) * onde_amp * hauteur * 0.5 * t2;
	VERTEX *= ecrase;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float gris = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(gris) * 0.8, terne * 0.6);
	c.rgb = mix(c.rgb, vec3(1.0, 0.97, 0.85), eclat * 0.35);
	COLOR = c;
}
