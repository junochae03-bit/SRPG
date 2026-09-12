extends SceneTree
## 실행은 메인 담당. 이미지의 미학/접촉 의미와 네이티브 툴팁은 수동 판정한다.
const Sim=preload("res://scripts/simulation.gd")
const Content=preload("res://scripts/content.gd")
const Areas=preload("res://scripts/monster_attacks.gd")
const Motion=preload("res://scripts/combat_sprite_art.gd")
const Costume=preload("res://scripts/costume_art_v04.gd")
const Gat=preload("res://scripts/gat_art.gd")
const Stagger=preload("res://scripts/boss_stagger.gd")
const Dungeon=preload("res://scripts/dungeon.gd")
const TrainingArt=preload("res://scripts/training_art.gd")
var checks=0
var failures=[]
var captures=[]
var poses=[]
var reader_samples=[]
# class_matching.json 및 costume_v04/catalog.json에 실제로 존재하는 조합만 사용.
const COSTUME_SAMPLES={"warrior":"mint-hanbok","swordsman":"mint-hanbok","mage":"amethyst-purple-dress","summoner":"amethyst-purple-dress"}
var game
var surface:SubViewport
var output=""

class AreaRecorder extends RefCounted:
	var fills=[]
	var lines=[]
	func world_point(p:Vector2)->Vector2:return Vector2(250,210)+Vector2(p.x-p.y,(p.x+p.y)*.5)*35.
	func draw_colored_polygon(points:PackedVector2Array,_color:Color):
		fills.append(points)
	func draw_polyline(points:PackedVector2Array,_color:Color,_width:float=-1.,_antialiased:bool=false):
		lines.append(points)

class AreaCanvas extends Node2D:
	var zone={}
	var recorder=AreaRecorder.new()
	func world_point(p:Vector2)->Vector2:return recorder.world_point(p)
	func _draw():
		recorder.fills.clear();recorder.lines.clear()
		if not zone.is_empty():
			Areas.draw_area(self,zone,Color("ed8268"))
			Areas.draw_area(recorder,zone,Color("ed8268"))
	func painted(point:Vector2)->bool:
		for polygon in recorder.fills:
			if Geometry2D.is_point_in_polygon(world_point(point),polygon):return true
		return false

func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func fixture(job:String="warrior",kind:String="shade")->Dictionary:
	var sim=Sim.new(5301,"forest",1);sim.enemies.clear();sim.events.clear()
	for x in range(18,35):
		for y in range(18,35):sim.map.floor_cells[Vector2i(x,y)]=true
	var p=sim.add_player(1,"접촉 검사",{"schema_version":7,"class_id":job,"level":30,"stats":{},"skill_ranks":{},"skill_loadout":{},"constellation_allocations":{},"tutorial_done":true})
	p.pos=Vector2(24,24);p.aim=Vector2.RIGHT
	var e=sim.spawn_enemy(kind,p.pos+Vector2(1.3,0),1,kind=="warden");e.hp=10000;e.max_hp=e.hp
	return {"sim":sim,"p":p,"e":e}
func damage_events(f:Dictionary)->Array:
	return f.sim.events.filter(func(e):return e.type=="damage" and e.get("enemy",false))
func event_contract():
	for state in ["live","lethal","zero","dead","wall","reset"]:
		var f=fixture("warrior","warden" if state=="reset" else "shade")
		var context={}
		if state=="lethal":f.e.hp=1
		if state=="dead":f.e.hp=0
		if state=="wall":
			for y in range(18,35):f.sim.map.floor_cells.erase(Vector2i(25,y))
			check(not f.sim.map.line_clear(f.p.pos,f.e.pos),"벽 선행조건")
		if state=="reset":
			context=Stagger.context(Stagger.basic_token(false,0,f.sim.clock));f.sim.clock=1.;Stagger.reset(f.sim,f.e)
		var hp=f.e.hp
		var accepted=f.sim.combat.hit(f.p,f.e,0 if state=="zero" else 37,null,context)
		var events=damage_events(f);var expected=state in ["live","lethal"]
		check(accepted==expected,"적중 수락 "+state)
		check(events.size()==(1 if expected else 0),"피해 이벤트 수 "+state)
		if expected and not events.is_empty():
			check(events[0].get("target_id",-1)==f.e.id,"실제 표적 ID "+state)
			check(f.e.hp<hp,"수락 시 HP 감소 "+state)
		else:check(f.e.hp==hp,"거절 시 HP 보존 "+state)
		if state=="lethal":check(f.e.hp==0,"처치 이벤트 유지")
