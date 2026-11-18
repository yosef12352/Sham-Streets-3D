extends Node3D

const UI_FONT := preload("res://assets/fonts/DejaVuSans-UI.ttf")
const STREET_SURFACE := preload("res://assets/materials/street_surface.gdshader")
const CITY := preload("res://scripts/city_layout.gd")
const SPEED := 6.0
const JUMP_SPEED := 6.0
const GRAVITY := 18.0
var player: CharacterBody3D
var camera: Camera3D
var stick := Vector2.ZERO
var touch_start := Vector2.ZERO
var touch_id := -1
var yaw := 0.0
var pitch := 0.38
var zoom_scale := 1.0
var current_zoom := 1.0
var camera_fingers: Dictionary = {}
var camera_span := 0.0
var foot_buttons: Array[TouchScreenButton] = []
var car_buttons: Array[TouchScreenButton] = []
var action_button: TouchScreenButton
var movement_focus := Vector3(INF, 0, INF)
var car: ShamVehicleController
var districts := preload("res://scripts/district_stream.gd").new()
var pedestrians: Node3D
var road_response := preload("res://scripts/road_response.gd").new()
var state := ShamGameState.new()
var missions := ShamMissionManager.new()
var hud: Label
const MAP_VIEW := preload("res://scripts/market_map.gd")
var minimap := MAP_VIEW.new()
var district_map := MAP_VIEW.new()
var navigation := -1
var current_district := 0
var map_layer: Control
var gameplay_ui: Control
var marker: MeshInstance3D
var driving := false
var braking := false
var person := preload("res://scripts/person_model.gd").new()
var sounds := preload("res://scripts/street_audio.gd").new()
var action_cooldown := 0.0
var step_delay := 0.0
var rounds := 8
var reserve := 24
var action_requested := ""
var last_action := ""
var pad_touches: Dictionary = {}
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
    add_child(sounds)
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

func _box(pos: Vector3, size: Vector3, color: Color, solid: bool = true, material: Material = null) -> void:
    var body := StaticBody3D.new()
    body.position = pos
    var mesh := MeshInstance3D.new()
    var cube := BoxMesh.new()
    cube.size = size
    mesh.mesh = cube
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mesh.material_override = material if material != null else mat
    body.add_child(mesh)
    if solid:
        var collider := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        collider.shape = shape
        body.add_child(collider)
    add_child(body)

func _build_city() -> void:
    _box(Vector3(0,-0.5,0), Vector3(CITY.HALF_SIZE * 2, 1, CITY.HALF_SIZE * 2), Color(0.64,0.58,0.46))
    add_child(districts)
    _build_pedestrians()
    _build_district_signs()
    var asphalt := _street_surface(Color("#555557"), 0)
    var paving := _street_surface(Color("#bdab90"), 1)
    var shop_stone := _street_surface(Color("#ae9171"), 2)
    for center: float in CITY.ROAD_CENTERS:
        _box(Vector3(center, 0.02, 0), Vector3(15, 0.04, 350), Color.WHITE, false, asphalt)
        _box(Vector3(0, 0.03, center), Vector3(350, 0.04, 15), Color.WHITE, false, asphalt)
    _build_park(paving)
    for i in range(-16, 17):
        if i in [-11, 0, 11]:
            continue
        _box(Vector3(0, 0.065, i * 10), Vector3(0.13, 0.015, 3), Color("#decf92"), false)
        _box(Vector3(i * 10, 0.065, 0), Vector3(3, 0.015, 0.13), Color("#decf92"), false)
    for side in [-1, 1]:
        for center_z in [-147.0, -55.0, 55.0, 147.0]:
            var length := 56.0 if absf(center_z) > 100 else 94.0
            for road_x: float in CITY.ROAD_CENTERS:
                _box(Vector3(road_x + side * 8.5, 0.05, center_z), Vector3(2, 0.1, length), Color.WHITE, true, paving)
        for zebra in range(6):
            _box(Vector3(-4.8 + zebra * 1.9, 0.066, side * 7.8), Vector3(0.72, 0.012, 2.9), Color("#d7d2bd"), false)
    for stall in range(-3, 5):
        if stall in [-2, -1, 0, 1]:
            continue
        _build_shop(stall * 4.5, stall, shop_stone)
    for z in [-51, -25, 14, 31, 55]:
        _street_lamp(Vector3(-9.2, 0.10, z))
    _street_lamp(Vector3(9.2, 0.10, -36))
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-38, -31, 0)
    sun.light_color = Color("#fff1d8")
    sun.light_energy = 1.18
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 50.0
    add_child(sun)
    var env := WorldEnvironment.new()
    var e := Environment.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color("#7195b7")
    sky_material.sky_horizon_color = Color("#c8c5b2")
    sky_material.ground_horizon_color = Color("#c8c5b2")
    var atmosphere := Sky.new()
    atmosphere.sky_material = sky_material
    e.background_mode = Environment.BG_SKY
    e.sky = atmosphere
    e.fog_enabled = true
    e.fog_light_color = Color("#c3bba7")
    e.fog_density = 0.006
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color(0.75,0.8,0.9)
    e.ambient_light_energy = 0.67
    env.environment = e
    add_child(env)

