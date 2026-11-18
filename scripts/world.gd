extends Node3D

const SPEED := 6.0
const JUMP_SPEED := 6.0
const GRAVITY := 18.0
var player: CharacterBody3D
var camera: Camera3D
var stick := Vector2.ZERO
var touch_start := Vector2.ZERO
var touch_id := -1

func _ready() -> void:
    _build_city()
    _build_player()
    _build_ui()

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
    for x in range(-4,5):
        for z in range(-4,5):
            if x == 0 or z == 0:
                continue
            var px := x * 22.0
            var pz := z * 22.0
            var height := float(7 + (abs(x * 7 + z * 11) % 5) * 3)
            _box(Vector3(px,height/2,pz),Vector3(13,height,13),Color(0.74,0.66,0.51))
            _box(Vector3(px,height+0.25,pz),Vector3(14,0.5,14),Color(0.48,0.37,0.28))
    _box(Vector3(0,0.02,0),Vector3(15,0.04,230),Color(0.19,0.2,0.21),false)
    _box(Vector3(0,0.03,0),Vector3(230,0.04,15),Color(0.19,0.2,0.21),false)
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

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.position = Vector3(0,2,0)
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

func _build_ui() -> void:
    var ui := CanvasLayer.new()
    add_child(ui)
    var title := Label.new()
    title.text = "شوارع الشام 3D | بناء أولي"
    title.position = Vector2(24,20)
    ui.add_child(title)
    var jump := Button.new()
    jump.text = "قفز"
    jump.position = Vector2(1100,570)
    jump.custom_minimum_size = Vector2(130,90)
    jump.pressed.connect(_jump)
    ui.add_child(jump)

func _jump() -> void:
    if player.is_on_floor():
        player.velocity.y = JUMP_SPEED

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and event.position.x < get_viewport().get_visible_rect().size.x * 0.5 and touch_id == -1:
            touch_id = event.index
            touch_start = event.position
        elif not event.pressed and event.index == touch_id:
            touch_id = -1
            stick = Vector2.ZERO
    elif event is InputEventScreenDrag and event.index == touch_id:
        stick = (event.position - touch_start).limit_length(100) / 100.0

func _physics_process(delta: float) -> void:
    var input_dir := Input.get_vector("ui_left","ui_right","ui_up","ui_down")
    if stick.length() > 0.1:
        input_dir = stick
    var direction := Vector3(input_dir.x,0,input_dir.y).normalized()
    player.velocity.x = direction.x * SPEED
    player.velocity.z = direction.z * SPEED
    if not player.is_on_floor():
        player.velocity.y -= GRAVITY * delta
    if Input.is_key_pressed(KEY_SPACE):
        _jump()
    player.move_and_slide()
    if direction.length() > 0.1:
        player.rotation.y = atan2(-direction.x,-direction.z)
    var target := player.global_position + Vector3(0,5,9)
    camera.global_position = camera.global_position.lerp(target,min(1.0,delta*5.0))
    camera.look_at(player.global_position + Vector3(0,1.1,0))
