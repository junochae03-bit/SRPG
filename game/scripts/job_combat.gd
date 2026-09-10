extends RefCounted
# Runtime for the level-30 jobs. Cast snapshots prevent resource reuse on cancellation.
const Content=preload("res://scripts/content.gd")
const Balance=preload("res://scripts/job_balance.gd")
const HitGeometry=preload("res://scripts/enemy_hit_geometry.gd")
var owner_ref:WeakRef
var combat:
	get:return owner_ref.get_ref()
var sim:
	get:return combat.sim
func _init(owner_combat):owner_ref=weakref(owner_combat)
func reset(p:Dictionary):
	p["job_state"]={"runes":0,"combo":0,"combo_time":0.0,"last_skill":"","momentum":0.0,"grit":[],"counter":0.0,"instant":0.0,"rush":0,"rush_time":0.0,"dash_charges":2 if p.class_id=="infighter" else 1,"dash_timer":0.0,"casting":{},"buffs":{},"pets":[],"marks":{},"deck":[],"hand":[],"discard":[],"selected":0,"held":-1,"dice":0,"dice_time":0.0,"anchor":[],"parry":0.0,"shield":0.0,"shield_time":0.0,"pet_timer":0.0,"last_pos":p.pos}
	if p.class_id=="gambler":
		for i in range(52):p.job_state.deck.append(i)
		shuffle(p.job_state.deck)
		draw_cards(p,2)
func shuffle(cards:Array):
	for i in range(cards.size()-1,0,-1):
		var j=sim.rng.randi_range(0,i);var v=cards[i];cards[i]=cards[j];cards[j]=v
func draw_cards(p:Dictionary,count:int):
	var s=p.job_state
	for i in range(count):
		if s.deck.is_empty():s.deck=s.discard.duplicate();s.discard.clear();shuffle(s.deck)
		if not s.deck.is_empty():s.hand.append(s.deck.pop_back())
static func hand_total(hand:Array)->int:
	var total=0;var aces=0
	for card in hand:
		var n=int(card)%13+1
		if n==1:total+=11;aces+=1
		else:total+=mini(n,10)
	while total>21 and aces>0:total-=10;aces-=1
	return total
static func payout(hand:Array)->float:
	var total=hand_total(hand)
	if total>21:return 1.0
	if total==21:return 2.1 if hand.size()==2 else 1.85
	return {17:1.15,18:1.25,19:1.4,20:1.6}.get(total,1.0)
func select_card(p:Dictionary)->bool:
	if p.class_id!="gambler":return false
	if not p.job_state.get("candidates",[]).is_empty():p.job_state.candidate_index=1-int(p.job_state.candidate_index);return true
	p.job_state.selected=(int(p.job_state.selected)+1)%maxi(1,p.job_state.hand.size());return true
func dispose_hand(p:Dictionary):
	var s=p.job_state;s.discard.append_array(s.hand);s.hand.clear();s.held=-1;s.selected=0;draw_cards(p,2)
func passive(p:Dictionary,index:int)->int:return int(p.skill_ranks.get(p.class_id+"_p%02d"%(index+1),0))
func buff(p:Dictionary,key:String,value:float,duration:float):
	var old=p.job_state.buffs.get(key,{})
	var layers=old.get("layers",[])
	if layers.is_empty() and not old.is_empty():layers.append({"value":old.value,"time":old.time})
	var same=layers.filter(func(layer):return is_equal_approx(layer.value,value))
	if same.is_empty():layers.append({"value":value,"time":duration})
	else:same[0].time=maxf(same[0].time,duration)
	var strongest=0.;var remaining=0.
	for layer in layers:strongest=maxf(strongest,layer.value);remaining=maxf(remaining,layer.time)
	p.job_state.buffs[key]={"value":strongest,"time":remaining,"layers":layers}
func value(p:Dictionary,key:String)->float:return float(p.job_state.buffs.get(key,{}).get("value",0))
func basic(p:Dictionary):
	p.job_state.current_heavy=false
	if p.class_id=="gambler":
		var s=p.job_state
		if s.hand.is_empty():draw_cards(p,2)
		var idx=clampi(int(s.selected),0,s.hand.size()-1)
		if s.hand[idx]==s.held:idx=(idx+1)%s.hand.size()
		s.discard.append(s.hand.pop_at(idx));draw_cards(p,1);s.selected=mini(idx,s.hand.size()-1)
	if p.class_id=="breaker":p.job_state["punch"]=1-int(p.job_state.get("punch",0))
func basic_hit(p:Dictionary,e:Dictionary):
	var s=p.job_state
	match p.class_id:
		"runesword":
			if s.get("rune_cd",0)<=0:s.runes=mini(6+passive(p,0),s.runes+1);s.rune_cd=maxf(.05,.25-passive(p,1)*.035)
		"infighter":
			if s.get("resource_cd",0)<=0:s.rush=mini(10,s.rush+1);s.rush_time=2.0+passive(p,0)*.15;s.resource_cd=.15
		"breaker":s.momentum=minf(100,s.momentum+5)
		"thief":mark(p,e)
		"summoner":
			if passive(p,5)>0:s.pet_target=e.id
		"swordsman":
			s.same_hits=mini(5,s.get("same_hits",0)+1) if s.get("same_target",-1)==e.id else 1;s.same_target=e.id;buff(p,"attack",s.same_hits*passive(p,2)*.01,2.)
func mark(p:Dictionary,e:Dictionary):
	var s=p.job_state;s.marks[str(e.id)]=8.0
	while s.marks.size()>2+passive(p,1):s.marks.erase(s.marks.keys()[0])
func attack_speed(p:Dictionary)->float:
	return 1+value(p,"haste")+(p.job_state.rush*.035 if p.class_id=="infighter" else 0)+(.25 if p.job_state.dice==2 and p.job_state.dice_time>0 else 0)