func _build_district_signs() -> void:
    for district: Dictionary in CITY.DISTRICTS:
        var district_entry: Vector3 = district.point
        if district.name == "حيدرية":
            district_entry.z = -12.0
        var edge := district_entry + Vector3(6.4, 0, 0)
        var metal := Color("#353f3c")
        for side in [-1, 1]:
            _box(edge + Vector3(side * 0.96, 1.57, 0), Vector3(0.11, 3.14, 0.11), metal, false)
        _box(edge + Vector3(0, 2.78, 0), Vector3(3.15, 0.85, 0.17), district.color.darkened(0.64), false)
        for face in [-1, 1]:
            var title := Label3D.new()
            title.font = UI_FONT
            title.text = "حلب  " + district.name
            title.font_size = 50
            title.pixel_size = 0.009
            title.outline_size = 3
            title.modulate = Color("#fff1d1")
            title.rotation.y = (face + 1) * PI * 0.5
            title.position = edge + Vector3(0, 2.78, -face * 0.11)
            add_child(title)

func _build_park(paving: Material) -> void:
    var center: Vector3 = CITY.PARK + Vector3(-11, 0, -11)
    _box(center + Vector3(0, 0.025, 0), Vector3(37, 0.05, 37), Color("#626c49"), false)
    _box(center + Vector3(0, 0.043, 0), Vector3(37, 0.04, 3.2), Color.WHITE, false, paving)
    _box(center + Vector3(0, 0.045, 0), Vector3(3.2, 0.04, 37), Color.WHITE, false, paving)
    for x in [-13, -6, 6, 13]:
        for z in [-13, -6, 6, 13]:
            var location := center + Vector3(x, 0, z)
            _box(location + Vector3.UP * 0.83, Vector3(0.22, 1.65, 0.22), Color("#69543c"), true)
            var leaves := MeshInstance3D.new()
            var canopy := SphereMesh.new()
            canopy.radius = 1.42
            canopy.height = 2.7
            canopy.radial_segments = 8
            canopy.rings = 5
            var material := StandardMaterial3D.new()
            material.albedo_color = Color("#485738").lightened(float(abs(x + z) % 8) * 0.025)
            canopy.material = material
            leaves.mesh = canopy
            leaves.position = location + Vector3.UP * 2.5
            add_child(leaves)

func _street_surface(color: Color, kind: int) -> ShaderMaterial:
    var material := ShaderMaterial.new()
    material.shader = STREET_SURFACE
    material.set_shader_parameter("base", color)
    material.set_shader_parameter("surface_kind", kind)
    return material

