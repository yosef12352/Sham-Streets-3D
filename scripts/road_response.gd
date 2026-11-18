extends Node3D

const CAR := preload("res://scenes/market_car.tscn")
const PATROL_START := Vector3(-3, 0.66, -34)
const TRAFFIC_START := Vector3(3, 0.66, -82)
const RESPONSE_INTERVAL := 9.0

var traffic: ShamVehicleController
var patrol: ShamVehicleController
var traffic_heading := 1.0
var remaining := 0.0
var contact_cooldown := 0.0

func _ready() -> void:
    traffic = _spawn(TRAFFIC_START, Color("#b58f58"))
    patrol = _spawn(PATROL_START, Color("#526da6"))
    patrol.hide()
    patrol.collision_layer = 0
    patrol.collision_mask = 0
    patrol.set_physics_process(false)

func _spawn(location: Vector3, color: Color) -> ShamVehicleController:
    var vehicle := CAR.instantiate() as ShamVehicleController
    vehicle.position = location
    vehicle.maximum_speed = 9.0
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    vehicle.get_node("Body").material_override = material
    add_child(vehicle)
    vehicle.enter_vehicle()
    return vehicle

func tick(delta: float, player_car: ShamVehicleController, actor_position: Vector3, state: ShamGameState) -> void:
    contact_cooldown = maxf(0.0, contact_cooldown - delta)
    if traffic.position.z < -91 or traffic.position.z > 77:
        traffic_heading = 1.0 if traffic.position.z < -91 else -1.0
        traffic.rotation.y = PI if traffic_heading > 0.0 else 0.0
        traffic.forward_speed = 0.0
    elif is_zero_approx(traffic.rotation.y) and traffic_heading > 0.0:
        traffic.rotation.y = PI
    traffic.set_mobile_controls(0.55, 0.0, false)
    if player_car.driver_active and contact_cooldown == 0.0:
        for index in range(player_car.get_slide_collision_count()):
            if player_car.get_slide_collision(index).get_collider() == traffic:
                state.set_wanted(state.wanted_level + 1)
                remaining = RESPONSE_INTERVAL
                contact_cooldown = 2.5
                break
    if state.wanted_level > 0:
        if not patrol.visible:
            patrol.position = PATROL_START
            patrol.velocity = Vector3.ZERO
            patrol.forward_speed = 0.0
            patrol.collision_layer = 1
            patrol.collision_mask = 1
            patrol.show()
            patrol.set_physics_process(true)
            remaining = RESPONSE_INTERVAL
        _pursue(actor_position)
        remaining -= delta
        if remaining <= 0.0:
            state.set_wanted(state.wanted_level - 1)
            remaining = RESPONSE_INTERVAL
    elif patrol.visible:
        patrol.hide()
        patrol.collision_layer = 0
        patrol.collision_mask = 0
        patrol.set_physics_process(false)

func _pursue(actor_position: Vector3) -> void:
    var difference := actor_position - patrol.position
    difference.y = 0.0
    var desired_yaw := atan2(-difference.x, -difference.z)
    var angle := wrapf(patrol.rotation.y - desired_yaw, -PI, PI)
    patrol.set_mobile_controls(0.92, clampf(angle, -1.0, 1.0), difference.length_squared() < 18.0)
