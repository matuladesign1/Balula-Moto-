class_name TouchPad
extends Control
## Gros bouton tactile qui gère plusieurs doigts en même temps (accélérer + tourner).
## Il appuie sur une "action" (accelerate, brake, steer_left, steer_right) tant qu'un doigt est dessus.
## Avec la souris sur ordinateur, ça marche aussi (le projet émule le toucher avec la souris).

var action := ""
var caption := ""
var base_color := Color(1, 1, 1, 0.18)

var _finger := -1
var _pressed := false


func setup(p_action: String, p_caption: String, size_px: Vector2, color: Color) -> void:
	action = p_action
	caption = p_caption
	base_color = color
	custom_minimum_size = size_px
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # les touches sont lues dans _input


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _finger == -1 and _contains(t.position):
				_finger = t.index
				_set_pressed(true)
		elif t.index == _finger:
			_finger = -1
			_set_pressed(false)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _finger:
			if not _contains(d.position):
				_finger = -1
				_set_pressed(false)      # le doigt est sorti du bouton
		elif _finger == -1 and _contains(d.position):
			_finger = d.index            # le doigt glisse d'un bouton à l'autre
			_set_pressed(true)


func _contains(p: Vector2) -> bool:
	var local := get_global_transform_with_canvas().affine_inverse() * p
	return Rect2(Vector2.ZERO, size).has_point(local)


## Relâche le bouton (utilisé quand le jeu passe en pause).
func release_all() -> void:
	_finger = -1
	_set_pressed(false)


func _set_pressed(on: bool) -> void:
	if on == _pressed:
		return
	_pressed = on
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and _pressed:
		_finger = -1
		_set_pressed(false)


func _exit_tree() -> void:
	if _pressed:
		Input.action_release(action)


func _draw() -> void:
	var c := size * 0.5
	var rad := minf(size.x, size.y) * 0.5
	var col := base_color
	if _pressed:
		col = Color(base_color.r, base_color.g, base_color.b, 0.6).lightened(0.3)
	draw_circle(c, rad, col)
	draw_arc(c, rad - 2.0, 0.0, TAU, 48, Color(1, 1, 1, 0.55), 3.0, true)
	var font := ThemeDB.fallback_font
	var fs := 26
	var ts := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	draw_string(font, Vector2(c.x - ts.x * 0.5, c.y + ts.y * 0.28), caption, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color.WHITE)
