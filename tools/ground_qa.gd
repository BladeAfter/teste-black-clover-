extends SceneTree
func _initialize(): call_deferred("run")
func run():
 root.size=Vector2i(1280,720)
 var home=load("res://scenes/premium_home.tscn").instantiate()
 home.game_save_path="user://ground_qa_game.json"
 home.home_save_path="user://ground_qa_profile.json"
 root.add_child(home)
 await process_frame
 home.game.set_process(false)
 home.activities.launch("Arena")
 await create_timer(0.6).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/arena-grounded.png")
 for unit in home.game.allies+home.game.foes:
  assert(unit.body.position==Vector2.ZERO)
  assert(unit.position.y>=260)
 for path in [home.game_save_path,home.home_save_path]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 print("GROUND_QA: PASS")
 quit()
