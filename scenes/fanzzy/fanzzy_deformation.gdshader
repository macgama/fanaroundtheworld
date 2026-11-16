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
uniform float flash = 0.0;         // 0..1 éclair de couleur quand le FANZZY est touché
uniform vec3 flash_couleur = vec3(1.0);

// Bras levés (poses joie / pousse), repérés par tools/fanzzy/analyser_bras.py.
// Chaque bras est plié autour de son épaule : rien ne bouge sous l'épaule ni
// dans la bande de la tête, la rotation monte en douceur vers le poing.
// Angles en radians à l'écran (+ = le haut du bras part vers la droite).
uniform vec2 bras_tete = vec2(0.0, -600.0); // x du centre de la tête, y des épaules
uniform float bras_demi = 50.0;             // demi-largeur de la tête
uniform vec2 bras_long = vec2(0.0);         // longueur du bras gauche, droit (0 = pas de bras)
uniform vec2 bras_angle = vec2(0.0);        // rotation à l'épaule (gauche, droit)
uniform vec2 bras_coude = vec2(0.0);        // rotation en plus pour l'avant-bras

// Squelette 2D retrouvé sur la silhouette (SqueletteFanzzy), façon « papier
// découpé » : la même image est dessinée en 5 morceaux (corps, 2 jambes,
// 2 bras), chacun découpé par un masque calculé dans le shader et tourné
// d'un bloc autour de son articulation. Les jambes passent derrière le corps,
// les bras devant ; les morceaux se chevauchent aux articulations pour ne pas
// laisser de trou. Angles = rotation à l'écran, en radians (+ = la main ou le
// pied part vers la gauche). Coordonnées du maillage.
uniform int partie = 0;            // 0 corps, 1 jambe g, 2 jambe d, 3 bras g, 4 bras d
uniform float sq_actif = 0.0;      // 0 = pas de squelette (image seule)
uniform float sq_jambes_on = 1.0;  // 0 = jambes pas trouvées : elles ne bougent pas
uniform float sq_hanche = -400.0;  // y des hanches (entrejambe)
uniform float sq_entre = 0.0;      // x de l'entrejambe
uniform vec2 sq_jambes = vec2(-40.0, 40.0); // x des deux jambes (pivots)
uniform vec2 sq_jambes_ext = vec2(-120.0, 120.0); // bords extérieurs des jambes
uniform vec2 jambe_angle = vec2(0.0);
uniform vec2 jambe_lever = vec2(0.0); // 0..1 : part de la jambe repliée
uniform vec2 sq_torse = vec2(-80.0, 80.0); // bords du torse (gauche, droite)
uniform vec2 sq_epaule = vec2(-650.0);     // y des épaules (gauche, droite)
uniform vec2 sq_main = vec2(-380.0);       // y du bas des mains (très haut = bras fixe)
uniform vec2 brasb_angle = vec2(0.0);      // rotation à l'épaule
uniform vec2 brasb_coude = vec2(0.0);      // rotation en plus de l'avant-bras

varying vec2 repos; // position de repos du point, pour les masques