func attack_multiplier(p:Dictionary,heavy:bool)->float:
	var s=p.job_state;var mult=float(Balance.role(p.class_id)[2])
	if s.dice_time>0 and s.dice==1:mult+=.2
	if p.class_id=="breaker":mult*=1+s.get("heavy_grit",0)/70.0 if heavy else (1.35 if s.get("punch",0)==1 else .85)
	if heavy:s.current_heavy=true
	if p.class_id=="reaper" and heavy:mult*=1+passive(p,2)*.05
	return mult
func after_heavy(p:Dictionary):p.job_state["heavy_grit"]=0.0;p.job_state.current_heavy=false
func outgoing(p:Dictionary,e:Dictionary,amount:int,hit_details:Dictionary={})->int:
	if not p.has("job_state"):return amount
	var states=e.get("job_status",{})
	amount=roundi(amount*(1+value(p,"attack")))
	if states.has("break_armor"):amount=roundi(amount*1.15)
	if states.has("vulnerable"):amount=roundi(amount*1.2)
	if p.class_id=="swordsman" and (e.get("boss",false) or e.get("elite",false)):amount=roundi(amount*(1+passive(p,1)*.05))
	if p.class_id=="sniper" and e.get("boss",false):amount=roundi(amount*(1+passive(p,2)*.05))
	if p.class_id=="hunter":
		amount=roundi(amount*(1+passive(p,1)*.025))
		if states.has("root") and not states.root.get("ambushed",false):amount=roundi(amount*(1+passive(p,3)*.1));states.root.ambushed=true
	if p.class_id=="infighter" and p.pos.distance_to(e.pos)<2:
		amount=roundi(amount*(1+passive(p,1)*.04))
		if p.job_state.get("recovery_cd",0)<=0:
			p.job_state.hit_count=p.job_state.get("hit_count",0)+1
			if p.job_state.hit_count>=8:p.hp=mini(p.max_hp,p.hp+passive(p,5)*2);p.job_state.hit_count=0;p.job_state.recovery_cd=1.
	if p.class_id=="thief" and p.pos.distance_to(e.pos)<2:amount=roundi(amount*(1+mini(6,states.size())*passive(p,3)*.015))
	if p.class_id=="explorer" and (states.has("root") or states.has("stun")):amount=roundi(amount*(1+passive(p,3)*.05))
	var critical=value(p,"crit")+(passive(p,4)*.02 if p.class_id=="swordsman" else 0)+(.15 if p.job_state.dice_time>0 and p.job_state.dice==3 else 0)
	if critical>0 and sim.rng.randf()<critical:
		amount=roundi(amount*(1.5+value(p,"crit_damage")+(passive(p,5)*.08 if p.class_id=="swordsman" else 0)));hit_details["critical"]=true
	if p.class_id=="reaper" and p.job_state.get("current_heavy",false) and p.job_state.get("heavy_proc_cd",0)<=0:
		p.hp=mini(p.max_hp,p.hp+passive(p,4)*2);p.job_state.heavy_proc_cd=1.
		if p.job_state.get("natural_heavy",false):reduce_cd(p,"reaper_a01",passive(p,5)*.2)
	if value(p,"leech")>0 and p.job_state.get("leech_cd",0)<=0:p.hp=mini(p.max_hp,p.hp+maxi(1,roundi(amount*.04)));p.job_state.leech_cd=.5
	return maxi(1,amount)
func receive(p:Dictionary,e:Dictionary,amount:int,parryable:bool)->int:
	if not p.has("job_state"):return amount
	var s=p.job_state;var facing=p.aim.dot(p.pos.direction_to(e.pos))>0.0
	if s.parry>0 and parryable and facing:
		s.parry=0;s.counter=5.;
		p.stamina=minf(p.max_stamina,p.stamina+passive(p,2)*2)
		if s.get("parry_kind","") in ["parry_counter","parry_knee"]:
			if combat.hit(p,e,roundi(sim.damage_for(p)*s.get("counter_power",2.)),null,s.get("parry_stagger",{})):status(p,e,"stun",.5)
		s.momentum=minf(100,s.momentum+25+minf(20,amount*.05*passive(p,3)));fx(p,"breaker:2",p.pos)
		return 0
	for ally in allies(p):
		var wall=ally.job_state.get("wall",{})
		if not wall.is_empty() and Geometry2D.segment_intersects_segment(e.pos,p.pos,wall.pos+wall.dir.orthogonal()*wall.radius,wall.pos-wall.dir.orthogonal()*wall.radius)!=null:return 0
	var st=e.get("job_status",{})
	if st.has("blind") and sim.rng.randf()<.35:return 0
	if st.has("weaken"):amount=roundi(amount*.8)
	amount=maxi(0,amount-roundi(value(p,"armor")*15))
	amount=roundi(amount*(1-minf(.65,value(p,"defense"))))
	if p.class_id=="infighter" and s.get("channel",0)>0:amount=roundi(amount*(1-passive(p,4)*.025))
	if p.class_id=="breaker" and p.motion=="slam" and p.motion_time>0:amount=roundi(amount*(1-passive(p,4)*.025))
	if p.class_id=="breaker" and (p.charge_time>=0 or not s.casting.is_empty()):amount=roundi(amount*(1-passive(p,1)*.025))
	if s.dice_time>0 and s.dice==6:amount=roundi(amount*.8)
	if value(p,"guard")>0 and facing:
		amount=roundi(amount*(1-minf(.8,value(p,"guard")+(passive(p,2)*.03 if p.class_id=="tank" else 0))))
		if p.class_id=="tank":buff(p,"attack",passive(p,4)*.04,2.)
	if value(p,"evade")>0 and sim.rng.randf()<value(p,"evade"):return 0
	var absorb=minf(s.shield,amount);s.shield-=absorb;amount-=int(absorb)
	if p.class_id=="breaker" and amount>0:
		# Each hit has its own expiry; subsequent hits never refresh older grit.
		var total=grit(p);var earned=minf(100-s.momentum-total,amount*.8)
		if earned>0:s.grit.append({"amount":earned,"remaining":2.0})
	if amount>0:
		var resist=p.class_id=="elementalist" and passive(p,3)>0 and sim.rng.randf()<minf(.85,.25+passive(p,3)*.12)
		if not resist and value(p,"guard")<=0:s.casting={};p.charge_time=-1.;s.heavy_grit=0.
		s.meditate=0.
		s.channel=0.
	return maxi(0,amount)
