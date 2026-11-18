extends RefCounted

const HALF_SIZE := 176.0
const BLOCK_SIZE := 22.0
const ROAD_CENTERS := [-110.0, 0.0, 110.0]
const PARK := Vector3(-44, 0, -44)

static func has_building(column: int, row: int) -> bool:
    if column in [-5, 0, 5] or row in [-5, 0, 5]:
        return false
    return not (column in [-3, -2] and row in [-3, -2])

const DISTRICTS := [
    {"name": "حيدرية", "point": Vector3(0, 0, 35), "color": Color("#bd9365")},
    {"name": "الصاخور", "point": Vector3(0, 0, -84), "color": Color("#95b48b")},
    {"name": "مساكن هنانو", "point": Vector3(110, 0, -66), "color": Color("#83afbc")},
    {"name": "ميسلون", "point": Vector3(-110, 0, 65), "color": Color("#b69bc2")},
]

static func district_index(location: Vector3) -> int:
    if location.x > 55:
        return 2
    if location.x < -55:
        return 3
    return 1 if location.z < -16 else 0
