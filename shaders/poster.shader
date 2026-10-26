shader_type canvas_item;
render_mode blend_mix;

// O PÔSTER (abertura e o fim da apresentação). Parado ele já "respira" e um
// brilho atravessa o letreiro; com "vida" (o pôster vivo) as coisas da arte
// MEXEM, cada uma do seu jeito, pelo mapa imagens/poster_vivo.png:
//   R  luzes (janelas dos prédios, refletores): cada grupo (G = sorteio)
//      acende mais forte ou apaga de vez em quando, no seu tempo;
//   B  neon (o telão SLAM, a coroa e o muro grafitado): pulsa e falha
//      (neon vem do script) e uma faixa de luz corre o telão;
//   A  fogo (a bola, o aro, o contorno em brasa): tremula com o ruído
//      SUBINDO, como chama, e esquenta para o amarelo.
// Leve para a Mali-450: três leituras de textura direto das coordenadas
// que vêm do vértice (sem conta antes da leitura) e poucas contas.

uniform float brilho_pos = -2000.0;
uniform float brilho_forca = 0.0;
uniform float respiro = 0.0;
uniform float relampago = 0.0;
uniform float escurecer = 0.0;
uniform float vida = 0.0;
uniform float tempo = 0.0;      // (dá a volta a cada 600 s: o ruído emenda)
uniform float luz_a = 0.0;      // tempo das janelas, já com a volta (0..2pi)
uniform float luz_c = 0.0;      // idem, vezes o sorteio (0..30pi; sorteio = j/15)
uniform float neon = 0.0;
uniform float telao_y = -1000.0;
uniform sampler2D mapa : hint_black;
uniform sampler2D ruido : hint_black;

varying float v_brilho;
varying vec2 v_ruido;
varying vec2 v_ruido2;
varying vec2 v_pos;

void vertex() {
	float diag = VERTEX.x + VERTEX.y * 0.55;
	v_brilho = clamp(1.0 - abs(diag - brilho_pos) / 150.0, 0.0, 1.0) * brilho_forca;
	// o ruído do fogo sobe (duas camadas, velocidades diferentes; fract no
	// vértice: o número fica pequeno e a leitura, precisa)
	v_ruido = UV * vec2(4.2, 7.5) + vec2(0.0, fract(tempo * 0.55));
	v_ruido2 = UV * vec2(2.6, 4.6) + vec2(fract(tempo * 0.07), fract(tempo * 0.31));
	v_pos = VERTEX;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec4 m = texture(mapa, UV);
	float n = texture(ruido, v_ruido).r + texture(ruido, v_ruido2).r;
	float lum = max(c.r, max(c.g, c.b));
	float forte = clamp((lum - 0.35) * 1.8, 0.0, 1.0);
	float azulado = clamp((c.b - c.r) * 2.5, 0.0, 1.0);
	// luzes: cada grupo de janelas no seu ritmo (números pequenos: a
	// Mali-450 faz estas contas com pouca precisão)
	float onda = sin(luz_a + m.g * luz_c);
	float pisca = smoothstep(0.55, 0.95, onda) * 1.1 - smoothstep(0.80, 0.99, -onda) * 0.8;
	// fogo: o ruído (0..2) vira chama (-0.7 .. +1.1)
	float chama = (n - 0.9) * 1.6;
	float faixa = clamp(1.0 - abs(v_pos.y - telao_y) / 28.0, 0.0, 1.0) * step(860.0, v_pos.x);
	float k = 1.0 + respiro * 0.10 + vida * (m.r * pisca + m.b * (neon + faixa * 1.4) + m.a * chama);
	vec3 cor = c.rgb * k + c.rgb * forte * v_brilho * 1.5;
	cor += vec3(0.30, 0.16, 0.02) * (m.a * max(chama, 0.0) * vida);
	cor += vec3(0.30, 0.60, 1.0) * azulado * relampago * 0.9;
	cor *= 1.0 - escurecer * 0.62;
	COLOR = vec4(cor, 1.0);
}