static func grit(p:Dictionary)->float:
	var result=0.0
	for hit in p.job_state.grit:result+=hit.amount*hit.remaining/2.0
	return result
func spend_grit(p:Dictionary,limit:float)->float:
	var s=p.job_state;var used=0.0
	for hit in s.grit:
		var current=hit.amount*hit.remaining/2.0;var take=minf(limit-used,current)
		hit.amount-=take*2.0/maxf(.001,hit.remaining);used+=take
		if used>=limit:break
	s.grit=s.grit.filter(func(h):return h.amount>.001)
	var stable=minf(limit-used,s.momentum);s.momentum-=stable;return used+stable
func target(p:Dictionary,distance:float=8.,marked:bool=false)->Dictionary:
	var best={};var score=INF
	for e in sim.enemies.values():
		if e.hp<=0 or not HitGeometry.circle(e,p.pos,distance) or not sim.map.line_clear(p.pos,e.pos):continue
		if e.get("training",false) and not preload("res://scripts/training_ground.gd").can_practice(sim,p):continue
		if marked and not p.job_state.marks.has(str(e.id)):continue
		var angle=p.aim.dot(p.pos.direction_to(e.pos))
		if angle<.1:continue
		var next=e.pos.distance_to(p.pos)+(1-angle)*4
		if next<score:score=next;best=e
	return best
func move(p:Dictionary,direction:Vector2,distance:float):
	for i in range(ceili(distance/.1)):p.pos=sim.map.move(p.pos,direction.normalized()*minf(.1,distance-i*.1))
func fx(p:Dictionary,key:String,at:Vector2,radius:float=1.5,visual:Dictionary={})->Dictionary:
	return combat.skills.fx(p,key,at,.45,radius,Vector2.INF,visual)
func cast_visual(p:Dictionary,cast:Dictionary)->Dictionary:
	return {"skill_id":cast.node.id,"skill_mode":cast.node.mode,"rank":cast.rank,"class_id":p.class_id,"origin":p.pos,"count":cast.count,"skill_index":cast.node.index,"ground_shape":preload("res://scripts/skill_reach.gd").job_shape(cast.node.mode),"arc_dot":0.}
