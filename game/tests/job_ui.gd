extends SceneTree
const Content=preload("res://scripts/content.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
	var game=load("res://main.tscn").instantiate();game.options.mute=true;root.add_child(game);await process_frame
	game.session.save_directory=ProjectSettings.globalize_path("res://../runtime/job-ui/"+str(Time.get_ticks_usec()));game.join_game();game.session.set_physics_process(false);game.set_physics_process(false)
	game.session.sim.players[1].tutorial_done=true;game.session.travel("town")
	var p=game.session.sim.players[1];p.level=100;game.toggle_skills();var tree=game.skill_tree
	for job in Content.CLASSES:
		game.session.act("class",Content.base_class(job));game.session.act("class",job);tree.choice="";tree.search.text="";tree.filter_index=0;game.session.refresh();tree.refresh(true)
		check(tree.nodes.size()==Content.SKILLS[job].size()+45,"originals and specializations visible in connected graph "+job)
		var rects=[]
		for node in Content.SKILLS[job]:
			var control=tree.nodes[node.id]
			check(control.icon!=null and control.size.x>=26,"illustrated zoomable node "+node.id)
			check(not rects.any(func(rect):return rect.intersects(control.get_rect())),"nodes do not overlap "+node.id)
			rects.append(control.get_rect())
		var actives=Content.SKILLS[job].filter(func(n):return n.effect=="active")
		if not Content.job(p):continue
		for i in range(mini(6,actives.size())):
			var n=actives[i]
			for parent in n.parents:p.skill_ranks[parent]=1
			tree.choice=n.id;tree.refresh(true);tree.invest.pressed.emit()
			check(p.skill_ranks.get(n.id,0)>0,"UI learns skill "+n.id)
			tree.bind_buttons[i].pressed.emit();check(p.skill_loadout.get(Content.ACTIONS[i],"")==n.id,"six slot UI assignment "+n.id)
		var selected=actives[0];tree.search.text=selected.name;tree.apply_search()
		check(tree.choice==selected.id,"search finds selected path "+job)
		var prior=tree.comparison_rows.duplicate(true);tree.invest.pressed.emit()
		check(tree.comparison_rows!=prior,"rank investment changes comparison "+job)
		tree.search.text="존재하지않는검색어";tree.apply_search()
		check(tree.notice.text.contains("조건에 맞는"),"empty search explains result "+job)
		tree.search.text="";tree.filter_index=0;tree.refresh(true)
		var child=Content.SKILLS[job].filter(func(n):return not n.parents.is_empty())[0];tree.choice=child.id;tree.refresh(true)
		var parent_buttons=tree.prerequisites.find_children("*","Button",true,false).filter(func(c):return c.get_meta("related_id","")==child.parents[0])
		check(parent_buttons.size()==1,"scrollable prerequisite exposes exact parent "+job)
		if not parent_buttons.is_empty():parent_buttons[0].pressed.emit()
		check(tree.choice==child.parents[0],"prerequisite button reveals parent "+job)
		var same_detail=tree.details.get_instance_id();var before_rank=int(p.skill_ranks.get(tree.choice,0))
		if not tree.invest.disabled:
			tree.invest.pressed.emit();check(int(p.skill_ranks.get(tree.choice,0))==before_rank+1 and tree.details.get_instance_id()==same_detail,"prerequisite investment stays in the same detail panel "+job)
		game.session.refresh();game.hud.refresh()
		check(game.hud.job_resource.heading.text.contains(Content.CLASSES[job].name),"HUD identifies job resource "+job)
	game.toggle_skills()
	var controls=game.hud.circles.values();var rectangles=[]
	for c in controls:
		if not c.visible:continue
		var rect=c.get_rect().grow(3)
		for other in rectangles:check(not rect.intersects(other),"combat buttons and captions do not overlap "+c.kind)
		rectangles.append(rect)
	for i in range(6):check(game.hud.circles[Content.ACTIONS[i]].position==Vector2(500+i*90,803),"horizontal Q F V C Z X visual order")
	game.session.save_game();check(game.session.parse_save(game.session.save_path())!=null,"new starter and advanced investments remain readable")
	game.stop_audio();game.session.disconnect_game();game.queue_free();await process_frame;await process_frame
	print("JOB_UI_TESTS checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
