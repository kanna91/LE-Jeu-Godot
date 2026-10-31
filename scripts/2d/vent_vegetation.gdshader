// Balancement léger d'un sprite de végétation : le haut ondule, le bas (pied) reste fixe.
shader_type canvas_item;

uniform float amplitude = 2.0;   // déplacement maximal, en pixels de la texture
uniform float vitesse = 1.1;
uniform float phase = 0.0;

void fragment() {
	float hauteur = 1.0 - UV.y;                      // 0 au pied, 1 en haut
	float onde = sin(TIME * vitesse + phase + UV.y * 7.0) + 0.4 * sin(TIME * vitesse * 2.3 + UV.x * 11.0);
	vec2 decalage = vec2(onde * amplitude * hauteur * hauteur * TEXTURE_PIXEL_SIZE.x, 0.0);
	COLOR = texture(TEXTURE, UV + decalage);
}
