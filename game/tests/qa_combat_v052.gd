extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Content=preload("res://scripts/content.gd")
const Stagger=preload("res://scripts/boss_stagger.gd")
const Geometry=preload("res://scripts/enemy_hit_geometry.gd")
const Training=preload("res://scripts/training_ground.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
const Equipment=preload("res://scripts/equipment_catalog.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func fixture(job:String="runesword",kind:String="shade")->Dictionary:
	var sim=Sim.new(20260910,"forest",1);sim.enemies.clear();sim.events.clear()
	for x in range(18,35):
		for y in range(18,35):sim.map.floor_cells[Vector2i(x,y)]=true
	var p=sim.add_player(1,"적중 검증",{"schema_version":7,"class_id":job,"level":30,"stats":{},"skill_ranks":{},"skill_loadout":{},"constellation_allocations":{},"tutorial_done":true})
	p.pos=Vector2(24,24);p.aim=Vector2.RIGHT
	var e=sim.spawn_enemy(kind,p.pos+Vector2(2,0),1,kind=="warden");e.hp=10000;e.max_hp=e.hp
	return {"sim":sim,"p":p,"e":e}
func damages(f:Dictionary)->Array:
	return f.sim.events.filter(func(event):return event.type=="damage" and event.get("enemy",false))
func barrier(f:Dictionary):
	for y in range(18,35):f.sim.map.floor_cells.erase(Vector2i(25,y))
	check(not f.sim.map.line_clear(f.p.pos,f.e.pos),"fixture contains a real blocking wall")
func fly(f:Dictionary):
	for _i in range(45):f.sim.combat.tick_projectiles(.04)
func direct_contract():
	var f=fixture()
	check(not f.sim.combat.hit(f.p,f.e,0) and damages(f).is_empty(),"zero damage returns rejected")
	f.e.hp=0
	check(not f.sim.combat.hit(f.p,f.e,37) and damages(f).is_empty(),"dead enemy returns rejected")
	f.e.hp=f.e.max_hp;barrier(f)
	check(not f.sim.combat.hit(f.p,f.e,37) and damages(f).is_empty(),"wall-rejected hit returns false")
	f=fixture();var hp=f.e.hp
	check(f.sim.combat.hit(f.p,f.e,37) and hp-f.e.hp==37 and damages(f)[0].amount==37,"accepted direct damage and event keep exact amount")
	f.e.hp=1;var kills=f.p.kills
	check(f.sim.combat.hit(f.p,f.e,37) and f.e.hp==0 and f.p.kills==kills+1,"killing blow returns accepted after kill bookkeeping")
	f=fixture("runesword","warden")
	var stale=Stagger.context(Stagger.basic_token(false,0,f.sim.clock));f.sim.clock=1.;Stagger.reset(f.sim,f.e)
	check(not f.sim.combat.hit(f.p,f.e,37,null,stale) and damages(f).is_empty(),"pre-reset attack budget returns rejected against reset boss")
func melee_resources():
	for state in ["dead","wall","live","killing"]:
		var f=fixture();var hp=f.e.hp;var kills=f.p.kills
		if state=="dead":f.e.hp=0
		elif state=="wall":barrier(f)
		elif state=="killing":f.e.hp=1
		check(Geometry.arc(f.e,f.p.pos,f.p.aim,float(Content.CLASSES.runesword.range),-.05,.7),"swing overlaps tested body "+state)
		check(f.sim.action(1,"attack"),"real rune sword attack dispatched "+state)
		var accepted=state in ["live","killing"]
		check(f.p.job_state.runes==(1 if accepted else 0),"runes generated only for accepted melee hit "+state)
		check(damages(f).size()==(1 if accepted else 0),"one actual melee damage event or no event "+state)
		if state=="live":check(f.e.hp<hp and f.p.kills==kills,"nonlethal rune hit preserves target and kill count")
		elif state=="killing":check(f.e.hp==0 and f.p.kills==kills+1,"last melee strike retains resource and normal kill")
		elif state=="wall":check(f.e.hp==hp,"blocked body takes no melee damage")
		else:check(f.e.hp==0 and f.p.kills==kills,"dead body grants no second kill")
	# 다른 근접 직업의 자원도 동일한 유효 타격 조건을 따른다.
	for job in ["infighter","breaker","thief","swordsman"]:
		var f=fixture(job);f.e.hp=0
		check(f.sim.action(1,"attack"),"dead-body swing still animates "+job)
		var s=f.p.job_state
		check(s.rush==0 and s.momentum==0 and s.marks.is_empty() and s.get("same_hits",0)==0,"dead body cannot trigger another melee job effect "+job)
func ranged_resources():
	# 소환사의 실제 지팡이 기본 공격으로 적중 후 표적 지휘를 검증한다.
	# 직접 타격과 폭발 전달 모두 같은 기본 공격 적중 경로를 사용한다.
	for splash in [0.,1.4]:
		for state in ["dead","wall","stale","live","killing"]:
			var f=fixture("summoner","warden");f.e.pos=f.p.pos+Vector2(3,0);f.e.home=f.e.pos
			f.p.skill_ranks.summoner_p06=1
			var kills=f.p.kills;var hp=f.e.hp
			check(f.sim.action(1,"attack") and f.sim.combat.projectiles.size()==1,"real summoner staff launches "+state+str(splash))
			var shot=f.sim.combat.projectiles[0];shot.splash=splash
			check(shot.get("basic",false),"real projectile carries basic-hit attribution")
			if state=="dead":f.e.hp=0
			elif state=="wall":barrier(f)
			elif state=="stale":f.sim.clock=1.;Stagger.reset(f.sim,f.e)
			elif state=="killing":f.e.hp=1
			fly(f)
			var accepted=state in ["live","killing"]
			check(f.p.job_state.get("pet_target",-1)==(f.e.id if accepted else -1),"projectile command requires accepted primary damage "+state+str(splash))
			check(damages(f).size()==(1 if accepted else 0),"projectile damage applied once or rejected "+state+str(splash))
			if state=="killing":check(f.e.hp==0 and f.p.kills==kills+1,"last projectile hit keeps command and kill result")
			elif state not in ["live","dead"]:check(f.e.hp==hp,"rejected projectile leaves target health intact "+state)
	# 리셋된 보스는 탄환을 막지도 폭발시키지도 않는다. 이후 정상 표적에
	# 실제 충돌하면 그 표적에서 한 번 폭발하고 정상 적중 효과를 얻는다.
	var f=fixture("summoner","warden");f.e.pos=f.p.pos+Vector2(3,0);f.e.home=f.e.pos;f.p.skill_ranks.summoner_p06=1
	var secondary=f.sim.spawn_enemy("shade",f.e.pos+Vector2(0,.8),1);secondary.hp=10000;secondary.max_hp=secondary.hp
	check(f.sim.action(1,"attack"),"mixed splash fixture launches normal staff basic")
	f.sim.clock=1.;Stagger.reset(f.sim,f.e)
	f.sim.combat.tick_projectiles(.08)
	check(damages(f).is_empty() and secondary.hp==secondary.max_hp and f.sim.combat.projectiles[0].hit.is_empty(),"거절된 보스에서는 폭발·주변 피해·충돌 기록이 생기지 않음")
	fly(f)
	check(f.e.hp==f.e.max_hp and secondary.hp<secondary.max_hp and damages(f).size()==1,"정상 표적에 도착한 폭발은 해당 표적을 한 번만 타격")
	check(f.p.job_state.get("pet_target",-1)==secondary.id,"정상 표적의 유효 충돌은 해당 표적 지휘로 연결")

func status_projectile(f:Dictionary,status:String,splash:float=0.,pierce:int=0)->Dictionary:
	var previous=f.sim.combat.stagger_context
	f.sim.combat.stagger_context=Stagger.context(Stagger.basic_token(false,0,f.sim.clock))
	f.sim.combat.launch(f.p,"bow",Vector2.RIGHT,50,12,14,splash)
	f.sim.combat.stagger_context=previous
	var shot=f.sim.combat.projectiles.back();shot["basic"]=true;shot["status"]=status;shot.pierce=pierce
	return shot

func status_and_pierce():
	# 도적의 상태 부여는 표식·아군 지원·대기시간 반환까지 이어진다.
	# 보스 리셋 뒤 거절된 탄환은 이 연결 전체를 건드리지 않아야 한다.
	for status in ["bleed","root","slow"]:
		for splash in [0.,1.4]:
			var f=fixture("thief","warden");f.e.pos=f.p.pos+Vector2(3,0);f.e.home=f.e.pos
			f.p.skill_ranks.thief_p06=1;f.p.skill_cooldowns.thief_a03=5.
			var ally=f.sim.add_player(2,"지원 검증");ally.pos=f.p.pos+Vector2(.2,.2)
			var shot=status_projectile(f,status,splash,1)
			f.sim.clock=1.;Stagger.reset(f.sim,f.e)
			var before=f.p.duplicate(true);var other_before=ally.duplicate(true);var target_before=f.e.duplicate(true)
			f.sim.combat.tick_projectiles(.1)
			check(shot.hit.is_empty() and shot.remaining>0 and shot.pierce==1,"거절된 상태 탄환은 충돌·관통 횟수를 소모하지 않음 "+status+str(splash))
			fly(f)
			check(damages(f).is_empty() and f.e==target_before,"거절된 상태 탄환의 보스 체력·상태·표식·무력화 불변 "+status+str(splash))
			check(f.p==before and ally==other_before and f.sim.combat.constellation.pending.is_empty(),"거절된 상태 탄환의 자원·표식·아군 지원·대기시간 불변 "+status+str(splash))
	for killing in [false,true]:
		var f=fixture("thief");f.p.skill_ranks.thief_p06=1;f.p.skill_cooldowns.thief_a03=5.
		var ally=f.sim.add_player(2,"정상 지원 검증");ally.pos=f.p.pos
		if killing:f.e.hp=1
		var shot=status_projectile(f,"bleed");fly(f)
		check(shot.hit==[f.e.id] and damages(f).size()==1 and f.p.job_state.marks.has(str(f.e.id)),"정상·처치 타격은 충돌과 기본 공격 표식을 유지 "+str(killing))
		if killing:
			check(f.e.hp==0 and not f.e.get("job_status",{}).has("bleed") and f.p.skill_cooldowns.thief_a03==5. and ally.job_state.buffs.is_empty(),"처치 타격은 사망 대상의 지속 상태 지원을 새로 발생시키지 않음")
		else:
			check(f.e.job_status.has("bleed") and f.p.skill_cooldowns.thief_a03<5. and ally.job_state.buffs.has("leech"),"정상 상태 적중의 지속 피해·대기시간 반환·아군 지원 유지")
	# 관통 횟수는 정상 타격 두 번에만 사용된다. 사망/리셋된 대상은 건너뛴다.
	for splash in [0.,1.4]:
		var f=fixture("runesword","warden");f.e.pos=f.p.pos+Vector2(3,0);f.e.home=f.e.pos
		var dead=f.sim.spawn_enemy("shade",f.p.pos+Vector2(.5,0),1);dead.hp=0
		var valid=[]
		for distance in [5.6,8.6,11.6]:
			var enemy=f.sim.spawn_enemy("shade",f.p.pos+Vector2(distance,0),1);enemy.hp=10000;enemy.max_hp=enemy.hp;valid.append(enemy)
		# 마지막 표적까지 길을 확보하되 이 검사는 관통 수로 그 전에 멈춰야 한다.
		for x in range(34,39):
			for y in range(23,26):f.sim.map.floor_cells[Vector2i(x,y)]=true
		var shot=status_projectile(f,"root",splash,1)
		f.sim.clock=1.;Stagger.reset(f.sim,f.e);fly(f)
		check(shot.hit==[valid[0].id,valid[1].id] and shot.remaining==0,"사망·거절 표적 뒤 정상 타격 두 번만 관통 예산 사용 "+str(splash))
		check(damages(f).size()==2 and valid[0].hp==9950 and valid[1].hp==9950 and valid[2].hp==10000,"직접·폭발 관통의 정상 표적당 피해 50과 예산 밖 표적 보존 "+str(splash))
		check(f.e.hp==f.e.max_hp and f.e.get("job_status",{}).is_empty() and valid[0].job_status.has("root") and valid[1].job_status.has("root") and not valid[2].get("job_status",{}).has("root"),"상태는 실제로 충돌한 관통 표적에만 적용 "+str(splash))
		check(f.p.job_state.runes==1,"거절 표적은 룬을 주지 않으며 정상 표적은 기존 룬 생성 간격을 지킴 "+str(splash))
func training_and_damage():
	var sim=Sim.new(20260910,"town");var p=sim.add_player(1,"수련 적중",{"schema_version":7,"class_id":"runesword","level":30,"tutorial_done":true})
	var e=sim.enemies.values()[0]
	check(not sim.combat.hit(p,e,37) and Training.summary(p).hits==0,"safe-town hit rejects training target")
	p.pos=Training.POSITION+Vector2(-3,0);p.aim=Vector2.RIGHT
	check(sim.combat.hit(p,e,37) and Training.summary(p).total_damage==37 and e.hp==e.max_hp,"immortal training hit returns accepted with exact recorded damage")
	var saved=sim.persistent(p.id).duplicate(true)
	check(sim.action(p.id,"attack") and p.job_state.runes==1,"real accepted dummy basic generates rune")
	check(sim.persistent(p.id)==saved and Training.summary(p).hits==2,"practice resource grant keeps all saved fields unchanged")
	# 30레벨 성장분 43을 포함한 기본 공격력은 61이다.
	# 두 번째 사례는 힘 7 / 마력 11, 공격력 4의 일반 무기를 실제 장착한다.
	# 검사 79, 궁수 79×0.92→73, 마법사 87×1.08→94를 유지해야 한다.
	for spec in [["warrior",61,false],["ranger",56,false],["mage",66,false],["warrior",79,true],["ranger",73,true],["mage",94,true]]:
		var f=fixture(spec[0]);f.e.pos=f.p.pos+Vector2(1,0)
		if spec[2]:
			f.p.stats.strength=7;f.p.stats.magic=11
			var weapon=Equipment.make(Content.CLASSES[spec[0]].weapon,0,0,"qa-damage-"+spec[0],"none",spec[0])
			check(weapon.bonus==4 and Inventory.add_gear(f.p,weapon) and f.sim.action(1,"equip",weapon.id),"공격력 4 일반 무기 실제 장착 "+spec[0])
		check(f.p.level==30 and f.p.stats.strength==(7 if spec[2] else 0) and f.p.stats.magic==(11 if spec[2] else 0) and f.p.inventory.size()==(1 if spec[2] else 0) and f.p.skill_ranks.is_empty(),"피해 검증의 레벨·능력치·장비·스킬 상태 확인 "+str(spec))
		check(f.sim.action(1,"attack"),"기본 공격 실행 "+str(spec));fly(f)
		check(damages(f).size()==1 and damages(f)[0].amount==spec[1] and f.e.hp==10000-spec[1],"기본 무기 피해 보존: 기대 %s, 실제 %s"%[spec,damages(f)])
func run():
	direct_contract();melee_resources();ranged_resources();status_and_pierce();training_and_damage()
	print("QA_COMBAT_V052 checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
