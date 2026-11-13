extends Node3D

const PLAYER_SPEED := 6.0
const JUMP_VELOCITY := 5.2
const MOUSE_SENSITIVITY := 0.0025
const MAGAZINE_SIZE := 12
const RELOAD_SECONDS := 1.15
const ARENA_RADIUS := 22.0

var player: CharacterBody3D
var camera: Camera3D
var enemies: Array = []
var game_active := false
var health := 100.0
var score := 0
var wave := 1
var ammo := MAGAZINE_SIZE
var reloading := false
var wave_wait := 0.0
var look_touch_id := -1
var move_touch_id := -1
var move_input := Vector2.ZERO
var joystick_center := Vector2.ZERO
var fire_held := false
var hud: Control
var overlay: ColorRect
var title_label: Label
var message_label: Label
var start_button: Button
var health_label: Label
var score_label: Label
var wave_label: Label
var ammo_label: Label
var notice_label: Label
var notice_timer := 0.0
var joystick_base: Panel
var joystick_knob: Panel
var look_yaw := 0.0
var look_pitch := 0.0

func _ready() -> void:
	_build_world()
	_build_player()
	_build_hud()
	_update_hud()
	set_process(true)
	set_physics_process(true)

func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.15, 0.34, 0.48)
	sky_mat.sky_horizon_color = Color(0.66, 0.76, 0.78)
	sky_mat.ground_bottom_color = Color(0.13, 0.16, 0.13)
	sky_mat.ground_horizon_color = Color(0.48, 0.53, 0.43)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.79, 0.82)
	env.ambient_light_energy = 0.65
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.88, 0.7)
	sun.light_energy = 1.7
	add_child(sun)

	var floor_body := StaticBody3D.new()
	floor_body.position.y = -0.12
	add_child(floor_body)
	var floor_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(52, 0.24, 52)
	floor_shape.shape = box_shape
	floor_body.add_child(floor_shape)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(52, 52)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.31, 0.38, 0.27)
	floor_mat.roughness = 1.0
	floor_mesh.material_override = floor_mat
	floor_body.add_child(floor_mesh)

	# Perimeter walls and chunky cover make the arena readable on small screens.
	_add_box(Vector3(0, 1.3, -24), Vector3(50, 2.6, 1), Color(0.28, 0.33, 0.31))
	_add_box(Vector3(0, 1.3, 24), Vector3(50, 2.6, 1), Color(0.28, 0.33, 0.31))
	_add_box(Vector3(-24, 1.3, 0), Vector3(1, 2.6, 50), Color(0.28, 0.33, 0.31))
	_add_box(Vector3(24, 1.3, 0), Vector3(1, 2.6, 50), Color(0.28, 0.33, 0.31))
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		var p := Vector3(cos(angle) * 9.5, 1.0, sin(angle) * 9.5)
		_add_box(p, Vector3(1.8, 2.0, 1.8), Color(0.43, 0.37, 0.27))
	for i in range(4):
		var x := -12.0 if i % 2 == 0 else 12.0
		var z := -5.0 if i < 2 else 5.0
		_add_box(Vector3(x, 0.75, z), Vector3(3.0, 1.5, 1.1), Color(0.34, 0.40, 0.36))