func _build_shop(z: float, index: int, stone: Material) -> void:
    var canvas := Color("#53756b") if index % 2 == 0 else Color("#985746")
    _box(Vector3(11.05, 1.55, z), Vector3(1.15, 3.1, 3.7), Color.WHITE, true, stone)
    _box(Vector3(10.44, 1.12, z), Vector3(0.08, 2.05, 2.9), Color("#343732"), false)
    _box(Vector3(10.39, 1.74, z), Vector3(0.08, 0.10, 2.94), Color("#a09274"), false)
    for side in [-1, 0, 1]:
        _box(Vector3(10.38, 1.15, z + side * 1.43), Vector3(0.10, 2.15, 0.09), Color("#88775f"), false)
    _box(Vector3(9.95, 2.45, z), Vector3(1.65, 0.14, 3.72), canvas, false)
    _box(Vector3(9.15, 2.37, z), Vector3(0.09, 0.23, 3.75), canvas.darkened(0.15), false)
    var signboard := Label3D.new()
    signboard.font = UI_FONT
    signboard.text = "بقالة السوق" if index % 2 == 0 else "أقمشة حلب"
    signboard.font_size = 44
    signboard.pixel_size = 0.009
    signboard.modulate = Color("#f4ddad")
    signboard.outline_size = 5
    signboard.position = Vector3(10.40, 2.80, z)
    signboard.rotation.y = -PI * 0.5
    add_child(signboard)

func _street_lamp(at: Vector3) -> void:
    var steel := Color("#474943")
    _box(at + Vector3(0, 1.9, 0), Vector3(0.10, 3.8, 0.10), steel, false)
    _box(at + Vector3(0, 0.19, 0), Vector3(0.28, 0.38, 0.28), steel, false)
    var side := -signf(at.x)
    _box(at + Vector3(side * 0.42, 3.82, 0), Vector3(0.90, 0.09, 0.10), steel, false)
    _box(at + Vector3(side * 0.82, 3.77, 0), Vector3(0.37, 0.12, 0.23), Color("#d5c8a8"), false)

func _build_pedestrians() -> void:
    pedestrians = Node3D.new()
    pedestrians.name = "MarketPedestrians"
    add_child(pedestrians)
    var colors := [Color(0.63, 0.31, 0.23), Color(0.26, 0.39, 0.52), Color(0.50, 0.42, 0.25)]
    for index in range(32):
        var side := -1 if index % 2 == 1 else 1
        var from := Vector3(side * 8.45, 0.93, 8 + (index / 2) * 12)
        if index >= 24:
            from = Vector3(110 + side * 8.45, 0.93, -88 + ((index - 24) / 2) * 16)
        elif index >= 12:
            from = Vector3(-110 + side * 8.45, 0.93, -91 + ((index - 12) / 2) * 13)
        var to := from + Vector3(0, 0, 8)
        var pedestrian := preload("res://scripts/market_pedestrian.gd").new()
        pedestrian.configure(from, to, colors[index % colors.size()], float(index % 4) * 0.28)
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
    person.build(Color("#29465a"), Color("#c99472"), Color("#363c45"))
    person.equip_launcher()
    player.add_child(person)
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
    gameplay_ui = overlay
    hud = Label.new()
    hud.text_direction = Control.TEXT_DIRECTION_RTL
    hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    hud.offset_left = -660
    hud.offset_right = -24
    hud.offset_top = 20
    hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hud.add_theme_font_override("font", UI_FONT)
    hud.add_theme_font_size_override("font_size", 25)
    hud.add_theme_constant_override("outline_size", 8)
    overlay.add_child(hud)
    minimap.position = Vector2(24, 24)
    minimap.size = Vector2(168, 168)
    minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(minimap)
    _touch_action(overlay, "الخريطة", Vector2(24, 200), func() -> void: _toggle_map(), Vector2(168, 50))
    _build_map_panel(ui)
    action_button = _touch_action(overlay, "تفاعل / ركوب", Vector2(1110, 620), _request_interaction, Vector2(146, 68), true)
    foot_buttons.append(_touch_action(overlay, "ضرب", Vector2(1110, 542), func() -> void: action_requested = "strike", Vector2(146, 68)))
    foot_buttons.append(_touch_action(overlay, "إطلاق", Vector2(976, 542), func() -> void: action_requested = "pulse"))
    foot_buttons.append(_touch_action(overlay, "تلقيم", Vector2(842, 542), func() -> void: action_requested = "reload"))
    foot_buttons.append(_touch_action(overlay, "قفز", Vector2(976, 620), _jump))
    car_buttons.append(_touch_action(overlay, "بوق", Vector2(842, 620), func() -> void: action_requested = "horn"))
    var brake := _touch_action(overlay, "فرامل", Vector2(976, 620), func() -> void: braking = true)
    brake.released.connect(func() -> void: braking = false)
    car_buttons.append(brake)
    _button(overlay, "حفظ", Vector2(-148, -324)).pressed.connect(_save_with_feedback)
    _touch_action(overlay, "+ تقريب", Vector2(1112, 468), func() -> void: _adjust_zoom(-0.15), Vector2(144, 56))
    _touch_action(overlay, "- إبعاد", Vector2(958, 468), func() -> void: _adjust_zoom(0.15), Vector2(144, 56))
    _movement_button(overlay, "▲", Vector2(105, 510), Vector2.UP)
    _movement_button(overlay, "▼", Vector2(105, 620), Vector2.DOWN)
    _movement_button(overlay, "◀", Vector2(22, 565), Vector2.LEFT)
    _movement_button(overlay, "▶", Vector2(188, 565), Vector2.RIGHT)

