extends SceneTree
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	var game=load("res://main.tscn").instantiate();game.options.mute=true
	game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/skill-conditions-visual/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game();game.set_process(false);game.set_physics_process(false);game.session.set_physics_process(false)
	var p=game.session.sim.players[1];p.level=100
	game.toggle_skills();var tree=game.skill_tree
	for row in [["elementalist","elementalist_a02","표적 추적"],["sniper","sniper_a01","시전 중 이동"],["tank","tank_a05","방어·시전 보호"]]:
		p.class_id=row[0];p.skill_ranks={row[1]:1};p.constellation_allocations={};p.skill_loadout={"skill_q":row[1]}
		game.session.sim.combat.jobs.reset(p);game.session.refresh();tree.choice="";tree.refresh(true);tree.select_node(row[1]);await process_frame
		check(row[2] in tree.detail_body.text,"condition shown "+row[0])
		# The lower numeric details scroll independently; bring conditions into view.
		tree.comparison_scroll.scroll_vertical=340;await process_frame;await RenderingServer.frame_post_draw
		check(tree.comparison_scroll.get_global_rect().end.y<root.size.y,"details stay inside viewport")
		check(tree.selected.get_line_count()*tree.selected.get_line_height()<=tree.selected.size.y+1,"title fits")
		check(root.get_texture().get_image().save_png("res://../artifacts/skill-conditions-"+row[0]+".png")==OK,"framebuffer "+row[0])
	game.queue_free();await process_frame
	print("SKILL_CONDITIONS_VISUAL checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
