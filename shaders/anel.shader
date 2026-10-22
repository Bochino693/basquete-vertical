// O ARCO FINO DO CRONÔMETRO, que corre por dentro dos tracinhos (os
// tracinhos têm o tracinhos.shader). Cada ponto sabe a sua fração do
// círculo (UV.x, do topo, no sentido do relógio) e se é o meio (UV.y = 10)
// ou a borda macia (11). O script só passa a fração do tempo que resta.
shader_type canvas_item;
render_mode blend_add;

uniform float frac = 1.0;         // tempo que resta (0..1)
uniform float varre = 1.0;        // acendendo no começo do turno (0..1)
uniform vec4 cor : hint_color = vec4(1.0, 0.46, 0.04, 1.0);
uniform float pulso = 0.0;        // 0..1 (piscar dos últimos segundos)

void vertex() {
	float f = min(frac, varre);
	float aceso = step(UV.x, f);
	float a = mix(0.85, 0.0, step(10.5, UV.y)) * aceso * (0.8 + pulso * 0.5);
	COLOR = vec4(mix(cor.rgb, vec3(1.0), 0.35), a);
}
