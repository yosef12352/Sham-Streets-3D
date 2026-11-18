extends CharacterBody3D

var start: Vector3
var finish: Vector3
var destination: Vector3
var wait_time := 0.0
var walking_speed := 1.7

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
    var model := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = shape.radius
    mesh.height = shape.height
    var material := StandardMaterial3D.new()
    material.albedo_color = tint
    mesh.material = material
    model.mesh = mesh
    add_child(model)

func _physics_process(delta: float) -> void:
    wait_time = maxf(0.0, wait_time - delta)
    var direction := destination - position
    direction.y = 0.0
    if direction.length_squared() < 0.22:
        _turn_around(0.7)
    var motion := direction.normalized() * walking_speed if wait_time == 0.0 else Vector3.ZERO
    velocity.x = motion.x
    velocity.z = motion.z
    velocity.y = velocity.y - 18.0 * delta if not is_on_floor() else -0.1
    move_and_slide()
    if is_on_wall() and motion != Vector3.ZERO:
        _turn_around(0.35)

func _turn_around(delay: float) -> void:
    destination = start if destination == finish else finish
    wait_time = delay
