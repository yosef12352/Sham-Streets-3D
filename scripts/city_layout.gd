extends RefCounted

const HALF_SIZE := 176.0
const BLOCK_SIZE := 22.0
const ROAD_CENTERS := [-110.0, 0.0, 110.0]
const PARK := Vector3(-44, 0, -44)

static func has_building(column: int, row: int) -> bool:
    if column in [-5, 0, 5] or row in [-5, 0, 5]:
        return false
    return not (column in [-3, -2] and row in [-3, -2])