func _add_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	add_child(body)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	var mesh_node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_node.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.88
	mesh_node.material_override = mat
	body.add_child(mesh_node)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 0.08, 0)
	add_child(player)
	var shape_node := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	shape_node.shape = capsule
	shape_node.position.y = 0.9
	player.add_child(shape_node)
	camera = Camera3D.new()
	camera.position.y = 1.58
	camera.current = true
	camera.fov = 78.0
	player.add_child(camera)
	# A low-poly weapon silhouette in view space.
	var gun := MeshInstance3D.new()
	var gun_mesh := BoxMesh.new()
	gun_mesh.size = Vector3(0.18, 0.16, 0.55)
	gun.mesh = gun_mesh
	gun.position = Vector3(0.28, -0.22, -0.48)
	var gun_mat := StandardMaterial3D.new()
	gun_mat.albedo_color = Color(0.12, 0.16, 0.18)
	gun.material_override = gun_mat
	camera.add_child(gun)

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_top = 12
	top.offset_right = -12
	top.offset_bottom = 58
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 12)
	hud.add_child(top)
	health_label = _make_stat(top, "الصحة 100")
	wave_label = _make_stat(top, "الموجة 1")
	score_label = _make_stat(top, "النقاط 0")
	ammo_label = _make_stat(top, "الذخيرة 12/12")

	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 26)
	crosshair.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -18
	crosshair.offset_top = -20
	crosshair.offset_right = 18
	crosshair.offset_bottom = 20
	hud.add_child(crosshair)

	joystick_base = Panel.new()
	joystick_base.position = Vector2(24, -164)
	joystick_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick_base.size = Vector2(136, 136)
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_base.add_theme_stylebox_override("panel", _rounded_style(Color(0.82, 0.9, 0.94, 0.17), 68))
	hud.add_child(joystick_base)
	joystick_knob = Panel.new()
	joystick_knob.position = Vector2(42, 42)
	joystick_knob.size = Vector2(52, 52)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_knob.add_theme_stylebox_override("panel", _rounded_style(Color(0.9, 0.95, 1, 0.42), 26))
	joystick_base.add_child(joystick_knob)

	var hint := Label.new()
	hint.text = "العصا للحركة  •  اسحب يمين الشاشة للتصويب"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_left = 0
	hint.offset_top = -30
	hint.offset_right = 0
	hint.offset_bottom = -7
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	hud.add_child(hint)

	var fire_button := _make_button("إطلاق", Vector2(-118, -130), Vector2(96, 96), true)
	fire_button.button_down.connect(func(): fire_held = true; _shoot())
	fire_button.button_up.connect(func(): fire_held = false)
	var reload_button := _make_button("إعادة\nتلقيم", Vector2(-224, -102), Vector2(92, 68), false)
	reload_button.pressed.connect(_reload)
	var jump_button := _make_button("قفز", Vector2(-118, -238), Vector2(82, 58), false)
	jump_button.pressed.connect(_jump)

	overlay = ColorRect.new()
	overlay.color = Color(0.015, 0.035, 0.055, 0.78)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(overlay)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -210
	panel.offset_top = -150
	panel.offset_right = 210
	panel.offset_bottom = 150
	panel.add_theme_stylebox_override("panel", _rounded_style(Color(0.055, 0.09, 0.12, 0.98), 20))
	overlay.add_child(panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	title_label = Label.new()
	title_label.text = "ساحة القتال"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
	column.add_child(title_label)
	message_label = Label.new()
	message_label.text = "اصمد أمام موجات الأعداء.\nWASD للحركة، الفأرة للتصويب، R للتلقيم.\nعلى الهاتف استخدم العصا والأزرار."
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size.x = 340
	message_label.add_theme_font_size_override("font_size", 16)
	column.add_child(message_label)
	start_button = Button.new()
	start_button.text = "ابدأ اللعب"
	start_button.custom_minimum_size = Vector2(180, 52)
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_button.add_theme_font_size_override("font_size", 20)
	column.add_child(start_button)
	start_button.pressed.connect(_start_game)

	notice_label = Label.new()
	notice_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	notice_label.offset_left = -180
	notice_label.offset_top = 82
	notice_label.offset_right = 180
	notice_label.offset_bottom = 120
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.add_theme_font_size_override("font_size", 20)
	notice_label.add_theme_color_override("font_color", Color(1, 0.85, 0.45))
	notice_label.visible = false
	hud.add_child(notice_label)

func _make_stat(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.96))
	label.add_theme_stylebox_override("normal", _rounded_style(Color(0.02, 0.045, 0.06, 0.76), 10))
	label.custom_minimum_size = Vector2(100, 40)
	parent.add_child(label)
	return label

func _make_button(text: String, bottom_right_offset: Vector2, button_size: Vector2, is_fire: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.offset_left = bottom_right_offset.x
	button.offset_top = bottom_right_offset.y
	button.offset_right = bottom_right_offset.x + button_size.x
	button.offset_bottom = bottom_right_offset.y + button_size.y
	button.add_theme_font_size_override("font_size", 18 if is_fire else 15)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _rounded_style(Color(0.72, 0.16, 0.14, 0.92) if is_fire else Color(0.08, 0.15, 0.19, 0.92), int(button_size.x / 2.0) if is_fire else 14))
	button.add_theme_stylebox_override("hover", _rounded_style(Color(0.84, 0.24, 0.18, 0.98) if is_fire else Color(0.15, 0.24, 0.28, 0.98), int(button_size.x / 2.0) if is_fire else 14))
	button.add_theme_stylebox_override("pressed", _rounded_style(Color(0.48, 0.1, 0.09, 1) if is_fire else Color(0.04, 0.09, 0.12, 1), int(button_size.x / 2.0) if is_fire else 14))
	hud.add_child(button)
	return button

