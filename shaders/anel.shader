// ANEL DO CRONÔMETRO: 60 tracinhos (com brilho) + o arco fino que corre
// por dentro. Cada ponto sabe a sua fração do círculo (UV.x, do topo, no
// sentido do relógio) e o que é (UV.y: 0 tracinho, 1 brilho de dentro, 2
// brilho de fora, 10 arco, 11 borda do arco). O script só passa a fração
// do tempo que resta: nada é redesenhado.
shader_type canvas_item;
render_mode blend_add;

uniform float frac = 1.0;         // tempo que resta (0..1)
uniform float varre = 1.0;        // acendendo no começo do turno (0..1)
uniform vec4 cor : hint_color = vec4(1.0, 0.46, 0.04, 1.0);
uniform vec4 cor_apagado : hint_color = vec4(0.35, 0.10, 0.02, 1.0);
uniform float pulso = 0.0;        // 0..1 (piscar dos últimos segundos)

void vertex() {
	float f = min(frac, varre);
	float tipo = UV.y;
	if (tipo < 5.0) {
		float aceso = step(UV.x, f);
		vec3 c = mix(cor_apagado.rgb, cor.rgb * (1.0 + pulso * 0.6), aceso);
		float a_miolo = mix(0.55, 1.0, aceso);
		float a_brilho = 0.50 * aceso * (1.0 + pulso);
		float a = mix(a_miolo, a_brilho, step(0.5, tipo));
		a = mix(a, 0.0, step(1.5, tipo));
		COLOR = vec4(c, a);
	} else {
		float aceso = step(UV.x, f);
		float a = mix(0.85, 0.0, step(10.5, tipo)) * aceso * (0.8 + pulso * 0.5);
		COLOR = vec4(mix(cor.rgb, vec3(1.0), 0.35), a);
	}
}
