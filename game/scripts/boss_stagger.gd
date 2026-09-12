extends RefCounted
# Pure skill metadata and a simulation-owned state machine. No Content preload:
# the database, skill UI and combat can all import this module without a cycle.
const LEGACY_MODES={"blade_wave":"wave","whirlwind":"spin","rush":"dash","piercing_shot":"piercing","arrow_rain":"rain","retreat_shot":"retreat","frost_nova":"frost","thunder":"thunder","blink":"blink"}
const SUPPORT=["heal","regen","field_heal","barrier","haste","shield","ally_dash","wall","cleanse","distribute","return_anchor","parry","meditate","hit_card","hold_card","cut_card","dice","reroll","pet_heal","pet_recall","pet_buff","pet_haste","pet_guard","pet_sacrifice","buff_attack","buff_crit","buff_crit_damage","guard","fortress","share","chant","stand_card","dice_buff","enchant","stance","empower"]
const DOT_MODES=["bleed","bleed_shot","trap_bleed","pet_command","pet_burst","pet_pull"]
const DOWN_SECONDS=6.0
const IMMUNITY_SECONDS=60.0
const FAILED_CHECK_IMMUNITY=6.0
const BASE_THRESHOLD=450.0
const FLOOR_THRESHOLD=2.0
const CHECK_SECONDS=12.0
const DOWN_DAMAGE=1.20

static func skill_profile(node:Dictionary,rank:int,player:Dictionary={})->Dictionary:
	var technique=maxf(0,float(player.get("stats",{}).get("technique",0))+float(player.get("gear_stats",{}).get("technique",0)))
	var multiplier=1.0+.60*technique/(technique+60.)
	var mode=str(node.get("mode",LEGACY_MODES.get(node.get("id",""),"")))
	var base=24.;var grade="중간"
	if rank<=0 or node.get("effect","active")!="active" or mode in SUPPORT or mode.is_empty():base=0.;grade="없음"
	elif mode.begins_with("charge") or mode in ["finisher","heavy_execute","thunder"]:base=40.;grade="매우 높음"
	elif mode.begins_with("heavy") or mode in ["stun","burst","pull","chain_pull","chain_group","parry_counter","parry_knee","frost","spin","piercing","pet_burst"]:base=32.;grade="높음"
	elif mode in ["shot","fan","retreat","dash","rush","blink","weave","flank","card_retreat","slow_shot","bleed_shot","settle_fan","wave"]:base=16.;grade="낮음"
	base*=1.+.20*(clampi(rank,1,int(node.get("max_rank",3)))-1)
	base*=preload("res://scripts/constellation_effects.gd").stagger_multiplier(player,str(node.get("id","")))
	var class_factor=clampf(1./float(preload("res://scripts/job_balance.gd").role(str(player.get("class_id",node.get("class_id",""))))[2]),1.,1.65)
	base*=class_factor
	return {"base":base,"value":base*multiplier,"grade":grade,"multiplier":multiplier,"class_multiplier":class_factor,"mode":mode,"rank":rank}

static func token(node:Dictionary,rank:int,p:Dictionary,clock:float,count:int=1)->Dictionary:
	var profile=skill_profile(node,rank,p)
	return {"value":profile.value,"count":maxi(1,count),"spent":{},"created":clock,"dot":profile.mode in DOT_MODES,"source":str(node.get("id","")),"kind":"skill"}

static func basic_token(heavy:bool,charge:float,clock:float)->Dictionary:
	return {"value":14.+6.*clampf(charge,0,1) if heavy else 7.,"count":1,"spent":{},"created":clock,"dot":false,"source":"heavy" if heavy else "basic","kind":"basic"}

static func context(budget:Dictionary,weight:float=-1.)->Dictionary:
	if budget.is_empty():return {}
	return {"budget":budget,"weight":((.75 if budget.get("dot",false) else 1.)/maxi(1,int(budget.get("count",1)))) if weight<0 else weight}

static func initialize(e:Dictionary,clock:float=0.):
	if not e.get("boss",false):return
	var floor_number=int(e.get("floor",0))
	e["stagger"]={"state":"ready","value":0.,"max_value":BASE_THRESHOLD+floor_number*FLOOR_THRESHOLD,"check_value":0.,"check_max":65.+floor_number*.2,"time_left":0.,"time_max":0.,"breaks":0,"checks_done":[],"idle_time":0.,"last_hit":clock,"reset_at":clock,"engaged":false,"generation":int(e.get("stagger",{}).get("generation",0))+1}
	var factor=float(e.get("party_stagger_factor",1.))
	e.stagger.max_value*=factor;e.stagger.check_max*=factor

static func cancel_attacks(sim,e:Dictionary):
	e.windup=0.;e.attack_motion=0.;e.erase("attack_areas");e.erase("wall_charge")
	sim.monster_attacks.zones=sim.monster_attacks.zones.filter(func(zone):return zone.enemy!=e.id)

