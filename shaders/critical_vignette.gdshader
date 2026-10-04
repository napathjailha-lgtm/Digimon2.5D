shader_type canvas_item;
render_mode unshaded;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
void fragment() {
    // ขอบสี่ด้านนุ่ม ๆ เว้นกลางสนามให้เห็นศัตรูและเส้นทางเดินชัด
    float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
    float fade = 1.0 - smoothstep(0.0, 0.16, edge);
    COLOR = vec4(0.88, 0.12, 0.21, fade * intensity);
}

