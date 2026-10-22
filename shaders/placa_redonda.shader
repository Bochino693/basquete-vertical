// PLACA REDONDA de vidro escuro atrás dos dígitos do relógio (display7.gd).
// Um quadrado com UV 0..1: o círculo é calculado por pixel, com a borda de
// 1 pixel da tela (o draw_circle da Mali sai em "escadinha"), um degradê
// leve no vidro, o reflexo em cima e um aro fino da cor do display.
shader_type canvas_item;

uniform vec4 cor : hint_color = vec4(1.0, 0.46, 0.04, 1.0);
uniform float raio_px = 169.0;     // raio em pixels DA TELA

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float d = (r - 1.0) * raio_px;                 // pixels até a borda (negativo dentro)
	float dentro = clamp(0.5 - d, 0.0, 1.0);
	// vidro: quase preto, um pouco mais claro perto da borda de cima
	vec3 c = vec3(0.012, 0.006, 0.004) + vec3(0.030, 0.016, 0.010) * clamp(r * 1.1 - p.y * 0.45 - 0.35, 0.0, 1.0);
	// reflexo: um arco claro e largo no alto
	float reflexo = clamp(1.0 - abs(length(p - vec2(0.0, 0.55)) - 1.25) / 0.10, 0.0, 1.0) * clamp(-p.y, 0.0, 1.0);
	c += vec3(0.05, 0.045, 0.04) * reflexo;
	// aro fino da cor, 2 pixels para dentro da borda, liso dos dois lados
	float aro = clamp(1.6 - abs(d + 2.6), 0.0, 1.0);
	c = mix(c, cor.rgb * 0.75, aro * 0.55);
	COLOR = vec4(c, dentro * 0.95);
}
