extends SceneTree
const C=preload("res://scripts/content.gd")
const R=preload("res://scripts/skill_build.gd")
var checks=0
var failures=[]
func _initialize():
	run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func capture(name:String):
	var motion=InputEventMouseMotion.new();motion.position=Vector2(12,12);root.push_input(motion,true)
	await create_timer(.15).timeout;await process_frame;await RenderingServer.frame_post_draw
	var path=ProjectSettings.globalize_path("res://../artifacts/v04-tree-"+name+".png");DirAccess.make_dir_recursive_absolute(path.get_base_dir());check(root.get_texture().get_image().save_png(path)==OK,"capture "+name)
func learn_plan(session,p,id):
	var plan=R.path_plan(p,id);check(plan.ok,"valid path "+id)
	for step in plan.get("steps",[]):
		while R.rank(p,R.definition(step.id))<int(step.rank):
			if not session.act("invest",step.id):check(false,"path learns "+step.id);break
func all_class_readability(game):
	var local=game.session;var p=local.sim.players[1];var tree=game.skill_tree;var total=0
	for cls in C.CLASSES:
		p.class_id=cls;p.skill_ranks={};p.constellation_allocations={};p.skill_loadout={};local.sim.combat.jobs.reset(p);local.refresh()
		tree.choice="";tree.search.text="";tree.tag_filter="";tree.filter_index=0;tree.change_mode("skills")
		for cluster in range(5):
			tree.show_branch(cluster);await process_frame
			var controls=tree.nodes.values().filter(func(control):return control.visible)
			check(controls.size()<=20,cls+" branch has at most twenty choices")
			for control in controls:
				total+=1
				var label=control.name_label;var text_width=minf(label.size.x,label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x)
				var name_rect=Rect2(control.position+label.position+Vector2((label.size.x-text_width)*.5,0),Vector2(text_width,label.get_line_count()*label.get_line_height()))
				check(control.icon_rect().size.x>=48,cls+" large semantic glyph "+control.id)
				check(label.visible and label.get_line_count()*label.get_line_height()<=label.size.y+1,cls+" full skill name fits "+control.id)
				check(Rect2(Vector2.ZERO,tree.graph.size).encloses(control.get_rect()) and Rect2(Vector2.ZERO,tree.graph.size).encloses(name_rect),cls+" node and name inside branch "+control.id)
				check(not controls.any(func(other):return other!=control and other.get_rect().intersects(name_rect)),cls+" skill name avoids other node "+control.id)
				tree.select_node(control.id)
				if R.definition(control.id).type!="minor":check(tree.selected.text.replace("\n"," · ")==R.definition(control.id).name,"전체 이름을 생략 없이 두 줄로 표시: "+control.id)
				check(tree.selected.get_line_count()*tree.selected.get_line_height()<=tree.selected.size.y+1,cls+" selected title fits "+control.id)
				check(tree.status.get_line_count()*tree.status.get_line_height()<=tree.status.size.y+1,cls+" status fits "+control.id)
				check(tree.description.get_line_count()*tree.description.get_line_height()<=tree.description.size.y+1,cls+" prerequisites fit "+control.id)
			if cls in ["warrior","gambler"] and cluster==0:await capture("large-"+cls)
	check(total==1510,"all1510 skills retain readable branch glyphs and names")
