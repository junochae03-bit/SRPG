extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Training=preload("res://scripts/training_ground.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr(label)
func _initialize():run.call_deferred()
func run():
	var test_image=Image.create(320,100,false,Image.FORMAT_RGBA8);test_image.fill(Color.TRANSPARENT)
	test_image.fill_rect(Rect2i(10,15,30,40),Color.WHITE);test_image.fill_rect(Rect2i(180,5,50,70),Color.WHITE)
	var sheet=ImageTexture.create_from_image(test_image)
	var left=AtlasTexture.new();left.atlas=sheet;left.region=Rect2(0,0,160,100)
	var right=AtlasTexture.new();right.atlas=sheet;right.region=Rect2(160,0,160,100)
	var hud_probe=preload("res://scripts/combat_hud.gd").new()
	check(hud_probe.cached_portrait_bounds(left)==Rect2(10,15,30,40),"first shared-sheet portrait bounds")
	check(hud_probe.cached_portrait_bounds(right)==Rect2(20,5,50,70),"second shared-sheet portrait has independent bounds")
	hud_probe.free()
	var status_world=Sim.new(5420,"forest",1);status_world.enemies.clear()
	var status_player=status_world.add_player(1,"상태 검증");status_player.barrier_time=2.;status_player.enemy_slow_time=1.;status_player.job_state.parry=.5
	status_world.combat.jobs.buff(status_player,"attack",.2,3.)
	var status=preload("res://scripts/status_markers.gd")
	var before_status=var_to_bytes(status_player)
	check(status.timed_for(status_player).size()==4 and var_to_bytes(status_player)==before_status,"timed HUD exposes four live statuses without mutation")
	status_world.combat.tick_player(status_player,.6)
	var remaining=status.timed_for(status_player)
	check(remaining.size()==3 and remaining.all(func(row):return row.remaining>0),"expired status removed while other countdowns remain")
	check(is_equal_approx(remaining.filter(func(row):return row.key=="buff:attack")[0].remaining,2.4),"buff countdown follows actual combat duration")
	status_player.hp=0;check(status.timed_for(status_player).is_empty(),"dead player has no stale status icons")
	var job_art=preload("res://scripts/job_art.gd");job_art.initialize()
	for key in ["companions","hunter_wolf"]:
		for f in job_art.data.effects[key].frames:
			check(f.body_height>0 and f.visible_rect[3]<=f.body_height,"companion uses stable row body scale")
	var portrait_source=job_art.frame({"class_id":"runesword"},0.).texture
	var portrait_bounds=preload("res://scripts/combat_hud.gd").visible_portrait_bounds(portrait_source)
	check(portrait_bounds.position.x>0 and portrait_bounds.position.y>0,"portrait ignores opaque keyed padding")
	check(portrait_bounds.size.x>200 and portrait_bounds.size.y>220,"portrait retains entire illustrated body before crop")
	var pet_world=Sim.new(5400,"forest",1);pet_world.enemies.clear()
	for x in range(18,35):
		for y in range(18,35):pet_world.map.floor_cells[Vector2i(x,y)]=true
	var hunter=pet_world.add_player(1,"늑대 검증",{"schema_version":7,"class_id":"hunter","level":30,"tutorial_done":true})
	hunter.pos=Vector2(24,24);pet_world.combat.tick_player(hunter,.1)
	check(hunter.job_state.pets.size()==1,"hunter creates actual companion")
	var wolf=hunter.job_state.pets[0];wolf.pos=Vector2(27,24)
	pet_world.combat.tick_player(hunter,.1)
	check(wolf.moving and wolf.facing==-1.,"companion turns left while returning to owner")
	var target=pet_world.spawn_enemy("shade",wolf.pos+Vector2(1,0),1,false);target.hp=10000;target.max_hp=10000
	pet_world.combat.tick_player(hunter,.1)
	check(wolf.facing==1. and wolf.cd>0 and target.hp<10000,"companion turns toward target and attacks")
	for job in ["rogue","thief"]:
		for distance in [1.3,6.0]:
			var sim=Sim.new(5401,"forest",1);sim.enemies.clear()
			for x in range(18,35):
				for y in range(18,35):sim.map.floor_cells[Vector2i(x,y)]=true
			var p=sim.add_player(1,"근접 검증",{"schema_version":7,"class_id":job,"level":30,"tutorial_done":true})
			p.pos=Vector2(24,24);p.aim=Vector2.RIGHT
			var e=sim.spawn_enemy("shade",p.pos+Vector2(distance,0),1,false);e.hp=10000;e.max_hp=e.hp
			check(sim.combat.attack(p,false,0),job+" attack accepted")
			check(sim.combat.projectiles.is_empty(),job+" no arrow")
			check((e.hp<10000)==(distance<2),job+" melee distance")
			check(p.motion=="cleave",job+" melee pose")
	var sim=Sim.new(5402,"town");var p=sim.add_player(1,"기록 검증")
	p.pos=Training.POSITION+Vector2(-1,0)
	var e=sim.enemies.values().filter(func(row):return row.get("training",false))[0]
	sim.clock=1.;Training.record(sim,p,e,100,false)
	p.attack_cd=2.;p.stamina=31.;var saved=sim.persistent(1).duplicate(true)
	Training.expire_measurement(p,10.99)
	check(Training.summary(p).total_damage==100,"retained before deadline")
	Training.expire_measurement(p,11.)
	check(Training.summary(p).hits==0 and Training.summary(p).elapsed==0,"expired at deadline")
	check(p.attack_cd==2. and p.stamina==31. and sim.persistent(1)==saved,"reset only measurement")
	sim.clock=12.;Training.record(sim,p,e,50,false)
	check(Training.summary(p).total_damage==50 and p.training_stats.first_hit==12.,"fresh attempt")
	sim.clock=22.;Training.record(sim,p,e,70,false)
	check(Training.summary(p).total_damage==70,"new hit after silence starts new attempt")
	p.dir=Vector2.ZERO
	for i in range(601):sim.tick(1./60.)
	check(Training.summary(p).hits==0,"real simulation expires record without another hit")
	var content=preload("res://scripts/content.gd")
	for job in content.CLASSES:
		for frame_delta in [.01,.1,.5]:
			var world=Sim.new(5410,"forest",1);world.enemies.clear()
			for x in range(18,35):
				for y in range(18,35):world.map.floor_cells[Vector2i(x,y)]=true
			var actor=world.add_player(1,"이동 검증",{"schema_version":7,"class_id":job,"level":30,"tutorial_done":true})
			actor.pos=Vector2(24,24);actor.dir=Vector2.ZERO;actor.aim=Vector2.RIGHT
			check(world.action(1,"dodge"),job+" dash accepted")
			var expected=actor.dodge_time*actor.dash_speed
			while actor.dodge_time>0:world.combat.tick_player(actor,frame_delta)
			check(absf(actor.pos.x-24.-expected)<.01 and expected>=3.5,job+" full dash distance independent of frame rate")
			actor.pos=Vector2(24,24);actor.dodge_cd=0;actor.job_state.dash_charges=1;actor.stamina=actor.max_stamina
			for y in range(18,35):world.map.floor_cells.erase(Vector2i(26,y))
			check(world.action(1,"dodge"),job+" wall dash accepted")
			world.combat.tick_player(actor,.5)
			check(actor.pos.x<26 and world.map.walkable(actor.pos),job+" long frame cannot tunnel through wall")
	p.class_id="warrior";p.level=2;p.skill_ranks={};p.constellation_allocations={}
	var unchanged=JSON.stringify(p);var route=preload("res://scripts/skill_build.gd").learning_route(p,"warrior:star:0:key")
	check(route.ok and route.cost>1 and not route.steps.is_empty(),"low level can preview future growth before affording entire route")
	check(JSON.stringify(p)==unchanged,"growth preview never grants levels or points")
	var panel=preload("res://scripts/town_panel.gd")
	var inventory=preload("res://scripts/inventory_model.gd")
	var stored=preload("res://scripts/equipment_catalog.gd").make("sword",1,0,"feedback-stored","none",p.class_id)
	var worn=preload("res://scripts/equipment_catalog.gd").make("sword",1,0,"feedback-worn","none",p.class_id)
	p.inventory=[stored,worn];p.equipment.weapon=worn.id;p.equipped=worn.id
	var equipment=p.inventory.filter(func(item):return item.get("category","") in ["weapon","armor","accessory"])
	if not equipment.is_empty():
		var order=p.inventory.duplicate(true)
		var sorted=panel.smith_items(p,"upgrade")
		var saw_stored=false
		for item in sorted:
			if not inventory.is_equipped(p,item.id):saw_stored=true
			else:check(not saw_stored,"smith equipped first")
		check(p.inventory==order,"smith leaves bag order unchanged")
		check(panel.smith_items(p,"salvage").all(func(item):return not inventory.is_equipped(p,item.id)),"smith salvage excludes equipped")
	p.potions=4;p.materials={"ore":2,"seed":1}
	var before_sort=sim.persistent(1).duplicate(true);before_sort.erase("bag_positions")
	check(sim.action(1,"sort_bag"),"sort action succeeds")
	check(p.bag_positions.size()==4 and not p.bag_positions.has(worn.id),"sort includes stacks and excludes equipped")
	var after_sort=sim.persistent(1).duplicate(true);after_sort.erase("bag_positions")
	check(before_sort==after_sort,"sort changes no possessions or stats")
	var positions=p.bag_positions.duplicate(true);sim.action(1,"sort_bag")
	check(p.bag_positions==positions,"sort is deterministic")
	var local=preload("res://scripts/local_session.gd").new();root.add_child(local);local.set_physics_process(false)
	local.save_directory=ProjectSettings.globalize_path("res://../runtime/feedback-sort/"+str(Time.get_ticks_usec()))
	local.start_game("정렬 저장 검증",1)
	var full=local.sim.players[1];full.inventory=[];full.equipment={};full.equipped="";full.materials={};full.potions=0;full.bag_positions={}
	for i in range(inventory.CAPACITY):full.inventory.append(preload("res://scripts/equipment_catalog.gd").make("sword",1,i%3,"full-%03d"%i,"none",full.class_id))
	inventory.initialize(full);local.paused=true
	var possessions=full.inventory.duplicate(true)
	check(local.act("sort_bag"),"paused full bag sorts through real session")
	check(full.bag_positions.size()==120 and full.bag_positions.values().any(func(at):return at.x==9 and at.y==11),"sort uses final bag cell")
	var disk=local.parse_save(local.save_path())
	check(disk!=null and disk.bag_positions==full.bag_positions,"sort automatically flushes exact positions to disk")
	check(full.inventory==possessions,"full bag sort preserves every equipment instance")
	check(local.disconnect_game(),"sorted session closes cleanly")
	local.start_game("정렬 저장 검증",1)
	check(local.sim.players[1].bag_positions==disk.bag_positions and local.sim.players[1].inventory.size()==120,"full bag reload preserves sort and quantity")
	local.disconnect_game();local.free()
	for job in content.CLASSES:
		p.class_id=job;sim.combat.jobs.reset(p);p.skill_ranks={}
		var before_report=var_to_bytes(p)
		var report=preload("res://scripts/player_stats.gd").rows(sim,p)
		check(report.size()==17 and var_to_bytes(p)==before_report,"stat sheet is complete and read only "+job)
		sim.combat.attack(p,false,0)
		check(report[11][1]=="%.2f초"%p.attack_cd,"displayed attack interval matches real attack "+job)
		for node in content.SKILLS[job]:
			if node.get("effect","")!="active":continue
			p.skill_ranks[node.id]=1
			var text=preload("res://scripts/skill_presentation.gd").quickslot_description(p,node,1,100.)
			check(text.contains("재사용") and text.contains(str(node.get("description",""))),job+" skill tooltip")
			if node.get("rune_cost",0)>0:check(text.count("소모 룬")==1,"rune cost appears once")
	print("FEEDBACK_V054 checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
