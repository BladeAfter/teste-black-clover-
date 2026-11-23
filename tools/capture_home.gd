extends SceneTree
func _initialize() -> void:
	call_deferred("_capture")
func _capture() -> void:
	root.size = Vector2i(720, 1280)
	var home = load("res://scenes/premium_home.tscn").instantiate()
	root.add_child(home)
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/home-premium-player.png")
	print("HOME_PLAYER_CAPTURE_OK")
	quit()
