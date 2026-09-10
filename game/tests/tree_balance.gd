extends SceneTree
const C=preload("res://scripts/content.gd")
const R=preload("res://scripts/skill_build.gd")
const E=preload("res://scripts/constellation_effects.gd")
const B=preload("res://scripts/job_balance.gd")
const S=preload("res://scripts/skill_scaling.gd")
const Stagger=preload("res://scripts/boss_stagger.gd")
const Sim=preload("res://scripts/simulation.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;push_error(label)
func profile(p:Dictionary,n:Dictionary)->Dictionary:
	return B.profile(p,n,1,100,1000) if C.job(p) else S.profile(n,1,preload("res://scripts/active_skills.gd").bonuses(p))
func fixture(job:String)->Dictionary:
	var sim=Sim.new(123);sim.enemies.clear();var p=sim.add_player(1,"노드 역할 검사")
	p.class_id=job;p.level=100;p.skill_ranks={};p.constellation_allocations={};p.skill_loadout={}
	for n in C.SKILLS[job]:
		if n.effect=="active":p.skill_ranks[n.id]=1
	for suffix in ["n0","n1"]:
		var plan=R.path_plan(p,job+":star:0:"+suffix);check(plan.ok,"모듈 경로: "+job)
		p.skill_ranks=plan.player.skill_ranks;p.constellation_allocations=plan.player.constellation_allocations
	sim.recalculate(p);sim.combat.jobs.reset(p);sim.combat.constellation.reset(p)
	p.pos=Vector2(sim.map.rooms[1]);p.aim=Vector2.RIGHT;p.stamina=p.max_stamina
	return {"sim":sim,"p":p}
func run():
	C.initialize_jobs();var totals={};var modules=0
	for job in C.CLASSES:
		var kinds={};var f=fixture(job);var p=f.p
		check(R.validate_build(p).ok,"기존 SP·선행·저장 규칙 유효: "+job)
		for n in R.nodes_for(job):
			kinds[n.node_kind]=true;totals[n.node_kind]=totals.get(n.node_kind,0)+1
			if n.node_kind=="active_module":
				modules+=1;var target=R.definition(n.target_active_id)
				check(target.class_id==job and target.effect=="active","모듈 대상 직업·액티브 참조: "+n.id)
		check(kinds.size()==4,"모든 직업에 네 역할 존재: "+job)
		var baseline=p.duplicate(true);baseline.constellation_allocations.erase(job+":star:0:n0");baseline.constellation_allocations.erase(job+":star:0:n1")
		check(not R.effects(p).has("followup_damage") and not R.effects(p).has("stagger_followup"),"모듈은 전역 캐릭터 효과에 섞이지 않음: "+job)
		var target_id=R.definition(job+":star:0:n0").target_active_id
		for ready in [false,true]:
			p.constellation_state.support_time=4. if ready else 0.;baseline.constellation_state.support_time=p.constellation_state.support_time
			for n in C.SKILLS[job]:
				if n.effect!="active":continue
				var a=profile(baseline,n);var b=profile(p,n);var power="power" if C.job(p) else "multiplier"
				check(b[power]>a[power] if ready and n.id==target_id else is_equal_approx(b[power],a[power]),"조건 및 대상 격리: "+n.id+str(ready))
				check(is_equal_approx(a.cost,b.cost) and is_equal_approx(a.cooldown,b.cooldown),"피해 모듈은 비용·쿨타임을 바꾸지 않음: "+n.id)
				var sa=Stagger.skill_profile(n,1,baseline).value;var sb=Stagger.skill_profile(n,1,p).value
				check(sb>sa if ready and n.id==target_id else is_equal_approx(sa,sb),"무력화 모듈 대상 격리: "+n.id)
		# 저장된 ID와 배분 그대로 왕복하며 새 분류는 저장 데이터에 넣지 않는다.
		var restored=JSON.parse_string(JSON.stringify({"class_id":job,"level":100,"skill_ranks":p.skill_ranks,"constellation_allocations":p.constellation_allocations}))
		check(R.validate_build(restored).ok and R.spent_points(restored)==R.spent_points(p),"저장 배분 호환: "+job)
	for job in ["swordsman","healer"]:
		var damage=[]
		for enabled in [false,true]:
			var f=fixture(job);var p=f.p;var id=R.definition(job+":star:0:n0").target_active_id
			if not enabled:p.constellation_allocations.erase(job+":star:0:n0");p.constellation_allocations.erase(job+":star:0:n1")
			p.constellation_state.support_time=4.;p.skill_loadout.skill_q=id
			var enemy=f.sim.spawn_enemy("shade",p.pos+Vector2.RIGHT,60);enemy.hp=100000;enemy.max_hp=enemy.hp
			check(f.sim.action(1,"skill_q"),"지원 연계 모듈 실제 시전: "+job)
			for i in range(50):f.sim.combat.tick_player(p,.02);f.sim.combat.tick_projectiles(.02);f.sim.combat.skills.tick(.02)
			damage.append(100000-enemy.hp)
		check(damage[0]>0 and damage[1]>damage[0],"지원 직업도 모듈로 실제 피해 증가: "+job)
	check(modules==220,"원기술 강화 180개 및 대상 지정 연결 모듈 40개")
	var db=preload("res://scripts/game_database.gd").snapshot();check(db.build_concepts.size()==100,"직업별 컨셉 5개 기록")
	for row in db.build_nodes:
		var n=R.definition(row.id);check(row.node_kind==n.node_kind and row.target_active_id==n.target_active_id and row.effect_scope==n.effect_scope,"DB와 실제 역할·범위 일치: "+row.id)
	print("TREE_BALANCE_ROLE_COUNTS ",JSON.stringify(totals))
	print("TREE_BALANCE checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
