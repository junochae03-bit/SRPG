extends RefCounted
const Rules=preload("res://scripts/skill_build.gd")
const HitGeometry=preload("res://scripts/enemy_hit_geometry.gd")
const SUPPORT=["heal","regen","field_heal","barrier","haste","shield","ally_dash","wall","cleanse","distribute","return_anchor","parry","parry_counter","parry_knee","meditate","hit_card","hold_card","cut_card","dice","reroll","summon","pet_heal","pet_recall","pet_buff","pet_haste","pet_guard","pet_sacrifice","buff_attack","buff_crit","buff_crit_damage","guard","fortress","share","chant","stand_card","dice_buff","enchant","stance","empower"]
const MOVEMENT=["dash","rush","retreat","weave","flank","blink","teleport","teleport_chain","ally_dash","heavy_dash","card_retreat","chain_dash","chain_retreat","return_anchor"]
var combat_ref:WeakRef
var pending:Array=[]
var cast_serial=0
var combat:
	get:return combat_ref.get_ref()
func _init(owner_combat):combat_ref=weakref(owner_combat)
static func values(p:Dictionary)->Dictionary:return Rules.effects(p)
static func state(p:Dictionary)->Dictionary:return p.get("constellation_state",{})
static func following(p:Dictionary,node_id:String)->bool:
	var s=state(p);return s.get("last_time",0)>0 and s.get("last_skill","")!="" and s.last_skill!=node_id
static func stagger_multiplier(p:Dictionary,node_id:String="")->float:
	var v=values(p)
	return 1.+float(v.get("stagger_power",0))+(float(v.get("stagger_followup",0)) if following(p,node_id) else 0.)
static func resolve(p:Dictionary,node:Dictionary,raw:Dictionary,advanced:bool=false)->Dictionary:
	var s=raw.duplicate(true);var v=values(p)
	if v.is_empty():return s
	var n=s.get("node",node);var mode=str(n.get("mode",s.get("mode","")));var attacking=mode not in SUPPORT
	var follow=following(p,str(node.id));var ready=state(p).get("move_time",0)>0;var support_ready=state(p).get("support_time",0)>0
	var info={"effects":v.duplicate(true),"source_id":node.id,"source_mode":mode,"attacking":attacking,"followup":follow,"mobile":ready,"support":support_ready,"delivery":"original","direct_damage":1.,"direct_stagger":1.,"procs":[],"max_targets":0,"paid_cost":0.}
	s["constellation"]=info
	s.cooldown=maxf(.5,s.cooldown*(1.-minf(.4,float(v.get("skill_haste",0)))))
	s.cost=maxf(5.,s.cost*(1.-minf(.4,float(v.get("skill_discount",0)))))
	if follow:s.cost=maxf(5.,s.cost*(1.-minf(.35,float(v.get("efficiency_followup",0)))))
	var geometry=s.node if advanced else s
	for key in ["range","radius","distance"]:
		if geometry.has(key):geometry[key]*=1.+float(v.get("skill_radius" if key=="radius" else "skill_range",0))
	if geometry.has("duration"):geometry.duration*=1.+float(v.get("skill_duration",0))
	for key in ["slow","stun"]:
		if s.has(key):s[key]*=1.+float(v.get("skill_duration",0))
	var support_scale=1.+float(v.get("support_power",0))
	if v.get("warrior_reprise",0)>0 or v.get("mage_relay",0)>0:support_scale*=.8
	for key in ["heal","regen","shield","buff","pet_power","pet_hp","pet_buff","counter_power","barrier","haste_speed","haste_attack"]:
		if s.has(key):s[key]*=support_scale
	if not attacking:return s
	var power_key="power" if advanced else "multiplier"
	s[power_key]*=1.+float(v.get("skill_damage",0))+(float(v.get("followup_damage",0)) if follow else 0.)+(float(v.get("support_followup",0)) if support_ready else 0.)
	if v.get("focus",0)>0:s[power_key]*=1.25;s.cost*=1.25;info.max_targets=1
	if v.get("momentum",0)>0:
		s.cost*=1.1
		if ready:s[power_key]*=1.25;s["time"]=float(s.get("time",0))*.5
	if v.get("rogue_contract",0)>0:s[power_key]*=.9
	if v.get("echo",0)>0:_split(info,"echo",.7,.4,.7,.3,.35);s.cooldown*=1.15
	if v.get("warrior_wave",0)>0:_split(info,"wave",.75,.35,.75,.25,0.);s.cost*=1.15
	if v.get("warrior_reprise",0)>0 and support_ready:_split(info,"reprise",.5,.7,.5,.5,.25)
	if v.get("ranger_chain",0)>0:_split(info,"chain",.7,.5,.7,.3,.12)
	if v.get("ranger_snare",0)>0:_split(info,"snare",.4,.8,.4,.6,1.);s.cooldown*=1.25
	if v.get("mage_burn",0)>0:_split(info,"burn",.6,.4,.6,.4,1.);s.cost=maxf(5.,s.cost*.9)
	if v.get("mage_relay",0)>0 and support_ready:_split(info,"relay",.5,.7,.5,.5,.3)
	if v.get("rogue_venom",0)>0:_split(info,"venom",.6,.4,.6,.4,1.);s.cost*=1.15
	if advanced and (v.get("fighter_flurry",0)>0 or v.get("fighter_crush",0)>0):
		var total=float(s[power_key])*int(s.count)
		if v.get("fighter_flurry",0)>0:info.delivery="flurry";s.count=3;s[power_key]=total*.9/3.;s.time*=.5
		else:info.delivery="crush";s.count=1;s[power_key]=total*1.2;s.time+=.45;geometry.radius*=.8
	s[power_key]*=info.direct_damage
	info["dot_damage_multiplier"]=s[power_key]/maxf(.001,float(raw[power_key]))
	info.paid_cost=s.cost
	return s
