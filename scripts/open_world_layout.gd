class_name OpenWorldLayout
extends Resource
## ข้อมูลภูมิประเทศเดียวกันใช้สร้างภาพ พื้นที่ชน Navigation และมินิแมป
## พิกัดทั้งหมดเป็นพิกัดโลก ไม่ขึ้นกับขนาดหน้าจอมือถือ
@export var extent: Vector2 = Vector2(10240, 6400)
@export var village_center: Vector2 = Vector2(850, 930)
@export var river_x: float = 2920.0
@export var river_width: float = 270.0
@export var bridge_y: PackedFloat32Array = PackedFloat32Array([1000, 2250, 4000, 5400])
@export var bridge_clearance: float = 180.0
@export var road_width: float = 120.0
@export var decoration_seed: int = 1401
@export var roads: Array[PackedVector2Array] = [
    PackedVector2Array([Vector2(700, 930), Vector2(1400, 950), Vector2(2100, 1070), Vector2(2920, 1000), Vector2(3540, 1000), Vector2(4260, 700), Vector2(4820, 700), Vector2(5600, 1050), Vector2(6700, 1100), Vector2(8000, 850), Vector2(9500, 1000)]),
    PackedVector2Array([Vector2(850, 930), Vector2(850, 1630), Vector2(1050, 2300), Vector2(1800, 2660), Vector2(2400, 3600), Vector2(2920, 4000), Vector2(4200, 4000), Vector2(5600, 4300), Vector2(7000, 4000), Vector2(9000, 4300)]),
    PackedVector2Array([Vector2(2100, 1070), Vector2(2450, 1760), Vector2(2920, 2250), Vector2(3660, 2250), Vector2(4500, 2580), Vector2(5700, 2600), Vector2(7100, 2700), Vector2(8700, 2850), Vector2(9600, 3100)]),
    PackedVector2Array([Vector2(1400, 950), Vector2(1740, 440), Vector2(2350, 500)]),
    PackedVector2Array([Vector2(3540, 1000), Vector2(3710, 1650), Vector2(3660, 2250), Vector2(3800, 3200), Vector2(4200, 4000), Vector2(4100, 5300), Vector2(5200, 5700), Vector2(6800, 5550), Vector2(8300, 5600), Vector2(9600, 5500)]),
    PackedVector2Array([Vector2(1050, 2300), Vector2(1150, 3750), Vector2(1600, 5000), Vector2(2400, 5400), Vector2(2920, 5400), Vector2(4100, 5300)]),
    PackedVector2Array([Vector2(6700, 1100), Vector2(6600, 1900), Vector2(7100, 2700), Vector2(7000, 4000), Vector2(6800, 5550)]),
    PackedVector2Array([Vector2(9500, 1000), Vector2(9000, 1900), Vector2(8700, 2850), Vector2(9000, 4300), Vector2(9600, 5500)])
]

func distance_to_roads(point: Vector2) -> float:
    # ใช้กันต้นไม้สุ่มไปขวางเส้นทางหลัก
    var nearest: float = INF
    for road: PackedVector2Array in roads:
        for i: int in range(road.size() - 1):
            nearest = minf(nearest, point.distance_to(Geometry2D.get_closest_point_to_segment(point, road[i], road[i + 1])))
    return nearest

func is_river(point: Vector2) -> bool:
    return absf(point.x - river_x) < river_width * 0.5

func is_bridge(point: Vector2) -> bool:
    for y: float in bridge_y:
        if absf(point.y - y) < bridge_clearance * 0.5:
            return true
    return false

func polygon_for_rect(rect: Rect2) -> PackedVector2Array:
    return PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)])
