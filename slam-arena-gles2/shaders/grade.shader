// GRADE DE QUADRADOS QUE AFUNDA E ACENDE EM ONDA (a marca do Slam Arena).
// Uma malha só com todos os quadrados (moldura + miolo de cada um); cada
// ponto sabe o centro do seu quadrado (VERTEX), o canto (UV = ±1, ±1) e se
// é moldura de fora, de dentro ou miolo (COLOR.r / COLOR.g); COLOR.b é um
// sorteio por quadrado (cintilar). TUDO é calculado aqui no vértice: o
// script só move 4 ondas + o recorde por quadro (nenhum quadrado em
// GDScript). Miolo apagado vira um ponto (a placa não pinta nada).
shader_type canvas_item;
render_mode blend_add;

uniform float passo = 90.0;
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

	float tam = passo * (0.38 + 0.35 * k) * 0.5;
	vec2 desl = vec2(k * passo * 0.16);
	float esp = 1.6 + k * 3.4;
	float interno = COLOR.r;
	float miolo = COLOR.g;
	float meia = mix(tam, tam - esp, max(interno, miolo));
	meia *= mix(1.0, step(0.04, k), miolo);
	VERTEX = centro + desl + UV * meia;

	float cintila = 0.5 + 0.5 * sin(TIME * 1.4 + COLOR.b * 40.0);
	float a_base = (0.035 + 0.030 * cintila) * base;
	vec3 c = mix(cor_base.rgb, cor, clamp(k * 2.5, 0.0, 1.0));
	float a = mix(a_base + k * 0.80, k * 0.22, miolo);
	COLOR = vec4(c, a);
}