func act(p:Dictionary,kind:String)->bool:
	var s=p.job_state
	if kind=="cancel_charge":s.casting={};p.charge_time=-1.;s.heavy_grit=0.;return true
	if kind=="dodge":
		if s.dash_charges<=0 or p.stamina<10:return false
		s.dash_charges-=1;s["after_dash"]=2.
		if p.class_id=="martialist":p.attack_cd=maxf(0,p.attack_cd-passive(p,4)*.025)
		if s.dash_timer<=0:s.dash_timer=8. if p.class_id=="breaker" else 2.5
		p.stamina-=10;p.dodge_time=.3 if p.class_id=="breaker" else .22;p.dash_speed=16.;p.invulnerable=.12
		p.dodge_dir=p.dir.normalized() if p.dir.length()>.1 else p.aim.normalized();p.charge_time=-1.;s.casting={};s.heavy_grit=0.
		if p.dodge_dir==Vector2.ZERO:p.dodge_dir=Vector2.RIGHT
		combat.constellation.pending=combat.constellation.pending.filter(func(hit):return hit.owner!=p.id or hit.kind!="flurry")
		combat.constellation.moved(p,true)
		fx(p,p.class_id+":"+str(3 if p.class_id in ["breaker","martialist"] else 2),p.pos);return true
	if sim.map.in_town(p.pos) or p.dodge_time>0:return false
	if kind=="heavy_begin":
		if p.attack_cd>0 or not s.casting.is_empty() or p.charge_time>=0 or p.stamina<20:return false
		p.charge_time=0.;s.natural_heavy=true
		if p.class_id=="breaker":
			s.heavy_grit=spend_grit(p,100.);p.charge_time=minf(.45,s.heavy_grit*.004);s.shield+=s.heavy_grit*.7;s.shield_time=2.
		if p.class_id=="reaper" and s.instant>0:p.charge_time=.9;s.instant=0.;s.natural_heavy=false
		return true
	if kind=="heavy":
		if p.charge_time<0:return false
		var charge=p.charge_time/.9;p.charge_time=-1.;p.stamina-=20
		s.natural_heavy=s.get("natural_heavy",false) and charge>=.99
		if p.class_id=="breaker" and charge>=.99 and s.get("heavy_proc_cd",0)<=0:s.dash_timer=maxf(1.,s.dash_timer-passive(p,5)*.2);s.heavy_proc_cd=3.
		return combat.attack(p,true,charge)
	if not s.casting.is_empty() or p.charge_time>=0 or s.get("lock",0)>0:return false
	if kind=="attack":
		if not s.get("candidates",[]).is_empty():
			var pick=int(s.candidate_index);s.hand.append(s.candidates[pick]);s.deck.push_front(s.candidates[1-pick]);s.candidates=[];s.selected=0;return true
		if p.attack_cd>0 or value(p,"stand")>0:return false
		return combat.attack(p,false,0)
	if kind not in Content.ACTIONS or not s.get("candidates",[]).is_empty():return false
	var n=Content.active_node(p,kind)
	if n.is_empty() or Content.action_rank(p,kind)<=0:return false
	var rank=Content.action_rank(p,kind);var up=int(p.skill_ranks.get(n.id+"_upgrade",0))>0
	var cast=Balance.profile(p,n,rank,sim.damage_for(p),p.max_hp,up)
	if p.skill_cooldowns.get(n.id,0)>0 or p.stamina<cast.cost:return false
	if n.get("rune_cost",0)>s.runes:return false
	var mode=n.mode;var t=target(p,cast.node.range,mode in ["teleport","teleport_chain"])
	if mode in ["teleport","teleport_chain","chain_pull","chain_dash","chain_retreat","chain_group"] and t.is_empty():return false
	if mode.begins_with("pet_") and s.pets.is_empty():return false
	if mode=="cut_card" and s.hand.is_empty():return false
	if mode in ["reroll","dice_buff"] and s.dice_time<=0:return false
	if mode=="hit_card" and s.hand.size()>=5:return false
	p.stamina-=cast.cost;p.skill_cooldowns[n.id]=cast.cooldown;s.runes-=int(n.get("rune_cost",0))
	cast.merge({"target":t.get("id",-1),"origin":p.pos,"aim":p.aim})
	configure(p,cast)
	if mode.begins_with("settle"):
		cast.power*=payout(s.hand);cast["blackjack"]=hand_total(s.hand)==21;dispose_hand(p)
	if p.class_id=="breaker" and mode.begins_with("charge"):
		var consumed=spend_grit(p,100.);cast.power*=1+consumed/75.;cast.time=maxf(.45,cast.time-consumed*.006)
		s.shield+=consumed*.7;s.shield_time=cast.time+.5
		if s.counter>0:cast.power*=1.5;s.counter=0.
	if p.class_id=="reaper" and mode.begins_with("heavy") and s.instant>0:cast.time=0.;s.instant=0.
	if p.class_id=="gambler" and mode.begins_with("settle"):
		s["clean_card"]=true
		if cast.get("blackjack",false):reduce_cd(p,"gambler_a09",passive(p,3)*.25)
	if p.class_id=="infighter" and n.index==3:var used=mini(5,s.rush);s.rush-=used;cast.power*=1+used*.1
	if mode=="finisher":cast.power*=1+s.combo*.3;s.combo=0;s.combo_time=0
	cast["stagger"]=combat.constellation.prepare(p,n,cast)
	if cast.get("constellation",{}).get("attacking",true):combat.constellation.committed(p,n,cast)
	p.motion="cast_high" if cast.time>0 else "cleave";p.motion_time=maxf(.4,cast.time);p.motion_duration=p.motion_time
	if cast.time>0:
		s.casting=cast
		var visual=cast_visual(p,cast);visual["skill_phase"]="windup";visual["duration"]=cast.time;visual["follow_owner"]=true;visual["follow_offset"]=0.0
		fx(p,p.class_id+":0",p.pos,1.5,visual)
	else:execute(p,cast)
	return true
func allies(p:Dictionary,radius:float=6.)->Array:
	if p.class_id=="thief":radius+=passive(p,4)*.4
	return sim.players.values().filter(func(a):return a.hp>0 and a.pos.distance_to(p.pos)<=radius)
func status(p:Dictionary,e:Dictionary,key:String,duration:float,attribution:Variant=null):
	if e.hp<=0:return
	if not e.has("job_status"):e.job_status={}
	if p.class_id=="explorer" and key in ["root","stun"]:
		duration+=passive(p,2)*.15
		if e.get("boss",false):e.job_status["vulnerable"]={"time":duration,"owner":p.id,"tick":0.}
	e.job_status[key]={"time":duration,"owner":p.id,"tick":0.0}
	if key=="bleed":
		var source=combat.stagger_context if attribution==null else attribution
		var budget=source.get("budget",{})
		e.job_status[key]["stagger"]=combat.constellation.periodic_context(source,maxi(1,floori(duration))) if budget.get("dot",false) else {}
		e.job_status[key]["damage_multiplier"]=float(source.get("build",{}).get("dot_damage_multiplier",1.))
	if key=="slow":e.slow_time=maxf(e.get("slow_time",0),duration)
	if key in ["root","stun"] and not e.get("boss",false):e.stun_time=maxf(e.get("stun_time",0),minf(duration,1.5))
	if p.class_id=="thief":
		if key in p.job_state.get("support_sent",[]):return
		p.job_state.get_or_add("support_sent",[]).append(key)
		reduce_cd(p,"thief_a03",passive(p,5)*.15)
		var mapping={"slow":"speed","break_armor":"armor","vulnerable":"attack","weaken":"defense","bleed":"leech","blind":"evade"}
		if mapping.has(key):
			for a in allies(p):buff(a,mapping[key],.15,5.);fx(a,"thief:5",a.pos)
func execute(p:Dictionary,cast:Dictionary):
	var previous=combat.stagger_context
	combat.stagger_context=cast.get("stagger",{})
	if cast.node.mode in ["pet_command","pet_burst","pet_pull"] and not combat.stagger_context.is_empty():
		combat.stagger_context["weight"]=.75/maxi(1,p.job_state.pets.size())*float(combat.stagger_context.get("build",{}).get("direct_stagger",1.))
	var before_position:Vector2=p.pos
	_execute(p,cast)
	if not cast.get("constellation",{}).get("attacking",true):combat.constellation.committed(p,cast.node,cast)
	if cast.node.mode in combat.constellation.MOVEMENT and p.pos.distance_to(before_position)>.05:combat.constellation.moved(p)
	combat.stagger_context=previous

