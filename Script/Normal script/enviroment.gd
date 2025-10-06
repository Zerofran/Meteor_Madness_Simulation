extends Node3D

# Nodo DirectionalLight llamado "Sun" como child directo
@onready var sun_light: DirectionalLight3D = $Sun
@onready var earth_root: Node3D = $"../earth"   # ajusta la ruta si tu nodo raíz de la Tierra está en otro lugar

# Parámetros editables
@export var latitude_deg: float = 0.0       # latitud del observador (N positivo)
@export var longitude_deg: float = 0.0      # longitud (E positivo)
@export var distance: float = 1000.0        # distancia virtual para colocar la luz
@export var use_system_utc: bool = true
@export var fast_time: bool = false
@export var future_second: int = 12 * 3600  # cuando fast_time=true, segundos del día a usar

# Constante: inclinación de la Tierra (referencia)
const EARTH_OBLIQUITY_DEG := 23.43928

func _day_of_year(y: int, m: int, d: int) -> int:
	var months := [31,28,31,30,31,30,31,31,30,31,30,31]
	# año bisiesto
	if (y % 4 == 0 and y % 100 != 0) or (y % 400 == 0):
		months[1] = 29
	var sum: int = 0
	for i in range(0, m-1):
		sum += months[i]
	sum += d
	return sum

func _process(delta: float) -> void:
	# Obtener fecha/hora UTC en segundos (segundos del día y día del año)
	var utc_dict := Time.get_time_dict_from_system(true)
	var year: int = int(utc_dict.get("year", 1970))
	var month: int = int(utc_dict.get("month", 1))
	var day: int = int(utc_dict.get("day", 1))
	var hour: int = int(utc_dict.get("hour", 0))
	var minute: int = int(utc_dict.get("minute", 0))
	var second: int = int(utc_dict.get("second", 0))

	var segundos_del_dia: int
	if fast_time:
		segundos_del_dia = int(future_second) % 86400
	else:
		segundos_del_dia = hour * 3600 + minute * 60 + second

	var day_of_year: int = _day_of_year(year, month, day)        # 1..365/366

	# calcular declinación solar (aprox armónica)
	var decl_deg: float = 23.43928 * sin( (TAU * float(day_of_year - 81)) / 365.0 )
	var decl_rad: float = deg_to_rad(decl_deg)

	# calcular hora solar local: hora UTC + longitude/15
	var utc_fraction: float = float(segundos_del_dia) / 3600.0    # horas fraccionales 0..24
	var local_solar_hours: float = utc_fraction + (longitude_deg / 15.0)
	local_solar_hours = fposmod(local_solar_hours, 24.0)
	var hour_angle_deg: float = (local_solar_hours - 12.0) * 15.0
	var hour_angle_rad: float = deg_to_rad(hour_angle_deg)

	var lat_rad: float = deg_to_rad(latitude_deg)

	# Elevación solar (approx)
	var sin_elev: float = sin(lat_rad) * sin(decl_rad) + cos(lat_rad) * cos(decl_rad) * cos(hour_angle_rad)
	sin_elev = clamp(sin_elev, -1.0, 1.0)
	var elev_rad: float = asin(sin_elev)

	# Azimut (aprox)
	var cos_az: float = 0.0
	var az_rad: float = 0.0
	var cos_lat: float = cos(lat_rad)
	var cos_elev: float = cos(elev_rad)
	if abs(cos_lat * cos_elev) > 1e-6:
		cos_az = (sin(decl_rad) - sin(lat_rad) * sin(elev_rad)) / (cos_lat * cos_elev)
		cos_az = clamp(cos_az, -1.0, 1.0)
		az_rad = acos(cos_az)
		if hour_angle_rad > 0.0:
			az_rad = TAU - az_rad
	else:
		az_rad = 0.0

	# Convertir azimuth/elevación a vector de dirección en coordenadas Godot (+Y up)
	var dir: Vector3 = _dir_from_az_el(az_rad, elev_rad)

	# Orientar la luz: la DirectionalLight apunta en -Z local; usamos look_at(earth_pos) desde sun_pos
	var earth_pos: Vector3 = earth_root.global_transform.origin if earth_root else Vector3.ZERO
	var sun_pos: Vector3 = earth_pos + dir * distance
	if sun_light:
		sun_light.global_transform.origin = sun_pos
		sun_light.look_at(earth_pos, Vector3.UP)

# Devuelve vector unitario desde la Tierra hacia el Sol (Godot coord: Y up)
func _dir_from_az_el(az_rad: float, el_rad: float) -> Vector3:
	var x: float = cos(el_rad) * sin(az_rad)   # east
	var y: float = sin(el_rad)                 # up
	var z: float = cos(el_rad) * cos(az_rad)   # north
	return Vector3(x, y, z).normalized()
