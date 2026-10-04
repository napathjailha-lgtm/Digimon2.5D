shader_type canvas_item;
render_mode unshaded;
// ใช้ alpha รูปร่างจริงของพร็อพ แต่สีเงาเป็นสีเย็นจาง ๆ
uniform float opacity = 0.22;
void fragment() {
    float alpha = texture(TEXTURE, UV).a;
    COLOR = vec4(0.055, 0.09, 0.12, alpha * opacity);
}
