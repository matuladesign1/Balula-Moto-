class_name Minimap
extends Control
## Mini-carte : le véhicule est au centre, la carte tourne pour que "devant" soit toujours en haut.
## La carte (TestMap ou KinshasaMap) fournit : road_rects, road_lines, building_rects, landmarks.

var map = null
var target: Node3D
var pixels_per_meter := 0.8

var _t := 0.0


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(190, 190)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	if _t >= 0.066:
		_t = 0.0
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.08, 0.12, 0.88))
	if map != null and target != null and is_instance_valid(target):
		var c := size * 0.5
		var p := Vector2(target.global_position.x, target.global_position.z)
		var cull := size.length() * 0.5 / pixels_per_meter + 40.0
		var cull2 := cull * cull
		draw_set_transform(c, target.global_rotation.y, Vector2(pixels_per_meter, pixels_per_meter))
		var rects: Variant = map.get("road_rects")
		if rects is Array:
			for r in rects:
				draw_rect(Rect2(r.position - p, r.size), Color("#8b93a1"))
		var lines: Variant = map.get("road_lines")
		if lines is Array:
			for ln in lines:
				var a: Vector2 = ln["a"]
				var b: Vector2 = ln["b"]
				if a.distance_squared_to(p) > cull2 and b.distance_squared_to(p) > cull2:
					continue
				draw_line(a - p, b - p, Color("#8b93a1"), float(ln["w"]))
		var blds: Variant = map.get("building_rects")
		if blds is Array:
			for r in blds:
				draw_rect(Rect2(r.position - p, r.size), Color("#4b5565"))
		var lms: Variant = map.get("landmarks")
		if lms is Array:
			for lm in lms:
				var lp: Vector2 = lm["pos"]
				draw_circle(lp - p, 5.0 / pixels_per_meter, lm["color"])
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -10), c + Vector2(7, 8), c + Vector2(-7, 8)]), Color("#f7c600"))
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.7), false, 2.0)
