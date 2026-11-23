extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var scene := load("res://main.tscn").instantiate() as Node
	root.add_child(scene)
	current_scene = scene
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://asta-battle-preview.png")
	print("ASTA_CAPTURE_OK")
	quit()