func _execute(p:Dictionary,cast:Dictionary):
	var s=p.job_state;var n=cast.node;var mode=n.mode;var damage=roundi(sim.damage_for(p)*cast.power);var t=sim.enemies.get(cast.target,{})
	var point=combat.skills.target(p,3.);var upgraded=cast.up;var duration=float(n.duration)
	# Ground skills land on the acquired target; empty ground still follows aim.
	if not t.is_empty():point=t.pos
	p.motion="slam" if mode.begins_with("charge") or mode.begins_with("heavy") or mode=="finisher" else "cleave"
	p.motion_time=.6 if p.motion=="slam" else .35;p.motion_duration=p.motion_time
	s.lock=.6 if p.motion=="slam" else .16
	s["current_index"]=int(n.index)
	s["current_heavy"]=mode.begins_with("charge") or mode.begins_with("heavy")
	s["natural_heavy"]=false
	s["direct_cast"]=n.id
	s["support_sent"]=[]
	if p.level>=100:master(p,cast)
	var visual=cast_visual(p,cast);visual["skill_phase"]="release"
	var effect={}
	# Ground and moving skills share the same coordinates as their combat result.
	if mode not in ["field","trap","trap_bleed","barrage","combo","settle_barrage"]:
		var effect_point=point if mode in ["burst","root","slow","pull","wall"] else p.pos
		effect=fx(p,n.fx,effect_point,n.radius,visual)
		if mode=="chain":effect["end"]=combat.skills.target(p,minf(1.,n.radius))
	if mode in ["haste","buff_attack","buff_crit","buff_crit_damage","stance","empower","enchant","guard","fortress","share","chant","stand_card","dice_buff"]:
		var key=Balance.BUFF_KEYS.get(mode,"attack")
		for a in allies(p) if p.class_id in ["healer","tank"] else [p]:buff(a,key,cast.buff,duration)
		return
	if mode=="wall":
		s["wall"]={"pos":point,"dir":p.aim,"time":duration,"radius":1.6+(1. if upgraded else 0)}
		return
	if mode in ["shield","ally_dash"]:
		if mode=="ally_dash":
			var friends=allies(p).filter(func(a):return a.id!=p.id)
			if not friends.is_empty():move(p,p.pos.direction_to(friends[0].pos),p.pos.distance_to(friends[0].pos))
			else:move(p,p.aim,2.5)
			effect["end"]=p.pos
			buff(p,"defense",.03*passive(p,1)+(.15 if upgraded else 0),3.)
		for a in allies(p) if p.class_id in ["tank","healer"] else [p]:
			var power=cast.shield
			if p.class_id=="tank" and a.hp<a.max_hp*.35:power*=1+passive(p,0)*.08
			if p.class_id=="healer" and a.hp<a.max_hp*.35:power*=1+passive(p,5)*.08
			a.job_state.shield=maxf(a.job_state.shield,power);a.job_state.shield_time=duration
		if p.class_id=="runesword":buff(p,"defense",passive(p,5)*.03,3.)
		return
	if mode in ["heal","regen","field_heal"]:
		for a in allies(p) if p.class_id=="healer" else [p]:
			var healing=roundi(cast.heal*float(a.max_hp)/p.max_hp)
			var effective=mini(a.max_hp-a.hp,healing);a.hp+=effective
			if p.class_id=="healer" and effective>0:p.stamina=minf(p.max_stamina,p.stamina+passive(p,1))
			if cast.regen>0:buff(a,"regen",cast.regen*float(a.max_hp)/p.max_hp,duration)
		return
	if mode=="cleanse":
		for a in allies(p) if p.class_id=="healer" else [p]:a.enemy_slow_time=0;buff(a,"defense",cast.buff,duration)
		return
	if mode=="distribute":
		var shared=s.buffs.duplicate(true)
		for a in allies(p):
			for key in shared:
				for layer in shared[key].get("layers",[{"value":shared[key].value,"time":shared[key].time}]):buff(a,key,layer.value,layer.time)
			a.job_state.shield=maxf(a.job_state.shield,cast.shield*.4);a.job_state.shield_time=duration
		return
	if mode=="return_anchor":
		if s.anchor.is_empty():s.anchor=[p.pos];p.skill_cooldowns[n.id]=.4
		else:
			if p.pos.distance_to(s.anchor[0])<cast.anchor_range and sim.map.line_clear(p.pos,s.anchor[0]):p.pos=s.anchor[0]
			s.anchor.clear()
		effect["end"]=p.pos
		return
	if mode in ["parry","parry_counter","parry_knee"]:s.parry=cast.parry;s.parry_kind=mode;s.counter_power=cast.counter_power;s.parry_stagger=combat.stagger_context;return
	if mode=="meditate":s["meditate"]=1.2;s["meditate_rate"]=cast.meditate_rate;s.lock=1.2;return
	if mode=="hit_card":
		draw_cards(p,1)
		if hand_total(s.hand)>21:fx(p,"gambler:5",p.pos);dispose_hand(p);buff(p,"speed",passive(p,1)*.05,2.)
		return
	if mode=="hold_card":s.held=-1 if s.held==s.hand[s.selected] else s.hand[s.selected];return
	if mode=="cut_card":
		s.discard.append(s.hand.pop_at(clampi(int(s.selected),0,s.hand.size()-1)));draw_cards(p,2)
		s["candidates"]=[s.hand.pop_back(),s.hand.pop_back()];s["candidate_index"]=0
		return
	if mode in ["dice","reroll"]:s.dice=sim.rng.randi_range(1,6);s.dice_time=duration;return
	if mode=="summon":
		s.pets=s.pets.filter(func(pet):return pet.source!=n.id)
		if s.pets.size()>=2+(1 if passive(p,0)>=3 else 0):s.pets.pop_front()
		s.pets.append({"source":n.id,"pos":p.pos,"hp":cast.pet_hp,"max_hp":cast.pet_hp,"cd":0.,"power":cast.pet_power,"kind":n.index,"stagger":combat.BossStagger.context(cast.get("stagger",{}).get("budget",{}),1./6.)});return
	if mode.begins_with("pet_"):
		for pet in s.pets:
			match mode:
				"pet_heal":pet.hp=pet.get("max_hp",100.);buff(p,"pet_guard",cast.pet_buff,duration)
				"pet_recall":pet.pos=p.pos;pet.hp=minf(pet.get("max_hp",100.),pet.hp+pet.get("max_hp",100.)*cast.recall_heal)
				"pet_buff":buff(p,"pet_power",cast.pet_buff,duration)
				"pet_haste":buff(p,"pet_haste",cast.pet_buff,duration)
				"pet_guard":buff(p,"pet_guard",cast.pet_buff,duration)
				"pet_sacrifice":s.shield=minf(p.max_hp*.6,s.shield+pet.hp*cast.sacrifice_ratio);s.shield_time=duration;pet.hp=0
				_:
					if not t.is_empty() and t.hp>0:
						pet.pos=sim.map.move(t.pos,Vector2(.5,0))
						if combat.hit(p,t,maxi(1,roundi(float(damage)/s.pets.size()))):status(p,t,"bleed",5.)
		return
	if mode in ["teleport","teleport_chain"]:
		if t.is_empty() or t.hp<=0:return
		var destination=sim.map.move(t.pos,p.aim*.7)
		if sim.map.walkable(destination) and sim.map.line_clear(p.pos,destination):p.pos=destination
		else:return
		effect["end"]=p.pos
		buff(p,"speed",passive(p,0)*.04,2.)
	if mode.begins_with("chain_"):
		if t.is_empty() or t.hp<=0:return
		effect["end"]=t.pos
		if mode=="chain_dash" or t.get("boss",false):
			move(p,p.pos.direction_to(t.pos),maxf(0,p.pos.distance_to(t.pos)-1))
			effect["end"]=p.pos
		if not combat.hit(p,t,damage):return
		if mode!="chain_dash" and not t.get("boss",false) and t.hp>0:
			for i in range(30):t.pos=sim.map.move(t.pos,t.pos.direction_to(p.pos)*.1)
		s.instant=5.+passive(p,3)*.4;buff(p,"speed",passive(p,1)*.04,2.);return
	if mode in ["dash","rush","weave","retreat","flank","blink","card_retreat","heavy_dash"]:
		move(p,-p.aim if mode in ["retreat","card_retreat"] else p.aim.orthogonal() if mode in ["weave","flank"] else p.aim,n.distance)
		effect["end"]=p.pos
		if mode=="weave":p.invulnerable=.1
		if mode=="retreat" and p.class_id=="sniper":buff(p,"speed",passive(p,5)*.03,2.)
		if mode=="card_retreat":basic(p)
	if mode in ["shot","fan","root_shot","slow_shot","bleed_shot","pull_shot","execute_shot","settle","settle_heavy","settle_fan"]:
		var count=int(cast.count)
		for i in range(count):
			combat.launch(p,"bow" if Content.CLASSES[p.class_id].weapon=="bow" else "staff",p.aim.rotated((i-(count-1)*.5)*.15),damage,n.range,14.,0)
			combat.projectiles.back()["status"]=mode.trim_suffix("_shot") if mode.ends_with("_shot") else ""
			combat.projectiles.back()["pierce"]=2 if p.class_id=="sniper" else 0
			combat.projectiles.back().merge(visual,true);combat.projectiles.back()["fx"]=n.fx;combat.projectiles.back()["origin"]=combat.projectiles.back().pos
			combat.projectiles.back()["skill_rank"]=cast.rank;combat.projectiles.back()["visual_scale"]=1.+.18*(cast.rank-1)
		return
	if mode in ["field","trap","trap_bleed","barrage","combo","settle_barrage"]:
		if combat.constellation.delivery(p,cast):return
		var count=int(cast.count)
		visual["follow_owner"]=mode in ["barrage","combo"] and not Content.CLASSES[p.class_id].projectile
		visual["follow_offset"]=1.1
		combat.skills.add_zone(p,n.fx,point if mode in ["field","trap","trap_bleed"] else p.pos+p.aim*1.1,n.radius,damage,combat.skills.pulses(count,.05,.12 if mode in ["barrage","combo","settle_barrage"] else .5),2. if mode=="trap" else 0.,0.,visual)
		var zone=combat.skills.zones.back();zone["job_node"]=n.id;zone["mode"]=mode;zone["follow"]=mode in ["barrage","combo"] and not Content.CLASSES[p.class_id].projectile;zone["hit_any"]=false
		if mode=="barrage":s["channel"]=.8;s.lock=.8
		return
	var center=point if mode in ["burst","root","slow","pull"] else p.pos
	if combat.constellation.delivery(p,cast):return
	var any_hit=false
	for e in sim.enemies.values():
		if e.hp<=0 or not HitGeometry.circle(e,center,n.radius) or not sim.map.line_clear(center,e.pos):continue
		if center==p.pos and not preload("res://scripts/skill_reach.gd").radial(mode) and p.aim.dot(p.pos.direction_to(e.pos))<0:continue
		var amount=damage
		# 근접 연쇄의 연결선은 실제 피해가 적용된 표적까지만 그린다.
		if mode in ["execute","heavy_execute","charge_execute"]:amount=roundi(amount*(1+(1-float(e.hp)/e.max_hp)))
		if not combat.hit(p,e,amount):continue
		any_hit=true
		if mode=="chain":effect["end"]=e.pos
		if mode in ["slow","stun","root","bleed","blind","vulnerable","weaken","break_armor"]:status(p,e,mode,duration)
		if mode=="mark":mark(p,e);status(p,e,"vulnerable",duration)
		if mode in ["pull","taunt"] and not e.get("boss",false):
			e.pos=sim.map.move(e.pos,e.pos.direction_to(p.pos)*.8);e.target=p.id;e.taunt_owner=p.id;e.taunt_time=duration+(passive(p,5)*.5 if p.class_id=="tank" else 0)
	if any_hit:
		if p.class_id=="infighter":s.rush=mini(10,s.rush+1);s.rush_time=2.+(passive(p,3)*.2 if s.get("after_dash",0)>0 else 0)
		if p.class_id=="martialist" and mode!="finisher":combo(p,n.id)
	s.current_heavy=false
