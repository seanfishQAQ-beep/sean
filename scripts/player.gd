extends CharacterBody3D
class_name WhiteoutPlayer

var speed := 7.0
var sprint_speed := 11.0
var sensitivity := 0.0022
var gravity := 24.0
var health := 100
var charging := false
var charge := 0.0
var detached := false
var attack_cooldown := 0.0
var camera: Camera3D
var hand: MeshInstance3D
var game: Node
var punch_tween: Tween
const HAND_REST := Vector3(0.48, -0.44, -0.72)

func _ready() -> void:
    collision_layer = 1
    collision_mask = 1
    var capsule := CapsuleShape3D.new()
    capsule.height = 1.8
    capsule.radius = 0.32
    var collider := CollisionShape3D.new()
    collider.shape = capsule
    collider.position.y = 0.9
    add_child(collider)
    camera = Camera3D.new()
    camera.position.y = 1.65
    camera.current = true
    add_child(camera)
    hand = MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.27, 0.3, 0.56)
    hand.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.66, 0.51, 0.45)
    hand.material_override = mat
    hand.position = HAND_REST
    camera.add_child(hand)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * sensitivity)
        camera.rotate_x(-event.relative.y * sensitivity)
        camera.rotation.x = clamp(camera.rotation.x, -1.4, 1.4)
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
        elif event.keycode == KEY_Z:
            detached = not detached
            hand.scale = Vector3(1.3, 1.3, 2.3) if detached else Vector3.ONE
        elif event.keycode == KEY_E:
            _finish_or_interact()
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            charging = true
            charge = 0.0
        elif charging:
            charging = false
            _attack()

func _physics_process(delta: float) -> void:
    attack_cooldown = maxf(attack_cooldown - delta, 0.0)
    if charging:
        charge = minf(charge + delta, 1.5)
    if not is_on_floor():
        velocity.y -= gravity * delta
    elif Input.is_key_pressed(KEY_SPACE):
        velocity.y = 7.2
    var axis := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var direction := (global_transform.basis * Vector3(axis.x, 0, axis.y)).normalized()
    var current_speed := sprint_speed if Input.is_key_pressed(KEY_SHIFT) else speed
    velocity.x = direction.x * current_speed
    velocity.z = direction.z * current_speed
    move_and_slide()

func _attack() -> void:
    if attack_cooldown > 0.0:
        return
    var heavy := charge > 0.4 or detached
    attack_cooldown = 0.55 if detached else (0.4 if heavy else 0.18)
    _animate_punch(heavy)
    var candidates := get_tree().get_nodes_in_group("enemies")
    var origin := camera.global_position
    var forward := -camera.global_transform.basis.z
    var strikes := 0
    for e in candidates:
        if not is_instance_valid(e) or e.dead:
            continue
        var offset: Vector3 = e.global_position + Vector3.UP - origin
        var distance := offset.length()
        if distance > (4.1 if detached else 3.0) or distance < 0.01:
            continue
        if offset.normalized().dot(forward) < (0.55 if detached else 0.79):
            continue
        var direction: Vector3 = e.global_position - global_position
        direction.y = 0
        e.hit(direction.normalized(), heavy)
        strikes += 1
        if not detached:
            break
        if strikes >= 3:
            break

func _animate_punch(heavy: bool) -> void:
    if punch_tween != null and punch_tween.is_valid():
        punch_tween.kill()
    hand.position = HAND_REST
    punch_tween = create_tween()
    var reach := Vector3(0.12, -0.2, -1.35 if heavy else -1.1)
    punch_tween.tween_property(hand, "position", reach, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    punch_tween.tween_property(hand, "position", HAND_REST, 0.22 if heavy else 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func _finish_or_interact() -> void:
    for e in get_tree().get_nodes_in_group("enemies"):
        if is_instance_valid(e) and not e.dead and e.stunned > 0 and global_position.distance_to(e.global_position) < 2.4:
            e.finish()
            return
    if game != null and game.has_method("try_elevator"):
        game.try_elevator()

func take_damage(amount: int) -> void:
    health -= amount
    if health <= 0:
        get_tree().reload_current_scene()
