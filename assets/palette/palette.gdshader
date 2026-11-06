shader_type canvas_item;
// Ostateczny obraz gry -> paleta max 256 kolorów. Jedno pobranie z ekranu + jedno z tablicy LUT 32x32x32
// (x = b*32 + r, y = g), wygenerowanej przez tools/make_palette.py. Wynik zawsze należy do palety.
uniform sampler2D lut : filter_nearest, repeat_disable;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	ivec3 q = ivec3(clamp(floor(c * 31.0 + 0.5), 0.0, 31.0));
	COLOR = vec4(texelFetch(lut, ivec2(q.b * 32 + q.r, q.g), 0).rgb, 1.0);
}
