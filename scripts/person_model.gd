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
var muzzle: Marker3D
var elbows: Array[Node3D] = []
var aim_weight := 0.0
const UPPER_ARM := 0.27
const FOREARM := 0.26
const GRIP := Vector3(0.065, 0.555, -0.40)

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
        _part(arm, Vector3(0, -0.13, 0), Vector3(0.145, 0.31, 0.15), top)
        var elbow := Node3D.new()
        elbow.position.y = -UPPER_ARM
        arm.add_child(elbow)
        elbows.append(elbow)
        _part(elbow, Vector3(0, -0.092, 0), Vector3(0.111, 0.24, 0.11), top)
        _part(elbow, Vector3(0, -0.232, -0.005), Vector3(0.083, 0.112, 0.077), skin)
        _part(elbow, Vector3(-side * 0.038, -0.218, -0.019), Vector3(0.035, 0.062, 0.042), skin)
        var leg := _joint(Vector3(side * 0.10, 0.08, 0))
        hips.append(leg)
        _part(leg, Vector3(0, -0.39, 0), Vector3(0.16, 0.79, 0.18), pants)
        _part(leg, Vector3(0, -0.84, -0.052), Vector3(0.16, 0.13, 0.27), shoes)

func equip_launcher() -> void:
    launcher = Node3D.new()
    add_child(launcher)
    var metal := StandardMaterial3D.new()
    metal.albedo_color = Color("#344349")
    _part(launcher, Vector3(0, 0.068, -0.06), Vector3(0.10, 0.095, 0.24), metal)
    _part(launcher, Vector3(0, -0.015, -0.02), Vector3(0.07, 0.12, 0.085), metal)
    muzzle = Marker3D.new()
    muzzle.position = Vector3(0, 0.069, -0.177)
    launcher.add_child(muzzle)
    launcher.hide()

func ready_aim() -> void:
    aim_weight = maxf(aim_weight, 0.8)
    _pose_aim(aim_weight)
    launcher.show()

func _pose_aim(weight: float) -> void:
    launcher.position = GRIP + Vector3(0, 0, (1.0 - weight) * 0.078)
    for index in range(2):
        var shoulder := shoulders[index]
        var grip_offset := Vector3(-0.075, -0.026, 0.025) if index == 0 else Vector3.ZERO
        var direction := (launcher.position + grip_offset - shoulder.position).normalized()
        var distance := minf(launcher.position.distance_to(shoulder.position + -grip_offset), UPPER_ARM + FOREARM - 0.001)
        var along := (UPPER_ARM * UPPER_ARM - FOREARM * FOREARM + distance * distance) / (2.0 * distance)
        var bend_direction := Vector3.DOWN.slide(direction).normalized()
        var hinge := shoulder.position + direction * along + bend_direction * sqrt(maxf(0.0, UPPER_ARM * UPPER_ARM - along * along))
        var upper := (hinge - shoulder.position).normalized()
        var lower := (launcher.position + grip_offset - hinge).normalized()
        var shoulder_pose := Quaternion(Vector3.DOWN, upper)
        var elbow_pose := Quaternion(Vector3.DOWN, shoulder_pose.inverse() * lower)
        shoulder.quaternion = shoulder.quaternion.slerp(shoulder_pose, weight)
        elbows[index].quaternion = elbows[index].quaternion.slerp(elbow_pose, weight)

func animate(delta: float, speed: float, grounded: bool, strike: float = 0.0, aiming: bool = false) -> void:
    gait = fmod(gait + delta * speed * 2.2, TAU)
    var stride := sin(gait) * clampf(speed * 0.13, 0, 0.80)
    var weight := 1.0 - exp(-delta * 16.0)
    for index in range(2):
        var step := stride if index == 0 else -stride
        hips[index].rotation.x = lerpf(hips[index].rotation.x, step if grounded else 0.22, weight)
        var swing := -step * 0.78 if grounded else -0.52
        if index == 1:
            swing -= sin(strike * PI) * 1.7
        shoulders[index].quaternion = shoulders[index].quaternion.slerp(Quaternion(Vector3.RIGHT, swing), weight)
        elbows[index].quaternion = elbows[index].quaternion.slerp(Quaternion(Vector3.RIGHT, 0.16 + absf(stride) * 0.24), weight)
    if launcher != null:
        aim_weight = move_toward(aim_weight, 1.0 if aiming else 0.0, delta * 8.0)
        launcher.visible = aim_weight > 0.0
        if launcher.visible:
            _pose_aim(aim_weight)

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