func combo(p:Dictionary,id:String):
	var s=p.job_state
	if s.last_skill!=id:s.combo=mini(3,s.combo+1)
	s.last_skill=id;s.combo_time=2.+passive(p,1)*.1+passive(p,2)*.1
func tick(p:Dictionary,delta:float):
	if not p.has("job_state"):reset(p)
	var s=p.job_state
	for key in ["counter","instant","combo_time","rush_time","parry","dice_time","shield_time","pet_timer","resource_cd","leech_cd","lock","channel","rune_cd","recovery_cd","after_dash","heavy_proc_cd"]:s[key]=maxf(0,float(s.get(key,0))-delta)
	if s.shield_time<=0:s.shield=0.
	if not s.get("wall",{}).is_empty():
		s.wall.time-=delta
		if s.wall.time<=0:s.wall={}
	if sim.map.in_town(p.pos):s.grit=[];s.momentum=0.
	elif p.class_id=="breaker":
		if p.combat_time<=0:s.out_of_combat=s.get("out_of_combat",0.)+delta
		else:s.out_of_combat=0.
		if s.get("out_of_combat",0)>2.+passive(p,0)*.4:s.momentum=maxf(0,s.momentum-delta*25)
	for key in s.buffs.keys():
		var entry=s.buffs[key];var layers=entry.get("layers",[{"value":entry.value,"time":entry.time}])
		for layer in layers:layer.time-=delta
		layers=layers.filter(func(layer):return layer.time>0)
		if layers.is_empty():s.buffs.erase(key);continue
		entry.value=0.;entry.time=0.;entry.layers=layers
		for layer in layers:entry.value=maxf(entry.value,layer.value);entry.time=maxf(entry.time,layer.time)
	if s.combo_time<=0:s.combo=0;s.last_skill=""
	if s.rush_time<=0:s.rush=maxi(0,s.rush-1);s.rush_time=1.
	for h in s.grit:h.remaining-=delta
	s.grit=s.grit.filter(func(h):return h.remaining>0)
	for key in s.marks.keys():
		s.marks[key]-=delta
		if s.marks[key]<=0 or sim.enemies.get(int(key),{}).get("hp",0)<=0:s.marks.erase(key)
	if Content.job(p) and s.dash_timer>0:
		s.dash_timer-=delta
		if s.dash_timer<=0:
			s.dash_charges+=1
			if s.dash_charges<(2 if p.class_id=="infighter" else 1):s.dash_timer=2.5
	if Content.job(p):p.dodge_cd=maxf(0,s.dash_timer) if s.dash_charges<=0 else 0.
	if s.get("meditate",0)>0:
		if p.dir.length()>.1:s.meditate=0.
		else:s.momentum=minf(100,s.momentum+minf(delta,s.meditate)*s.get("meditate_rate",25.));s.meditate-=delta
	if not s.casting.is_empty():
		s.casting.time-=delta
		if s.casting.time<=0:var cast=s.casting;s.casting={};execute(p,cast)
	if value(p,"regen")>0:
		s["regen"]=s.get("regen",0)+delta*value(p,"regen")
		if s.regen>=1:p.hp=mini(p.max_hp,p.hp+int(s.regen));s.regen=fposmod(s.regen,1.)
	if p.class_id=="hunter" and s.pets.is_empty():
		s.hound_respawn=maxf(0,s.get("hound_respawn",0)-delta)
		if s.hound_respawn<=0:s.pets.append({"source":"hound","pos":p.pos,"hp":p.max_hp*.3,"max_hp":p.max_hp*.3,"cd":0.,"power":.35,"kind":0})
	for pet in s.pets:
		pet.cd-=delta
		var previous_position:Vector2=pet.pos
		if pet.hp<=0:continue
		if pet.source!="hound" and pet.source!="test" and pet.source not in p.skill_loadout.values():pet.hp=0;continue
		var t=target(p,7.)
		var ordered=sim.enemies.get(s.get("pet_target",-1),{})
		if ordered.get("training",false) and not preload("res://scripts/training_ground.gd").can_practice(sim,p):ordered={}
		if not ordered.is_empty() and ordered.hp>0 and HitGeometry.circle(ordered,p.pos,9+passive(p,5)*.5) and sim.map.line_clear(pet.pos,ordered.pos):t=ordered
		if t.is_empty():pet.pos=sim.map.move(pet.pos,pet.pos.direction_to(p.pos)*minf(delta*4,pet.pos.distance_to(p.pos)))
		else:
			pet.pos=sim.map.move(pet.pos,pet.pos.direction_to(t.pos)*delta*4)
			if pet.cd<=0 and HitGeometry.circle(t,pet.pos,5. if pet.kind==1 else 1.6):
				combat.hit(p,t,roundi(sim.damage_for(p)*pet.power*(1+value(p,"pet_power"))),pet.pos,pet.get("stagger",{}));pet.cd=.8/(1+value(p,"pet_haste"))
		pet.moving=pet.pos.distance_squared_to(previous_position)>.000001
		var facing_direction:Vector2=pet.pos-previous_position if t.is_empty() else t.pos-pet.pos
		var screen_direction=preload("res://scripts/dungeon.gd").iso(facing_direction)
		if absf(screen_direction.x)>.001:pet.facing=-1. if screen_direction.x<0 else 1.
	if p.class_id=="hunter" and s.pets.any(func(pet):return pet.hp<=0):s.hound_respawn=8.
	s.pets=s.pets.filter(func(pet):return pet.hp>0)
	if p.class_id=="hunter":
		for drop in sim.drops.values():
			if drop.owner==p.id and p.pos.distance_to(drop.pos)<5+passive(p,5)*.5:drop.pos=sim.map.move(drop.pos,drop.pos.direction_to(p.pos)*delta*6)
		if s.pet_timer<=0:s.pet_timer=.5;sim.action(p.id,"interact")
	# One owner ticks each applied status; periodic damage cannot generate class resources.
	for e in sim.enemies.values():
		for key in e.get("job_status",{}).keys():
			var st=e.get("job_status",{}).get(key,{})
			if st.is_empty():continue
			if st.owner!=p.id:continue
			st.time-=delta;st.tick+=delta
			if key=="bleed" and st.tick>=1 and e.hp>0:st.tick=0.;combat.hit(p,e,roundi(sim.damage_for(p)*.25*(1+passive(p,0)*.08 if p.class_id=="hunter" else 1)*float(st.get("damage_multiplier",1.))),e.pos,st.get("stagger",{}))
			if st.time<=0:e.job_status.erase(key)
