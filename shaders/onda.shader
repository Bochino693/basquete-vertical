// ONDA DE LUZ DA CESTA: até 9 anéis de neon + até 18 raios, numa malha só
// (feita uma vez, em raio 1). Cada ponto sabe se é anel (UV.y = número do
// anel, UV.x = linha: 0 borda de dentro, 1 e 2 miolo, 3 brilho de fora)
// ou raio (UV.y = 100 + número, UV.x = 0 começo / 1 ponta, VERTEX.x =
// lado). O raio de cada anel, a força, as cores e quantos anéis/raios
// aparecem vêm do script; o que não aparece vira um ponto (não pinta).
shader_type canvas_item;
render_mode blend_add;

uniform float raio = 100.0;
uniform float espaco = 100.0;
uniform float larg = 7.0;
uniform float alfa = 1.0;
uniform float n_aneis = 4.0;
uniform float n_raios = 10.0;
uniform float raio_ini = 0.10;
uniform float raio_fim = 1.15;
uniform float larg_raio = 3.0;
uniform float ang0 = -2.89;
uniform vec4 cor_anel : hint_color = vec4(1.0, 0.48, 0.06, 1.0);
uniform vec4 cor_brilho : hint_color = vec4(1.0, 1.0, 1.0, 1.0);

void vertex() {
	if (UV.y < 50.0) {
		float i = UV.y;
		float vivo = step(i + 0.5, n_aneis);
		float r = raio + i * espaco;
		float w = larg + i * 1.6;
		float linha = UV.x;
		float off = -w * 1.0;
		off = mix(off, -w * 0.45, step(0.5, linha));
		off = mix(off, w * 0.45, step(1.5, linha));
		off = mix(off, w * 2.6, step(2.5, linha));
		VERTEX = VERTEX * max(0.0, r + off) * vivo;
		float a = max(0.0, 0.40 - i * 0.034) * alfa;
		float miolo = step(0.5, linha) * (1.0 - step(2.5, linha));
		vec3 c = mix(cor_anel.rgb, cor_brilho.rgb, step(1.5, linha) * 0.55);
		COLOR = vec4(mix(c, vec3(1.0), 0.15 * miolo), a * miolo);
	} else {
		float j = UV.y - 100.0;
		float vivo = step(j + 0.5, n_raios);
		float ang = ang0 + 6.2831853 * j / max(1.0, n_raios);
		vec2 dir = vec2(cos(ang), sin(ang));
		vec2 perp = vec2(-dir.y, dir.x);
		float rr = raio * mix(raio_ini, raio_fim, UV.x);
		float lado = VERTEX.x;
		VERTEX = (dir * rr + perp * lado * larg_raio) * vivo;
		COLOR = vec4(mix(cor_anel.rgb, cor_brilho.rgb, 0.35), (1.0 - abs(lado)) * 0.26 * alfa * (1.0 - UV.x * 0.7));
	}
}
