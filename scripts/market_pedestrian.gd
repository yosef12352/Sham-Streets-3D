extends CharacterBody3D

var start: Vector3
var finish: Vector3
var destination: Vector3
var wait_time := 0.0
var walking_speed := 1.7
var model := preload("res://scripts/person_model.gd").new()
var reaction := 0.0

func configure(from: Vector3, to: Vector3, tint: Color, delay: float) -> void:
    start = from
    finish = to
    position = start
    destination = finish
    wait_time = delay
    collision_layer = 2
    collision_mask = 3
    var collider := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.30
    shape.height = 1.65
    collider.shape = shape
    add_child(collider)
    model.scale = Vector3.ONE * 0.91
    model.build(tint, Color("#ad795a").lerp(Color("#e5b68d"), tint.g), Color("#343a44"))
    add_child(model)

func react() -> void:
    reaction = 2.0
    _turn_around(0.12)

func _physics_process(delta: float) -> void:
    reaction = maxf(0.0, reaction - delta)
    wait_time = maxf(0.0, wait_time - delta)
    var direction := destination - position
    direction.y = 0.0
    if direction.length_squared() < 0.22:
        _turn_around(0.7)
    var motion := direction.normalized() * (walking_speed + (2.0 if reaction > 0.0 else 0.0)) if wait_time <= 0.0 else Vector3.ZERO
    velocity.x = motion.x
    velocity.z = motion.z
    velocity.y = velocity.y - 18.0 * delta if not is_on_floor() else -0.1
    move_and_slide()
    if motion.length_squared() > 0.01:
        rotation.y = atan2(-motion.x, -motion.z)
    model.animate(delta, motion.length(), is_on_floor())
    if is_on_wall() and motion != Vector3.ZERO:
        _turn_around(0.35)

func _turn_around(delay: float) -> void:
    destination = start if destination == finish else finish
    wait_time = delay
