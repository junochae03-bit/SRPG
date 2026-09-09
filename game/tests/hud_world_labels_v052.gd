extends SceneTree
const World=preload("res://scripts/world_catalog.gd")
const Dungeon=preload("res://scripts/dungeon.gd")
const Training=preload("res://scripts/training_ground.gd")
const TrainingArt=preload("res://scripts/training_art.gd")
const Aim=preload("res://scripts/monster_aim.gd")
var checks=0
var failures=[]
var captures=[]
var geometry_cases=[]
var surface:SubViewport
var game
var session
var p:Dictionary
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func place_label(world:Vector2,offset:Vector2,baseline:Vector2,zoom:float=1.):
	var anchor=game.screen_center()
	surface.canvas_transform=Transform2D(Vector2(zoom,0),Vector2(0,zoom),anchor*(1.-zoom))
	var unzoomed=surface.canvas_transform.affine_inverse()*baseline
	game.camera_pos=Dungeon.iso(world)+anchor+offset-unzoomed
	game.smooth_positions.clear();game.refresh_world_label_regions()
func skill_caption()->Vector2:
	var control=game.hud.circles.skill_v
	return control.get_global_transform_with_canvas()*Vector2(control.size.x*.5,control.size.y+21)
func draw_frame():
	# 이 검사는 일반 처리 루프를 멈추므로 이동한 검사 카메라를 지면에도 반영합니다.
	game.forest.update_camera(0.)
	game.smooth_positions.clear();game.queue_redraw();game.map_overlay.queue_redraw()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
