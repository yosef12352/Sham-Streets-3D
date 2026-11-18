extends CharacterBody3D
class_name ShamVehicleController

@export var acceleration: float = 17.0
@export var reverse_acceleration: float = 9.0
@export var maximum_speed: float = 24.0
@export var steering_speed: float = 1.7
@export var braking: float = 25.0
@export var drag: float = 4.0
@export var gravity: float = 25.0

var throttle_input: float = 0.0
var steering_input: float = 0.0
var brake_input: bool = false
var driver_active: bool = false
var forward_speed: float = 0.0

func set_mobile_controls(throttle: float, steering: float, brake: bool) -> void:
    throttle_input = clampf(throttle, -1.0, 1.0)
    steering_input = clampf(steering, -1.0, 1.0)
    brake_input = brake

func enter_vehicle() -> void:
    driver_active = true

func exit_vehicle() -> void:
    driver_active = false
    set_mobile_controls(0.0, 0.0, true)

func _physics_process(delta: float) -> void:
    var target_throttle: float = throttle_input if driver_active else 0.0
    var engine_force: float = acceleration if target_throttle >= 0.0 else reverse_acceleration
    if brake_input:
        forward_speed = move_toward(forward_speed, 0.0, braking * delta)
    elif absf(target_throttle) > 0.01:
        var speed_limit := maximum_speed if target_throttle > 0.0 else maximum_speed * 0.4
        forward_speed = move_toward(forward_speed, target_throttle * speed_limit, engine_force * delta)
    else:
        forward_speed = move_toward(forward_speed, 0.0, drag * delta)
    if absf(forward_speed) > 0.2:
        rotate_y(-steering_input * steering_speed * delta * signf(forward_speed) * minf(absf(forward_speed) / 6.0, 1.0))
    var forward: Vector3 = -global_transform.basis.z
    velocity.x = forward.x * forward_speed
    velocity.z = forward.z * forward_speed
    velocity.y = velocity.y - gravity * delta if not is_on_floor() else -0.1
    move_and_slide()
    if is_on_wall():
        forward_speed = get_real_velocity().dot(forward)