func _build_map_panel(layer: CanvasLayer) -> void:
    map_layer = ColorRect.new()
    (map_layer as ColorRect).color = Color("#101a1cef")
    map_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.add_child(map_layer)
    district_map.expanded = true
    district_map.position = Vector2(65, 70)
    district_map.size = Vector2(570, 570)
    district_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
    map_layer.add_child(district_map)
    var actions := VBoxContainer.new()
    actions.position = Vector2(715, 125)
    actions.custom_minimum_size.x = 475
    actions.add_theme_constant_override("separation", 12)
    map_layer.add_child(actions)
    var title := Label.new()
    title.text = "خريطة أحياء حلب"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    title.add_theme_font_override("font", UI_FONT)
    title.add_theme_font_size_override("font_size", 40)
    actions.add_child(title)
    for index in range(CITY.DISTRICTS.size()):
        _map_button(actions, CITY.DISTRICTS[index].name, _select_district.bind(index))
    _map_button(actions, "إزالة المسار", _select_district.bind(-1))
    _map_button(actions, "رجوع للعبة", _toggle_map)
    map_layer.hide()

func _map_button(parent: Control, title: String, callback: Callable) -> void:
    var button := Button.new()
    button.text = title
    button.focus_mode = Control.FOCUS_NONE
    button.custom_minimum_size.y = 50
    button.add_theme_font_override("font", UI_FONT)
    button.add_theme_font_size_override("font_size", 24)
    button.pressed.connect(callback)
    parent.add_child(button)

func _select_district(index: int) -> void:
    navigation = index
    district_map.set_navigation(index)
    minimap.set_navigation(index)
    _toggle_map()
    _refresh_ui()

func _toggle_map() -> void:
    map_layer.visible = not map_layer.visible
    gameplay_ui.visible = not map_layer.visible
    stick = Vector2.ZERO
    touch_id = -1
    camera_fingers.clear()
    camera_span = 0.0
    pad_touches.clear()
    braking = false
    action_requested = ""
    interact_requested = false

func _movement_button(parent: Control, title: String, location: Vector2, direction: Vector2) -> void:
    var button := _touch_action(parent, title, location, func() -> void: pad_touches[direction] = true, Vector2(72, 60))
    button.released.connect(func() -> void: pad_touches.erase(direction))

