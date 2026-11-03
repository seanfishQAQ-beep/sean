extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")

var player: WhiteoutPlayer
var hud: Label
var elevator_label: Label
var kills := 0
var total_enemies := 10
var elevator_ready := false
var splatters: Node3D

func _ready() -> void:
    add_to_group("game")
    _configure_inputs()
    _build_world()
    _spawn_player()
    _spawn_enemies()
    _build_ui()

func _configure_inputs() -> void:
    var mapping := {
        "move_forward": KEY_W, "move_back": KEY_S,
        "move_left": KEY_A, "move_right": KEY_D
    }
    for action in mapping:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        var key := InputEventKey.new()
        key.physical_keycode = mapping[action]
        InputMap.action_add_event(action, key)

func _box(pos: Vector3, dims: Vector3, color: Color, solid: bool = true) -> void:
    var model := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = dims
    model.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.9
    model.material_override = mat
    model.position = pos
    add_child(model)
    if solid:
        var static_body := StaticBody3D.new()
        static_body.position = pos
        var collider := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = dims
        collider.shape = box
        static_body.add_child(collider)
        add_child(static_body)

func _build_world() -> void:
    var white := Color(0.96, 0.96, 0.96)
    var pale := Color(0.86, 0.86, 0.86)
    _box(Vector3(0, -0.25, 0), Vector3(30, 0.5, 38), white)
    _box(Vector3(0, 5.0, 0), Vector3(30, 0.3, 38), white)
    _box(Vector3(-15, 2.5, 0), Vector3(0.5, 5, 38), white)
    _box(Vector3(15, 2.5, 0), Vector3(0.5, 5, 38), white)
    _box(Vector3(0, 2.5, -19), Vector3(30, 5, 0.5), white)
    _box(Vector3(0, 2.5, 19), Vector3(30, 5, 0.5), white)
    for x in [-6.0, 6.0]:
        for z in [-9.0, 2.0, 12.0]:
            _box(Vector3(x, 1.7, z), Vector3(0.3, 3.4, 6), pale)
    for z in [-5.0, 7.0]:
        _box(Vector3(-10, 0.55, z), Vector3(2, 1.1, 1.0), pale)
        _box(Vector3(10, 0.55, z), Vector3(2, 1.1, 1.0), pale)
    _box(Vector3(0, 2.5, -18.7), Vector3(4, 4, 0.08), Color(0.04, 0.04, 0.05), false)
    _box(Vector3(0, 4.5, -18.5), Vector3(4.5, 0.2, 0.2), Color(0.75, 0.1, 0.1), false)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, 25, 0)
    sun.light_energy = 1.2
    add_child(sun)
    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.94, 0.94, 0.94)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color.WHITE
    env.ambient_light_energy = 0.8
    environment.environment = env
    add_child(environment)
    splatters = Node3D.new()
    splatters.name = "BloodMarks"
    add_child(splatters)

func _spawn_player() -> void:
    player = PlayerScript.new()
    player.position = Vector3(0, 0.2, 15)
    add_child(player)
    player.game = self

func _spawn_enemies() -> void:
    var positions := [
        Vector3(0, 0, 7), Vector3(-3, 0, 3), Vector3(4, 0, 1),
        Vector3(-8, 0, -7), Vector3(8, 0, -6), Vector3(1, 0, -3),
        Vector3(-3, 0, -11), Vector3(3, 0, -12), Vector3(-9, 0, 9),
        Vector3(9, 0, 9)
    ]
    for p in positions:
        var enemy := EnemyScript.new()
        enemy.position = p
        enemy.add_to_group("enemies")
        add_child(enemy)
        enemy.target = player

func _build_ui() -> void:
    var overlay := CanvasLayer.new()
    add_child(overlay)
    hud = Label.new()
    hud.position = Vector2(20, 16)
    hud.add_theme_font_size_override("font_size", 22)
    overlay.add_child(hud)
    elevator_label = Label.new()
    elevator_label.position = Vector2(20, 50)
    elevator_label.add_theme_font_size_override("font_size", 18)
    overlay.add_child(elevator_label)
    var crosshair := Label.new()
    crosshair.text = "+"
    crosshair.set_anchors_preset(Control.PRESET_CENTER)
    crosshair.position = Vector2(-5, -12)
    crosshair.add_theme_font_size_override("font_size", 24)
    overlay.add_child(crosshair)

func _process(_delta: float) -> void:
    if not is_instance_valid(player):
        return
    hud.text = "WHITEOUT  |  HP %d  |  KILLS %d/%d  |  %s" % [
        player.health, kills, total_enemies,
        "DETACHED ARM" if player.detached else "FISTS"
    ]
    elevator_label.text = "ELEVATOR OPEN - Approach the black door and press E" if elevator_ready else "CLEAR THE FLOOR"
    if player.charging:
        elevator_label.text += "  |  CHARGE %.1f" % player.charge

func enemy_killed(at_position: Vector3) -> void:
    kills += 1
    _blood_burst(at_position)
    if kills >= total_enemies:
        elevator_ready = true

func _blood_burst(p: Vector3) -> void:
    for i in 18:
        var drop := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = randf_range(0.06, 0.24)
        sphere.height = sphere.radius * 2.0
        drop.mesh = sphere
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.70 + randf() * 0.25, 0.0, 0.02)
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        drop.material_override = mat
        drop.position = p + Vector3(randf_range(-1.6, 1.6), randf_range(0.03, 1.9), randf_range(-1.6, 1.6))
        splatters.add_child(drop)

func try_elevator() -> void:
    if not elevator_ready:
        return
    if player.global_position.distance_to(Vector3(0, 0, -18.7)) > 4.5:
        return
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var panel := AcceptDialog.new()
    panel.title = "FLOOR CLEARED"
    panel.dialog_text = "KILLS: %d/%d\nThe elevator descends.\nPrototype complete. Replay the floor?" % [kills, total_enemies]
    add_child(panel)
    panel.confirmed.connect(func(): get_tree().reload_current_scene())
    panel.popup_centered(Vector2i(440, 210))