func capture(name:String):
	await draw_frame();var image=surface.get_texture().get_image()
	check(image.get_size()==surface.size,"실제 해상도 "+name)
	var path="res://../artifacts/hud-world-labels-v052-"+name+".png"
	check(image.save_png(ProjectSettings.globalize_path(path))==OK,"화면 저장 "+name);captures.append(path)
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	surface=SubViewport.new();surface.size=Vector2i(1920,1080);surface.size_2d_override=Vector2i(1600,900);surface.size_2d_override_stretch=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;surface.gui_embed_subwindows=true;root.add_child(surface)
	game=load("res://main.tscn").instantiate();game.options.mute=true;surface.add_child(game);await process_frame
	session=game.session;session.save_directory=ProjectSettings.globalize_path("res://../runtime/hud-world-labels-v052/"+str(Time.get_ticks_usec()));game.join_game()
	session.sim.players[1].tutorial_done=true;check(session.travel("town"),"실제 마을 입장")
	session.set_physics_process(false);game.set_physics_process(false);game.set_process(false);game.set_process_unhandled_input(false)
	p=session.sim.players[1];p.level=100;session.sim.recalculate(p);session.refresh()
	var dummy=session.sim.enemies.values().filter(func(enemy):return enemy.get("training",false))[0]
	var name=str(dummy.name);var offset=Vector2(0,-TrainingArt.HEIGHT-20)
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440)]:
		surface.size=resolution;await process_frame;await process_frame
		var target=skill_caption();var control=game.hud.circles.skill_v
		check(not (control.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,control.size)).has_point(target),"기술명은 버튼 바깥에 위치 "+str(resolution))
		for zoom in [.72,1.,1.18]:
			place_label(dummy.pos,offset,target,zoom)
			var point=game.world_point(dummy.pos)+offset;var rect=game.world_label_rect(point,"이름",19,true)
			var expected=surface.canvas_transform*point
			check(expected.distance_to(target)<.01,"확대 후 이름 기준점 일치 "+str(resolution)+str(zoom))
			check(rect.has_point(expected-Vector2(0,2)) and game.world_label_hidden(point,"이름",19,true),"실제 글자 범위와 기술명 겹침 감지 "+str(resolution)+str(zoom))
			control.hide();game.refresh_world_label_regions()
			# 확대된 이름의 아래쪽은 다음 행 버튼까지 닿을 수 있습니다.
			var lower=game.hud.circles.skill_x
			var lower_bounds=lower.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,lower.size).grow(4)
			var touches_lower=rect.intersects(lower_bounds)
			geometry_cases.append({"resolution":str(resolution),"zoom":zoom,"name_bounds":str(rect),"lower_button_bounds":str(lower_bounds),"touches_lower":touches_lower})
			check(touches_lower==(zoom>1.),"1.18배 이름은 다음 행 실제 버튼 영역까지 교차 "+str(resolution)+str(zoom))
			check(game.world_label_hidden(point,"이름",19,true)==touches_lower,"남아 있는 다음 행 HUD와 겹칠 때만 이름 계속 숨김 "+str(resolution)+str(zoom))
			if touches_lower:
				lower.hide();game.refresh_world_label_regions()
				check(not game.world_label_hidden(point,"이름",19,true),"실제로 겹친 두 HUD를 숨기면 이름 표시 가능 "+str(resolution)+str(zoom))
				lower.show()
			control.show();game.refresh_world_label_regions()
		place_label(dummy.pos,offset,target)
		await capture("겹침-"+str(resolution.x)+"x"+str(resolution.y))
		check(game.hidden_world_labels.has(name) and not game.visible_world_labels.has(name),"실제 그리기에서 HUD 아래 허수아비 이름만 생략 "+str(resolution))
		check(game.monster_aim_frames.has(dummy.id),"이름을 숨겨도 스프라이트와 조준 영역 유지 "+str(resolution))
		if game.monster_aim_frames.has(dummy.id):check(is_equal_approx(game.monster_aim_frames[dummy.id].rect.size.y,TrainingArt.HEIGHT),"기존 허수아비 몸체 크기 유지")
		place_label(dummy.pos,offset,Vector2(800,460))
		await capture("가림없음-"+str(resolution.x)+"x"+str(resolution.y))
		check(game.visible_world_labels.has(name) and not game.hidden_world_labels.has(name),"HUD와 떨어지면 월드 이름 다시 표시 "+str(resolution))
		# 이름 가림은 렌더링에만 적용하고 실제 근접 대화 요청은 그대로 보냅니다.
		p.pos=World.FACILITIES.smith.pos+Vector2(2.5,1.8);session.refresh()
		var resident=World.resident_pos("smith");place_label(resident,Vector2(0,-130),skill_caption())
		await draw_frame()
		check(game.hidden_world_labels.has(World.RESIDENTS.smith.name),"스킬 HUD 아래 NPC 이름 숨김 "+str(resolution))
		check(session.act("interact") and game.npc_dialogue.visible and game.npc_dialogue.facility=="smith" and game.npc_dialogue.speaker.text==World.RESIDENTS.smith.name,"이름이 가려져도 실제 NPC 대화 가능 "+str(resolution))
		game.npc_dialogue.close()
	# 조준과 피해는 동일한 실제 몸체와 세션 전투 경로를 사용합니다.
	p.pos=Training.POSITION+Vector2(1,1);p.aim=p.pos.direction_to(dummy.pos);p.attack_cd=0;session.refresh();game.hud.boss_hud._process(0.)
	place_label(dummy.pos,offset,Vector2(800,460));await draw_frame()
	var body=game.monster_aim_frames[dummy.id];var mouse=body.transform*body.rect.get_center()
	check(Aim.target_at(mouse,session.sim.enemies,game.monster_aim_frames,p.pos,session.sim.map).get("id",-1)==dummy.id,"기존 실제 몸체 조준 유지")
	check(session.act("attack") and Training.summary(p).hits>0 and game.effects.any(func(event):return event.type=="damage"),"기본 공격과 실제 피해 표시 이벤트 유지")
	await capture("피해표시")
	var report=FileAccess.open("res://../artifacts/hud-world-labels-v052.json",FileAccess.WRITE);report.store_string(JSON.stringify({"suite":"hud_world_labels_v052","checks":checks,"failures":failures,"captures":captures,"geometry_cases":geometry_cases},"\t"));report.close()
	game.stop_audio();session.disconnect_game();game.queue_free();await process_frame;await process_frame
	print("HUD_WORLD_LABELS_V052 checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
