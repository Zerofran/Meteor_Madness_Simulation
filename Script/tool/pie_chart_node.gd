@tool
extends Node

@export var valores: Array[float] = [30.0, 45.0, 25.0]:
	set(value):
		valores = value
		_actualizar_leyendas()
		_redibujar()

@export var colores: Array[Color] = [
	Color(0, 1, 0),
	Color(0, 0, 1),
	Color(1, 0, 0),
]:
	set(value):
		colores = value
		_actualizar_leyendas()
		_redibujar()

@export var etiquetas: Array[String] = [
	"Local Effect", "Continental Effect", "Global Effect"
]:
	set(value):
		etiquetas = value
		_actualizar_leyendas()
		_redibujar()

@export var grapic_node: NodePath
@export var legend_container: NodePath
@export var legend_item_scene: PackedScene

func _ready() -> void:
	_actualizar_leyendas()
	_redibujar()

func _redibujar() -> void:
	if grapic_node == NodePath(""):
		return
	var canvas := get_node(grapic_node)
	if canvas and canvas.has_method("set_datos"):
		canvas.set_datos(valores, colores)
		canvas.queue_redraw()

func _actualizar_leyendas() -> void:
	if not legend_item_scene or legend_container == NodePath(""):
		return

	var contenedor := get_node(legend_container)
	for child in contenedor.get_children():
		contenedor.remove_child(child)
		child.queue_free()

	for i in valores.size():
		var item := legend_item_scene.instantiate()
		var color_rect := item.get_node("ColorRect") as ColorRect
		var label := item.get_node("legend_text") as Label

		color_rect.color = colores[i % colores.size()]
		var texto := etiquetas[i] if i < etiquetas.size() else "Segmento %d" % [i + 1]
		label.text = "%s: %.1f" % [texto, valores[i]] + "%"

		contenedor.add_child(item)
