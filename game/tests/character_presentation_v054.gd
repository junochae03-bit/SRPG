extends SceneTree
const Art=preload("res://scripts/gat_art.gd")
const Presentation=preload("res://scripts/character_presentation.gd")
const Content=preload("res://scripts/content.gd")
const Costume=preload("res://scripts/costume_art_v04.gd")
const Sim=preload("res://scripts/simulation.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func run():
	Content.initialize_jobs()
	var cases=[]
	for key in Content.CLASSES:cases.append({"class_id":key,"avatar":"auto","costume":"none"})
	for key in Content.AVATARS:cases.append({"class_id":"ranger","avatar":key,"costume":"none"})
	for key in Costume.ids():cases.append({"class_id":"ranger","avatar":"auto","costume":key})
	var sim=Sim.new();sim.enemies.clear()
	var p=sim.add_player(1,"렌더 검사")
	p.pos=Vector2(sim.map.rooms[1]);p.dir=Vector2.ZERO
	var records=[]
	for sample in cases:
		p.merge(sample,true);sim.combat.initialize(p)
		var id=Art.presentation_id(p)
		check(not Presentation.profile(id).is_empty(),"registered profile "+id)
		for side in [-1.,1.]:
			p.aim=Vector2(side,-side).normalized();p.charge_time=-1.;p.hurt_time=0.;p.dodge_time=0.
			for repeat in range(3):
				p.attack_cd=0;sim.events.clear();sim.combat.projectiles.clear()
				check(sim.combat.attack(p,false,0),"actual attack "+id)
				var frame=Art.frame(p,0)
				check(frame.index==6 if frame.animated else frame.index==3,"immediate release "+id)
				check(is_finite(frame.height) and frame.height>0 and frame.body_pixels==112.,"body unit "+id)
				check(frame.foot.x>=0 and frame.foot.y>=0,"foot anchor "+id)
				check(Presentation.facing(p,frame.source_facing)==side,"shot direction "+id)
				var at=Art.launch_offset(p,p.aim)
				check(is_finite(at.x) and is_finite(at.y) and at.x*side>0 and at.y<0,"forward muzzle "+id)
				if not sim.combat.projectiles.is_empty():
					var shot=sim.combat.projectiles.back()
					check(shot.pos==p.pos,"simulation launch unchanged "+id)
					check(Presentation.projectile_offset(shot).is_equal_approx(at),"projectile begins at muzzle "+id)
					var flashes=sim.events.filter(func(e):return e.type=="attack")
					check(flashes.size()==1 and flashes[0].visual_origin.is_equal_approx(at),"flash and shot coincide "+id)
					shot.pos+=shot.dir*10
					check(Presentation.projectile_offset(shot)==Vector2(0,-70),"distant projectile reaches hit plane "+id)
				p.aim=-p.aim
				check(Presentation.facing(p)==side,"aim change preserves active release "+id)
				sim.combat.tick_player(p,.14)
				check(Art.frame(p,0).index==7 if frame.animated else Art.frame(p,0).index==0,"recovery visible "+id)
				sim.combat.tick_player(p,.10)
				check(Presentation.facing(p)==-side,"idle follows new aim "+id)
				p.aim=-p.aim
			records.append({"id":id,"side":side,"height":Art.frame(p,0).height})
		# A dodge, hurt, death, charge and a new skill must not retain the shot gaze.
		p.aim=Vector2(1,-1);sim.combat.attack(p,false,0);p.aim=-p.aim
		for state in ["dodge_time","hurt_time","down_time"]:
			p[state]=.1;check(Presentation.facing(p)==-1.,"interrupt unlock "+state+id);p[state]=0.
		p.charge_time=0.;check(Presentation.facing(p)==-1.,"charge unlock "+id);p.charge_time=-1.
		p.motion_duration=.35;check(Presentation.facing(p)==-1.,"new skill unlock "+id)
	check(cases.size()==90,"all registered routes")
	check(preload("res://scripts/job_art.gd").pet_body_pixels(false)>=Presentation.BODY_PIXELS*2.,"summoner companions at least twice player body")
	for corrected in ["sniper","hunter","explorer"]:
		var measured=Presentation.profile("jobs:"+corrected).measurement
		var data=Art.frame({"class_id":corrected,"avatar":"auto","costume":"none"},0)
		var displayed=(measured.source_sole_y-measured.source_crown_y)*data.body_pixels/data.height
		check(absf(displayed-112.)<.01,"measured crown to sole equals reference "+corrected)
		check(measured.before_body_pixels<100.,"correction addresses measured undersize "+corrected)
		check((-data.foot*data.body_pixels/data.height+data.foot*data.body_pixels/data.height).is_zero_approx(),"corrected sole remains on world point "+corrected)
	var mage={"class_id":"mage","avatar":"auto","costume":"none","aim":Vector2(1,-1),"motion":"cast_high","motion_time":.24,"motion_duration":.5}
	check(Art.frame(mage,0).index==10 and Art.frame(mage,0).source_facing==-1.,"mage high cast hand uses opposite source-facing")
	check(Art.launch_offset(mage,mage.aim).x>0,"mage high cast launches on aim side")
	mage.motion="cast";check(Art.frame(mage,0).source_facing==1.,"mage normal source-facing restored")
	var path=ProjectSettings.globalize_path("res://../runtime/character-runtime-gallery/verification.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":records},"\t"));file.close()
	print("CHARACTER_PRESENTATION_V054 checks=",checks," failures=",failures.size()," routes=",cases.size());quit(0 if failures.is_empty() else 1)