static func _split(info:Dictionary,kind:String,direct:float,extra:float,stagger_direct:float,stagger_extra:float,delay:float):
	info.procs.append({"kind":kind,"damage":float(info.direct_damage)*extra,"weight":float(info.direct_stagger)*stagger_extra,"delay":delay})
	info.direct_damage*=direct;info.direct_stagger*=stagger_direct
static func metrics(profile:Dictionary)->Array:
	var info=profile.get("constellation",{})
	if info.is_empty() or not info.attacking:return []
	var names={"original":"원기술","flurry":"이동 연격 3타","crush":"압축 강타","echo":"메아리","wave":"전방 파동","reprise":"수호 파동","chain":"추적 연쇄","snare":"잔류 덫","burn":"연소","relay":"문장 폭발","venom":"회수 독"}
	var labels=[names[info.delivery]]
	for proc in info.procs:labels.append(names[proc.kind])
	if info.max_targets==1:labels.append("한 표적")
	return [["특성 전달"," · ".join(labels)]]
func reset(p:Dictionary):
	p["constellation_state"]={"last_skill":"","last_time":0.,"move_time":0.,"support_time":0.,"support_pos":p.pos}
	pending=pending.filter(func(hit):return hit.owner!=p.id)
func prepare(p:Dictionary,node:Dictionary,s:Dictionary)->Dictionary:
	var context=combat.BossStagger.context(combat.BossStagger.token(node,int(s.rank),p,combat.sim.clock,int(s.count)))
	var info=s.get("constellation",{}).duplicate(true)
	if info.is_empty():return context
	cast_serial+=1
	info.merge({"cast_id":cast_serial,"rank":s.rank,"fx":str(node.get("fx",node.id)),"origin":p.pos,"aim":p.aim,"support_pos":state(p).get("support_pos",p.pos),"fired":false,"targets":{},"contract_targets":{},"primary":true,"paid_cost":s.cost,"total_damage":combat.sim.damage_for(p)*float(s.get("power",s.get("multiplier",0)))*int(s.count)/maxf(.001,float(info.direct_damage))},true)
	context["build"]=info;context.weight*=float(info.direct_stagger)
	return context
func committed(p:Dictionary,node:Dictionary,s:Dictionary):
	if not p.has("constellation_state"):reset(p)
	var info=s.get("constellation",{});var mode=str(node.get("mode",s.get("mode","")))
	if not info.is_empty() and info.attacking:p.constellation_state.move_time=0.;p.constellation_state.support_time=0.
	elif mode in SUPPORT:p.constellation_state.support_time=5.;p.constellation_state.support_pos=p.pos
