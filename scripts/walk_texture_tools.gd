class_name WalkTextureTools
extends RefCounted
## ภาพเดินมี margin เพื่อปักเท้า แต่ Portrait/คัตซีนต้องใช้ภาพจริงไม่รวม padding
static func visible_texture(texture: Texture2D) -> Texture2D:
    if texture is AtlasTexture and texture.margin.size != Vector2.ZERO:
        var visible := AtlasTexture.new()
        visible.atlas = texture.atlas
        visible.region = texture.region
        visible.filter_clip = true
        return visible
    return texture
