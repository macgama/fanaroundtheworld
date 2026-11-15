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

// Bras levés (poses joie / pousse), repérés par tools/fanzzy/analyser_bras.py.
// Chaque bras est plié autour de son épaule : rien ne bouge sous l'épaule ni
// dans la bande de la tête, la rotation monte en douceur vers le poing.
// Angles en radians à l'écran (+ = le haut du bras part vers la droite).
uniform vec2 bras_tete = vec2(0.0, -600.0); // x du centre de la tête, y des épaules
uniform float bras_demi = 50.0;             // demi-largeur de la tête
uniform vec2 bras_long = vec2(0.0);         // longueur du bras gauche, droit (0 = pas de bras)
uniform vec2 bras_angle = vec2(0.0);        // rotation à l'épaule (gauche, droit)
uniform vec2 bras_coude = vec2(0.0);        // rotation en plus pour l'avant-bras

vec2 plier_bras(vec2 p, float cote, float longueur, float angle, float coude) {
	if (longueur <= 0.0) {
		return p;
	}
	float dehors = (p.x - bras_tete.x) * cote;
	float wx = smoothstep(bras_demi * 0.95, bras_demi * 1.55, dehors);
	float monte = bras_tete.y - p.y;
	float wy = smoothstep(0.0, longueur * 0.3, monte);
	float wc = smoothstep(longueur * 0.4, longueur * 0.8, monte);
	float a = (angle * wy + coude * wc) * wx;
	vec2 pivot = vec2(bras_tete.x + cote * bras_demi * 1.55, bras_tete.y);
	vec2 v = p - pivot;
	float c = cos(a);
	float s = sin(a);
	return pivot + vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

void vertex() {
	VERTEX = plier_bras(VERTEX, -1.0, bras_long.x, bras_angle.x, bras_coude.x);
	VERTEX = plier_bras(VERTEX, 1.0, bras_long.y, bras_angle.y, bras_coude.y);
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
