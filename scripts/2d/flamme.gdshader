// Flamme qui vacille : luminosité irrégulière et léger balancement du haut du sprite.
shader_type canvas_item;

uniform float force = 0.25;    // variation de luminosité
uniform float vitesse = 9.0;

void fragment() {
	float t = TIME * vitesse;
	float v = 0.5 * sin(t) + 0.3 * sin(t * 2.7 + 1.3) + 0.2 * sin(t * 5.1 + 0.7);
	float haut = 1.0 - UV.y;
	vec2 decalage = vec2(sin(t * 1.3 + UV.y * 9.0) * 1.2 * haut * TEXTURE_PIXEL_SIZE.x, 0.0);
	vec4 c = texture(TEXTURE, UV + decalage);
	c.rgb *= 1.0 + force * v;
	COLOR = c;
}
