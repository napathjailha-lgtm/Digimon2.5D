shader_type canvas_item;
uniform float white_flash : hint_range(0.0, 1.0) = 0.0;
void fragment() {
    vec4 source = texture(TEXTURE, UV) * COLOR;
    COLOR = vec4(mix(source.rgb, vec3(1.0), white_flash), source.a);
}