func _touch_action(parent: Control, title: String, location: Vector2, callback: Callable, extent := Vector2(124, 68), primary := false) -> TouchScreenButton:
    var button := TouchScreenButton.new()
    button.position = location
    button.texture_normal = _button_texture(extent, Color("#233336ed") if not primary else Color("#355551f5"))
    button.texture_pressed = _button_texture(extent, Color("#53695ced"))
    var label := Label.new()
    label.name = "Caption"
    label.text = title
    label.size = extent
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_override("font", UI_FONT)
    label.add_theme_font_size_override("font_size", 22)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(label)
    button.pressed.connect(callback)
    parent.add_child(button)
    return button

func _button_texture(extent: Vector2, fill: Color) -> ImageTexture:
    var image := Image.create(int(extent.x), int(extent.y), false, Image.FORMAT_RGBA8)
    var radius := 13.0
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            var position := Vector2(x + 0.5, y + 0.5)
            var corner := position.clamp(Vector2.ONE * radius, extent - Vector2.ONE * radius)
            var distance := (position - corner).length()
            if distance < radius:
                var shade := fill.lightened(0.33) if distance > radius - 1.7 else fill
                image.set_pixel(x, y, shade)
    return ImageTexture.create_from_image(image)

func _button(parent: Control, label: String, offset: Vector2) -> Button:
    var button := Button.new()
    button.text = label
    button.add_theme_font_override("font", UI_FONT)
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
    for button in foot_buttons:
        button.visible = not driving
    for button in car_buttons:
        button.visible = driving
    (action_button.get_node("Caption") as Label).text = "نزول" if driving else "تفاعل / ركوب"
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
    else:
        objective += " · ذخيرة %d / %d" % [rounds, reserve]
    hud.text = "حلب · %s  |  الرصيد %d  |  المطلوبية %d/5\n%s" % [CITY.DISTRICTS[current_district].name, state.money, state.wanted_level, objective]
    if navigation >= 0:
        hud.text += "\nالوجهة · " + CITY.DISTRICTS[navigation].name
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
    person.top.albedo_color = Color(0.20, 0.43, 0.34) if state.outfit_id == "market" else Color(0.15, 0.3, 0.6)

func _save_with_feedback() -> void:
    _refresh_ui("تم الحفظ" if _save() else "تعذّر الحفظ")

func _save() -> bool:
    var location := car.position if driving else player.position
    var data := state.to_dict()
    data["position"] = [location.x, location.y, location.z]
    data["car_position"] = [car.position.x, car.position.y, car.position.z]
    data["car_yaw"] = car.rotation.y
    data["driving"] = driving
    data["rounds"] = rounds
    data["reserve"] = reserve
    data["delivery_active"] = missions.active_mission == JOB
    return ShamSaveSystem.save_game(data)

func _position_from_save(value: Variant, fallback: Vector3) -> Vector3:
    if value is Array and value.size() == 3:
        for component in value:
            if not (component is float or component is int) or not is_finite(float(component)):
                return fallback
        var position := Vector3(value[0], value[1], value[2])
        if absf(position.x) < CITY.HALF_SIZE - 1 and absf(position.z) < CITY.HALF_SIZE - 1 and position.y >= 0 and position.y < 40:
            return position
    return fallback

