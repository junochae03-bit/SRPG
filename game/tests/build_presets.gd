extends SceneTree
const Content=preload("res://scripts/content.gd")
const Sim=preload("res://scripts/simulation.gd")
const Presets=preload("res://scripts/build_presets.gd")
const Local=preload("res://scripts/local_session.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	Content.initialize_jobs()
	var sim=Sim.new(812,"town",0);sim.add_player(1,"빌드 검사")
	var p=sim.players[1]
	for job in Content.CLASSES:
		p.class_id=job;p.level=100;p.skill_ranks={};p.constellation_allocations={};p.skill_loadout={}
		for key in Presets.choices(p):
			var before=JSON.stringify(p);var quote=Presets.preview(p,key.id)
			check(JSON.stringify(p)==before,"preview leaves player untouched "+key.id)
			check(quote.ok,"legal preview "+key.id)
			if not quote.ok:continue
			check(Content.Build.validate_build(quote.player).ok and quote.spent<=99,"bounded prerequisites "+key.id)
			check(quote.player.constellation_allocations.has(key.id),"keystone identity "+key.id)
			check(quote.loadout.size()==mini(6,Content.SKILLS[job].filter(func(n):return n.effect=="active").size()),"complete active bar "+key.id)
			for id in quote.loadout:check(quote.player.skill_ranks.get(id,0)>0 and Content.Build.definition(id).class_id==job,"learned own class active "+id)
			var request=JSON.stringify({"target":key.id,"signature":quote.signature})
			check(sim.action(1,"apply_build",request),"actual application "+key.id)
			check(p.skill_loadout==quote.player.skill_loadout and p.skill_ranks==quote.player.skill_ranks,"atomic result "+key.id)
			p.skill_ranks={};p.constellation_allocations={};p.skill_loadout={}
		p.level=1
		for key in Presets.choices(p):check(not Presets.preview(p,key.id).ok,"no low level free unlock "+key.id)
	p.class_id="warrior";p.level=100
	var quote=Presets.preview(p,Presets.choices(p)[0].id)
	var argument=JSON.stringify({"target":quote.target,"signature":quote.signature})
	p.level=99;var before=JSON.stringify(p)
	check(not sim.action(1,"apply_build",argument) and before==JSON.stringify(p),"stale preview rejects without mutation")
	p.level=100;sim.map.zone="forest";before=JSON.stringify(p)
	check(not sim.action(1,"apply_build",argument) and before==JSON.stringify(p),"cannot respec in dungeon")
	var local=Local.new();root.add_child(local);local.set_physics_process(false)
	local.save_directory=ProjectSettings.globalize_path("res://../runtime/preset-save/"+str(Time.get_ticks_usec()));local.start_game("프리셋 저장",1)
	p=local.sim.players[1];p.level=100;local.sim.map.zone="town";p.tutorial_done=true
	quote=Presets.preview(p,Presets.choices(p)[0].id);local.paused=true
	check(local.act("apply_build",JSON.stringify({"target":quote.target,"signature":quote.signature})),"paused menu supports applying")
	check(local.parse_save(local.save_path())!=null,"applied build keeps save contract")
	var ranks=p.skill_ranks.duplicate(true);var loadout=p.skill_loadout.duplicate(true)
	local.disconnect_game();local.start_game("",1)
	check(local.sim.players[1].skill_ranks==ranks and local.sim.players[1].skill_loadout==loadout,"restart preserves full preset")
	local.disconnect_game();local.free()
	print("BUILD_PRESETS checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
