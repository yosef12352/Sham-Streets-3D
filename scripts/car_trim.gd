extends Node3D

func _ready() -> void:
    var car := get_parent() as Node3D
    var hood := car.get_node("Body") as MeshInstance3D
    var cabin := car.get_node("Cab") as MeshInstance3D
    var original_body := hood.mesh as BoxMesh
    var original_glass := cabin.mesh as BoxMesh
    hood.mesh = _shell([
        Vector4(-2.02, 0.76, -0.31, 0.15), Vector4(-1.65, 0.91, -0.33, 0.30),
        Vector4(1.62, 0.91, -0.33, 0.32), Vector4(2.02, 0.79, -0.30, 0.20)
    ], original_body.material)
    cabin.position.y = 0.0
    cabin.mesh = _shell([
        Vector4(-1.18, 0.76, 0.28, 0.30), Vector4(-0.55, 0.65, 0.28, 0.82),
        Vector4(0.65, 0.65, 0.28, 0.82), Vector4(1.46, 0.75, 0.28, 0.34)
    ], original_glass.material)
    for side in [-1, 1]:
        _box(self, Vector3(side * 0.53, 0.13, -2.0), Vector3(0.40, 0.17, 0.08), Color("#fff4c9"))
        _box(self, Vector3(side * 0.58, 0.14, 2.0), Vector3(0.35, 0.17, 0.08), Color("#a63224"))
        _box(self, Vector3(side * 0.84, 0.49, -0.58), Vector3(0.24, 0.13, 0.18), Color("#343e42"))
    _box(self, Vector3(0, -0.06, -2.04), Vector3(0.63, 0.15, 0.08), Color("#23292b"))
    _box(self, Vector3(0, -0.03, 2.04), Vector3(0.35, 0.11, 0.08), Color("#ded4ba"))
    for wheel_name in ["WheelFL", "WheelFR", "WheelRL", "WheelRR"]:
        var wheel := car.get_node(wheel_name) as MeshInstance3D
        var hub := MeshInstance3D.new()
        var drum := CylinderMesh.new()
        drum.top_radius = 0.19
        drum.bottom_radius = 0.19
        drum.height = 0.255
        drum.radial_segments = 12
        drum.material = _material(Color("#85878a"))
        hub.mesh = drum
        wheel.add_child(hub)

func _shell(sections: Array, material: Material) -> ArrayMesh:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    surface.set_material(material)
    var previous := PackedVector3Array()
    for entry: Vector4 in sections:
        var current := PackedVector3Array([
            Vector3(-entry.y, entry.z, entry.x), Vector3(-entry.y * 0.92, entry.w, entry.x),
            Vector3(entry.y * 0.92, entry.w, entry.x), Vector3(entry.y, entry.z, entry.x)
        ])
        if previous.is_empty():
            _face(surface, current[0], current[1], current[2], current[3])
        else:
            for side in range(4):
                var next := (side + 1) % 4
                _face(surface, previous[side], current[side], current[next], previous[next])
        previous = current
    _face(surface, previous[3], previous[2], previous[1], previous[0])
    surface.generate_normals()
    return surface.commit()

func _face(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
    for point in [a, b, c, a, c, d]:
        surface.add_vertex(point)

func _box(parent: Node3D, location: Vector3, dimensions: Vector3, color: Color) -> void:
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    mesh.material = _material(color)
    var part := MeshInstance3D.new()
    part.mesh = mesh
    part.position = location
    parent.add_child(part)

func _material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.52
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    return material
