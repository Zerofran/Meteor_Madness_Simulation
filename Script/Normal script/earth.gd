extends Node3D
# --- Parámetros exportados para el shader ---
@export var sun_father : Node3D
@export var eart : MeshInstance3D
@export var atmosphere : MeshInstance3D
# --- Parámetros exportados ---
@export var fastTime: bool = false
@export var futureSecond: int = 12 * 3600          # segundos del día cuando fastTime = true
@export var autorotate: bool = true
@export var autorotate_smooth: float = 6.0         # mayor = la interpolación hacia la rotación por hora es más rápida

@export var allow_manual_override: bool = true
@export var return_on_manual_end: bool = true
@export var return_speed: float = 2.0              # mayor = regreso más rápido
@export var return_tolerance: float = 0.0005

# --- Estado interno ---
var _manual_rotating: bool = false
var _returning: bool = false
var _return_target: Vector3 = Vector3.ZERO         # rotación objetivo (rad) hacia la que volver
var _manual_applied: bool = false                  # indica si se ha modificado manualmente desde start

func _ready() -> void:
	# Inicializar la rotación del nodo según la hora desde el arranque
	rotation = _time_rotation()

func _process(delta: float) -> void:
	#------Funcionalidades del shader de la tierra y la admosfera----
	eart.get_active_material(0).set_shader_parameter("Objeto", sun_father.get_node("sun/sun_position").global_position)
	atmosphere.get_active_material(0).set_shader_parameter("Objeto", sun_father.get_node("sun/sun_position").global_position)
	
	# Si estamos retornando, interpolamos hacia _return_target
	if _returning:
		rotation.x = lerp_angle(rotation.x, _return_target.x, clamp(delta * return_speed, 0.0, 1.0))
		rotation.y = lerp_angle(rotation.y, _return_target.y, clamp(delta * return_speed, 0.0, 1.0))
		rotation.z = lerp_angle(rotation.z, _return_target.z, clamp(delta * return_speed, 0.0, 1.0))
		if rotation.distance_to(_return_target) <= return_tolerance:
			_returning = false
			_manual_rotating = false
			_manual_applied = false
		return

	# Si no hay override manual activo y autorotate está activado, acercarse suavemente a la rotación por hora
	if autorotate and not _manual_rotating and not _returning:
		var target := _time_rotation()
		rotation.x = lerp_angle(rotation.x, target.x, clamp(delta * autorotate_smooth, 0.0, 1.0))
		rotation.y = lerp_angle(rotation.y, target.y, clamp(delta * autorotate_smooth, 0.0, 1.0))
		rotation.z = lerp_angle(rotation.z, target.z, clamp(delta * autorotate_smooth, 0.0, 1.0))

	# Si _manual_rotating es true, se espera que la rotación se aplique externamente
	# mediante apply_manual_delta. Este script no vuelve a sobrescribir la rotación mientras dure el override.

# ----------------- API pública para controlar interacción manual -----------------

func start_manual_rotation() -> void:
	if not allow_manual_override:
		return
	_manual_rotating = true
	_returning = false
	_manual_applied = false

# delta_pitch_rad y delta_yaw_rad son en radianes (aplica la sensibilidad en el controlador)
func apply_manual_delta(delta_pitch_rad: float, delta_yaw_rad: float) -> void:
	if not _manual_rotating:
		return
	var r := rotation
	r.x += delta_pitch_rad
	r.y += delta_yaw_rad
	rotation = r
	_manual_applied = true

func end_manual_rotation() -> void:
	if not allow_manual_override:
		return
	_manual_rotating = false
	if return_on_manual_end and _manual_applied:
		# calcular objetivo de tiempo actual y comenzar retorno
		_return_target = _time_rotation()
		_returning = true
		_manual_applied = false

# ----------------- Utilidad: conversión tiempo -> rotación en radianes -----------------

func _time_rotation() -> Vector3:
	var segundos_del_dia: int
	if fastTime:
		segundos_del_dia = int(futureSecond) % 86400
	else:
		var utc_dict := Time.get_time_dict_from_system(true)
		var hour := int(utc_dict.get("hour", 0))
		var minute := int(utc_dict.get("minute", 0))
		var second := int(utc_dict.get("second", 0))
		segundos_del_dia = hour * 3600 + minute * 60 + second
		segundos_del_dia = segundos_del_dia % 86400

	# 24 horas -> 360 grados. Convertir segundos a grados y luego a radianes.
	var grados := float(segundos_del_dia) * (360.0 / 86400.0)
	# Mantengo el mismo offset que usabas (-180) para ajustar la orientación inicial
	var offset_degrees: float = -180.0
	grados += offset_degrees
	var rad := deg_to_rad(grados)

	# Solo yaw cambia por la hora; mantengo X y Z en 0 para comportamiento igual al tuyo
	return Vector3(0.0, rad, 0.0)
