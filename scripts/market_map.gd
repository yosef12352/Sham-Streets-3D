extends Control

const CITY := preload("res://scripts/city_layout.gd")
var actor := Vector3.ZERO
var target := Vector3.ZERO
var heading := 0.0

func update_positions(position: Vector3, objective: Vector3, angle: float) -> void:
    if actor.is_equal_approx(position) and target.is_equal_approx(objective) and is_equal_approx(heading, angle):
        return
    actor = position
    target = objective
    heading = angle
    queue_redraw()

func _draw() -> void:
    var border := Rect2(Vector2.ZERO, size)
    draw_style_box(_panel(), border)
    var edge := 12.0
    for road: float in CITY.ROAD_CENTERS:
        var x := _point(Vector3(road, 0, 0)).x
        var y := _point(Vector3(0, 0, road)).y
        draw_line(Vector2(x, edge), Vector2(x, size.y - edge), Color("#728383"), 4, true)
        draw_line(Vector2(edge, y), Vector2(size.x - edge, y), Color("#728383"), 4, true)
    var park := _point(CITY.PARK + Vector3(-11, 0, -11))
    draw_circle(park, 7, Color("#89a76e"), true, -1, true)
    draw_circle(_point(target), 4.7, Color("#f4bb63"), true, -1, true)
    var point := _point(actor)
    var forward := Vector2(-sin(heading), -cos(heading))
    draw_colored_polygon(PackedVector2Array([
        point + forward * 6.5,
        point - forward * 4 + forward.orthogonal() * 4.5,
        point - forward * 4 - forward.orthogonal() * 4.5
    ]), Color("#f5fbf7"))

func _panel() -> StyleBoxFlat:
    var panel := StyleBoxFlat.new()
    panel.bg_color = Color("#192729ee")
    panel.border_color = Color("#a9ab9088")
    panel.set_border_width_all(2)
    panel.set_corner_radius_all(18)
    return panel

func _point(location: Vector3) -> Vector2:
    var normalized := (Vector2(location.x, location.z) / CITY.HALF_SIZE).clamp(-Vector2.ONE, Vector2.ONE)
    return size * 0.5 + normalized * (size * 0.5 - Vector2(12, 12))
