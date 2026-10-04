class_name DigitalPixelDust
extends Node2D
## ละอองสี่เหลี่ยมขึ้นจากเท้า: GPU + ParticleProcessMaterial, มี CPU preset สำหรับ Reduce Effects
var gpu: GPUParticles2D
var cpu: CPUParticles2D

func _ready() -> void:
    # พื้นที่คัตซีนเล็ก ปิด collision/trail และใช้แค่ 56 เม็ด ไม่คำนวณทั่วแผนที่
    process_mode = Node.PROCESS_MODE_ALWAYS
    var process := ParticleProcessMaterial.new()
    process.particle_flag_disable_z = true
    process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    process.emission_box_extents = Vector3(105, 10, 0)
    process.direction = Vector3(0, -1, 0)
    process.spread = 18.0
    process.initial_velocity_min = 55.0
    process.initial_velocity_max = 140.0
    process.gravity = Vector3(0, -25, 0)
    process.scale_min = 0.7
    process.scale_max = 1.8
    var gradient := Gradient.new()
    gradient.offsets = PackedFloat32Array([0.0, 0.12, 0.75, 1.0])
    gradient.colors = PackedColorArray([Color(0.3, 0.8, 1, 0), Color(0.4, 0.95, 1, 0.9), Color(0.8, 0.9, 1, 0.7), Color(0.5, 0.8, 1, 0)])
    var ramp := GradientTexture1D.new()
    ramp.gradient = gradient
    process.color_ramp = ramp
    var additive := CanvasItemMaterial.new()
    additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    gpu = GPUParticles2D.new()
    gpu.name = "DigitalDustGPU"
    gpu.amount = 56
    gpu.lifetime = 1.6
    gpu.preprocess = 0.35
    gpu.local_coords = true
    gpu.visibility_rect = Rect2(-160, -350, 320, 420)
    gpu.texture = preload("res://assets/ui/digital/pixel_dust.png")
    gpu.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    gpu.process_material = process
    gpu.material = additive
    gpu.emitting = false
    add_child(gpu)
    cpu = CPUParticles2D.new()
    cpu.name = "DigitalDustCPU"
    cpu.convert_from_particles(gpu)
    cpu.amount = 24
    cpu.material = additive
    cpu.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    cpu.emitting = false
    add_child(cpu)

func start_dust() -> void:
    # ลดเอฟเฟกต์เลือก CPU 24 เม็ด; โหมดปกติใช้ GPU ตามที่กำหนด
    stop_dust()
    if GameVisualSettings.low_effects:
        cpu.restart()
        cpu.emitting = true
    else:
        gpu.restart()
        gpu.emitting = true

func stop_dust() -> void:
    # จบคัตซีนแล้วไม่ปล่อย emission ต่อ; ทั้งคู่ถูกลบพร้อม stage
    if is_instance_valid(gpu):
        gpu.emitting = false
    if is_instance_valid(cpu):
        cpu.emitting = false