func _rounded_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _start_game() -> void:
	health = 100.0
	score = 0
	wave = 1
	ammo = MAGAZINE_SIZE
	reloading = false
	wave_wait = 0.0
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	look_yaw = 0.0
	look_pitch = 0.0
	player.rotation.y = 0.0
	camera.rotation.x = 0.0
	for enemy in enemies:
		if is_instance_valid(enemy.body):
			enemy.body.queue_free()
	enemies.clear()
	game_active = true
	overlay.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_spawn_wave()
	_update_hud()

func _end_game() -> void:
	game_active = false
	fire_held = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	title_label.text = "انتهت اللعبة"
	message_label.text = "نتيجتك: %d نقطة\nوصلت إلى الموجة %d" % [score, wave]
	start_button.text = "العب مرة ثانية"
	overlay.visible = true

func _spawn_wave() -> void:
	var count := mini(3 + wave * 2, 20)
	for i in range(count):
		_spawn_enemy()
	_show_notice("الموجة %d — %d أعداء" % [wave, count])

func _spawn_enemy() -> void:
	var body := CharacterBody3D.new()
	body.name = "Enemy"
	var angle := randf() * TAU
	var radius := randf_range(14.0, 19.0)
	body.position = Vector3(cos(angle) * radius, 0.08, sin(angle) * radius)
	add_child(body)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.88
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.42
	mesh.height = 1.75
	visual.mesh = mesh
	visual.position.y = 0.88
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.19, 0.16)
	mat.roughness = 0.8
	visual.material_override = mat
	body.add_child(visual)
	# Bright shoulder marker makes enemies easier to identify at a distance.
	var marker := MeshInstance3D.new()
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.12
	marker_mesh.height = 0.24
	marker.mesh = marker_mesh
	marker.position = Vector3(0, 1.62, 0)
	var marker_mat := StandardMaterial3D.new()
	marker_mat.albedo_color = Color(1.0, 0.72, 0.18)
	marker_mat.emission_enabled = true
	marker_mat.emission = Color(0.75, 0.3, 0.02)
	marker.material_override = marker_mat
	body.add_child(marker)
	enemies.append({"body": body, "hp": 70.0, "speed": randf_range(1.35, 2.05), "attack": 0.0})

func _physics_process(delta: float) -> void:
	if not game_active:
		return
	_update_player(delta)
	_update_enemies(delta)
	if fire_held:
		_shoot()
	if enemies.is_empty():
		wave_wait += delta
		if wave_wait >= 2.0:
			wave_wait = 0.0
			wave += 1
			_spawn_wave()
			_update_hud()

func _update_player(delta: float) -> void:
	var direction := Vector3.ZERO
	var keyboard := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_back", "move_forward")
	)
	var move_vec := move_input
	if keyboard.length() > 0.1:
		move_vec = keyboard.normalized()
	var forward := -player.global_transform.basis.z
	var right := player.global_transform.basis.x
	direction = right * move_vec.x + forward * move_vec.y
	if direction.length() > 1.0:
		direction = direction.normalized()
	player.velocity.x = direction.x * PLAYER_SPEED
	player.velocity.z = direction.z * PLAYER_SPEED
	if not player.is_on_floor():
		player.velocity.y -= 18.0 * delta
	else:
		player.velocity.y = 0.0
		if Input.is_action_just_pressed("jump"):
			player.velocity.y = JUMP_VELOCITY
	player.move_and_slide()
	var flat := Vector2(player.position.x, player.position.z)
	if flat.length() > ARENA_RADIUS:
		flat = flat.normalized() * ARENA_RADIUS
		player.position.x = flat.x
		player.position.z = flat.y

