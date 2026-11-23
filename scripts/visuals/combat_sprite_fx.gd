extends Node2D
## Shared 4x6 generated sprite atlas; Phaser uses the same cells.
static var atlas: Texture2D
var sprite: Sprite2D
var row := 0
var special := false
var origin := Vector2.ZERO
var destination := Vector2.ZERO
var age := 0.0
var duration := 0.32
var base_size := 95.0
var frames: Array[int] = [1, 2, 3]
var textures: Array[AtlasTexture] = []

static func spawn(parent: Node2D, element: int, from: Vector2, to: Vector2, ultimate: bool) -> Node2D:
	var fx = load("res://scripts/visuals/combat_sprite_fx.gd").new()
	fx.row = clampi(element, 0, 5)
	fx.special = ultimate
	fx.origin = from
	fx.destination = to
	parent.add_child(fx)
	return fx

func _ready() -> void:
	if atlas == null: atlas = load("res://assets/combat/elements-atlas.png")
	duration = 0.72 if special else 0.32
	base_size = 230 if special else 100
	frames.assign([0, 1, 2, 3] if special else [1, 2, 3])
	var cell := Vector2(atlas.get_width() / 4.0, atlas.get_height() / 6.0)
	for column in frames:
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		texture.region = Rect2(Vector2(column, row) * cell, cell)
		textures.append(texture)
	sprite = Sprite2D.new()
	sprite.texture = textures[0]
	sprite.scale = Vector2.ONE * base_size / cell.y
	sprite.flip_h = destination.x < origin.x
	add_child(sprite)
	z_index = 900
	position = origin if special else destination
	_process(0)

func _process(delta: float) -> void:
	age += delta
	var phase := clampf(age / duration, 0, 1)
	var index := mini(textures.size() - 1, int(phase * frames.size()))
	sprite.texture = textures[index]
	position = origin.lerp(destination, clampf(phase * 2.4, 0, 1)) if special else destination
	var grow := (0.65 + minf(1.0, phase * 3) * 0.5) if special else (0.9 + phase * 0.2)
	sprite.scale = Vector2.ONE * base_size / (atlas.get_height() / 6.0) * grow
	modulate.a = 1.0 - maxf(0, (phase - 0.72) / 0.28)
	if phase >= 1: queue_free()
