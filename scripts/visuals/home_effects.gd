extends Node2D
## Lightweight ambient overlays, independent of the static kingdom illustration.
var clock := 0.0
var enabled := true
var petals: Array = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 435
	for i in range(28):
		petals.append(Vector3(rng.randf_range(0, 720), rng.randf_range(200, 1130), rng.randf_range(0.4, 1.0)))
	z_index = 1

func _process(delta: float) -> void:
	if not enabled: return
	clock += delta
	queue_redraw()

func _draw() -> void:
	for i in range(petals.size()):
		var p: Vector3 = petals[i]
		var pos := Vector2(fposmod(p.x + clock * (5 + p.z * 4) + sin(clock + i) * 10, 740) - 10, 180 + fposmod(p.y - 180 + clock * 9 * p.z, 940))
		draw_circle(pos, 1.3 + p.z, Color(1, 0.83, 0.9, 0.5 * p.z))
	for center in [Vector2(120, 594), Vector2(115, 782)]:
		var opacity := 0.23 + sin(clock * 2.0) * 0.10
		draw_arc(center, 27 + sin(clock * 1.6) * 2, -clock * 0.4, TAU - clock * 0.4 - 0.3, 48, Color(0.86, 0.49, 1, opacity), 3, true)
		for i in range(5):
			var phase := clock * 0.35 + i * TAU / 5
			draw_circle(center + Vector2(cos(phase) * 27, sin(phase) * 37), 2, Color(0.96, 0.83, 1, opacity + 0.2))
	# Water shimmer follows the waterfall channels in the artwork.
	for i in range(18):
		var x: float = [318.0, 345.0, 513.0][i % 3] + sin(i * 14.0) * 5
		var y := 377 + fposmod(clock * 72 + i * 37, 183)
		draw_line(Vector2(x, y), Vector2(x - 1, y + 13), Color(0.75, 0.97, 1, 0.11), 1.4, true)
	# Golden orbit and rising motes around the central clover.
	for i in range(16):
		var phase := clock * 0.4 + i * TAU / 16
		var pos := Vector2(360 + cos(phase) * (56 + i * 2), 730 - fposmod(clock * 16 + i * 13, 124))
		draw_circle(pos, 1.4, Color(1, 0.85, 0.39, 0.35 + sin(clock + i) * 0.2))
	# Very faint cloud wisps drift across the upper sky.
	for i in range(3):
		var x := fposmod(clock * 3 + i * 283, 1000) - 150
		draw_set_transform(Vector2(x, 135 + i * 23), 0, Vector2(2.6, 0.35))
		draw_circle(Vector2.ZERO, 24, Color(0.9, 0.96, 1, 0.04))
	draw_set_transform(Vector2.ZERO)