func run():
	# Full HD client area, independent of desktop title-bar constraints.
	root.borderless=true;root.size=Vector2i(1920,1080)
	var game=load("res://main.tscn").instantiate();game.options.mute=true;root.add_child(game);await process_frame
	var local=game.session;local.save_directory=ProjectSettings.globalize_path("res://../runtime/tree-v04/"+str(Time.get_ticks_usec()));game.join_game();local.set_physics_process(false);game.set_physics_process(false)
	var p=local.sim.players[1];p.level=100;p.tutorial_done=true;local.travel("town");p=local.sim.players[1]
	check(local.act("class","fighter") and local.act("class","breaker"),"enter breaker fixture");local.refresh();game.toggle_skills();var tree=game.skill_tree
	check(local.paused,"graph pauses world");check(tree.nodes.size()==C.SKILLS.breaker.size()+45,"originals and45 choices in onegraph")
	check(tree.graph.centers.size()==5,"five themed clusters");check(tree.graph.scope_cluster==0 and tree.graph.zoom>.5,"first entry focuses readable first branch")
	check(tree.nodes.values().filter(func(control):return control.visible).size()<tree.nodes.size()/2,"first branch hides unrelated choices")
	check(tree.branch_picker.item_count==6 and tree.branch_picker.selected==1,"five branch choices and optional full map")
	var original=C.SKILLS.breaker.filter(func(n):return n.effect=="active")[0];tree.select_node(original.id)
	var expected=preload("res://scripts/job_balance.gd").metrics(p,original,1,local.sim.damage_for(p),p.max_hp)
	for metric in expected:
		check(tree.comparison_rows.any(func(row):return row[0]==metric[0] and row[2]==metric[1]),"original combat value matches runtime including stamina: "+metric[0])
	await capture("branch")
	var click_target=tree.nodes.values().filter(func(control):return control.visible and control.id!=tree.choice)[0]
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=click_target.get_global_transform_with_canvas()*(click_target.size*.5);event.pressed=true;root.push_input(event,true);event=event.duplicate();event.pressed=false;root.push_input(event,true);await process_frame
	check(tree.choice==click_target.id and local.paused,"actual node click respects centered Full HD canvas and keeps combat paused")
	var before_browse=JSON.stringify(p);var discovered={}
	for cluster in range(5):
		tree.show_branch(cluster);check(tree.graph.scope_cluster==cluster,"branch navigation "+str(cluster))
		for id in tree.nodes:
			if tree.nodes[id].visible:discovered[id]=true
	check(discovered.size()==tree.nodes.size(),"five branches expose every original and specialization")
	check(JSON.stringify(p)==before_browse,"branch navigation never allocates points")
	tree.select_node("breaker:star:4:key");tree.show_path()
	check(tree.graph.planned_ids.all(func(id):return tree.graph.in_scope(id)),"path preview reveals prerequisites outside current branch")
	check(tree.graph.scope_extra.keys().any(func(id):return int(R.definition(id).get("cluster",0))!=4),"cross-branch path remains connected")
	check(JSON.stringify(p)==before_browse,"cross-branch plan keeps investment explicit");await capture("branch-path")
	for id in tree.nodes:
		var control=tree.nodes[id];check(control.icon!=null and control.size.x>=26,"illustrated accessible node target %s %s"%[id,str(control.size)])
	for id in tree.graph.positions:
		tree.graph.focus_node(id);tree.graph.clamp_pan();tree.graph.layout_controls()
		check(Rect2(Vector2.ZERO,tree.graph.size).encloses(tree.nodes[id].get_rect()),"pan limits let every target be revealed "+id)
	tree.graph.fit_all()
	check(tree.graph.scope_cluster==-1 and tree.nodes.values().all(func(control):return control.visible),"optional full map shows every node")
	await capture("overview")
	check(tree.graph.get_rect().end.y<tree.overview_button.position.y,"map nodes cannot overlap camera toolbar")
	var anchor=Vector2(360,200);var world=tree.graph.view_to_world(anchor);tree.graph.zoom_at(anchor,1.5)
	check(tree.graph.view_to_world(anchor).distance_to(world)<.01,"cursor anchored zoom")
	var old_offset=tree.graph.offset;tree.graph.pan_by(Vector2(90,-30));check(tree.graph.offset!=old_offset,"two axis pan")
	var down=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_MIDDLE;down.pressed=true;down.position=Vector2(340,190);tree.graph._gui_input(down)
	var moved=InputEventMouseMotion.new();moved.position=down.position+Vector2(60,40);old_offset=tree.graph.offset;tree.graph._gui_input(moved)
	check(tree.graph.offset.distance_to(old_offset+Vector2(60,40))<.01,"middle drag moves map by pointer distance");down.pressed=false;tree.graph._gui_input(down);check(not tree.graph.dragging,"release ends pan gesture")
	var target="breaker:star:0:key";tree.select_node(target);tree.focus_choice();check(tree.graph.zoom>=.8,"selected node readable zoom")
	check(tree.graph.world_to_view(tree.graph.positions[target]).distance_to(tree.graph.size*.5)<1,"select focuses target")
	check("선택의 대가" in tree.detail_body.text and "함께 쓰는 방식" in tree.detail_body.text,"behavior and tradeoffs visible")
	check("선행" in tree.description.text and "현재 선택과 충돌" not in tree.detail_body.text,"prerequisites are not falsely marked as exclusion")
	var before=JSON.stringify(p);tree.show_path();check(tree.graph.planned_ids.size()>0,"path preview highlights actual steps");check(JSON.stringify(p)==before,"path preview read only")
	await capture("choice")
	check(tree.description.get_rect().end.y<tree.comparison_scroll.position.y,"description never overlaps long effects")
	learn_plan(local,p,target);tree.refresh(true);check(R.rank(p,R.definition(target))==1,"learned keystone")
	tree.select_node("breaker:star:1:key");tree.focus_choice();check(tree.invest.disabled==not R.node_state(p,tree.choice).can_invest,"UI mirrors allocation rule");check(tree.graph.planned_ids.is_empty(),"new selection clears stale path preview")
	learn_plan(local,p,"breaker:star:1:n0");learn_plan(local,p,"breaker:star:1:n1");tree.refresh(true)
	check(tree.invest.disabled and "배타" in tree.status.text,"incompatible choice explained")
	await capture("excluded")
	tree.select_node("breaker:star:0:m0");tree.preview_refund();check("회수 미리보기" in tree.detail_body.text,"refund dependent preview")
	var invested=JSON.stringify(p);tree.refresh(true);check(JSON.stringify(p)==invested,"refund preview read only");tree.invest.pressed.emit();check(R.rank(p,R.definition(target))==0,"dependent keystone removed atomically")
	tree.refund_mode=false;var dodge_name=R.definition("breaker:star:2:key").name;tree.search.text=dodge_name;tree.apply_search();check(tree.selected.tooltip_text==dodge_name,"현재 한국어 이름 검색과 전체 이름 툴팁")
	tree.show_branch(0);tree.search.text=R.definition("breaker:star:4:key").name;tree.apply_search();check(tree.graph.scope_cluster==4 and tree.nodes[tree.choice].visible,"cross-branch search reveals matching choice")
	tree.search.text="존재하지않는별자리_xyz";tree.apply_search();check("조건에 맞는" in tree.notice.text,"empty search state")
	tree.search.text="";tree.tag_filter="행동 변화";tree.refresh(true);check(tree.node_list.filter(func(n):return tree.matches(n,p)).size()==5,"tag filter finds five keystones")
	tree.tag_filter="";tree.change_mode("stats");check(tree.stats_panel.visible and tree.stat_buttons.size()==5 and not tree.graph.visible,"five stats preserved");await capture("stats")
	tree.change_mode("class");var original_class=p.class_id;tree.class_picker.select(C.CLASSES.keys().find("ranger"));tree.class_picker.item_selected.emit(tree.class_picker.selected)
	game.dungeon.zone="forest";tree.refresh_class();check(tree.class_commit.disabled,"forest safe area cannot bypass town-only class change");game.dungeon.zone="town";tree.refresh_class()
	check(p.class_id==original_class and tree.class_commit.disabled==false,"class preview requires explicit commit");await capture("class");tree.class_commit.pressed.emit();check(p.class_id=="ranger","class commit works")
	game.toggle_skills();game.toggle_codex("skills");game.codex.open("skills",{"class_id":"breaker","effect":"constellation"});game.codex.select_record(target)
	check(game.codex.result.total==45 and "선택의 대가" in game.codex.detail_body.text,"codex mirrors specialization choices")
	check(not game.codex.reference_picker.visible and "무력화 없음" not in game.codex.detail_body.text,"no inactive stagger noise in specialization DB");await capture("codex")
	game.codex.close();game.toggle_skills();await all_class_readability(game);game.stop_audio();local.disconnect_game();game.queue_free();await process_frame;print("SKILL_TREE_UI_V04_TESTS checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
