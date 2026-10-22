// OS 60 TRACINHOS DO CRONÔMETRO (anel_crono.gd). Cada tracinho é um
// quadrado com folga para o brilho; o UV é a posição em unidades do jogo a
// partir do centro dele (x ao longo do círculo, y para fora) e a cor do
// ponto traz a fração do círculo onde ele começa (COLOR.r). Por pixel:
//   * o tracinho é um retângulo de cantos redondos com a borda de 1 pixel
//     da tela (liso de perto e de longe, sem "escadinha");
//   * aceso: a cor com o miolo quase branco e um brilho que some suave;
//   * apagado: vidro escuro da mesma cor, com a beirada um pouco mais clara;
//   * o tracinho da vez apaga AOS POUCOS, junto com o tempo (sem pular).
// Só contas simples (nada de textura): leve para a Mali-450.
shader_type canvas_item;

uniform float frac = 1.0;         // tempo que resta (0..1)
uniform float varre = 1.0;        // acendendo no começo do turno (0..1)
uniform float n = 60.0;           // quantos tracinhos
uniform vec4 cor : hint_color = vec4(1.0, 0.46, 0.04, 1.0);
uniform vec4 cor_apagado : hint_color = vec4(0.30, 0.10, 0.02, 1.0);
uniform float pulso = 0.0;        // 0..1 (piscar dos últimos segundos)
uniform vec2 meio = vec2(6.4, 11.0);   // meia largura e meia altura do tracinho
uniform float canto = 2.8;        // raio dos cantos
uniform float px = 1.0;           // pixels da tela por unidade do jogo

void vertex() {
	float f = min(frac, varre);
	// 1 = aceso; entre 1 e 0 enquanto o tempo passa por este tracinho
	float luz = clamp((f - COLOR.r) * n, 0.0, 1.0);
	COLOR = vec4(luz, 0.0, 0.0, 1.0);
}

void fragment() {
	float luz = COLOR.r;
	vec2 p = UV;
	vec2 q = abs(p) - meio + vec2(canto);
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - canto;
	float corpo = clamp(0.5 - d * px, 0.0, 1.0);
	// aceso: miolo quase branco no meio, a cor nas beiradas
	float miolo = clamp(1.0 - length(p / meio), 0.0, 1.0);
	vec3 c_aceso = mix(cor.rgb * (1.0 + pulso * 0.45), vec3(1.0, 0.96, 0.88), miolo * 0.8);
	// apagado: vidro escuro, a beirada (1,5 unidade para dentro) mais clara
	float beira = clamp(1.0 - abs(d + 1.4) / 1.2, 0.0, 1.0);
	vec3 c_apagado = cor_apagado.rgb * (0.55 + 0.85 * beira);
	vec3 c_corpo = mix(c_apagado, c_aceso, luz);
	float a_corpo = corpo * mix(0.92, 1.0, luz);
	// brilho em volta (só do aceso), some suave antes da borda do quadrado
	float g = luz * (0.55 + 0.35 * pulso) * exp(-max(d, 0.0) * 0.40);
	vec3 pm = cor.rgb * g;
	float a = g;
	pm = c_corpo * a_corpo + pm * (1.0 - a_corpo);
	a = a_corpo + a * (1.0 - a_corpo);
	COLOR = vec4(pm / max(a, 0.002), a);
}
