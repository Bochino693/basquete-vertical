// MOLDURA COLORIDA: um quadrado por cima de UMA caixa da arte do fundo
// (META, PONTOS, a caixa da fase), que lê a mesma arte (fundo_jogo.png, no
// mesmo lugar) e troca o laranja do neon pela cor da caixa. A forma é a
// da própria arte (chanfros, brilho, linha dupla): fica encaixada
// perfeitamente. Nas beiradas do quadrado a cor volta suave para a arte
// original (lá só há fundo escuro: a emenda não aparece).
// Por pixel: uma leitura de textura e poucas contas, só na área da caixa.
shader_type canvas_item;

uniform vec4 cor : hint_color = vec4(0.35, 0.95, 1.0, 1.0);
uniform vec4 caixa = vec4(0.0, 0.0, 100.0, 100.0);   // x0, y0, x1, y1 (unidades do jogo)
uniform float suave = 6.0;         // volta para a arte nas beiradas
uniform float forca = 1.0;         // 0 = a arte laranja original
uniform float respiro = 0.0;       // o mesmo pulso lento do fundo
uniform float brilho = 0.0;        // acende mais (passou, recorde)
uniform float apagado = 0.0;       // arena de luz apagada

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 p = UV * vec2(1080.0, 1920.0);
	vec2 b = min(p - caixa.xy, caixa.zw - p);
	float m = clamp(min(b.x, b.y) / suave, 0.0, 1.0) * forca;
	// o vermelho da arte é a força do neon; o verde alto é o miolo quente
	float neon = clamp(c.r * 1.8 - 0.40, 0.0, 1.0);
	float quente = clamp((c.g - 0.42) * 2.4, 0.0, 1.0);
	vec3 novo = cor.rgb * c.r * 1.15 + vec3(0.92, 0.96, 1.0) * quente * 0.5;
	novo *= 1.0 + neon * (0.22 * respiro + brilho);
	vec3 orig = c.rgb * (1.0 + neon * 0.22 * respiro);
	// só o neon (e o brilho dele) troca de cor: o fundo escuro fica igual
	// (senão aparece um retângulo tingido em volta da caixa)
	m *= clamp((c.r - 0.10) / 0.20, 0.0, 1.0);
	vec3 res = mix(orig, novo, m) * (1.0 - apagado * 0.55);
	COLOR = vec4(res, 1.0);
}
