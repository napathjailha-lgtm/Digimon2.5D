shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float radius_px : hint_range(0.0, 12.0) = 5.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float darken : hint_range(0.0, 0.7) = 0.28;

void fragment() {
    // Godot สร้าง mipmap ที่กรองภาพไว้แล้ว; LOD สูงทำให้เบลอนุ่มโดยไม่เห็นตัวอักษรซ้อน
    float lod = log2(max(radius_px, 1.0)) * strength;
    vec3 color = textureLod(screen_texture, SCREEN_UV, lod).rgb;
    // ลดแสงและเติมน้ำเงินนิดเดียว เพื่อให้หน้าต่างสว่างเด่นโดยไม่แสบตา
    color = mix(color, vec3(0.025, 0.045, 0.085), darken * strength);
    COLOR = vec4(color, 1.0);
}
