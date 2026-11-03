extends CharacterBody3D
class_name WhiteoutEnemy

var target: CharacterBody3D
var hp := 2
var stunned := 0.0
var attack_timer := 0.0
var flight := Vector3.ZERO
var flying := false
var dead := false
var body_mesh: MeshInstance3D
var suit_material: StandardMaterial3D
var white_material: StandardMaterial3D

func _ready() -> void:
    collision_layer = 2
    collision_mask = 1
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.32
    capsule.height = 1.9
    var collider := CollisionShape3D.new()
    collider.shape = capsule
    collider.position.y = 0.95
    add_child(collider)
    suit_material = StandardMaterial3D.new()
    suit_material.albedo_color = Color(0.018, 0.018, 0.022)
    white_material = StandardMaterial3D.new()
    white_material.albedo_color = Color(0.95, 0.95, 0.94)
    _box(Vector3(0, 1.05, 0), Vector3(0.72, 0.9, 0.36), suit_material)
    _box(Vector3(-0.46, 1.04, 0), Vector3(0.22, 0.85, 0.27), suit_material)
    _box(Vector3(0.46, 1.04, 0), Vector3(0.22, 0.85, 0.27), suit_material)
    _box(Vector3(-0.19, 0.40, 0), Vector3(0.27, 0.75, 0.29), suit_material)
    _box(Vector3(0.19, 0.40, 0), Vector3(0.27, 0.75, 0.29), suit_material)
    _box(Vector3(0, 1.70, 0), Vector3(0.42, 0.44, 0.42), white_material)
    _box(Vector3(0, 1.18, -0.203), Vector3(0.09, 0.47, 0.015), white_material)

func _box(pos: Vector3, dims: Vector3, mat: Material) -> void:
    var mesh := MeshInstance3D.new()
    var shape := BoxMesh.new()
    shape.size = dims
    mesh.mesh = shape
    mesh.material_override = mat
    mesh.position = pos
    add_child(mesh)

func _physics_process(delta: float) -> void:
    if dead:
        return
    if flying:
        velocity = flight
        flight.y -= 15.0 * delta
        var collision := move_and_collide(flight * delta)
        if collision != null or global_position.y < -2.0:
            _burst()
        return
    if stunned > 0.0:
        stunned -= delta
        velocity = Vector3.ZERO
        return
    if not is_instance_valid(target):
        return
    attack_timer -= delta
    var offset := target.global_position - global_position
    offset.y = 0
    if offset.length() > 1.4:
        velocity = offset.normalized() * 2.0
        move_and_slide()
    else:
        velocity = Vector3.ZERO
        if attack_timer <= 0.0:
            attack_timer = 1.5
            if target.has_method("take_damage"):
                target.take_damage(12)
    if offset.length() > 0.05:
        look_at(global_position + Vector3(offset.x, 0, offset.z), Vector3.UP)

func hit(force_direction: Vector3, heavy: bool) -> void:
    if dead:
        return
    if heavy or hp <= 1:
        flying = true
        flight = force_direction.normalized() * (18.0 if heavy else 11.0) + Vector3.UP * 2.6
        velocity = flight
        collision_mask = 1
    else:
        hp -= 1
        stunned = 0.8

func finish() -> void:
    if dead or flying:
        return
    _burst()

func _burst() -> void:
    if dead:
        return
    dead = true
    get_tree().call_group("game", "enemy_killed", global_position)
    queue_free()
