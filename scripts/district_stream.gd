extends Node3D

const BLOCK_DISTANCE := 22.0
const LOAD_RADIUS := 57.0
const UNLOAD_RADIUS := 70.0
const UPDATE_DISTANCE := 4.0

var blocks: Dictionary = {}
var last_focus := Vector3(INF, 0, INF)
var limestone := ShaderMaterial.new()
var trim := StandardMaterial3D.new()
var window_mesh := BoxMesh.new()
var frame_mesh := BoxMesh.new()

func _ready() -> void:
    limestone.shader = preload("res://assets/materials/street_surface.gdshader")
    limestone.set_shader_parameter("base", Color("#bca489"))
    limestone.set_shader_parameter("surface_kind", 2)
    trim.albedo_color = Color(0.48, 0.37, 0.28)
    var glass := StandardMaterial3D.new()
    glass.albedo_color = Color("#535d5b")
    glass.roughness = 0.43
    window_mesh.material = glass
    window_mesh.size = Vector3(1.18, 1.42, 0.15)
    frame_mesh.size = Vector3(1.43, 1.65, 0.14)
    frame_mesh.material = trim

func update_focus(focus: Vector3) -> void:
    focus.y = 0
    if focus.distance_squared_to(last_focus) < UPDATE_DISTANCE * UPDATE_DISTANCE:
        return
    last_focus = focus
    for x in range(-4, 5):
        for z in range(-4, 5):
            if x == 0 or z == 0:
                continue
            var key := Vector2i(x, z)
            var location := Vector3(x * BLOCK_DISTANCE, 0, z * BLOCK_DISTANCE)
            var distance := focus.distance_squared_to(location)
            if blocks.has(key):
                if distance > UNLOAD_RADIUS * UNLOAD_RADIUS:
                    blocks[key].queue_free()
                    blocks.erase(key)
            elif distance < LOAD_RADIUS * LOAD_RADIUS:
                blocks[key] = _create_building(key, location)

func _create_building(key: Vector2i, location: Vector3) -> StaticBody3D:
    var height := float(7 + (abs(key.x * 7 + key.y * 11) % 5) * 3)
    var building := StaticBody3D.new()
    building.position = location
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(13, height + 0.5, 13)
    collision.position.y = shape.size.y * 0.5
    collision.shape = shape
    building.add_child(collision)
    _add_mesh(building, Vector3(13, height, 13), height * 0.5, limestone)
    _add_mesh(building, Vector3(14, 0.5, 14), height + 0.25, trim)
    _add_windows(building, floori(height / 3.0))
    add_child(building)
    return building

func _add_mesh(parent: Node3D, size: Vector3, elevation: float, material: Material) -> void:
    var instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh.material = material
    instance.mesh = mesh
    instance.position.y = elevation
    parent.add_child(instance)

func _add_windows(parent: Node3D, floors: int) -> void:
    var windows := MultiMesh.new()
    windows.transform_format = MultiMesh.TRANSFORM_3D
    windows.mesh = window_mesh
    windows.instance_count = floors * 12
    var frames := MultiMesh.new()
    frames.transform_format = MultiMesh.TRANSFORM_3D
    frames.mesh = frame_mesh
    frames.instance_count = windows.instance_count
    var index := 0
    for wall in range(4):
        var rotation := Basis(Vector3.UP, wall * PI * 0.5)
        for floor_index in range(floors):
            for column in [-3.5, 0.0, 3.5]:
                var location := rotation * Vector3(column, 1.8 + floor_index * 2.65, 6.54)
                frames.set_instance_transform(index, Transform3D(rotation, location))
                windows.set_instance_transform(index, Transform3D(rotation, location + rotation.z * 0.08))
                index += 1
    var renderer := MultiMeshInstance3D.new()
    renderer.multimesh = windows
    parent.add_child(renderer)
    var frames_renderer := MultiMeshInstance3D.new()
    frames_renderer.multimesh = frames
    parent.add_child(frames_renderer)