func resource_text(p:Dictionary)->String:
	var s=p.job_state
	match p.class_id:
		"breaker":return "기세 %d  + 피격 %d   반격 %s"%[s.momentum,grit(p),"준비" if s.counter>0 else "—"]
		"infighter":return "몰아침 %d/10 · 대시 %d/2"%[s.rush,s.dash_charges]
		"martialist":return "연무 %d/3"%s.combo
		"runesword":return "룬 %d"%s.runes
		"reaper":return "즉결 준비" if s.instant>0 else "사슬 적중 → 즉결"
		"gambler":
			var cards=[]
			for i in range(s.hand.size()):
				var card=s.hand[i];var face=["A","2","3","4","5","6","7","8","9","10","J","Q","K"][int(card)%13]
				cards.append(("▶" if i==s.selected else "")+face+("★" if card==s.held else ""))
			if not s.get("candidates",[]).is_empty():return "컷 카드 후보 %d / %d · 선택 %d [TAB 변경 · 평타로 확정]"%[int(s.candidates[0])%13+1,int(s.candidates[1])%13+1,int(s.candidate_index)+1]
			var summary=""
			if passive(p,0)>0:
				var aces=0;var tens=0
				for card in s.discard:
					if int(card)%13==0:aces+=1
					elif int(card)%13>=9:tens+=1
				summary="\n버림 A %d · 10점 %d · 기타 %d"%[aces,tens,s.discard.size()-aces-tens]
			if s.get("peek",-1)>=0:summary+=" · 다음 카드 "+str(int(s.peek)%13+1)
			return "패 %s = %d · 덱 %d · 버림 %d · 주사위 %d  [TAB 선택]"%[" ".join(cards),hand_total(s.hand),s.deck.size(),s.discard.size(),s.dice if s.dice_time>0 else 0]+summary
	return "보호막 %d"%s.shield if s.shield>0 else ""