func attack_contract():
	for job in ["warrior","ranger","mage","swordsman","sniper","summoner"]:
		for heavy in [false,true]:
			var f=fixture(job)
			if heavy:
				check(f.sim.action(1,"heavy_begin"),"충전 시작 "+job)
				f.sim.combat.tick_player(f.p,.6)
				check(damage_events(f).is_empty() and f.sim.combat.projectiles.is_empty(),"충전 중 피해/발사 없음 "+job)
			check(f.sim.action(1,"heavy" if heavy else "attack"),"공개 행동 공격 "+job+str(heavy))
			check(f.p.charge_time<0,"해제 뒤 충전 종료 "+job)
			var progress=1.-f.p.motion_time/f.p.motion_duration
			check(progress>=.5 and progress<.75,"준비 포즈를 건너뛴 단계 "+job+str(heavy))
			var index=10 if heavy else 6
			check(Motion.index_for(f.p,0.)==index,"공통 reader 단계 "+job+str(heavy))
			check(Gat.frame(f.p,0.).index==index,"기본/전직 실제 reader 단계 "+job+str(heavy))
			reader_samples.append({"class":job,"heavy":heavy,"reader":"default_or_job","expected_index":index})
			var ranged=Content.CLASSES[job].get("projectile",Content.WEAPONS[f.sim.combat.weapon_type(f.p)].projectile)
			check(f.sim.combat.projectiles.size()>0 and damage_events(f).is_empty() if ranged else not damage_events(f).is_empty(),"근접 즉시피해/원거리 즉시발사 구분 "+job)
			if ranged:
				for _tick in range(45):f.sim.combat.tick_projectiles(.04)
				check(damage_events(f).any(func(e):return e.get("target_id",-1)==f.e.id),"탄환 도착 후 피해 "+job)
			costume_reader_contract(f.p,heavy,index)
func costume_reader_contract(p:Dictionary,heavy:bool,index:int):
	var job=str(p.class_id)
	if not COSTUME_SAMPLES.has(job):
		reader_samples.append({"class":job,"heavy":heavy,"reader":"costume_v04","status":"not_applicable","reason":"현재 허용된 costume_v04 조합 없음. 기본 외형 검사로 대체하지 않음."})
		return
	var id=str(COSTUME_SAMPLES[job])
	var supported=id in Content.costume_options(job) and Costume.recognizes(id)
	check(supported,"명시한 코스튬 표본의 허용/등록 "+job+":"+id)
	if not supported:return
	var dressed=p.duplicate(true);dressed.costume=id
	check(Costume.has_sprite(dressed),"실제 코스튬 reader 선택 "+job+":"+id)
	check(Costume.frame(dressed,0.).index==index and Gat.frame(dressed,0.).index==index,"코스튬 직접 reader와 라우팅 단계 "+job+str(heavy))
	reader_samples.append({"class":job,"heavy":heavy,"reader":"costume_v04","costume":id,"expected_index":index})
	poses.append({"class":job,"heavy":heavy,"index":index,"costume":id,"player":dressed})
func draw_frame():
	game.forest.update_camera(0.);game.queue_redraw();game.map_overlay.queue_redraw()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
