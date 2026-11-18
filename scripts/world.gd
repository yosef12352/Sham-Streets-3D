extends Node3D

const SPEED := 6.0
const JUMP_SPEED := 6.0
const GRAVITY := 18.0
var player: CharacterBody3D
var camera: Camera3D
var stick := Vector2.ZERO
var touch_start := Vector2.ZERO
var touch_id := -1
var look_id := -1
var yaw := 0.0
var pitch := 0.38
var car: ShamVehicleController
var districts := preload("res://scripts/district_stream.gd").new()
var pedestrians: Node3D
var road_response := preload("res://scripts/road_response.gd").new()
var state := ShamGameState.new()
var missions := ShamMissionManager.new()
var hud: Label
var minimap := preload("res://scripts/market_map.gd").new()
var marker: MeshInstance3D
var driving := false
var braking := false
var interact_requested := false

const SPAWN := Vector3(1, 1, 8)
const CAR_SPAWN := Vector3(-3, 0.66, 8)
const PICKUP := Vector3(4, 0, 16)
const DELIVERY := Vector3(4, 0, -65)
const SHOP := Vector3(-5, 0, -10)
const JOB := "market_delivery"


func _ready() -> void:
    _build_city()
    _build_player()
    _build_car()
    add_child(road_response)
    add_child(state)
    add_child(missions)
    _build_ui()
    _build_marker()
    _restore()
    state.wanted_changed.connect(func(_level: int) -> void: _refresh_ui())
    districts.update_focus(car.position if driving else player.position)
    _refresh_ui()
    camera.position = player.position + Vector3(0, 4, 8)

func _box(pos: Vector3, size: Vector3, color: Color, solid: bool = true) -> void:
    var body := StaticBody3D.new()
    body.position = pos
    var mesh := MeshInstance3D.new()
    var cube := BoxMesh.new()
    cube.size = size
    mesh.mesh = cube
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mesh.material_override = mat
    body.add_child(mesh)
    if solid:
        var collider := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        collider.shape = shape
        body.add_child(collider)
    add_child(body)

func _build_city() -> void:
    _box(Vector3(0,-0.5,0), Vector3(240,1,240), Color(0.64,0.58,0.46))
    add_child(districts)
    _build_pedestrians()
    _box(Vector3(0,0.02,0),Vector3(15,0.04,230),Color(0.19,0.2,0.21),false)
    _box(Vector3(0,0.03,0),Vector3(230,0.04,15),Color(0.19,0.2,0.21),false)
    for i in range(-5, 6):
        _box(Vector3(0, 0.065, i * 19), Vector3(0.18, 0.015, 4), Color(0.94, 0.75, 0.37), false)
        _box(Vector3(i * 19, 0.065, 0), Vector3(4, 0.015, 0.18), Color(0.94, 0.75, 0.37), false)
    for side in [-1, 1]:
        _box(Vector3(side * 8.5, 0.05, 0), Vector3(2, 0.1, 220), Color(0.81, 0.72, 0.58))
    for x in range(-3, 4):
        var awning_color := Color(0.17, 0.40, 0.33) if x % 2 == 0 else Color(0.63, 0.24, 0.18)
        _box(Vector3(10, 2.7, x * 4.5), Vector3(2.7, 0.22, 3.2), awning_color, false)
        _box(Vector3(11, 1.2, x * 4.5), Vector3(1.1, 2.4, 3), Color(0.63, 0.51, 0.37))
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50,-35,0)
    sun.light_energy = 1.5
    add_child(sun)
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color(0.55,0.74,0.89)
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color(0.75,0.8,0.9)
    e.ambient_light_energy = 0.6
    env.environment = e
    add_child(env)

func _build_pedestrians() -> void:
    pedestrians = Node3D.new()
    pedestrians.name = "MarketPedestrians"
    add_child(pedestrians)
    var colors := [Color(0.63, 0.31, 0.23), Color(0.26, 0.39, 0.52), Color(0.50, 0.42, 0.25)]
    for index in range(3):
        var side := -1 if index == 1 else 1
        var from := Vector3(side * 8.45, 0.93, 8 + index * 12)
        var to := from + Vector3(0, 0, 8)
        var pedestrian := preload("res://scripts/market_pedestrian.gd").new()
        pedestrian.configure(from, to, colors[index], float(index) * 0.4)
        pedestrians.add_child(pedestrian)

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.position = SPAWN
    player.collision_mask = 3
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.4
    capsule.height = 1.8
    collision.shape = capsule
    player.add_child(collision)
    var mesh := MeshInstance3D.new()
    var model := CapsuleMesh.new()
    model.radius = 0.4
    model.height = 1.8
    mesh.mesh = model
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.15,0.3,0.6)
    mesh.material_override = mat
    player.add_child(mesh)
    add_child(player)
    camera = Camera3D.new()
    camera.current = true
    add_child(camera)

