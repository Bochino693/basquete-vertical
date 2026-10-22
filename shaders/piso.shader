// O PISO DE LED DA QUADRA (a marca do Slam Arena): os ladrilhos acendem e
// sobem quando a onda passa (até 4 ondas + o modo RECORDE) e, parados,
// cintilam de leve com uma faixa de luz que corre do fundo para a frente
// de tempos em tempos (a quadra nunca fica morta). Tudo calculado no
// vértice (por ladrilho); o pixel só lê a textura do ladrilho (fx_ladrilho)
// - leve para a Mali-450. Malha: Malhas.piso (COLOR = u, v, sorteio,
// profundidade; UV = o canto em px).
shader_type canvas_item;
render_mode blend_add;

uniform vec4 o0 = vec4(0.0, 0.0, -9999.0, 0.0);   // xy centro, z raio, w força
uniform vec4 o1 = vec4(0.0, 0.0, -9999.0, 0.0);
uniform vec4 o2 = vec4(0.0, 0.0, -9999.0, 0.0);
uniform vec4 o3 = vec4(0.0, 0.0, -9999.0, 0.0);
uniform vec4 larg = vec4(180.0, 180.0, 180.0, 180.0);
uniform vec4 c0 : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 c1 : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 c2 : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 c3 : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 rec = vec4(0.0, 0.0, 0.0, 0.0);      // recorde: xy centro, z ciclo, w força
uniform vec4 cor_base : hint_color = vec4(1.0, 0.40, 0.04, 1.0);
uniform float base = 1.0;

varying vec2 tc;
varying vec4 tom;

float frente(vec2 p, vec4 o, float l) {
	float k = clamp(1.0 - abs(distance(p, o.xy) - o.z) / l, 0.0, 1.0) * o.w;
	return k * k;
}

float faixa(float d, float r, float l) {
	return clamp(1.0 - abs(d - r) / l, 0.0, 1.0);
}

void vertex() {
	vec2 centro = VERTEX;
	float k = frente(centro, o0, larg.x);
	vec3 cor = c0.rgb;
	float k1 = frente(centro, o1, larg.y);
	float m = step(k, k1);
	k = mix(k, k1, m);
	cor = mix(cor, c1.rgb, m);
	float k2 = frente(centro, o2, larg.z);
	m = step(k, k2);
	k = mix(k, k2, m);
	cor = mix(cor, c2.rgb, m);
	float k3 = frente(centro, o3, larg.w);
	m = step(k, k3);
	k = mix(k, k3, m);
	cor = mix(cor, c3.rgb, m);

	// RECORDE: duas ondas eternas, cada uma com a frente amarela e um
	// rastro branco logo atrás
	float d = distance(centro, rec.xy);
	float fa = fract(rec.z);
	float fb = fract(rec.z + 0.5);
	float ra = mix(140.0, 1500.0, fa);
	float rb = mix(140.0, 1500.0, fb);
	float ea = pow(max(0.0, sin(fa * 3.14159)), 0.72) * rec.w;
	float eb = pow(max(0.0, sin(fb * 3.14159)), 0.72) * rec.w;
	float amarelo = max(faixa(d, ra, 60.0) * ea, faixa(d, rb, 60.0) * eb);
	float branco = max(faixa(d, ra - 120.0, 50.0) * ea, faixa(d, rb - 120.0, 50.0) * eb) * 0.85;
	m = step(k, amarelo);
	k = mix(k, amarelo, m);
	cor = mix(cor, vec3(1.0, 0.80, 0.05), m);
	m = step(k, branco);
	k = mix(k, branco, m);
	cor = mix(cor, vec3(1.0, 1.0, 1.0), m);

	float prof = COLOR.a;
	// parado, o ladrilho é um LED menor (e a placa pinta menos pixels);
	// aceso, ele cresce até encostar no vizinho e sobe um pouco (mais na
	// frente: perspectiva)
	VERTEX = centro + vec2(0.0, -k * (5.0 + 9.0 * prof)) + UV * (0.64 + 0.48 * min(k * 1.6, 1.0));
	tc = COLOR.rg;

	float cintila = 0.5 + 0.5 * sin(TIME * 1.3 + COLOR.b * 40.0);
	float varre = faixa(prof, fract(TIME * 0.11) * 1.6 - 0.3, 0.12);
	float a_base = ((0.08 + 0.06 * cintila) * (0.45 + 0.55 * prof) + varre * 0.22) * base;
	vec3 c = mix(cor_base.rgb, cor, clamp(k * 2.5, 0.0, 1.0));
	tom = vec4(c, min(1.0, a_base + k * 0.95));
}

void fragment() {
	COLOR = vec4(tom.rgb, tom.a * texture(TEXTURE, tc).a);
}