func capture(name:String):
	await draw_frame()
	var path=output.path_join(name+".png")
	check(surface.get_texture().get_image().save_png(path)==OK,"캡처 저장 "+name);captures.append(path)
func impact_contract():
	game.enemy_impacts.clear()
	var f=fixture();f.sim.combat.hit(f.p,f.e,37)
	game.on_event(damage_events(f)[0])
	check(game.enemy_impacts.has(f.e.id),"실제 피해 이벤트가 시각효과 생성")
	# 이 표적은 현재 게임 세션에 없으므로 draw_actor는 호출되지 않는다.
	game._process(.06);check(game.enemy_impacts.has(f.e.id),"화면 밖 효과 만료 전 유지")
	game._process(.07);check(not game.enemy_impacts.has(f.e.id),"화면 밖 효과 만료 정리")
	f.e.hp=1;f.sim.events.clear();f.sim.combat.hit(f.p,f.e,37);game.on_event(damage_events(f)[0])
	game._process(.13);check(not game.enemy_impacts.has(f.e.id),"처치 표적 효과 만료 정리")
	game.on_event({"type":"damage","enemy":false,"target_id":987654,"amount":1,"pos":Vector2.ZERO})
	check(not game.enemy_impacts.has(987654),"플레이어 피해는 적 효과 없음")
	game.on_event({"type":"damage","enemy":true,"target_id":987655,"amount":1,"pos":Vector2.ZERO})
	check(game.session.travel("town"),"실제 맵 전환")
	check(game.enemy_impacts.is_empty(),"맵 전환 효과 초기화")
func geometry_contract():
	var canvas=AreaCanvas.new();surface.add_child(canvas)
	for target in [Vector2(3,0),Vector2(2,2),Vector2.ZERO]:
		var zone=Areas.area("line",Vector2.ZERO,target,1.)
		canvas.zone=zone;canvas.queue_redraw();await draw_frame()
		var direction=target.normalized() if target!=Vector2.ZERO else Vector2.RIGHT
		for end in [Vector2.ZERO,target]:
			var outward=-direction if end==Vector2.ZERO and target!=Vector2.ZERO else direction
			for offset in [-.02,.02]:
				var point=end+outward*(1.+offset);var expected=offset<0
				check(Areas.contains(zone,point)==expected,"캡슐 끝점 판정 "+str(target)+str(offset))
				check(canvas.painted(point)==expected,"실제 draw_area 다각형 끝점 "+str(target)+str(offset))
		check(Areas.contains(zone,target+direction),"캡슐 경계 포함")
	var ring=Areas.area("ring",Vector2.ZERO,Vector2.ZERO,3.);ring.inner=1.
	canvas.zone=ring;canvas.queue_redraw();await draw_frame()
	for radius in [0.,.98,1.02,2.98,3.02]:
		var expected=radius>1. and radius<3.;var point=Vector2(radius,0)
		check(Areas.contains(ring,point)==expected,"고리 판정 "+str(radius))
		check(canvas.painted(point)==expected,"고리 실제 채움/안전중앙 "+str(radius))
	check(Areas.contains(ring,Vector2(1,0)) and Areas.contains(ring,Vector2(3,0)),"고리 경계 포함")
	await capture("ring-telegraph");canvas.queue_free();await process_frame