func _build_car() -> void:
    car = preload("res://scenes/market_car.tscn").instantiate()
    car.position = CAR_SPAWN
    add_child(car)

func _build_ui() -> void:
    var ui := CanvasLayer.new()
    add_child(ui)
    var overlay := Control.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(overlay)
    hud = Label.new()
    hud.layout_direction = Control.LAYOUT_DIRECTION_RTL
    hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    hud.offset_left = -660
    hud.offset_right = -24
    hud.offset_top = 20
    hud.add_theme_font_size_override("font_size", 28)
    hud.add_theme_constant_override("outline_size", 8)
    overlay.add_child(hud)
    minimap.position = Vector2(24, 24)
    minimap.size = Vector2(128, 128)
    minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(minimap)
    _button(overlay, "تفاعل", Vector2(-150, -100)).pressed.connect(_request_interaction)
    _button(overlay, "قفز", Vector2(-288, -100)).pressed.connect(_jump)
    var brake := _button(overlay, "فرامل", Vector2(-426, -100))
    brake.button_down.connect(func() -> void: braking = true)
    brake.button_up.connect(func() -> void: braking = false)
    _button(overlay, "حفظ", Vector2(-150, -187)).pressed.connect(_save_with_feedback)

func _button(parent: Control, label: String, offset: Vector2) -> Button:
    var button := Button.new()
    button.text = label
    button.focus_mode = Control.FOCUS_NONE
    button.add_theme_font_size_override("font_size", 24)
    button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    button.offset_left = offset.x
    button.offset_top = offset.y
    button.offset_right = offset.x + 124
    button.offset_bottom = offset.y + 72
    parent.add_child(button)
    return button

func _build_marker() -> void:
    marker = MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 1.5
    mesh.bottom_radius = 1.5
    mesh.height = 0.1
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color(0.98, 0.72, 0.30)
    marker.mesh = mesh
    marker.material_override = material
    add_child(marker)

func _refresh_ui(message := "") -> void:
    var objective := "تسلّم الطلب عند العلامة"
    marker.position = PICKUP + Vector3.UP * 0.13
    if missions.active_mission == JOB:
        objective = "سلّم الطلب عند العلامة شمال السوق"
        marker.position = DELIVERY + Vector3.UP * 0.13
    elif state.completed_missions.has(JOB):
        objective = "متجر الملابس عند العلامة"
        marker.position = SHOP + Vector3.UP * 0.13
    if driving:
        objective += " · قيادة"
    hud.text = "سوق حلب  |  الرصيد %d  |  المطلوبية %d/5\n%s" % [state.money, state.wanted_level, objective]
    if not message.is_empty():
        hud.text += "\n" + message

func _request_interaction() -> void:
    interact_requested = true

func _interact() -> void:
    if driving:
        if absf(car.forward_speed) > 1.5:
            _refresh_ui("أوقف السيارة قبل النزول")
            return
        var exit_position := car.global_position + car.global_basis.x * 2.2 + Vector3.UP * 0.4
        var probe := PhysicsShapeQueryParameters3D.new()
        probe.shape = player.get_child(0).shape
        probe.collision_mask = 3
        probe.transform = Transform3D(Basis.IDENTITY, exit_position)
        if not get_world_3d().direct_space_state.intersect_shape(probe, 1).is_empty():
            _refresh_ui("اترك مساحة بجانب السيارة")
            return
        car.exit_vehicle()
        driving = false
        player.global_position = exit_position
        player.velocity = Vector3.ZERO
        player.show()
        player.collision_layer = 1
        player.collision_mask = 3
    elif player.position.distance_to(PICKUP) < 3.0 and not state.completed_missions.has(JOB):
        if missions.start_mission(JOB, 1, 150):
            _save()
    elif player.position.distance_to(DELIVERY) < 3.0 and missions.active_mission == JOB:
        if missions.advance() and missions.claim(state):
            _save()
            _refresh_ui("وصل الطلب · المكافأة 150")
            return
    elif player.position.distance_to(SHOP) < 3.0:
        if state.outfit_id == "market":
            _refresh_ui("ملابس السوق مجهّزة")
            return
        if not state.spend_money(50):
            _refresh_ui("سعر ملابس السوق 50")
            return
        state.set_outfit("market")
        _apply_outfit()
        _save()
    elif player.position.distance_to(car.position) < 3.6:
        driving = true
        car.enter_vehicle()
        player.hide()
        player.collision_layer = 0
        player.collision_mask = 0
    _refresh_ui()

func _apply_outfit() -> void:
    var mesh := player.get_child(1) as MeshInstance3D
    var material := mesh.material_override as StandardMaterial3D
    material.albedo_color = Color(0.20, 0.43, 0.34) if state.outfit_id == "market" else Color(0.15, 0.3, 0.6)