func _restore() -> void:
    var data := ShamSaveSystem.load_game()
    state.restore(data)
    rounds = clampi(int(data.get("rounds", 8)), 0, 8)
    reserve = clampi(int(data.get("reserve", 24)), 0, 24)
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
        camera_fingers.clear()
        camera_span = 0.0
        stick = Vector2.ZERO
        braking = false
        pad_touches.clear()
    if what == NOTIFICATION_APPLICATION_PAUSED and is_node_ready():
        _save()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_M, KEY_ESCAPE]:
        if event.physical_keycode == KEY_M or map_layer.visible:
            _toggle_map()
        return
    if map_layer.visible:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        match event.physical_keycode:
            KEY_EQUAL, KEY_KP_ADD:
                _adjust_zoom(-0.15)
            KEY_MINUS, KEY_KP_SUBTRACT:
                _adjust_zoom(0.15)
            KEY_F:
                action_requested = "strike"
            KEY_G:
                action_requested = "pulse"
            KEY_R:
                action_requested = "reload"
            KEY_H:
                action_requested = "horn"
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
            elif camera_fingers.size() < 2:
                camera_fingers[event.index] = event.position
                camera_span = _finger_span()
        elif event.index == touch_id:
            touch_id = -1
            stick = Vector2.ZERO
        elif camera_fingers.has(event.index):
            camera_fingers.erase(event.index)
            camera_span = 0.0
    elif event is InputEventScreenDrag:
        if event.index == touch_id:
            stick = (event.position - touch_start).limit_length(95) / 95.0
        elif camera_fingers.has(event.index):
            camera_fingers[event.index] = event.position
            if camera_fingers.size() == 2:
                var span := _finger_span()
                if camera_span > 12.0 and span > 12.0:
                    zoom_scale = clampf(zoom_scale * camera_span / span, 0.48, 1.9)
                camera_span = span
            else:
                _orbit(event.relative)
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _adjust_zoom(-0.15)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _adjust_zoom(0.15)
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        _orbit(event.relative)

func _finger_span() -> float:
    if camera_fingers.size() != 2:
        return 0.0
    var locations := camera_fingers.values()
    return locations[0].distance_to(locations[1])

func _adjust_zoom(amount: float) -> void:
    zoom_scale = clampf(zoom_scale + amount, 0.48, 1.9)

func _orbit(relative: Vector2) -> void:
    yaw = wrapf(yaw - relative.x * 0.008, -PI, PI)
    pitch = clampf(pitch - relative.y * 0.006, 0.14, 0.95)

func _physics_process(delta: float) -> void:
    if interact_requested:
        interact_requested = false
        _interact()
    var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    var letters := Vector2(
        float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
        float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
    )
    input_dir = (input_dir + letters).limit_length()
    for direction: Vector2 in pad_touches:
        input_dir += direction
    input_dir = input_dir.limit_length()
    if map_layer.visible:
        input_dir = Vector2.ZERO
    _update_actions(delta)
    sounds.set_engine(car.forward_speed, driving)
    if stick.length() > 0.1:
        input_dir = stick
    if driving:
        car.set_mobile_controls(-input_dir.y, input_dir.x, map_layer.visible or braking or Input.is_physical_key_pressed(KEY_SPACE))
        if car.position.y < -8:
            car.position = CAR_SPAWN
            car.velocity = Vector3.ZERO
            car.forward_speed = 0.0
    else:
        var direction := Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, yaw)
        var running := Input.is_physical_key_pressed(KEY_SHIFT) or stick.length() > 0.9
        var speed := SPEED * (1.55 if running else 1.0)
        var horizontal_velocity := Vector2(player.velocity.x, player.velocity.z)
        var desired_velocity := Vector2(direction.x, direction.z) * speed
        horizontal_velocity = horizontal_velocity.move_toward(desired_velocity, (23.0 if input_dir.length() > 0.08 else 34.0) * delta)
        player.velocity.x = horizontal_velocity.x
        player.velocity.z = horizontal_velocity.y
        if not player.is_on_floor():
            player.velocity.y -= GRAVITY * delta
        player.move_and_slide()
        var pace := Vector2(player.get_real_velocity().x, player.get_real_velocity().z).length()
        var aiming := last_action == "pulse" and action_cooldown > 0.0
        var strike := action_cooldown / 0.34 if last_action == "strike" else 0.0
        person.animate(delta, pace, player.is_on_floor(), strike, aiming)
        step_delay -= delta
        if pace > 0.9 and player.is_on_floor() and step_delay <= 0.0:
            sounds.play_effect("step", -22)
            step_delay = clampf(1.65 / pace, 0.19, 0.53)
        if direction.length() > 0.1 and not aiming:
            player.rotation.y = lerp_angle(player.rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-delta * 19.0))
        if player.position.y < -8:
            player.position = SPAWN
            player.velocity = Vector3.ZERO
    var actor_position := car.position if driving else player.position
    districts.update_focus(actor_position)
    if actor_position.distance_squared_to(movement_focus) > 25.0:
        movement_focus = actor_position
        for pedestrian in pedestrians.get_children():
            var near: bool = actor_position.distance_squared_to(pedestrian.position) < 65.0 * 65.0
            pedestrian.visible = near
            pedestrian.set_physics_process(near)
    var district := CITY.district_index(actor_position)
    if district != current_district:
        current_district = district
        _refresh_ui()
    var heading_on_map := (car if driving else player).rotation.y
    minimap.update_positions(actor_position, marker.position, heading_on_map)
    district_map.update_positions(actor_position, marker.position, heading_on_map)
    road_response.tick(delta, car, actor_position, state)
    var focus := actor_position + Vector3.UP * 0.95
    var heading := yaw + (car.rotation.y if driving else 0.0)
    var offset := Vector3(0, sin(pitch), cos(pitch)).rotated(Vector3.UP, heading)
    current_zoom = lerpf(current_zoom, zoom_scale, 1.0 - exp(-delta * 11.0))
    var target := focus + offset * (10.0 if driving else 7.0) * current_zoom
    var query := PhysicsRayQueryParameters3D.create(focus, target, 1, [player.get_rid(), car.get_rid()])
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        target = hit.position - offset * 0.18
    camera.position = target if not hit.is_empty() else camera.position.lerp(target, 1.0 - exp(-delta * 12.0))
    camera.look_at(focus)

