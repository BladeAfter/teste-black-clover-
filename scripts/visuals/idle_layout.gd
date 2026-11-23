extends RefCounted
## Relative formation slots in the viewport's logical coordinate system.
## Slots 0/1 face the other team; slots 2/3/4 form the rear column.
const FRONT := [Vector2(0.365, 0.535), Vector2(0.365, 0.650)]
const BACK := [Vector2(0.170, 0.480), Vector2(0.170, 0.595), Vector2(0.170, 0.710)]

static func anchor(size: Vector2, slot: int, enemy: bool) -> Vector2:
	var point: Vector2 = FRONT[clampi(slot, 0, 1)] if slot < 2 else BACK[clampi(slot - 2, 0, 2)]
	if enemy: point.x = 1.0 - point.x
	return point * size

static func actor_scale(size: Vector2, slot: int) -> float:
	return 0.70 * minf(size.x / 1080.0, size.y / 1920.0) * (0.96 if slot >= 2 else 1.0)

static func safe_margins(viewport: Viewport) -> Vector2:
	var size := viewport.get_visible_rect().size
	var margins := Vector2(size.y * 0.015, size.y * 0.015)
	if OS.has_feature("mobile"):
		var screen := DisplayServer.screen_get_size()
		var safe := DisplayServer.get_display_safe_area()
		if screen.y > 0 and safe.size.y > 0:
			margins.x = maxf(margins.x, float(safe.position.y) / screen.y * size.y)
			margins.y = maxf(margins.y, float(screen.y - safe.end.y) / screen.y * size.y)
	return margins

static func ui_scale(size: Vector2) -> float:
	return minf(size.x / 1080.0 * 0.96, size.y / 1920.0)