func periodic_context(source:Dictionary,pulses:int)->Dictionary:
	var result=combat.BossStagger.context(source.get("budget",{}),.25/maxi(1,pulses))
	var info=source.get("build",{})
	if not info.is_empty():
		var periodic=info.duplicate(false);periodic.primary=false
		result["build"]=periodic;result.weight*=float(info.direct_stagger)
	return result
func moved(p:Dictionary,dodge:bool=false):
	if not p.has("constellation_state"):reset(p)
	if dodge:p.constellation_state.move_time=3.
	for hit in pending:
		if hit.owner!=p.id or hit.kind!="venom":continue
		var e=combat.sim.enemies.get(hit.target,{})
		if not e.is_empty() and e.hp>0 and p.pos.distance_to(e.pos)<=6. and combat.sim.map.line_clear(p.pos,e.pos):hit.time=0.
func before_hit(p:Dictionary,e:Dictionary,context:Dictionary)->Dictionary:
	var info=context.get("build",{})
	if info.is_empty() or not info.attacking:return {"allowed":true,"factor":1.}
	if info.max_targets==1 and not info.targets.is_empty() and not info.targets.has(e.id):return {"allowed":false,"factor":0.}
	info.targets[e.id]=true
	var v=info.effects;var factor=1.
	if e.get("slow_time",0)>0 or e.get("stun_time",0)>0 or e.get("job_status",{}).has("root"):factor+=float(v.get("control_damage",0))
	if float(e.hp)/e.max_hp<.3:factor+=float(v.get("execute_damage",0))
	if v.get("rogue_contract",0)>0:
		if info.primary and not info.contract_targets.has(e.id):
			var mark=e.get("constellation_marks",{}).get(str(p.id),{})
			info.contract_targets[e.id]=mark.get("time",0)>combat.sim.clock and mark.get("skill","")!=info.source_id
			if info.contract_targets[e.id]:e.constellation_marks.erase(str(p.id))
		if info.contract_targets.get(e.id,false):factor*=1.5
	return {"allowed":true,"factor":factor}
func after_hit(p:Dictionary,e:Dictionary,context:Dictionary):
	var info=context.get("build",{})
	if info.is_empty() or not info.attacking or not info.primary:return
	if not p.has("constellation_state"):reset(p)
	p.constellation_state.last_skill=info.source_id;p.constellation_state.last_time=4.
	if info.effects.get("rogue_contract",0)>0:
		if not e.has("constellation_marks"):e.constellation_marks={}
		if not info.contract_targets.get(e.id,false):e.constellation_marks[str(p.id)]={"skill":info.source_id,"time":combat.sim.clock+4.}
	if info.fired:return
	info.fired=true
	# Delivery changes preserve the source job's once-per-successful-cast resource.
	if info.delivery!="original":
		if p.class_id=="infighter":p.job_state.rush=mini(10,p.job_state.rush+1);p.job_state.rush_time=2.
		if p.class_id=="martialist" and info.source_mode!="finisher":combat.jobs.combo(p,info.source_id)
	var v=info.effects
	if info.mobile:p.stamina=minf(p.max_stamina,p.stamina+info.paid_cost*float(v.get("mobility_refund",0)))
	if info.followup:
		p.hp=mini(p.max_hp,p.hp+roundi(p.max_hp*float(v.get("heal_on_followup",0))))
		var shield=p.max_hp*float(v.get("guard_on_followup",0))
		if shield>0:p.job_state.shield=maxf(p.job_state.shield,shield);p.job_state.shield_time=maxf(p.job_state.shield_time,2.)
		e["slow_time"]=maxf(float(e.get("slow_time",0)),float(v.get("slow_on_followup",0)))
	for proc in info.procs:
		var targets=[e]
		if proc.kind=="chain":
			targets=combat.sim.enemies.values().filter(func(other):return other.id!=e.id and other.hp>0 and HitGeometry.circle(other,e.pos,4.) and combat.sim.map.line_clear(e.pos,other.pos))
			targets.sort_custom(func(a,b):return e.pos.distance_squared_to(a.pos)<e.pos.distance_squared_to(b.pos));targets=targets.slice(0,2)
		for target in targets:
			var pulses=4 if proc.kind in ["burn","venom"] else 1
			for i in range(pulses):
				var weight=float(proc.weight)/pulses/(2. if proc.kind=="chain" else 1.)
				var damage=info.total_damage*float(proc.damage)/pulses/(2. if proc.kind=="chain" else 1.)
				var position=info.support_pos if proc.kind=="relay" else info.origin if proc.kind in ["wave","reprise"] else target.pos
				_queue(p,context,proc.kind,target.id,position,damage,weight,float(proc.delay)*(i+1))