func _save_with_feedback() -> void:
    _refresh_ui("تم الحفظ" if _save() else "تعذّر الحفظ")

func _save() -> bool:
    var location := car.position if driving else player.position
    var data := state.to_dict()
    data["position"] = [location.x, location.y, location.z]
    data["car_position"] = [car.position.x, car.position.y, car.position.z]
    data["car_yaw"] = car.rotation.y
    data["driving"] = driving
    data["delivery_active"] = missions.active_mission == JOB
    return ShamSaveSystem.save_game(data)

func _position_from_save(value: Variant, fallback: Vector3) -> Vector3:
    if value is Array and value.size() == 3:
        for component in value:
            if not (component is float or component is int) or not is_finite(float(component)):
                return fallback
        var position := Vector3(value[0], value[1], value[2])
        if absf(position.x) < 114 and absf(position.z) < 114 and position.y >= 0 and position.y < 40:
            return position
    return fallback

func _restore() -> void:
    var data := ShamSaveSystem.load_game()
    state.restore(data)
    _apply_outfit()
    player.position = _position_from_save(data.get("position"), SPAWN)
    car.position = _position_from_save(data.get("car_position"), CAR_SPAWN)
    var saved_yaw: Variant = data.get("car_yaw", 0)
    if (saved_yaw is float or saved_yaw is int) and is_finite(float(saved_yaw)):
        car.rotation.y = float(saved_yaw)
    if data.get("driving") == true:
        driving = true
        car.enter_vehicle()
        player.hide()
        player.collision_layer = 0
        player.collision_mask = 0
    if data.get("delivery_active") == true and not state.completed_missions.has(JOB):
        missions.start_mission(JOB, 1, 150)

func _jump() -> void:
    if not driving and player.is_on_floor():
        player.velocity.y = JUMP_SPEED

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
        touch_id = -1
        look_id = -1
        stick = Vector2.ZERO
        braking = false
    if what == NOTIFICATION_APPLICATION_PAUSED and is_node_ready():
        _save()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.physical_keycode:
            KEY_E:
                _request_interaction()
            KEY_SPACE:
                _jump()
            KEY_F5:
                _save_with_feedback()
    elif event is InputEventScreenTouch:
        if event.pressed:
            if event.position.x < get_viewport().get_visible_rect().size.x * 0.5:
                if touch_id == -1:
                    touch_id = event.index
                    touch_start = event.position
            elif look_id == -1:
                look_id = event.index
        elif event.index == touch_id:
            touch_id = -1
            stick = Vector2.ZERO
        elif event.index == look_id:
            look_id = -1
    elif event is InputEventScreenDrag:
        if event.index == touch_id:
            stick = (event.position - touch_start).limit_length(95) / 95.0
        elif event.index == look_id:
            _orbit(event.relative)
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        _orbit(event.relative)

func _orbit(relative: Vector2) -> void:
    yaw = wrapf(yaw - relative.x * 0.008, -PI, PI)
    pitch = clampf(pitch - relative.y * 0.006, 0.14, 0.95)

func _physics_process(delta: float) -> void:
    if interact_requested:
        interact_requested = false
        _interact()
    var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    if stick.length() > 0.1:
        input_dir = stick
    if driving:
        car.set_mobile_controls(-input_dir.y, input_dir.x, braking or Input.is_physical_key_pressed(KEY_SPACE))
        if car.position.y < -8:
            car.position = CAR_SPAWN
            car.velocity = Vector3.ZERO
            car.forward_speed = 0.0
    else:
        var direction := Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, yaw)
        var running := Input.is_physical_key_pressed(KEY_SHIFT) or stick.length() > 0.9
        var speed := SPEED * (1.55 if running else 1.0)
        player.velocity.x = direction.x * speed
        player.velocity.z = direction.z * speed
        if not player.is_on_floor():
            player.velocity.y -= GRAVITY * delta
        player.move_and_slide()
        if direction.length() > 0.1:
            player.rotation.y = atan2(-direction.x, -direction.z)
        if player.position.y < -8:
            player.position = SPAWN
            player.velocity = Vector3.ZERO
    var actor_position := car.position if driving else player.position
    districts.update_focus(actor_position)
    minimap.update_positions(actor_position, marker.position)
    road_response.tick(delta, car, actor_position, state)
    var focus := actor_position + Vector3.UP * 0.95
    var heading := yaw + (car.rotation.y if driving else 0.0)
    var offset := Vector3(0, sin(pitch), cos(pitch)).rotated(Vector3.UP, heading)
    var target := focus + offset * (10.0 if driving else 7.0)
    var query := PhysicsRayQueryParameters3D.create(focus, target, 1, [player.get_rid(), car.get_rid()])
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        target = hit.position - offset * 0.18
    camera.position = target if not hit.is_empty() else camera.position.lerp(target, 1.0 - exp(-delta * 12.0))
    camera.look_at(focus)
