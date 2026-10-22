// DISPLAY DE 7 SEGMENTOS (display7.gd): a malha vem branca e diz, em cada
// ponto, se é segmento aceso (COLOR.g), o miolo quente do segmento
// (COLOR.r: o centro do LED quase branco, como no placar de verdade) e a
// transparência (COLOR.a: o brilho em volta some para fora). A cor do
// display é "cor"; o apagado é a mesma cor bem escura (vidro do LED).
// Uma conta por pixel: leve para a Mali-450.
shader_type canvas_item;

uniform vec4 cor : hint_color = vec4(1.0, 0.46, 0.04, 1.0);
uniform float tom_apagado = 0.16;

void fragment() {
	vec3 c = cor.rgb * mix(tom_apagado, 1.0, COLOR.g);
	c = mix(c, vec3(1.0, 0.98, 0.92), COLOR.r * 0.72);
	COLOR = vec4(c, COLOR.a);
}
