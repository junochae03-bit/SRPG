extends SceneTree
const Content=preload("res://scripts/content.gd")
const Rules=preload("res://scripts/skill_build.gd")
const Presentation=preload("res://scripts/skill_presentation.gd")
const Balance=preload("res://scripts/job_balance.gd")
var checks=0
var failures=[]
var screenshots=[]
var surface:SubViewport
func _initialize():run.call_deferred()
func check(value:bool,label:String):
	checks+=1
	if not value:failures.append(label);push_error(label)
func fitted(label:Label,context:String):
	check(label.get_line_count()*label.get_line_height()<=label.size.y+1,"full glyph height "+context+" "+label.text)
	if label.autowrap_mode==TextServer.AUTOWRAP_OFF:
		check(label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x<=label.size.x+1,"full glyph width "+context+" "+label.text)
func learn_plan(session,p,id:String):
	var plan=Rules.path_plan(p,id);check(plan.ok,"learnable path "+id)
	for step in plan.get("steps",[]):
		while Rules.rank(p,Rules.definition(str(step.id)))<int(step.rank):
			if not session.act("invest",step.id):check(false,"invest real prerequisite "+step.id);return
func capture(name:String):
	var event=InputEventMouseMotion.new();event.position=Vector2(10,10);surface.push_input(event,true)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var image=surface.get_texture().get_image();check(image.get_size()==Vector2i(1920,1080),"FullHD "+name)
	var relative="artifacts/skill-clarity-v052-"+name+".png";var path=ProjectSettings.globalize_path("res://../"+relative);DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	check(image.save_png(path)==OK,"render "+name);screenshots.append(relative)
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	surface=SubViewport.new();surface.size=Vector2i(1920,1080);surface.size_2d_override=Vector2i(1600,900);surface.size_2d_override_stretch=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;surface.gui_embed_subwindows=true;root.add_child(surface)
	var game=load("res://main.tscn").instantiate();game.options.mute=true;surface.add_child(game);await process_frame
	var session=game.session;session.save_directory=ProjectSettings.globalize_path("res://../runtime/skill-clarity-v052/"+str(Time.get_ticks_usec()))
	game.join_game();session.set_physics_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false)
	var p=session.sim.players[1];p.level=100;p.tutorial_done=true;session.travel("town");p=session.sim.players[1];game.toggle_skills();var tree=game.skill_tree
	var all_nodes=0;var actives=0;var keys=0;var branch_checks=0
	for class_id in Content.CLASSES:
		p.class_id=class_id;p.level=100;p.skill_ranks={};p.constellation_allocations={};p.skill_loadout={};session.sim.combat.jobs.reset(p);session.sim.recalculate(p);session.refresh()
		tree.choice="";tree.search.text="";tree.tag_filter="";tree.filter_index=0;tree.change_mode("skills")
		check(tree.branch_buttons.size()==3,"three display groups "+class_id)
		check(tree.graph.scope_cluster==-1 and Rules.node_state(p,tree.choice).can_invest,"first view opens unfiltered readable map with a learnable entry "+class_id)
		check(tree.nodes.values().any(func(node):return node.visible and Rules.node_state(p,node.id).can_invest),"first view contains actual next investments "+class_id)
		check(not tree.headline_rows.any(func(row):return str(row[1])=="0.0" and str(row[2])=="0.0"),"non-attacking skills omit zero stagger from main outcomes "+class_id)
		await capture(class_id+"-entry")
		for node in Rules.nodes_for(class_id):
			all_nodes+=1;var caption=Presentation.short_label(node)
			check(not caption.is_empty(),"mechanical caption "+node.id)
			check(tree.nodes[node.id].tooltip_text.begins_with(node.name),"canonical name retained "+node.id)
			if node.effect=="active":
				actives+=1;check(Presentation.MODE_LABELS.has(Presentation.mode(node)),"explicit active pattern "+node.id)
				check(tree.nodes[node.id].shape()=="active_square" and tree.nodes[node.id].active_badge(),"active shape and badge "+node.id)
			else:check(not tree.nodes[node.id].active_badge(),"passive cannot impersonate active "+node.id)
			if node.type=="keystone":keys+=1;check(Presentation.key_effect(node)!="","known branch result "+node.id)
		for cluster in range(3):
			# Browsing must preserve build and point allocation. Runtime rendering
			# may refresh transient combat caches during the awaited input frame.
			var unchanged=JSON.stringify([p.class_id,p.skill_ranks,p.constellation_allocations,p.skill_loadout,Rules.available_points(p)])
			var target=tree.branch_buttons[cluster].get_global_transform_with_canvas()*(tree.branch_buttons[cluster].size*.5)
			var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=target;surface.push_input(click,true)
			click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=false;click.position=target;surface.push_input(click,true);await process_frame
			check(tree.graph.scope_cluster==cluster and JSON.stringify([p.class_id,p.skill_ranks,p.constellation_allocations,p.skill_loadout,Rules.available_points(p)])==unchanged,"branch click browses without spending %s%d actual_branch=%s"%[class_id,cluster,tree.graph.scope_cluster]);branch_checks+=1
			check(not str(tree.branch_buttons[cluster].get_meta("branch_outcome","")).is_empty(),"branch states resulting play style")
			fitted(tree.branch_labels[cluster],"branch tab")
			var visible=tree.nodes.values().filter(func(node):return node.visible)
			for control in visible:
				check(control.size.x>=64,"readable skill icon "+control.id)
				if not control.name_label.visible:continue
				fitted(control.name_label,"node "+control.id)
				var label_rect=Rect2(control.position+control.name_label.position,Vector2(control.name_label.size.x,control.name_label.get_line_count()*control.name_label.get_line_height()))
				check(Rect2(Vector2.ZERO,tree.graph.size).encloses(label_rect),"effect caption inside graph "+control.id)
				check(not visible.any(func(other):return other!=control and other.get_rect().intersects(label_rect)),"effect caption clear of other icons "+control.id)
				check(not visible.any(func(other):return other!=control and other.role_badge_rect().has_area() and Rect2(other.position+other.role_badge_rect().position,other.role_badge_rect().size).intersects(label_rect)),"role badge cannot cover another effect caption "+control.id)
				if control.role_badge_rect().has_area():
					check(Rect2(Vector2.ZERO,tree.graph.size).encloses(Rect2(control.position+control.role_badge_rect().position,control.role_badge_rect().size)),"role badge inside graph "+control.id)
		if class_id in ["warrior","breaker","healer"]:
			tree.show_branch(0);var active=Rules.nodes_for(class_id).filter(func(node):return node.effect=="active")[0]
			tree.select_node(active.id);tree.graph.fit_scope();await process_frame
			check(tree.status.text.begins_with("액티브"),"detail explicitly identifies active "+class_id)
			check(tree.headline_rows.size()>0 and tree.headline_rows.size()<=3,"three main outcome comparisons "+class_id)
			for pair in tree.impact_labels:
				if pair[0].visible:fitted(pair[0],"summary title");fitted(pair[1],"summary value")
			await capture(class_id+"-active")
			learn_plan(session,p,active.id);tree.refresh(true)
			for slot in range(6):tree.bind_buttons[slot].pressed.emit();check(Content.active_node(p,Content.ACTIONS[slot]).id==active.id,"actual six-slot assignment "+class_id+str(slot))
			if active.get("runtime","")=="job":
				var exact=Presentation.shape_rows(p,Rules.definition(active.id),Rules.rank(p,active),session.sim.damage_for(p),p.max_hp)
				for row in exact:check(tree.comparison_rows.any(func(compare):return compare[0]==row[0] and compare[1]==row[1]),"geometry comparison uses cast profile "+active.id)
	# A no-SP build must show the real potential improvement while refusing spend.
	p.class_id="warrior";p.level=2;p.skill_ranks={"blade":1};p.constellation_allocations={};p.skill_loadout={};session.sim.combat.jobs.reset(p);session.sim.recalculate(p);session.refresh()
	tree.choice="";tree.refresh(true);tree.select_node("warrior:star:0:m0");await process_frame
	check(tree.invest.disabled and Rules.available_points(p)==0,"no points cannot invest")
	check(tree.comparison_rows[0][1]!=tree.comparison_rows[0][2],"locked node previews actual improvement rather than 0 to 0")
	check(p.constellation_allocations.is_empty(),"hypothetical preview never changes build")
	await capture("locked-preview")
	p.level=100;p.skill_ranks={};session.refresh();tree.select_node("warrior:star:4:key")
	var unchanged=JSON.stringify(p);tree.show_path();await process_frame
	check(tree.next_step_button.visible and not tree.route_target.is_empty(),"path offers a concrete first investment")
	var expected=Rules.path_plan(p,tree.route_target).steps[0].id;tree.next_step_button.pressed.emit();await process_frame
	check(tree.choice==expected and JSON.stringify(p)==unchanged,"next-step action selects prerequisite without buying it")
	tree.graph.fit_scope();await capture("next-prerequisite")
	tree.select_node("blade_wave");var plan=Rules.path_plan(p,"blade_wave");check(plan.ok and plan.steps.size()>1,"locked active has a real prerequisite route")
	check(tree.path_button.text=="선행으로","locked active offers prerequisite navigation")
	tree.path_button.pressed.emit();await process_frame
	check(tree.choice==plan.steps[0].id and not tree.invest.disabled,"one click reveals an immediately learnable prerequisite")
	check(JSON.stringify(p)==unchanged and not tree.graph.planned_ids.is_empty(),"one-click route highlights without allocating")
	p.class_id="ranger";p.skill_ranks={};p.constellation_allocations={};p.skill_loadout={};session.sim.recalculate(p);session.refresh()
	learn_plan(session,p,"ranger:star:3:key");learn_plan(session,p,"ranger:star:1:n0");learn_plan(session,p,"ranger:star:1:n1")
	tree.choice="";tree.refresh(true);tree.select_node("ranger:star:1:key");await process_frame
	check(tree.invest.disabled and "배타" in tree.status.text,"exclusive route explains conflict")
	fitted(tree.status,"exclusive route status");await capture("exclusive-route")
	check(all_nodes==1510 and keys==100 and actives>200 and branch_checks==60,"all classes and branches retained")
	check(tree.comparison_scroll.get_rect().end.y<tree.prerequisites.position.y,"summary and long details stay within scrolling body")
	var report={"suite":"skill_clarity_v052","checks":checks,"failures":failures,"nodes":all_nodes,"active_nodes":actives,"branches":branch_checks,"screenshots":screenshots}
	var output=FileAccess.open("res://../artifacts/skill-clarity-v052.json",FileAccess.WRITE);output.store_string(JSON.stringify(report,"\t"));output.close()
	game.stop_audio();session.disconnect_game();game.queue_free();await process_frame;await process_frame
	print("SKILL_CLARITY_V052 checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
