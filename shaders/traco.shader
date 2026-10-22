// TRAÇO DE NEON QUE SE DESENHA SOZINHO: uma linha (feita uma vez) com
// miolo forte e brilho em volta. UV.x = onde o ponto está ao longo da
// linha (0..1); UV.y = 0/3 borda do brilho, 1/2 miolo. O script só mexe
// em "inicio" e "progresso" (a parte visível) - a ponta acesa corre
// sozinha.
shader_type canvas_item;
render_mode blend_add;

uniform float inicio = 0.0;
uniform float progresso = 1.0;
uniform float alfa = 1.0;
uniform float ponta = 1.0;          // brilho branco na ponta que avança
uniform vec4 cor : hint_color = vec4(1.0, 0.46, 0.04, 1.0);
uniform float tremor = 0.0;         // lâmpada falhando (0..1)

void vertex() {
	float vis = step(inicio, UV.x) * step(UV.x, progresso) * step(0.0001, progresso);
	float miolo = step(0.5, UV.y) * (1.0 - step(2.5, UV.y));
	float cabeca = clamp(1.0 - (progresso - UV.x) / 0.05, 0.0, 1.0) * ponta * step(progresso, 0.999);
	float falha = 1.0 - tremor * step(0.0, sin(TIME * 47.0 + UV.x * 9.0)) * 0.7;
	vec3 c = mix(cor.rgb, vec3(1.0), 0.25 * miolo + cabeca * 0.7);
	COLOR = vec4(c, vis * alfa * falha * mix(0.0, 1.0, miolo) * (1.0 + cabeca));
}
