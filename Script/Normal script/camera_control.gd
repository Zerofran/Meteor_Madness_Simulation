extends Node3D

# Exportados
@export var sencivilidad: float = 5.0
@export var Aceleracion: float = 10.0
@export var menu: bool = true

@onready var Camara3d: Camera3D = $Camera3D

# Zoom
@export var zoom_speed: float = 20.0
@export var zoom_step: float = 4.0
@export var zoom_min: float = 1.5
@export var zoom_max: float = 10.0
var zoom_target: float = 5.0

# Estado interacción
var arrastrando: bool = false
var seleccionado: Node3D = null

# Objetivos de rotación (radianes)
var objetivo_self: Vector2 = Vector2.ZERO
var objetivo_seleccionado: Vector2 = Vector2.ZERO

# Indica si el seleccionado implementa la API del Earth (start_manual_rotation / apply_manual_delta / end_manual_rotation)
var seleccionado_usa_api: bool = false

func _ready() -> void:
	if Camara3d:
		zoom_target = Camara3d.position.z
	objetivo_self.x = rotation.x
	objetivo_self.y = rotation.y

func _input(event) -> void:
	if menu:
		return

	# Inicio de clic: seleccionar SOLO si Ctrl está presionado
	if Input.is_action_just_pressed("Maus_left"):
		# limpiar selección por defecto; solo reasignamos si Ctrl está presionado y raycast encuentra algo rotatable
		seleccionado = null
		seleccionado_usa_api = false

		if Input.is_action_pressed("ctrl") and Camara3d:
			var mouse_pos: Vector2 = get_viewport().get_mouse_position()
			if event is InputEventMouseButton:
				mouse_pos = event.position
			elif event is InputEventMouseMotion:
				mouse_pos = event.position

			var origen: Vector3 = Camara3d.project_ray_origin(mouse_pos)
			var direccion: Vector3 = Camara3d.project_ray_normal(mouse_pos)
			var destino: Vector3 = origen + direccion * 1000.0
			var query := PhysicsRayQueryParameters3D.new()
			query.from = origen
			query.to = destino
			var resultado := get_world_3d().direct_space_state.intersect_ray(query)
			if resultado:
				var collider: Node = resultado.collider as Node
				if collider and collider.get_parent() and collider.get_parent().is_in_group("rotatable"):
					seleccionado = collider.get_parent() as Node3D
					# inicializar objetivo del seleccionado con su rotación actual
					objetivo_seleccionado.x = seleccionado.rotation.x
					objetivo_seleccionado.y = seleccionado.rotation.y
					# detectar si el nodo seleccionada implementa la API pública esperada
					seleccionado_usa_api = seleccionado.has_method("start_manual_rotation") and seleccionado.has_method("apply_manual_delta") and seleccionado.has_method("end_manual_rotation")
					# si usa API, avisamos al nodo que empieza rotación manual
					if seleccionado_usa_api:
						seleccionado.call("start_manual_rotation")

		# Activar arrastre y capturar cursor
		arrastrando = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Movimiento mientras se mantiene clic
	if Input.is_action_pressed("Maus_left") and arrastrando and event is InputEventMouseMotion:
		# convertir desplazamiento del ratón a radianes usando sensibilidad
		# event.relative está en píxeles; escalamos a radianes haciendo: (px / 1000) * sensibilidad => radianes aproximados
		var delta_pitch: float = -event.relative.y / 1000.0 * sencivilidad
		var delta_yaw: float = event.relative.x / 1000.0 * sencivilidad

		if seleccionado:
			if seleccionado_usa_api:
				# delegar la aplicación del delta en radianes al nodo seleccionado
				seleccionado.call("apply_manual_delta", delta_pitch, delta_yaw)
				# mantener objetivo local para visual fallback si es necesario
				objetivo_seleccionado.x += delta_pitch
				objetivo_seleccionado.y -= delta_yaw
			else:
				# rotación libre 360 para el seleccionado (fallback directo)
				objetivo_seleccionado.x += delta_pitch
				objetivo_seleccionado.y -= delta_yaw
		else:
			# rotación del nodo que contiene este script (con clamp en pitch)
			objetivo_self.x += delta_pitch
			# invertir la dirección horizontal de cámara para comportamiento esperado
			objetivo_self.y -= delta_yaw
			objetivo_self.x = clamp(objetivo_self.x, deg_to_rad(-60), deg_to_rad(60))

	# Fin del clic: soltado
	if Input.is_action_just_released("Maus_left"):
		arrastrando = false

		# Si el seleccionado usa la API y estábamos rotándolo, avisar que terminó
		if seleccionado and seleccionado_usa_api:
			seleccionado.call("end_manual_rotation")

		# dejamos seleccionado tal cual; si quieres que se deseleccione inmediatamente, descomenta la siguiente línea:
		# seleccionado = null

		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Zoom objetivo
	if Input.is_action_pressed("Zoom+"):
		zoom_target = clamp(zoom_target - zoom_step * get_process_delta_time(), zoom_min, zoom_max)
	elif Input.is_action_pressed("Zoom-"):
		zoom_target = clamp(zoom_target + zoom_step * get_process_delta_time(), zoom_min, zoom_max)

func _process(delta: float) -> void:
	if menu:
		return

	# Aplicar rotaciones suaves al seleccionado mientras lo estamos rotando (fallback para nodos sin API)
	if seleccionado and Input.is_action_pressed("Maus_left") and arrastrando and not seleccionado_usa_api:
		var actual: Vector3 = seleccionado.rotation
		actual.x = lerp(actual.x, objetivo_seleccionado.x, delta * Aceleracion)
		actual.y = lerp(actual.y, objetivo_seleccionado.y, delta * Aceleracion)
		seleccionado.rotation = actual
	else:
		# rotación del nodo que contiene este script (cámara) cuando no hay selección activa o cuando la selección delegó la rotación
		rotation.x = lerp(rotation.x, objetivo_self.x, delta * Aceleracion)
		rotation.y = lerp(rotation.y, objetivo_self.y, delta * Aceleracion)
		rotation.x = clamp(rotation.x, deg_to_rad(-60), deg_to_rad(60))
		rotation_degrees.y = lerp(rotation_degrees.y, rad_to_deg(rotation.y), delta * Aceleracion)
		rotation_degrees.x = lerp(rotation_degrees.x, rad_to_deg(rotation.x), delta * Aceleracion)

	# Suavizar zoom hacia zoom_target
	if Camara3d:
		var z_current: float = Camara3d.position.z
		z_current = lerp(z_current, zoom_target, clamp(delta * zoom_speed, 0.0, 1.0))
		Camara3d.position.z = clamp(z_current, zoom_min, zoom_max)
