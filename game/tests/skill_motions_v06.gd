extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Content=preload("res://scripts/content.gd")
const Art=preload("res://scripts/skill_motion_art_v06.gd")
const Gat=preload("res://scripts/gat_art.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func fixture(cls:String,skill:String):
	var sim=Sim.new(941,"cave",12);sim.enemies.clear();sim.map.floor_cells.clear();sim.map.spawn=Vector2.ONE
	for x in range(1,35):
		for y in range(1,25):sim.map.floor_cells[Vector2i(x,y)]=true
	var p=sim.add_player(1,"모션 검사");p.class_id=cls;p.level=100;p.skill_ranks={skill:1};p.skill_loadout={"skill_q":skill};p.pos=Vector2(10,10);p.aim=Vector2.RIGHT
	sim.combat.initialize(p);sim.recalculate(p);p.invulnerable=1000.;p.hp=p.max_hp;p.max_stamina=10000.;p.stamina=10000.
	var e=sim.spawn_enemy("rat",Vector2(13,10),20);e.hp=1000000;e.max_hp=e.hp;e.cooldown=1000.;e.speed=0.
	return sim
func _initialize():run.call_deferred()
func run():
	Content.initialize_jobs()
	check(Art.catalog().sprites.size()==19,"nineteen approved basic and second-job sheets")
	check(Art.sprite_id("rogue")=="thief","rogue shares authored thief")
	for cls in Art.catalog().sprites:
		var p={"class_id":cls,"avatar":"auto","costume":"none","motion":"cleave","motion_time":.5,"motion_duration":.5,"aim":Vector2.RIGHT}
		for row in range(4):
			for phase in range(4):
				p.skill_motion={"class_id":cls,"skill_id":"fixture","row":row,"windup":phase<2,"duration":.5,"motion":"cleave"}
				p.motion_time=.5 if phase%2==0 else .1
				p.job_state={"casting":{"node":{"id":"fixture"},"time":p.motion_time}} if phase<2 else {"casting":{}}
				var f=Gat.frame(p,0)
				check(f.get("skill_phase",-1)==phase and f.index==row*4+phase,"all 304 authored pose routes "+cls)
				check(f.foot.is_finite() and f.height>0 and f.body_pixels==112.,"finite foot and shared body unit")
				check(f.texture.atlas.get_meta("prepared_source","")==Art.catalog().sprites[cls].sheet,"prepared native RGBA, no per-frame pixel conversion")
				check(f.texture.atlas.get_image().get_pixel(0,0).a==0.,"green source removed in actual texture")
	for sample in [["elementalist","elementalist_a02"],["reaper","reaper_a05"],["warrior","warrior_wave"]]:
		var sim=fixture(sample[0],sample[1]);var p=sim.players[1]
		# The base class skill ID is resolved from the real default loadout below.
		if sample[0]=="warrior":
			p.skill_ranks={};p.skill_loadout={};Content.migrate_skills(p)
			var nodes=Content.SKILLS.warrior.filter(func(n):return n.get("effect","")=="active")
			var n=nodes[0];p.skill_ranks[n.id]=1;p.skill_loadout.skill_q=n.id
		check(sim.action(1,"skill_q"),"actual skill accepted "+sample[0])
		if not p.job_state.casting.is_empty():
			check(Art.selection(p).get("phase",-1)==0,"real windup starts prepare")
			var duration=float(p.job_state.casting.time);sim.combat.jobs.tick(p,duration*.6)
			check(Art.selection(p).get("phase",-1)==1,"anticipation held until actual release")
			sim.combat.jobs.tick(p,duration*.5)
		check(Art.selection(p).get("phase",-1)==2,"actual release starts impact pose")
		var remote=sim.snapshot(2).players[1]
		check(Art.selection(remote)==Art.selection(p),"remote snapshot carries actual cast phase")
		p.motion_time=p.motion_duration*.2
		check(Art.selection(p).get("phase",-1)==3,"actual remaining motion controls recovery")
		p.hurt_time=.2;check(Art.selection(p).is_empty(),"hurt never shows skill pose");p.hurt_time=0.
		p.dodge_time=.2;check(Art.selection(p).is_empty(),"dodge never shows skill pose");p.dodge_time=0.
		p.avatar="gat_role_tank_2";check(Art.selection(p).is_empty(),"manual avatar preserved");p.avatar="auto"
		p.costume="mint-summer";check(Art.selection(p).is_empty(),"costume preserved");p.costume="none"
		sim.combat.attack(p,false,0);check(Art.selection(p).is_empty(),"basic attack replaces old skill")
		Art.start(p,{"id":"fixture"});sim.reset_after_defeat(p.id);check(not p.has("skill_motion"),"defeat removes transient skill animation")
	for cancellation in ["cancel_charge","dodge","target_lost"]:
		var sim=fixture("elementalist","elementalist_a02");var p=sim.players[1]
		check(sim.action(1,"skill_q"),"cancellation fixture starts")
		if cancellation=="target_lost":sim.enemies[1].pos=Vector2(30,10);sim.combat.jobs.tick(p,3.)
		else:sim.action(1,cancellation)
		check(Art.selection(p).is_empty(),"cancelled windup never flashes release "+cancellation)
	print("SKILL_MOTIONS_V06_TESTS checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
