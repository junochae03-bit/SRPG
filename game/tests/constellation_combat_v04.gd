extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Content=preload("res://scripts/content.gd")
const Rules=preload("res://scripts/skill_build.gd")
const Effects=preload("res://scripts/constellation_effects.gd")
const Balance=preload("res://scripts/job_balance.gd")
const Scaling=preload("res://scripts/skill_scaling.gd")
const Active=preload("res://scripts/active_skills.gd")
const Stagger=preload("res://scripts/boss_stagger.gd")
const HitGeometry=preload("res://scripts/enemy_hit_geometry.gd")
var checks=0
var failures=[]
var build_comparison={}
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func close(a:float,b:float,tolerance:float=.02)->bool:return absf(a-b)<=tolerance
func fixture(job:String,keys:Array=[],all_routes:bool=false)->Dictionary:
	var sim=Sim.new(177,"forest",10);sim.enemies.clear()
	var p=sim.add_player(1,"별자리 전투 검사");p.class_id=job;p.level=99;p.stats={"technique":30};p.skill_ranks={};p.constellation_allocations={};p.skill_loadout={}
	for node in Content.SKILLS[job]:
		if node.effect=="active":p.skill_ranks[node.id]=1
	if all_routes:
		for node in Rules.constellation_nodes(job):
			if node.type!="keystone":p.constellation_allocations[node.id]=1
	for cluster in keys:
		var plan=Rules.path_plan(p,"%s:star:%d:key"%[job,cluster]);check(plan.ok,"legal key path "+job+str(cluster))
		p.skill_ranks=plan.player.skill_ranks;p.constellation_allocations=plan.player.constellation_allocations
	check(Rules.validate_build(p).ok,"legal shared SP fixture "+job+str(keys))
	sim.recalculate(p);sim.combat.jobs.reset(p);sim.combat.constellation.reset(p)
	p.max_stamina=10000.;p.stamina=10000.;p.pos=Vector2(sim.map.rooms[1]);p.aim=Vector2.RIGHT;p.dir=Vector2.ZERO
	var e=enemy(sim,p.pos+Vector2(1.2,0))
	return {"sim":sim,"p":p,"e":e,"origin":p.pos}
func enemy(sim,pos:Vector2)->Dictionary:
	var e=sim.spawn_enemy("shade",pos,99,true);e.max_hp=10000000;e.hp=e.max_hp;e.raid=false;e.stagger.max_value=1000000.
	return e
func node_for(job:String,mode:String)->Dictionary:
	for n in Content.SKILLS[job]:
		if n.effect=="active" and Stagger.skill_profile(n,1).mode==mode:return n
	check(false,"missing test skill "+job+" "+mode);return {}
func profile(f:Dictionary,n:Dictionary,rank:int=1)->Dictionary:
	return Balance.profile(f.p,n,rank,f.sim.damage_for(f.p),f.p.max_hp) if Content.job(f.p) else Scaling.profile(n,rank,Active.bonuses(f.p))
func cast(f:Dictionary,n:Dictionary)->Dictionary:
	var s=profile(f,n);f.p.skill_loadout.skill_q=n.id;f.p.skill_ranks[n.id]=1
	var stamina=f.p.stamina
	check(f.sim.action(1,"skill_q"),"actual cast "+n.id)
	# Immediate first-hit refunds are intentionally included in the paid amount.
	var refund=s.get("constellation",{}).get("mobile",false) and f.p.constellation_state.last_skill==n.id
	var expected=s.cost*(1.-float(Effects.values(f.p).get("mobility_refund",0))) if refund else s.cost
	check(close(stamina-f.p.stamina,expected),"preview cost equals real payment "+n.id)
	check(close(f.p.skill_cooldowns[n.id],s.cooldown),"preview cooldown equals real cooldown "+n.id)
	return s
func advance(f:Dictionary,seconds:float):
	for i in range(ceili(seconds/.02)):
		f.sim.clock+=.02;f.sim.combat.tick_player(f.p,.02);f.sim.combat.tick_projectiles(.02);f.sim.combat.skills.tick(.02)
func clear_cast(f:Dictionary):
	f.p.skill_cooldowns={};f.p.job_state.lock=0.;f.p.job_state.casting={};f.p.dodge_time=0.;f.p.attack_cd=0.
func total(f:Dictionary,id:int=-1)->float:
	var value=0.
	for event in f.sim.events:
		if event.type=="stagger_damage" and (id<0 or event.enemy==id):value+=event.amount
	return value
