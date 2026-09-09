extends "res://tests/qa_combat_v052.gd"
const Balance=preload("res://scripts/job_balance.gd")
const Scaling=preload("res://scripts/skill_scaling.gd")
const Active=preload("res://scripts/active_skills.gd")

func skill(job:String,id:String)->Dictionary:
	for node in Content.SKILLS[job]:
		if node.id==id:return node
	check(false,"검증 기술을 찾을 수 없음: "+job+" / "+id);return {}
func use_skill(f:Dictionary,id:String)->bool:
	f.p.skill_ranks[id]=1;f.p.skill_loadout.skill_q=id
	return f.sim.action(f.p.id,"skill_q")
func reset_boss(f:Dictionary):
	f.sim.clock+=1.;Stagger.reset(f.sim,f.e)
func prepared(f:Dictionary,id:String)->Dictionary:
	var node=skill(f.p.class_id,id);f.p.skill_ranks[id]=1
	var cast=Balance.profile(f.p,node,1,f.sim.damage_for(f.p),f.p.max_hp)
	cast.merge({"target":f.e.id,"origin":f.p.pos,"aim":f.p.aim})
	f.sim.combat.jobs.configure(f.p,cast)
	cast["stagger"]=f.sim.combat.constellation.prepare(f.p,node,cast)
	return cast

func old_zones():
	for spec in [["mage","frost_nova"],["mage","thunder"],["hunter","hunter_a05"],["infighter","infighter_a01"],["martialist","martialist_a03"]]:
		for rejected in [false,true]:
			var f=fixture(spec[0],"warden");var stamina=f.p.stamina
			check(use_skill(f,spec[1]) and f.sim.combat.skills.zones.size()==1,"실제 장판 시전: "+str(spec))
			check(f.p.stamina<stamina and f.p.skill_cooldowns[spec[1]]>0,"장판은 정상적으로 시전 비용과 대기시간 소비")
			var zone=f.sim.combat.skills.zones[0]
			if rejected:reset_boss(f)
			var target_before=f.e.duplicate(true);var player_before=f.p.duplicate(true)
			f.sim.combat.skills.tick(.4)
			if rejected:
				check(f.e==target_before and damages(f).is_empty(),"리셋 이전 장판은 체력·감속·기절·출혈·무력화 불변: "+str(spec))
				check(f.p==player_before and not zone.get("hit_any",false) and f.sim.combat.constellation.pending.is_empty(),"거절된 장판은 자원·연무·특성 후속 효과를 주지 않음: "+str(spec))
			else:
				check(f.e.hp<target_before.hp and not damages(f).is_empty(),"정상 장판의 실제 피해 유지: "+str(spec))
				if spec[1]=="frost_nova":check(f.e.slow_time>0,"정상 서리 장판의 감속 유지")
				elif spec[1]=="thunder":check(f.e.stun_time>0,"정상 번개의 기절 유지")
				elif spec[0]=="hunter":check(f.e.job_status.has("root") and f.e.job_status.has("bleed"),"정상 사냥꾼 덫의 속박과 출혈 유지")
				elif spec[0]=="infighter":check(f.p.job_state.rush==1 and zone.hit_any,"연타 장판도 시전당 몰아침 한 번 지급")
				elif spec[0]=="martialist":check(f.p.job_state.combo==1 and zone.hit_any,"연타 장판도 시전당 연무 한 번 지급")
	# 처치 타격도 해당 장판의 첫 유효 적중으로 인정한다.
	var f=fixture("infighter","warden");f.e.hp=1
	check(use_skill(f,"infighter_a01"),"처치 장판 시전")
	f.sim.combat.skills.tick(.08)
	check(f.e.hp==0 and f.p.kills==1 and f.p.job_state.rush==1,"장판의 마지막 타격은 처치와 몰아침 지급 유지")

