shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec4 glow_color : source_color = vec4(0.25, 0.85, 1.0, 1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;
void fragment() {
    // แสง additive เฉพาะบนปุ่ม ไม่ต้องเปิด HDR/Bloom ทั้งฉากบนมือถือ
    vec2 p = abs(UV - 0.5) * 2.0;
    float center = 1.0 - smoothstep(0.15, 1.0, max(p.x, p.y));
    COLOR = vec4(mix(glow_color.rgb, vec3(1.0), 0.5), center * flash * 0.55);
}