vec2 tourner(vec2 p, vec2 pivot, float a) {
	vec2 v = p - pivot;
	float c = cos(a);
	float s = sin(a);
	return pivot + vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

// Masque d'une jambe ; `haut` décale le début de la jambe par rapport aux hanches.
float masque_jambe(vec2 q, float cote, float haut) {
	if (sq_jambes_on < 0.5) {
		return 0.0;
	}
	float w = smoothstep(sq_hanche + haut - 6.0, sq_hanche + haut + 6.0, q.y);
	float bord = smoothstep(sq_entre - 2.0, sq_entre + 2.0, q.x);
	w *= cote < 0.0 ? 1.0 - bord : bord;
	// à hauteur des mains, la jambe s'arrête au bord du torse (la main et ce
	// qu'elle tient suivent le bras) ; plus bas, aux bords des jambes
	float torse_x = cote < 0.0 ? sq_torse.x : sq_torse.y;
	float main_y = cote < 0.0 ? sq_main.x : sq_main.y;
	float dedans = 1.0 - smoothstep(-2.0, 3.0, (q.x - torse_x) * cote);
	w *= mix(dedans, 1.0, smoothstep(main_y + 5.0, main_y + 25.0, q.y));
	float ext_x = cote < 0.0 ? sq_jambes_ext.x : sq_jambes_ext.y;
	return w * (1.0 - smoothstep(0.0, 4.0, (q.x - ext_x) * cote));
}

// Masque d'un bras le long du corps ; `haut` décale le haut du bras par
// rapport à l'épaule (fondu doux pour se raccorder à l'épaule).
// `decal` repousse le bord côté torse (le corps garde quelques pixels du bras
// pour que les morceaux se chevauchent au lieu de laisser une fente).
float masque_bras(vec2 q, float cote, float haut, float decal) {
	float bord_x = cote < 0.0 ? sq_torse.x : sq_torse.y;
	float epaule = cote < 0.0 ? sq_epaule.x : sq_epaule.y;
	float main = cote < 0.0 ? sq_main.x : sq_main.y;
	float w = smoothstep(1.0 + decal, 5.0 + decal, (q.x - bord_x) * cote);
	w *= smoothstep(epaule + haut - 14.0, epaule + haut + 14.0, q.y);
	return w * (1.0 - smoothstep(main + 8.0, main + 26.0, q.y));
}

vec2 bouger_jambe(vec2 p, float cote) {
	int i = cote < 0.0 ? 0 : 1;
	float L = max(-sq_hanche, 1.0);
	float t = clamp((p.y - sq_hanche) / L, 0.0, 1.0);
	p.y -= jambe_lever[i] * L * t; // genou levé : la jambe se replie
	return tourner(p, vec2(sq_jambes[i], sq_hanche), jambe_angle[i]);
}

vec2 bouger_bras(vec2 p, float cote) {
	int i = cote < 0.0 ? 0 : 1;
	float bord_x = cote < 0.0 ? sq_torse.x : sq_torse.y;
	float milieu = (sq_epaule[i] + sq_main[i]) * 0.5;
	float wc = smoothstep(milieu - 15.0, milieu + 25.0, p.y);
	p = tourner(p, vec2(bord_x + cote * 12.0, milieu), brasb_coude[i] * wc);
	return tourner(p, vec2(bord_x + cote * 12.0, sq_epaule[i] + 20.0), brasb_angle[i]);
}

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
	repos = VERTEX;
	if (sq_actif > 0.5) {
		if (partie == 1) { VERTEX = bouger_jambe(VERTEX, -1.0); }
		if (partie == 2) { VERTEX = bouger_jambe(VERTEX, 1.0); }
		if (partie == 3) { VERTEX = bouger_bras(VERTEX, -1.0); }
		if (partie == 4) { VERTEX = bouger_bras(VERTEX, 1.0); }
	}
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
	if (sq_actif > 0.5) {
		float m = 1.0;
		if (partie == 0) {
			// le corps garde un peu de chaque membre : les morceaux se chevauchent
			float membres = max(max(masque_jambe(repos, -1.0, 10.0), masque_jambe(repos, 1.0, 10.0)),
				max(masque_bras(repos, -1.0, 18.0, 7.0), masque_bras(repos, 1.0, 18.0, 7.0)));
			m = 1.0 - membres;
		} else if (partie == 1) {
			m = masque_jambe(repos, -1.0, -30.0);
		} else if (partie == 2) {
			m = masque_jambe(repos, 1.0, -30.0);
		} else if (partie == 3) {
			m = masque_bras(repos, -1.0, -20.0, 0.0);
		} else {
			m = masque_bras(repos, 1.0, -20.0, 0.0);
		}
		c.a *= m;
	} else if (partie != 0) {
		c.a = 0.0;
	}
	float gris = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(gris) * 0.8, terne * 0.6);
	c.rgb = mix(c.rgb, vec3(1.0, 0.97, 0.85), eclat * 0.35);
	c.rgb = mix(c.rgb, flash_couleur, clamp(flash, 0.0, 1.0));
	COLOR = c;
}
