extends SceneTree
const Local=preload("res://scripts/local_session.gd")
const Content=preload("res://scripts/content.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	var local=Local.new();root.add_child(local);local.set_physics_process(false)
	local.save_directory=ProjectSettings.globalize_path("res://../runtime/build-session-v04/"+str(Time.get_ticks_usec()));local.start_game("연결의 모험가",1)
	var p=local.sim.players[1];p.level=100;p.gold=781;p.tutorial_done=true;local.sim.map.zone="town"
	var key="warrior:star:0:key";var plan=Content.Build.path_plan(p,key)
	check(plan.ok and plan.cost>6,"key needs a real paid path")
	for step in plan.steps:check(local.act("invest",step.id),"actual session invests "+step.id)
	check(Content.Build.validate_build(p).ok and p.constellation_allocations.get(key,0)==1,"legal allocated build")
	var active=Content.SKILLS.warrior.filter(func(n):return n.effect=="active" and p.skill_ranks.get(n.id,0)>0)[0]
	check(local.act("bind_skill","skill_q:"+active.id),"learned original bound to active slot")
	var spent=Content.Build.spent_points(p);var ranks=p.skill_ranks.duplicate(true);var stars=p.constellation_allocations.duplicate(true)
	check(Content.available_points(p)==99-spent,"one shared point budget")
	local.save_game();check(local.parse_save(local.save_path())!=null,"selected path save validates")
	local.disconnect_game();local.start_game("무시",1);p=local.sim.players[1]
	check(p.name=="연결의 모험가" and p.gold==781 and p.skill_ranks==ranks and p.constellation_allocations==stars,"restart preserves property and both skill allocations")
	check(p.skill_loadout.skill_q==active.id and Content.Build.spent_points(p)==spent,"restart preserves loadout and exact spent SP")
	local.sim.map.zone="forest";p.pos=local.sim.map.spawn
	var before=JSON.stringify(p)
	check(not local.act("class","ranger") and not local.act("uninvest",key) and not local.act("reset_skills"),"dungeon entrance blocks every respec route")
	check(JSON.stringify(p)==before,"rejected respec does not alter build or runtime")
	local.sim.map.zone="town"
	p.barrier_time=9;p.haste_time=8;p.job_state.pets=[{"fixture":true}];p.job_state.buffs={"fixture":{"time":8}}
	local.sim.combat.projectiles.append({"owner":1});local.sim.combat.skills.zones.append({"owner":1});local.sim.combat.constellation.pending.append({"owner":1})
	check(local.act("uninvest","warrior:star:0:m0"),"town removes connection and dependent selections")
	check(not p.constellation_allocations.has(key) and Content.available_points(p)>99-spent,"orphaned keystone refunded")
	check(p.barrier_time==0 and p.haste_time==0 and p.job_state.pets.is_empty() and p.job_state.buffs.is_empty(),"old buffs and summons cleared")
	check(local.sim.combat.projectiles.is_empty() and local.sim.combat.skills.zones.is_empty() and local.sim.combat.constellation.pending.is_empty(),"old pending attacks cleared")
	check(local.parse_save(local.save_path())!=null,"cascaded refund persists a valid build")
	check(local.act("reset_skills") and Content.available_points(p)==99 and p.skill_ranks.is_empty() and p.constellation_allocations.is_empty() and p.skill_loadout.is_empty(),"full reset returns exact budget and clears loadout")
	check(p.gold==781 and p.level==100,"respec keeps property and level")
	local.disconnect_game();root.remove_child(local);local.free()
	print("SKILL_BUILD_SESSION_V04_TESTS checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
