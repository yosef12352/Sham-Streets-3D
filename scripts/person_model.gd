extends Node3D

var top := StandardMaterial3D.new()
var skin := StandardMaterial3D.new()
var pants := StandardMaterial3D.new()
var shoes := StandardMaterial3D.new()
var hair := StandardMaterial3D.new()
var shoulders: Array[Node3D] = []
var hips: Array[Node3D] = []
var gait := 0.0
var launcher: Node3D

func build(tint: Color, skin_tone: Color, trousers: Color) -> void:
    top.albedo_color = tint
    skin.albedo_color = skin_tone
    pants.albedo_color = trousers
    shoes.albedo_color = Color("#282625")
    hair.albedo_color = Color("#302823")
    _part(self, Vector3(0, 0.40, 0), Vector3(0.43, 0.56, 0.25), top)
    _part(self, Vector3(0, 0.10, 0), Vector3(0.34, 0.20, 0.24), pants)
    _part(self, Vector3(0, 0.77, -0.02), Vector3(0.24, 0.31, 0.24), skin)
    _part(self, Vector3(0, 0.88, 0.01), Vector3(0.25, 0.13, 0.24), hair)
    _part(self, Vector3(0, 0.66, 0), Vector3(0.13, 0.14, 0.13), skin)
    for side in [-1, 1]:
        var arm := _joint(Vector3(side * 0.245, 0.56, 0))
        shoulders.append(arm)
        _part(arm, Vector3(0, -0.17, 0), Vector3(0.135, 0.37, 0.145), top)
        _part(arm, Vector3(0, -0.38, -0.015), Vector3(0.10, 0.14, 0.105), skin)
        var leg := _joint(Vector3(side * 0.10, 0.08, 0))
        hips.append(leg)
        _part(leg, Vector3(0, -0.39, 0), Vector3(0.16, 0.79, 0.18), pants)
        _part(leg, Vector3(0, -0.84, -0.052), Vector3(0.16, 0.13, 0.27), shoes)

func equip_launcher() -> void:
    launcher = Node3D.new()
    launcher.position = Vector3(0.015, -0.40, -0.085)
    shoulders[1].add_child(launcher)
    var metal := StandardMaterial3D.new()
    metal.albedo_color = Color("#344349")
    _part(launcher, Vector3(0, 0.045, -0.06), Vector3(0.10, 0.095, 0.24), metal)
    _part(launcher, Vector3(0, -0.015, -0.02), Vector3(0.07, 0.12, 0.085), metal)
    launcher.hide()

func animate(delta: float, speed: float, grounded: bool, strike: float = 0.0, aiming: bool = false) -> void:
    gait = fmod(gait + delta * speed * 2.2, TAU)
    var stride := sin(gait) * clampf(speed * 0.13, 0, 0.80)
    var weight := 1.0 - exp(-delta * 16.0)
    for index in range(2):
        var step := stride if index == 0 else -stride
        hips[index].rotation.x = lerpf(hips[index].rotation.x, step if grounded else 0.22, weight)
        var swing := -step * 0.78 if grounded else -0.52
        if index == 1:
            swing = -1.65 if aiming else swing - sin(strike * PI) * 1.7
        shoulders[index].rotation.x = lerpf(shoulders[index].rotation.x, swing, weight)

func _joint(location: Vector3) -> Node3D:
    var joint := Node3D.new()
    joint.position = location
    add_child(joint)
    return joint

func _part(parent: Node3D, location: Vector3, dimensions: Vector3, material: Material) -> void:
    var part := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radial_segments = 10
    mesh.rings = 5
    mesh.radius = 0.5
    mesh.height = 1.0
    mesh.material = material
    part.mesh = mesh
    part.scale = dimensions
    part.position = location
    parent.add_child(part)
