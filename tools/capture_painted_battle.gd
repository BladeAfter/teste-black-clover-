extends SceneTree
func _initialize() -> void:
	call_deferred("_capture")
func _capture() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(810, 1440)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	view.size_2d_override = Vector2i(1080, 1920)
	view.size_2d_override_stretch = true
	var scene := load("res://main.tscn").instantiate() as Node
	view.add_child(scene)
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://artifacts/visual-v2/battle-action.png")
	print("LIVE_CAPTURE_OK")
	quit()