func _queue(p:Dictionary,context:Dictionary,kind:String,target:int,position:Vector2,damage:float,weight:float,delay:float):
	var primary=context.build;var secondary=primary.duplicate(false);secondary.primary=false
	# Keep the same budget and targeting ledgers; no triggered hit creates a cast.
	var source={"budget":context.budget,"weight":weight,"build":secondary}
	pending.append({"owner":p.id,"context":source,"kind":kind,"target":target,"pos":position,"time":delay,"amount":maxi(1,roundi(damage)),"radius":2.3,"origin":primary.origin,"aim":primary.aim})
	combat.skills.fx(p,primary.fx,position,delay+.4,2.3,Vector2.INF,{"skill_id":primary.source_id,"skill_mode":"field" if kind in ["burn","venom","snare"] else "burst","rank":primary.rank,"pulse_times":[delay],"triggered":true})
func delivery(p:Dictionary,cast:Dictionary)->bool:
	var info=cast.get("constellation",{})
	if info.is_empty() or info.get("delivery","original")=="original":return false
	var count=int(cast.count);var context=combat.stagger_context
	for i in range(count):
		pending.append({"owner":p.id,"context":context,"kind":info.delivery,"target":-1,"pos":p.pos,"time":i*.18,"amount":maxi(1,roundi(combat.sim.damage_for(p)*cast.power)),"radius":cast.node.radius,"origin":p.pos,"aim":p.aim})
	combat.skills.fx(p,cast.node.fx,p.pos,.18*(count-1)+.45,cast.node.radius,Vector2.INF,{"skill_id":cast.node.id,"skill_mode":"combo" if count>1 else "burst","rank":cast.rank,"pulse_times":[0.,.18,.36] if count>1 else [0.],"follow_owner":count>1,"follow_offset":.9})
	if count>1:p.job_state["constellation_channel"]=.18*(count-1)+.05;p.job_state.lock=0.
	p.job_state.current_heavy=false
	return true
func tick_player(p:Dictionary,delta:float):
	if not p.has("constellation_state"):reset(p)
	for key in ["last_time","move_time","support_time"]:p.constellation_state[key]=maxf(0,float(p.constellation_state[key])-delta)
	p.job_state["constellation_channel"]=maxf(0,float(p.job_state.get("constellation_channel",0))-delta)
func tick(delta:float):
	if delta<=0:return
	var due=[];var keep=[]
	for hit in pending:
		hit.time-=delta
		if hit.time<=0:due.append(hit)
		else:keep.append(hit)
	pending=keep
	for hit in due:
		var p=combat.sim.players.get(hit.owner,{})
		if p.is_empty() or p.hp<=0:continue
		if hit.kind in ["burn","venom","chain"]:
			var e=combat.sim.enemies.get(hit.target,{})
			if not e.is_empty() and e.hp>0:combat.hit(p,e,hit.amount,e.pos,hit.context)
			continue
		var center:Vector2=p.pos+p.aim*.9 if hit.kind=="flurry" else hit.pos
		for e in combat.sim.enemies.values():
			if e.hp<=0:continue
			var inside=HitGeometry.circle(e,center,hit.radius)
			if hit.kind=="wave":inside=HitGeometry.segment(e,hit.origin,hit.origin+hit.aim*5.5,1.1)
			if inside and combat.sim.map.line_clear(center,e.pos):
				var amount=int(hit.amount)
				if hit.context.build.primary and hit.context.build.source_mode in ["execute","heavy_execute","charge_execute"]:amount=roundi(amount*(1.+(1.-float(e.hp)/e.max_hp)))
				combat.hit(p,e,amount,center,hit.context)
