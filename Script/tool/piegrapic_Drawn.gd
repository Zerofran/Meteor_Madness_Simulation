@tool
extends Control

var valores: Array[float] = []
var colores: Array[Color] = []

func set_datos(v: Array[float], c: Array[Color]) -> void:
	valores = v
	colores = c
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW:
		_dibujar()

func _dibujar() -> void:
	var total: float = 0.0
	for v in valores:
		total += v
	if total == 0.0:
		return

	var center: Vector2 = size / 2.0
	var radius: float = min(size.x, size.y) * 0.45
	var start_angle: float = 0.0

	for i in valores.size():
		var fraccion: float = valores[i] / total
		var sweep: float = fraccion * TAU
		var end_angle: float = start_angle + sweep
		var color: Color = colores[i % colores.size()]

		var puntos: Array[Vector2] = [center]
		var segmentos: int = 32
		for j in range(segmentos + 1):
			var t: float = float(j) / float(segmentos)
			var angle: float = lerp(start_angle, end_angle, t)
			var punto: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
			puntos.append(punto)

		draw_polygon(puntos, [color])
		start_angle = end_angle