func reduce_cd(p:Dictionary,id:String,amount:float):
	if amount>0 and p.skill_cooldowns.get(id,0)>0:p.skill_cooldowns[id]=maxf(.5,p.skill_cooldowns[id]-amount)
func configure(p:Dictionary,cast:Dictionary):
	# Only transient, conditional effects live here. Stable values are in Balance.
	var n=cast.node;var s=p.job_state
	if cast.mitigation>0:buff(p,"defense",cast.mitigation,1. if n.mode.begins_with("parry") else 2.)
	if p.class_id=="explorer" and n.index>=8:buff(p,"speed",passive(p,5)*.03,2.)
	if p.class_id=="gambler":
		if n.index in [4,5,6,7] and hand_total(s.hand) in [17,18,19,20]:cast.power*=1+passive(p,2)*.03
		if s.dice_time>0:cast.time=maxf(0,cast.time-passive(p,4)*.03)
	if p.class_id=="martialist":
		if n.mode=="finisher" and s.combo>=3:buff(p,"next_combo",passive(p,5)*.04,4.)
		elif n.mode=="combo" and value(p,"next_combo")>0:cast.power*=1+value(p,"next_combo");s.buffs.erase("next_combo")
func master(p:Dictionary,cast:Dictionary):
	var s=p.job_state
	if p.class_id=="infighter":
		if s.rush>=10:
			var used=s.get("master_skills",[])
			if cast.node.id not in used:used.append(cast.node.id)
			if used.size()>=3:buff(p,"attack",.25,3.);used.clear()
			s.master_skills=used
	elif p.class_id=="breaker" and cast.node.mode.begins_with("charge"):
		buff(p,"defense",.2,1.)
	elif p.class_id=="martialist" and cast.node.mode=="finisher":buff(p,"haste",.2,3.)
	elif p.class_id=="thief":buff(p,"speed",.15,2.)
	elif p.class_id=="gambler" and cast.get("blackjack",false):s["peek"]=s.deck.back() if not s.deck.is_empty() else -1
	elif p.class_id=="reaper" and cast.node.mode.begins_with("heavy"):buff(p,"attack",.15,2.)
	else:
		var bonuses={"tank":["defense",.15],"swordsman":["crit",.1],"runesword":["haste",.15],"summoner":["pet_power",.2],"elementalist":["attack",.15],"healer":["regen",2.],"sniper":["crit_damage",.25],"hunter":["pet_haste",.2],"explorer":["speed",.15]}
		if bonuses.has(p.class_id):
			var b=bonuses[p.class_id]
			for a in allies(p) if p.class_id in ["tank","healer"] else [p]:buff(a,b[0],b[1],5.)