func _update_actions(delta: float) -> void:
    action_cooldown = maxf(0.0, action_cooldown - delta)
    var action := action_requested
    action_requested = ""
    if action.is_empty() or action_cooldown > 0.0:
        return
    if driving:
        if action == "horn":
            sounds.play_effect("horn")
            action_cooldown = 0.5
        return
    last_action = action
    match action:
        "reload":
            var moved := mini(8 - rounds, reserve)
            if moved > 0:
                rounds += moved
                reserve -= moved
                sounds.play_effect("reload")
                action_cooldown = 0.6
        "pulse":
            if rounds == 0:
                _refresh_ui("المخزن فارغ · لقّم أولاً")
                return
            rounds -= 1
            action_cooldown = 0.40
            sounds.play_effect("pulse")
            player.rotation.y = yaw
            person.ready_aim()
            _react_to_action(11.0)
        "strike":
            action_cooldown = 0.34
            sounds.play_effect("strike")
            _react_to_action(1.7)
    _refresh_ui()

func _react_to_action(reach: float) -> void:
    var ranged := reach > 2.0
    var origin := person.muzzle.global_position if ranged else player.global_position
    var forward := -person.muzzle.global_basis.z if ranged else -player.global_basis.z
    var end := origin + forward * reach
    var query := PhysicsRayQueryParameters3D.create(origin, end, 3, [player.get_rid()])
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if ranged:
        _pulse_flash(origin, hit.get("position", end))
    if not hit.is_empty() and hit.collider.has_method("react"):
        hit.collider.react()
        state.set_wanted(state.wanted_level + 1)

func _pulse_flash(from: Vector3, to: Vector3) -> void:
    var beam := MeshInstance3D.new()
    var segment := CylinderMesh.new()
    segment.top_radius = 0.022
    segment.bottom_radius = 0.022
    segment.height = from.distance_to(to)
    segment.radial_segments = 5
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color("#ffc77a")
    segment.material = material
    beam.mesh = segment
    beam.position = from.lerp(to, 0.5)
    var axis := (to - from).normalized() if from.distance_squared_to(to) > 0.0001 else Vector3.UP
    beam.basis = Basis(Quaternion(Vector3.UP, axis))
    add_child(beam)
    var tween := beam.create_tween()
    tween.tween_interval(0.07)
    tween.tween_callback(beam.queue_free)
