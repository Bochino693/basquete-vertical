// FUNDO VIVO DA PARTIDA: a arte de neon da arena reage ao jogo.
// O desenho é uma malha (25 x 43 pontos) por cima da tela: a conta das
// ondas, do "radar" que desce e da respiração é feita em cada PONTO da
// malha (o processador de vértices da Mali tem precisão alta e sobra) e o
// pixel só multiplica: barato na Mali-400/450, que é fraca por pixel.
// As próprias linhas de neon da arte acendem quando a onda da cesta passa
// por elas (a máscara do neon é o vermelho da arte: o fundo é escuro).
shader_type canvas_item;
render_mode blend_mix;

uniform float respiro = 0.0;        // 0..1 (pulso lento)
uniform float scan_y = -500.0;      // altura do radar (px)
uniform float scan_forca = 0.0;
uniform vec2 onda_centro = vec2(540.0, 776.0);
uniform float onda_raio = -1000.0;
uniform float onda_forca = 0.0;
uniform vec2 onda2_centro = vec2(540.0, 776.0);
uniform float onda2_raio = -1000.0;
uniform float onda2_forca = 0.0;
uniform float onda_larg = 90.0;
uniform vec4 cor_onda : hint_color = vec4(1.0, 0.75, 0.35, 1.0);
uniform float alerta = 0.0;         // últimos segundos: neon puxa para o vermelho
uniform float azul = 0.0;           // SLAM MODE: neon vira azul elétrico
uniform float apagado = 0.0;        // 1 = arena de luz apagada (apresentação)

varying float v_boost;
varying vec3 v_add;

void vertex() {
	float d1 = distance(VERTEX, onda_centro);
	float b1 = clamp(1.0 - abs(d1 - onda_raio) / onda_larg, 0.0, 1.0) * onda_forca;
	float d2 = distance(VERTEX, onda2_centro);
	float b2 = clamp(1.0 - abs(d2 - onda2_raio) / onda_larg, 0.0, 1.0) * onda2_forca;
	float s = clamp(1.0 - abs(VERTEX.y - scan_y) / 80.0, 0.0, 1.0) * scan_forca;
	float b = b1 * b1 + b2 * b2;
	v_boost = 0.22 * respiro + 1.0 * s * s + 2.2 * b - apagado * 0.85;
	v_add = cor_onda.rgb * b * 0.45 + vec3(1.0, 0.6, 0.3) * s * s * 0.12;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float neon = clamp(c.r * 1.8 - 0.40, 0.0, 1.0);
	vec3 cor = c.rgb + c.rgb * neon * v_boost + v_add * neon;
	cor = mix(cor, vec3(cor.r * 0.30, cor.r * 0.78, cor.r * 1.30), neon * azul);
	cor = mix(cor, vec3(cor.r * 1.15, cor.g * 0.30, cor.b * 0.25), neon * alerta);
	cor *= 1.0 - apagado * 0.55;
	COLOR = vec4(cor, 1.0);
}