static func reset(sim,e:Dictionary):
	cancel_attacks(sim,e)
	e.hp=e.max_hp;e.pos=e.home;e.phase=1;e.pattern=0;e.cooldown=1.;e["stun_time"]=0.;e["slow_time"]=0.;e["job_status"]={};e.erase("constellation_marks")
	initialize(e,sim.clock)

static func engagement_radius(e:Dictionary)->float:return 14.0 if e.get("raid",false) else 8.0

static func engaged_players(sim,e:Dictionary)->Array:
	return sim.players.values().filter(func(p):return p.hp>0 and not p.get("network_leaving",false) and not sim.map.in_town(p.pos) and p.pos.distance_to(e.home)<engagement_radius(e) and sim.map.line_clear(p.pos,e.pos))

static func start_check(sim,e:Dictionary,index:int):
	var s=e.stagger;s.state="check";s.check_value=0.;s.time_left=CHECK_SECONDS;s.time_max=CHECK_SECONDS;s.checks_done.append(index);s.engaged=true
	cancel_attacks(sim,e)
	for p in engaged_players(sim,e):sim.notice(p.id,"무력화 집중! 12초 안에 보스의 집중을 끊으세요.")
	sim.events.append({"type":"stagger_check","enemy":e.id,"pos":e.pos,"duration":CHECK_SECONDS})

static func check_threshold(sim,e:Dictionary):
	if not e.get("raid",false) or e.hp<=0 or not e.has("stagger") or e.stagger.state!="ready":return
	for index in range(2):
		if index not in e.stagger.checks_done and float(e.hp)/e.max_hp<=[.70,.40][index]:start_check(sim,e,index);return

static func break_boss(sim,e:Dictionary)->bool:
	if not e.get("boss",false) or e.get("hp",0)<=0 or not e.has("stagger") or e.stagger.state not in ["ready","check"]:return false
	var s=e.stagger;var was_check=s.state=="check"
	s.state="down";s.value=0.;s.time_left=DOWN_SECONDS;s.time_max=DOWN_SECONDS;s.breaks+=1
	cancel_attacks(sim,e)
	for p in engaged_players(sim,e):sim.notice(p.id,"무력화 성공! 6초 동안 보스가 받는 피해 +20%." if was_check else "보스 무력화! 6초 동안 받는 피해 +20%.")
	sim.events.append({"type":"stagger_break","enemy":e.id,"pos":e.pos,"duration":DOWN_SECONDS})
	return true

static func apply(sim,p:Dictionary,e:Dictionary,hit_context:Dictionary):
	if not e.get("boss",false) or e.hp<=0 or hit_context.is_empty():return
	if not e.has("stagger"):initialize(e,sim.clock)
	var s=e.stagger;var budget=hit_context.get("budget",{})
	if budget.is_empty() or s.state not in ["ready","check"] or float(budget.get("created",-1))<float(s.reset_at):return
	var key=str(e.id)+":"+str(s.generation)
	var amount=minf(float(budget.value)-float(budget.spent.get(key,0)),float(budget.value)*float(hit_context.get("weight",1.)))
	if amount<=0:return
	budget.spent[key]=float(budget.spent.get(key,0))+amount
	s.last_hit=sim.clock;s.engaged=true
	if s.state=="check":s.check_value=minf(s.check_max,s.check_value+amount)
	else:s.value=minf(s.max_value,s.value+amount)
	sim.events.append({"type":"stagger_damage","enemy":e.id,"pos":e.pos,"amount":amount,"owner":p.id,"source":budget.source})
	if s.check_value>=s.check_max and s.state=="check" or s.value>=s.max_value and s.state=="ready":break_boss(sim,e)

static func tick(sim,e:Dictionary,delta:float)->bool:
	if not e.get("boss",false) or e.hp<=0:return false
	if not e.has("stagger"):initialize(e,sim.clock)
	var s=e.stagger
	if delta<=0:return s.state in ["check","down"]
	var nearby=engaged_players(sim,e)
	if nearby.is_empty():
		if s.engaged:
			s.idle_time+=delta
			if s.idle_time>=5.:reset(sim,e);return false
	else:s.idle_time=0.
	if s.state=="ready":
		if not nearby.is_empty():check_threshold(sim,e)
		if s.state=="ready" and sim.clock-s.last_hit>4.:s.value=maxf(0,s.value-8.*delta)
		return s.state=="check"
	s.time_left=maxf(0,s.time_left-delta)
	if s.state=="check":
		if s.time_left<=0:
			s.state="immune";s.value=0.;s.time_left=FAILED_CHECK_IMMUNITY;s.time_max=FAILED_CHECK_IMMUNITY
			sim.monster_attacks.stagger_punishment(e)
			for p in nearby:sim.notice(p.id,"무력화 실패! 붉은 원 밖으로 피하세요.")
		return true
	if s.state=="down":
		if s.time_left<=0:s.state="immune";s.time_left=IMMUNITY_SECONDS;s.time_max=IMMUNITY_SECONDS;e.cooldown=maxf(1.,e.cooldown)
		return true
	if s.time_left<=0:s.state="ready";s.time_max=0.;s.check_value=0.
	return false