func hits(f:Dictionary)->Array:return f.sim.events.filter(func(ev):return ev.type=="damage" and ev.get("enemy",false))
func leave_delayed_area(f:Dictionary,kind:String):
	var areas=f.sim.combat.constellation.pending.filter(func(hit):return hit.kind==kind)
	check(not areas.is_empty(),"delayed area exists before evasion "+kind)
	if areas.is_empty():return
	var area=areas[0];var required=float(area.radius)+HitGeometry.radius(f.e)+.2
	var closest=INF;var destination=Vector2.INF
	for cell in f.sim.map.floor_cells:
		var point=Vector2(cell);var distance=point.distance_to(area.pos)
		if distance>=required and distance<closest and f.sim.map.walkable(point) and f.sim.map.line_clear(area.pos,point):
			closest=distance;destination=point
	check(destination.is_finite(),"reachable escape beyond receiving body "+kind)
	if not destination.is_finite():return
	f.e.pos=destination
	check(not HitGeometry.circle(f.e,area.pos,area.radius) and f.sim.map.line_clear(area.pos,f.e.pos),"entire receiving body outside delayed area with no wall hiding it "+kind)
func run():
	Content.initialize_jobs()
	# Exhaust all original active IDs at both rank endpoints with each legal key.
	for job in Content.CLASSES:
		for key in range(5):
			var f=fixture(job,[key]);var saved=Content.SKILLS[job].duplicate(true)
			for n in Content.SKILLS[job]:
				if n.effect!="active":continue
				for rank in [1,Content.max_rank(n)]:
					var s=profile(f,n,rank);var info=s.constellation;var budget=info.direct_stagger
					for proc in info.procs:budget+=proc.weight
					check(close(budget,1.) and s.cost>=5 and s.cooldown>=.5 and s.count>0,"finite bounded profile "+n.id+str(key)+str(rank))
					check(info.source_mode==Stagger.skill_profile(n,rank).mode,"source dispatcher preserved "+n.id)
					if Content.job(f.p):check(s.node.id==n.id and s.node.mode==n.mode and s.node.index==n.index,"class resource identity preserved "+n.id)
			check(Content.SKILLS[job]==saved,"pure resolve never mutates source catalog "+job+str(key))
	# Five families get competing legal, equal-SP builds with distinct live delivery.
	for spec in [["swordsman","strike","buff_attack"],["sniper","shot","stance"],["healer","strike","heal"],["reaper","heavy","guard"],["fighter","strike","guard"]]:
		var pair=[]
		for key in [3,4]:
			var f=fixture(spec[0],[key],true);var attack=node_for(spec[0],spec[1]);var support=node_for(spec[0],spec[2])
			f.p.hp=f.p.max_hp/2;cast(f,support);advance(f,1.2);clear_cast(f)
			var s=cast(f,attack);advance(f,6.)
			check(f.e.hp<f.e.max_hp and total(f)>0,"family build produces real hit "+spec[0]+str(key))
			check(total(f)<=Stagger.skill_profile(attack,1,f.p).value+.02,"family cast retains one stagger budget "+spec[0]+str(key))
			pair.append({"cost":Rules.spent_points(f.p),"profile":s,"damage":f.e.max_hp-f.e.hp,"hits":hits(f).size()})
		check(pair[0].cost==pair[1].cost,"competing builds use equal SP "+spec[0])
		check(pair[0].profile.constellation!=pair[1].profile.constellation and (pair[0].damage!=pair[1].damage or pair[0].hits!=pair[1].hits),"competing builds change actual outcome "+spec[0])
		build_comparison[spec[0]]={"sp":pair[0].cost,"family_a_damage":pair[0].damage,"family_a_hits":pair[0].hits,"family_b_damage":pair[1].damage,"family_b_hits":pair[1].hits}
	# Ground echo has an opportunity window; focus really limits an AoE to one enemy.
	var f=fixture("warrior",[0]);var n=node_for("warrior","spin");var second=enemy(f.sim,f.p.pos+Vector2(1.2,.8));var s=cast(f,n)
	advance(f,.1);var primary=f.e.hp;check(not f.sim.combat.constellation.pending.is_empty(),"actual multi-hit spawns only one echo")
	advance(f,2.);check(f.e.hp<primary and second.hp<second.max_hp,"echo and source AoE land on both targets")
	check(close(total(f,f.e.id),Stagger.skill_profile(n,1,f.p).value),"multi-hit plus echo spends exact shared boss budget")
	f=fixture("warrior",[1]);n=node_for("warrior","spin");second=enemy(f.sim,f.p.pos+Vector2(1.2,.8));cast(f,n);advance(f,2.)
	check(f.e.hp<f.e.max_hp and second.hp==second.max_hp and total(f,second.id)==0,"focus rejects every hit on second target")
	f=fixture("swordsman",[0]);n=node_for("swordsman","strike");cast(f,n);primary=f.e.hp;leave_delayed_area(f,"echo");advance(f,.5)
	check(f.e.hp==primary,"moving out of delayed echo avoids extra damage")
	# A common + family pair retains both effects and a single token.
	f=fixture("swordsman",[0,3]);n=node_for("swordsman","strike");var far=enemy(f.sim,f.p.pos+Vector2(4,0));s=cast(f,n)
	check(s.constellation.procs.size()==2,"echo and warrior wave both resolved")
	advance(f,1.);check(far.hp<far.max_hp,"warrior wave extends beyond the original sword reach")
	check(close(total(f,f.e.id),Stagger.skill_profile(n,1,f.p).value),"two triggered deliveries share one full budget")
	check(f.sim.combat.constellation.pending.is_empty(),"triggered hits cannot recursively trigger more casts")
	# Chain cannot revisit its source; a delayed trap can miss a moving victim.
	f=fixture("sniper",[3]);n=node_for("sniper","shot");second=enemy(f.sim,f.p.pos+Vector2(1.2,1.5));far=enemy(f.sim,f.p.pos+Vector2(1.2,-1.5));cast(f,n);advance(f,2.)
	check(second.hp<second.max_hp and far.hp<far.max_hp,"chain reaches two new real targets: %s / %s clear=%s"%[second.max_hp-second.hp,far.max_hp-far.hp,f.sim.map.line_clear(f.e.pos,far.pos)])
	check(total(f,f.e.id)<Stagger.skill_profile(n,1,f.p).value,"chain loses single-target stagger share")
	f=fixture("sniper",[4]);n=node_for("sniper","root_shot");cast(f,n);advance(f,.2);primary=f.e.hp;leave_delayed_area(f,"snare");advance(f,1.3)
	check(f.e.hp==primary,"snare explosion can be avoided after direct projectile hit")
	# Support-power tradeoff and anchored cross-skill activation are actual runtime.
	f=fixture("healer",[4]);n=node_for("healer","heal");var blank=fixture("healer");var support_profile=profile(f,n)
	check(support_profile.heal<profile(blank,n).heal,"relay sacrifices actual healing power")
	f.p.hp=1;cast(f,n);check(f.p.hp==1+roundi(support_profile.heal),"support preview is exact actual healing")
	var anchor=f.p.pos;clear_cast(f);f.p.pos+=Vector2(0,2.5);f.p.aim=Vector2.UP;f.e.pos=anchor;n=node_for("healer","strike");cast(f,n);advance(f,1.)
	check(f.e.hp<f.e.max_hp,"support anchor detonates at original support position")
	# Four DOT pulses are deferred, cancellable on reset and bounded.
	f=fixture("elementalist",[0,3]);n=node_for("elementalist","shot");cast(f,n);advance(f,1.);primary=f.e.hp
	check(f.sim.combat.constellation.pending.any(func(h):return h.kind=="burn"),"burn queues real four-tick effect")
	var queued=f.sim.combat.constellation.pending.duplicate(true);f.sim.combat.constellation.tick(0)
	check(f.sim.combat.constellation.pending==queued and f.e.hp==primary,"zero elapsed tick pauses procs")
	advance(f,5.);check(f.e.hp<primary and close(total(f,f.e.id),Stagger.skill_profile(n,1,f.p).value),"burn and echo exhaust one token with no recursive DOT")
	f=fixture("thief",[4]);n=node_for("thief","bleed");cast(f,n);advance(f,.04)
	var venom=f.sim.combat.constellation.pending.filter(func(h):return h.kind=="venom");check(venom.size()==4,"venom has exactly four pending ticks")
	primary=f.e.hp;check(f.sim.action(1,"dodge"),"real dodge triggers venom recall");f.sim.combat.skills.tick(.02)
	check(f.e.hp<primary and not f.sim.combat.constellation.pending.any(func(h):return h.kind=="venom"),"nearby venom ticks detonate once on dodge")
	advance(f,5.);check(total(f)<=Stagger.skill_profile(n,1,f.p).value+.02,"native bleed and venom retain shared stagger cap")
	f=fixture("thief",[4]);n=node_for("thief","bleed");cast(f,n);f.e.pos=f.p.pos+Vector2(7,0);f.sim.combat.constellation.moved(f.p)
	check(f.sim.combat.constellation.pending.all(func(h):return h.time>0),"venom cannot recall a distant target")
	f.sim.combat.constellation.reset(f.p);advance(f,.5);check(f.sim.combat.constellation.pending.is_empty(),"build reset clears pending new delivery")
	# Different skills consume contract marks; repeating the source never does.
	f=fixture("reaper",[3]);n=node_for("reaper","heavy");cast(f,n);advance(f,1.3);check(f.e.get("constellation_marks",{}).has("1"),"contract created by actual hit")
	clear_cast(f);var other=node_for("reaper","mark");var before=f.e.hp;s=cast(f,other)
	check(before-f.e.hp>=roundi(f.sim.damage_for(f.p)*s.power*1.49),"different skill consumes mark for real extra damage")
	check(not f.e.constellation_marks.has("1"),"consumed contract cannot immediately rearm itself")
	Stagger.reset(f.sim,f.e);check(not f.e.has("constellation_marks"),"boss encounter reset clears contract marks")
	# Movement + delivery must preserve source resource consumption and earning.
	for job in ["infighter","martialist"]:
		f=fixture(job,[3]);n=node_for(job,"barrage" if job=="infighter" else "combo");s=cast(f,n)
		advance(f,.05);check(hits(f).size()==1,"flurry first hit "+job)
		check(f.p.job_state.rush==1 if job=="infighter" else f.p.job_state.combo==1,"first actual transformed hit earns source resource "+job)
		check(f.sim.action(1,"dodge"),"flurry can be dodge cancelled "+job);advance(f,.7)
		check(hits(f).size()==1,"dodge cancels remaining moving hits "+job)
	f=fixture("fighter",[4]);n=node_for("fighter","strike");s=cast(f,n)
	check(hits(f).is_empty() and s.time>=.45,"crush adds real preparation window");advance(f,.7)
	check(hits(f).size()==1 and close(total(f),Stagger.skill_profile(n,1,f.p).value),"crush single hit spends complete source budget")
	f=fixture("breaker",[1,3]);n=node_for("breaker","charge");f.p.job_state.momentum=80;s=cast(f,n)
	check(f.p.job_state.momentum==0,"transformed charge consumes stored grit only once");advance(f,2.)
	check(hits(f).size()==3 and close(total(f),Stagger.skill_profile(n,1,f.p).value),"focus flurry hits one boss three times with source budget")
	f=fixture("breaker",[3]);n=node_for("breaker","parry_counter");s=cast(f,n)
	check(s.constellation.delivery=="original" and hits(f).is_empty(),"counter preparation retains its original class mechanic")
	# Follow-up and mobility effects arm only on the advertised real actions.
	f=fixture("swordsman",[2]);n=node_for("swordsman","strike");var neutral=profile(f,n)
	f.sim.combat.constellation.moved(f.p);check(not profile(f,n).constellation.mobile,"movement skill alone never arms dodge-only momentum")
	check(f.sim.action(1,"dodge"),"momentum real dodge");f.p.dodge_time=0.;s=profile(f,n)
	check(s.constellation.mobile and s.power>neutral.power,"dodge snapshot increases next skill damage")
	f.p.stamina=0;f.p.skill_loadout.skill_q=n.id;check(not f.sim.action(1,"skill_q") and f.p.constellation_state.move_time>0,"resource rejected cast preserves dodge opportunity")
	f.p.stamina=1000.;cast(f,n);check(f.p.constellation_state.move_time==0,"accepted attack consumes mobility opportunity once")
	f=fixture("swordsman",[0],true);n=node_for("swordsman","strike");neutral=profile(f,node_for("swordsman","execute"));cast(f,n)
	var next=profile(f,node_for("swordsman","execute"));check(next.power>neutral.power and next.cost<neutral.cost,"actual different skill hit raises damage and lowers cost")
	check(next.constellation.followup and not profile(f,n).constellation.followup,"same skill cannot earn alternate-skill bonuses")
	check(Stagger.skill_profile(node_for("swordsman","execute"),1,f.p).value>Stagger.skill_profile(n,1,f.p).value,"alternate hit raises next stagger profile")
	f.sim.combat.constellation.reset(f.p);clear_cast(f);f.e.pos=f.p.pos+Vector2(7,0);cast(f,n)
	check(f.p.constellation_state.last_skill.is_empty(),"missed skill grants no follow-up activation")
	print("CONSTELLATION_COMBAT_V04 ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures.size())
	print("EQUAL_SP_SINGLE_TARGET ",JSON.stringify(build_comparison))
	quit(0 if failures.is_empty() else 1)
