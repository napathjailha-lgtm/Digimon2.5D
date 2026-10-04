shader_type canvas_item;
// อ่าน 4 ช่องของ atlas โดยใช้พิกัดโลก จึงไม่ขยาย texture ตามขนาดแผนที่
uniform sampler2D terrain_atlas : source_color, filter_linear;
uniform vec2 quadrant = vec2(0.0, 0.0);
uniform float tile_size = 320.0;
uniform bool river = false;
uniform bool feather_edges = false;
varying vec2 world_point;
varying vec4 vertex_tint;

void vertex() {
    world_point = VERTEX;
    vertex_tint = COLOR;
}

void fragment() {
    vec2 p = world_point;
    if (river) { p += vec2(TIME * 5.0, TIME * 11.0); }
    vec2 uv = fract(p / tile_size);
    // กัน bilinear filter อ่านข้ามไป texture ช่องข้างเคียง
    uv = mix(vec2(0.002), vec2(0.998), uv);
    vec4 tex = texture(terrain_atlas, (uv + quadrant) * 0.5);
    COLOR = tex * vertex_tint;
    if (feather_edges) {
        COLOR.a *= smoothstep(0.0, 0.14, UV.y) * smoothstep(0.0, 0.14, 1.0 - UV.y);
    }
}
