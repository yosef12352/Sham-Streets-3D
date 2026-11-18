extends Control

const EXTENT := 116.0
var actor := Vector3.ZERO
var target := Vector3.ZERO

func update_positions(position: Vector3, objective: Vector3) -> void:
    if actor.is_equal_approx(position) and target.is_equal_approx(objective):
        return
    actor = position
    target = objective
    queue_redraw()

func _draw() -> void:
    var border := Rect2(Vector2.ZERO, size)
    draw_rect(border, Color("#263438"))
    var center := size * 0.5
    draw_line(Vector2(center.x, 7), Vector2(center.x, size.y - 7), Color("#809194"), 6)
    draw_line(Vector2(7, center.y), Vector2(size.x - 7, center.y), Color("#809194"), 6)
    draw_circle(_point(target), 4.5, Color("#f6bb52"))
    draw_circle(_point(actor), 4.5, Color("#f6ffff"))
    draw_rect(border, Color("#b8a183"), false, 2)

func _point(location: Vector3) -> Vector2:
    var normalized := (Vector2(location.x, location.z) / EXTENT).clamp(-Vector2.ONE, Vector2.ONE)
    return size * 0.5 + normalized * (size * 0.5 - Vector2(9, 9))