func delayed_casts():
	for rejected in [false,true]:
		var f=fixture("elementalist","warden");var stamina=f.p.stamina
		check(use_skill(f,"elementalist_a05") and not f.p.job_state.casting.is_empty(),"원소술사 감속 기술의 실제 지연 시전 시작")
		check(f.p.stamina<stamina and f.p.skill_cooldowns.elementalist_a05>0,"지연 시전 비용과 대기시간 소비")
		if rejected:reset_boss(f)
		var target_before=f.e.duplicate(true);var paid=f.p.stamina
		f.sim.combat.jobs.tick(f.p,1.)
		check(f.p.job_state.casting.is_empty() and f.p.stamina==paid,"지연 시전 완료는 적중 거절 시에도 소비한 기력 유지")
		if rejected:check(f.e==target_before and damages(f).is_empty(),"리셋 이전 지연 시전의 체력·감속·상태 불변")
		else:check(f.e.hp<target_before.hp and f.e.job_status.has("slow") and f.e.slow_time>0,"정상 지연 시전 피해와 감속 유지")
	# 즉시 기술도 저장된 시전 예산으로 전달되는 공통 실행 경로를 검사한다.
	for spec in [["thief","thief_a01"],["thief","thief_a09"],["infighter","infighter_a03"],["martialist","martialist_a06"],["reaper","reaper_a01"]]:
		for rejected in [false,true]:
			var f=fixture(spec[0],"warden");f.p.skill_ranks[spec[0]+"_p06"]=1
			var ally=f.sim.add_player(2,"연계 지원 검증");ally.pos=f.p.pos
			var cast=prepared(f,spec[1])
			if rejected:reset_boss(f)
			var target_before=f.e.duplicate(true)
			f.sim.combat.jobs.execute(f.p,cast)
			var state=f.p.job_state
			if rejected:
				check(f.e==target_before and damages(f).is_empty(),"거절된 일반 기술의 대상 상태 불변: "+str(spec))
				check(state.marks.is_empty() and state.get("support_sent",[]).is_empty() and state.buffs.is_empty() and ally.job_state.buffs.is_empty() and state.rush==0 and state.combo==0 and state.instant==0,"거절된 일반 기술의 표식·지원·몰아침·연무·즉결 준비 차단: "+str(spec))
			else:
				check(f.e.hp<target_before.hp,"정상 일반 기술의 실제 피해 유지: "+str(spec))
				if spec[1]=="thief_a01":check(state.marks.has(str(f.e.id)) and f.e.job_status.has("vulnerable"),"정상 도적 표식과 취약 유지")
				elif spec[1]=="thief_a09":check(f.e.job_status.has("bleed") and ally.job_state.buffs.has("leech"),"정상 도적 출혈과 아군 지원 유지")
				elif spec[0]=="infighter":check(state.rush==1,"정상 일반 기술의 몰아침 유지")
				elif spec[0]=="martialist":check(state.combo==1,"정상 일반 기술의 연무 유지")
				elif spec[0]=="reaper":check(state.instant>0,"정상 사신 사슬의 즉결 준비 유지")

func remaining_hit_effects():
	for rejected in [false,true]:
		var f=fixture("breaker","warden")
		check(use_skill(f,"breaker_a06") and f.p.job_state.parry>0,"실제 반격 자세 시작")
		if rejected:reset_boss(f)
		var hp=f.e.hp
		check(f.sim.combat.jobs.receive(f.p,f.e,100,true)==0 and f.p.job_state.momentum>0,"반격 타격 거절과 무관하게 실제 방어 성공은 피해 차단과 방어 자원 유지")
		check((f.e.hp==hp and f.e.get("job_status",{}).is_empty()) if rejected else (f.e.hp<hp and f.e.job_status.has("stun")),"반격 기절은 실제 반격 피해가 맞았을 때만 적용: "+str(rejected))
		f=fixture("summoner","warden")
		f.p.job_state.pets=[{"source":"검증 소환수","pos":f.p.pos,"hp":100.,"max_hp":100.,"cd":0.,"power":.32,"kind":0}]
		var cast=prepared(f,"summoner_a09")
		if rejected:reset_boss(f)
		var before=f.e.duplicate(true);f.sim.combat.jobs.execute(f.p,cast)
		check(f.e==before if rejected else (f.e.hp<before.hp and f.e.job_status.has("bleed")),"소환수 명령의 출혈은 실제 피해가 맞았을 때만 적용: "+str(rejected))
	# 기본 연쇄와 끌어당김도 적중을 거절한 표적을 후속 연결로 사용하지 않는다.
	for mode in ["chain","pull"]:
		var f=fixture("mage","warden");var node={}
		for candidate in Content.SKILLS.mage:
			if candidate.get("mode","")==mode:node=candidate;break
		check(not node.is_empty(),"기본 마법사 연쇄·끌어당김 기술 정의: "+mode)
		if node.is_empty():continue
		var profile=Scaling.profile(node,1,Active.bonuses(f.p))
		f.sim.combat.stagger_context=Stagger.context(Stagger.token(node,1,f.p,f.sim.clock))
		reset_boss(f);var before=f.e.duplicate(true)
		f.sim.combat.skills.cast_extended(f.p,node,50,profile)
		check(f.e==before and damages(f).is_empty(),"거절된 기본 기술은 대상 이동·피해·연쇄 연결을 만들지 않음: "+mode)
		if mode=="chain":check(not f.sim.events.any(func(event):return event.type=="skill_fx"),"거절된 연쇄 표적에 연결선이 생기지 않음")
		f.sim.combat.stagger_context={}

func run():
	old_zones();delayed_casts();remaining_hit_effects()
	print("QA_SKILL_REJECTION_V052 checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
