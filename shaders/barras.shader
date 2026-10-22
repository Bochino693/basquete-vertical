// BARRAS DE ENERGIA (equalizador nas "asas" da arena). Cada barra é um
// retângulo; o topo sobe e desce sozinho (TIME no vértice) e a "energia"
// do jogo (combo) aumenta a altura. UV.x = número da barra, UV.y = 0 base
// / 1 topo; COLOR.r = fase sorteada. Pixel: só a cor.
shader_type canvas_item;
render_mode blend_add;

uniform float energia = 0.2;     // 0..1
uniform float altura = 80.0;
uniform float alfa = 1.0;
uniform vec4 cor_base : hint_color = vec4(1.0, 0.35, 0.02, 1.0);
uniform vec4 cor_topo : hint_color = vec4(1.0, 0.85, 0.40, 1.0);

void vertex() {
	float topo = UV.y;
	float fase = COLOR.r * 6.2831853;
	float v = 0.5 + 0.5 * sin(TIME * (2.2 + COLOR.r * 3.0) + fase);
	v = v * v * (0.25 + energia * 0.75) + 0.08;
	VERTEX.y -= topo * altura * v;
	COLOR = vec4(mix(cor_base.rgb, cor_topo.rgb, topo * v), alfa * (0.55 + 0.45 * topo));
}
