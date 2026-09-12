extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Items=preload("res://scripts/consumables.gd")
const Inv=preload("res://scripts/inventory_model.gd")
const Ops=preload("res://scripts/town_operations.gd")
const Tools=preload("res://scripts/tactical_tools.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func fixture():
	var sim=Sim.new(741,"cave",12);sim.enemies.clear();sim.map.floor_cells.clear()
	for x in range(10,55):
		for y in range(10,55):sim.map.floor_cells[Vector2i(x,y)]=true
	var p=sim.add_player(1,"도구 검사");p.pos=Vector2(30,30);p.aim=Vector2.RIGHT;p.gold=10000
	for item in Items.ITEMS:
		if Tools.is_deployable(item):Inv.add_stack(p,item,10)
	return sim
func run():
	var sim=fixture();var p=sim.players[1]
	for item in ["lure_stone","snare_trap","fire_bottle"]:
		check(Inv.find_item(p,Items.bag_id(item)).count==10,"inventory count "+item)
		var staged=Ops.stage(p,"shop",item,{"quantity":5})
		check(staged.quote.reason.is_empty() and Items.count(staged.player,item)==15 and staged.player.gold==p.gold-Items.ITEMS[item].price*5,"transaction output and price "+item)
		check(not Ops.stage(p,"shop",item,{"quantity":0}).quote.reason.is_empty(),"invalid quantity "+item)
		var full=p.duplicate(true);full.consumables[item]=20;var before=var_to_bytes(full)
		check(not Ops.stage(full,"shop",item).quote.reason.is_empty() and before==var_to_bytes(full),"full stack no charge "+item)
		check(preload("res://scripts/icon_library.gd").has_key(Items.ITEMS[item].icon),"real icon "+item)
	p.tool_cd=0.;sim.map.floor_cells.erase(Vector2i(32,30))
	check(not sim.action(1,"fire_bottle") and Items.count(p,"fire_bottle")==10 and p.tool_cd==0.,"wall blocks throw without charge")
	sim.map.floor_cells[Vector2i(32,30)]=true;p.aim=Vector2.ZERO
	check(not sim.action(1,"lure_stone") and sim.tactical.records.is_empty(),"zero aim rejects")
	p.aim=Vector2.RIGHT
	check(sim.action(1,"fire_bottle") and Items.count(p,"fire_bottle")==9,"successful throw consumes once")
	check(not sim.action(1,"fire_bottle") and Items.count(p,"fire_bottle")==9,"immediate duplicate cannot consume")
	p.hp-=10
	check(sim.action(1,"potion"),"tool and healing cooldowns independent")
	var target=p.pos+Vector2(4,0);var enemy=sim.spawn_enemy("goblin_archer",target,12);enemy.hp=10000;enemy.max_hp=10000
	var blocked=sim.spawn_enemy("goblin_archer",target+Vector2(0,2),12);blocked.hp=10000;blocked.max_hp=10000
	sim.map.floor_cells.erase(Vector2i(34,31))
	var ally=sim.add_player(2,"동료");ally.pos=target;var hp=ally.hp
	sim.clock=.64;sim.tactical.tick();check(enemy.hp==10000,"throw delay telegraphs before damage")
	sim.clock=.65;sim.tactical.tick();var after=enemy.hp
	check(after<10000 and blocked.hp==10000 and ally.hp==hp,"explosion hits enemies only and respects wall")
	sim.tactical.tick();check(enemy.hp==after,"explosion cannot repeat same tick")
	sim.clock=2.;sim.tactical.tick();check(sim.tactical.records.is_empty(),"spent effect expires")
	sim=fixture();p=sim.players[1]
	check(sim.action(1,"snare_trap"),"place snare")
	var snare=sim.tactical.records[0]
	enemy=sim.spawn_enemy("goblin_archer",snare.pos,12);enemy.hp=10000;enemy.max_hp=10000
	sim.clock=.99;sim.tactical.tick();check(enemy.get("stun_time",0)==0,"snare cannot trigger before armed")
	sim.clock=1.;sim.tactical.tick()
	check(enemy.hp<10000 and enemy.stun_time==1.5 and enemy.slow_time==4.,"snare damage control and follow-up slow")
	check(snare.state=="spent","snare one activation")
	sim=fixture();p=sim.players[1];sim.action(1,"snare_trap")
	var boss=sim.spawn_enemy("golem",sim.tactical.records[0].pos,12,true)
	boss.hp=100000;boss.max_hp=100000
	sim.clock=1.;sim.tactical.tick()
	check(boss.hp<100000 and boss.get("stun_time",0)==0 and boss.get("slow_time",0)==0 and boss.stagger.value==24.,"boss gets stagger not immobilization")
	sim=fixture();p=sim.players[1]
	for i in range(8):sim.spawn_enemy("goblin_archer",p.pos+Vector2(11+i*.1,1),12)
	sim.action(1,"lure_stone");sim.clock=.45;sim.tactical.tick()
	check(sim.enemies.values().filter(func(e):return e.get("heard_until",0)>sim.clock).size()==4,"lure recruits shared four-enemy pool")
	check(sim.awareness.snapshot(1).pos==p.pos+Vector2(5,0),"noise originates at landing not caster")
	check(sim.enemies.values().filter(func(e):return e.has("search_path")).all(func(e):return e.search_path.back()==p.pos+Vector2(5,0)),"listeners investigate actual landing")
	for environment in ["still","echo","mist"]:
		sim=fixture();p=sim.players[1]
		sim.map.environment=preload("res://scripts/expedition_environment.gd").CONDITIONS[environment].duplicate(true)
		for i in range(8):sim.spawn_enemy("goblin_archer",p.pos+Vector2(11+i*.1,1),12)
		check(sim.action(1,"lure_stone"),"throw before heavy "+environment)
		sim.clock=.25;check(sim.action(1,"heavy_begin"),"start actual heavy "+environment)
		p.charge_time=.15;check(sim.action(1,"heavy"),"release actual heavy before landing "+environment)
		check(sim.awareness.snapshot(1).pos==p.pos,"heavy sound at owner "+environment)
		sim.clock=.45;sim.tactical.tick()
		check(sim.awareness.snapshot(1).pos==p.pos+Vector2(5,0),"landing overrides nearby-time sound from another cell "+environment)
		check(sim.enemies.values().filter(func(e):return e.get("heard_until",0)>sim.clock).size()<=4,"landing keeps shared reservation cap "+environment)
		check(sim.enemies.values().filter(func(e):return e.has("search_path")).all(func(e):return e.search_path.back()==p.pos+Vector2(5,0)),"heavy then landing redirects actual listeners "+environment)
	sim=fixture();p=sim.players[1]
	for i in range(2):p.tool_cd=0.;check(sim.action(1,"snare_trap"),"owner tool slot %d"%i)
	p.tool_cd=0.;var quantity=Items.count(p,"snare_trap")
	check(not sim.action(1,"snare_trap") and Items.count(p,"snare_trap")==quantity,"owner cap does not spend item")
	for id in range(2,7):
		ally=sim.add_player(id,"동료 %d"%id);ally.pos=p.pos;Inv.add_stack(ally,"snare_trap",10)
		for i in range(2):ally.tool_cd=0.;sim.action(id,"snare_trap")
	check(sim.tactical.records.size()==8,"six owners share eight active tools")
	check(Items.count(sim.players[5],"snare_trap")==10 and Items.count(sim.players[6],"snare_trap")==10,"over-cap peers retain quantities")
	sim.players.erase(2);sim.tactical.tick();check(sim.tactical.records.size()==6,"disconnect removes only owner's tools")
	sim.player_defeated(p);check(sim.tactical.records.filter(func(r):return r.owner==1).is_empty(),"death cancels tools before revival")
	sim.clock=32;sim.tactical.tick();check(sim.tactical.records.is_empty(),"unused trap lifetime bounded")
	sim=fixture();p=sim.players[1];sim.action(1,"snare_trap")
	var snap=sim.snapshot(1);check(snap.tactical_tools.size()==1,"visible tool snapshot")
	snap.tactical_tools[0].owner=99;check(sim.tactical.records[0].owner==1,"snapshot cannot mutate authority")
	p.pos=Vector2(50,50);check(sim.snapshot(1).tactical_tools.is_empty(),"unseen tool position omitted from wire")
	p.pos=Vector2(30,30);sim.map.floor_cells.erase(Vector2i(31,30));sim.map.revision+=1
	check(sim.snapshot(1).tactical_tools.is_empty(),"wall-occluded tool omitted")
	var saved=sim.persistent(1);saved.world_seed=741
	check(not saved.has("tactical_tools") and not saved.has("tool_cd"),"save inventory without armed traps")
	var session=preload("res://scripts/local_session.gd").new();root.add_child(session);session.set_physics_process(false)
	check(session.validate_save(JSON.parse_string(JSON.stringify(saved)))!=null,"strict save accepts owned tool quantities")
	var invalid=saved.duplicate(true);invalid.consumables.snare_trap=21
	check(session.validate_save(invalid)==null,"save rejects tool stack overflow")
	invalid=saved.duplicate(true);invalid.consumables.unknown_tool=1
	check(session.validate_save(invalid)==null,"save rejects unknown tool")
	var town=Sim.new(741,"town");var resident=town.add_player(1,"마을",saved)
	check(not town.action(1,"snare_trap") and Items.count(resident,"snare_trap")==Items.count(p,"snare_trap"),"town cannot deploy and new map clears records")
	session.sim=sim;session.connected=true;session.paused=true;session.local_id=1
	quantity=Items.count(p,"lure_stone")
	check(not session.act("lure_stone") and Items.count(p,"lure_stone")==quantity,"paused inventory cannot throw")
	session.connected=false;session.queue_free();await process_frame
	print("TACTICAL_TOOLS checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