func render_contract():
	var dummy=game.session.sim.enemies.values().filter(func(e):return e.get("training",false))[0]
	var control=game.hud.circles.skill_v
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		surface.size=resolution;await process_frame;await process_frame
		var caption=control.get_global_transform_with_canvas()*(control.size*.5)
		var local_point=surface.canvas_transform.affine_inverse()*caption
		game.camera_pos=Dungeon.iso(dummy.pos)+game.screen_center()+Vector2(0,-TrainingArt.HEIGHT-20)-local_point
		game.smooth_positions.clear();await capture("hud-overlap-"+str(resolution.x))
		check(game.hidden_world_labels.has(str(dummy.name)),"실제 렌더링에서 HUD와 겹친 이름 가림 "+str(resolution))
		check(game.monster_aim_frames.has(dummy.id),"가려진 이름의 몸체 조준은 유지")
		check(not control.tooltip_text.is_empty(),"실제 HUD 컨트롤 툴팁 내용 존재")
	# native tooltip popup의 화면 경계/가독성은 아래 보고서의 미검증 항목이다.
	var gallery=Control.new();surface.add_child(gallery)
	for i in range(poses.size()):
		var entry=poses[i];var picture=TextureRect.new();picture.position=Vector2(40+(i%6)*250,40+(i/6)*300);picture.size=Vector2(180,210)
		picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture=Gat.frame(entry.player,0.).texture;gallery.add_child(picture)
		var label=Label.new();label.position=picture.position+Vector2(0,215);label.text=entry.class+" / "+str(entry.index);gallery.add_child(label)
	await capture("contact-reader-gallery-manual-review");gallery.queue_free();await process_frame
func projectile_render_contract():
	surface.size=Vector2i(1920,1080)
	var local=game.session;var p=local.sim.players[1]
	for job in ["ranger","mage"]:
		p.class_id=job;p.avatar="auto";p.costume="none";p.skill_ranks={};p.skill_loadout={}
		local.sim.combat.jobs.reset(p);local.sim.recalculate(p);p.pos=Vector2(36,33)
		for direction in [Vector2.RIGHT,Vector2.LEFT]:
			p.aim=direction;p.attack_cd=0;local.sim.combat.projectiles.clear();game.effects.clear()
			check(local.act("attack"),"actual ranged launch "+job+str(direction))
			local.sim.combat.tick_projectiles(.08);local.refresh()
			check(not local.state.projectiles.is_empty(),"ranged projectile remains visible in flight")
			var before=var_to_bytes(local.sim.combat.projectiles)
			game.update_battle_camera(p,1.,true);game.smooth_positions.clear()
			await capture("projectile-"+job+("-right" if direction==Vector2.RIGHT else "-left"))
			check(var_to_bytes(local.sim.combat.projectiles)==before,"projectile drawing never changes damage, direction or travel")
			if not local.state.projectiles.is_empty():check(local.state.projectiles[0].dir==direction,"visual flight retains actual launch direction")

func run():
	output=ProjectSettings.globalize_path("res://../artifacts/combat-polish-v053/"+str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(output)
	Content.initialize_jobs();event_contract();attack_contract()
	root.size=Vector2i(1920,1080)
	surface=SubViewport.new();surface.size=Vector2i(1920,1080);surface.size_2d_override=Vector2i(1600,900);surface.size_2d_override_stretch=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;surface.gui_embed_subwindows=true;root.add_child(surface)
	game=load("res://main.tscn").instantiate();game.options.mute=true;surface.add_child(game);await process_frame
	game.session.save_directory=ProjectSettings.globalize_path("res://../runtime/combat-polish-v053/"+str(Time.get_ticks_usec()));game.join_game()
	game.session.set_physics_process(false);game.set_physics_process(false);game.set_process(false);game.set_process_unhandled_input(false)
	game.session.sim.players[1].tutorial_done=true;game.session.refresh()
	impact_contract();await geometry_contract();await render_contract();await projectile_render_contract()
	var report={"checks":checks,"failures":failures,"captures":captures,"manual_pending":["프레임 5/10 원화가 실제 접촉/발사로 보이는지", "네이티브 툴팁 팝업의 화면 가장자리 잘림/중첩", "대표 기본외형과 코스튬의 입력부터 접촉까지 연속 영상", "청음"],"scope":"합성 fixture 및 렌더링 회귀. 제품 사용성/접촉 원화 의미/청음 통과가 아님."}
	report["reader_samples"]=reader_samples
	var file=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	game.stop_audio();game.session.disconnect_game();game.queue_free();await process_frame;await process_frame
	print("COMBAT_POLISH_V053 checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
