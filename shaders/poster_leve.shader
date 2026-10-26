// O PÔSTER no modo EFEITOS LEVES (o de antes do pôster vivo): um brilho
// que atravessa o letreiro, o pulso da arte e os raios azuis piscando (as
// partes azuis da arte acendem num relâmpago). Conta no vértice (malha
// 13 x 23), pixel só multiplica. Os parâmetros são os do poster.shader.
shader_type canvas_item;
render_mode blend_mix;

uniform float brilho_pos = -2000.0;  // posição da faixa de brilho (px, na diagonal)
uniform float brilho_forca = 0.0;
uniform float respiro = 0.0;
uniform float relampago = 0.0;       // 0..1
uniform float escurecer = 0.0;       // 0..1 (painéis por cima)

varying float v_brilho;

void vertex() {
	float diag = VERTEX.x + VERTEX.y * 0.55;
	v_brilho = clamp(1.0 - abs(diag - brilho_pos) / 150.0, 0.0, 1.0) * brilho_forca;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = max(c.r, max(c.g, c.b));
	float forte = clamp((lum - 0.35) * 1.8, 0.0, 1.0);
	float azulado = clamp((c.b - c.r) * 2.5, 0.0, 1.0);
	vec3 cor = c.rgb * (1.0 + respiro * 0.10) + c.rgb * forte * v_brilho * 1.5;
	cor += vec3(0.30, 0.60, 1.0) * azulado * relampago * 0.9;
	cor *= 1.0 - escurecer * 0.62;
	COLOR = vec4(cor, 1.0);
}