func _update_enemies(delta: float) -> void:
	for enemy in enemies.duplicate():
		var body: CharacterBody3D = enemy.body
		if not is_instance_valid(body):
			enemies.erase(enemy)
			continue
		var toward := player.global_position - body.global_position
		toward.y = 0.0
		var distance := toward.length()
		if distance > 1.35:
			var dir := toward.normalized()
			body.velocity.x = dir.x * enemy.speed
			body.velocity.z = dir.z * enemy.speed
			body.velocity.y = 0.0
			body.move_and_slide()
			body.look_at(Vector3(player.global_position.x, body.global_position.y, player.global_position.z))
		else:
			body.velocity = Vector3.ZERO
			enemy.attack += delta
			if enemy.attack >= 0.65:
				enemy.attack = 0.0
				health -= 7.0
				_update_hud()
				if health <= 0.0:
					health = 0.0
					_update_hud()
					_end_game()
					return

func _shoot() -> void:
	if not game_active or reloading or ammo <= 0:
		if ammo <= 0 and not reloading:
			_show_notice("الذخيرة فارغة — أعد التلقيم")
		return
	if not _shot_cooldown_ready:
		return
	_shot_cooldown_ready = false
	get_tree().create_timer(0.16).timeout.connect(func(): _shot_cooldown_ready = true)
	ammo -= 1
	_update_hud()
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * 80.0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		var collider = result.get("collider")
		for enemy in enemies.duplicate():
			if enemy.body == collider:
				enemy.hp -= 35.0
				if enemy.hp <= 0.0:
					enemy.body.queue_free()
					enemies.erase(enemy)
				score += 100
					_update_hud()
				break
	if ammo == 0:
		_show_notice("اضغط إعادة تلقيم")

var _shot_cooldown_ready := true

func _reload() -> void:
	if not game_active or reloading or ammo == MAGAZINE_SIZE:
		return
	reloading = true
	_show_notice("إعادة تلقيم...")
	_update_hud()
	get_tree().create_timer(RELOAD_SECONDS).timeout.connect(func():
		if game_active:
			ammo = MAGAZINE_SIZE
			reloading = false
			_update_hud()
	)

func _jump() -> void:
	if game_active and player.is_on_floor():
		player.velocity.y = JUMP_VELOCITY

func _update_hud() -> void:
	if not is_instance_valid(health_label):
		return
	health_label.text = "♥ %d" % int(ceil(health))
	wave_label.text = "الموجة %d" % wave
	score_label.text = "النقاط %d" % score
	ammo_label.text = "تلقيم..." if reloading else "ذخيرة %d/%d" % [ammo, MAGAZINE_SIZE]

func _show_notice(text: String) -> void:
	if not is_instance_valid(notice_label):
		return
	notice_label.text = text
	notice_label.visible = true
	notice_timer = 1.6

func _process(delta: float) -> void:
	if notice_timer > 0.0:
		notice_timer -= delta
		if notice_timer <= 0.0 and is_instance_valid(notice_label):
			notice_label.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if game_active:
			game_active = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			title_label.text = "إيقاف مؤقت"
			message_label.text = "اللعبة متوقفة مؤقتًا."
			start_button.text = "متابعة اللعب"
			overlay.visible = true
		else:
			if overlay.visible and title_label.text == "إيقاف مؤقت":
				game_active = true
				overlay.visible = false
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
	if not game_active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_look(event.relative)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_shoot()
	elif event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < get_viewport().get_visible_rect().size.x * 0.42 and move_touch_id == -1:
				move_touch_id = event.index
				joystick_center = event.position
				_update_joystick(event.position)
			elif look_touch_id == -1 and event.position.y < get_viewport().get_visible_rect().size.y - 150:
				look_touch_id = event.index
		else:
			if event.index == move_touch_id:
				move_touch_id = -1
				move_input = Vector2.ZERO
				if is_instance_valid(joystick_knob): joystick_knob.position = Vector2(42, 42)
			if event.index == look_touch_id:
				look_touch_id = -1
	elif event is InputEventScreenDrag:
		if event.index == move_touch_id:
			_update_joystick(event.position)
		elif event.index == look_touch_id:
			_apply_look(event.relative)

func _update_joystick(position: Vector2) -> void:
	var delta := position - joystick_center
	var limit := 46.0
	if delta.length() > limit:
		delta = delta.normalized() * limit
	move_input = Vector2(delta.x / limit, -delta.y / limit)
	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(42, 42) + delta

func _apply_look(relative: Vector2) -> void:
	look_yaw -= relative.x * MOUSE_SENSITIVITY
	look_pitch = clamp(look_pitch - relative.y * MOUSE_SENSITIVITY, -1.25, 1.25)
	player.rotation.y = look_yaw
	camera.rotation.x = look_pitch
