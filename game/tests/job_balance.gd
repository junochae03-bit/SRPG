extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Content=preload("res://scripts/content.gd")
const Balance=preload("res://scripts/job_balance.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func fixture(job:String)->Dictionary:
	var sim=Sim.new(123);sim.enemies.clear();var p=sim.add_player(1,"밸런스 검사")
	p.class_id=job;p.level=90;p.pos=Vector2(sim.map.rooms[1]);p.aim=Vector2.RIGHT;p.skill_ranks={};p.skill_loadout={};sim.combat.jobs.reset(p)
	p.max_hp=10000;p.hp=1;p.max_stamina=200.;p.stamina=200.
	var e=sim.spawn_enemy("shade",p.pos+Vector2.RIGHT,90);e.hp=1000000;e.max_hp=1000000
	return {"sim":sim,"p":p,"enemy":e}
func cast(f:Dictionary,index:int,rank:int,up:bool=false)->Dictionary:
	var id=f.p.class_id+"_a%02d"%(index+1);var n=Content.SKILLS[f.p.class_id].filter(func(node):return node.id==id)[0]
	f.p.skill_ranks[id]=rank;f.p.skill_loadout.skill_q=id
	if up:f.p.skill_ranks[id+"_upgrade"]=1
	f.p.job_state.runes=10;f.p.job_state.marks={str(f.enemy.id):8.};f.p.job_state.hand=[0,9]
	var value=Balance.profile(f.p,n,rank,f.sim.damage_for(f.p),f.p.max_hp,up)
	var before=f.p.stamina
	check(f.sim.action(1,"skill_q"),"real cast "+id+" rank "+str(rank))
	check(is_equal_approx(before-f.p.stamina,value.cost),"quoted cost equals paid cost "+id)
	check(is_equal_approx(f.p.skill_cooldowns[id],value.cooldown),"quoted cooldown equals runtime "+id)
	return value
func tick(f:Dictionary,seconds:float,player_attacks:bool=false):
	for i in range(roundi(seconds/.02)):
		if player_attacks:f.sim.action(1,"attack")
		f.p.attack_cd=maxf(0,f.p.attack_cd-.02);f.sim.combat.tick_player(f.p,.02);f.sim.combat.tick_projectiles(.02);f.sim.combat.skills.tick(.02)
func run():
	Content.initialize_jobs()
	var attacks={"tank":11,"swordsman":1,"runesword":4,"summoner":0,"elementalist":0,"healer":11,"sniper":0,"hunter":0,"explorer":1,"thief":8,"reaper":4,"gambler":4,"infighter":0,"breaker":0,"martialist":2}
	for job in attacks:
		var results=[]
		for rank in [1,3,5]:
			var f=fixture(job);cast(f,attacks[job],rank);tick(f,3.,job=="summoner")
			results.append(1000000-f.enemy.hp)
		check(results[0]>0 and results[1]>results[0] and results[2]>results[1],"actual ranked damage increases "+job+" "+str(results))
		var upgraded=fixture(job);cast(upgraded,attacks[job],5,true);tick(upgraded,3.,job=="summoner")
		check(1000000-upgraded.enemy.hp>results[2],"third upgrade increases actual damage "+job)
	for setup in [["swordsman",0],["healer",4],["tank",4],["runesword",0],["infighter",8]]:
		var strengths=[]
		for rank in [1,5]:
			var f=fixture(setup[0]);var s=cast(f,setup[1],rank);tick(f,.02)
			var key=Balance.BUFF_KEYS[s.node.mode]
			check(is_equal_approx(f.sim.combat.jobs.value(f.p,key),s.buff),"actual buff equals comparison "+s.node.id)
			strengths.append(f.sim.combat.jobs.value(f.p,key))
		check(strengths[1]>strengths[0],"support rank increases actual buff "+setup[0])
	for job in ["tank","healer","runesword"]:
		var index={"tank":1,"healer":9,"runesword":9}[job];var values=[]
		for rank in [1,5]:
			var f=fixture(job);var s=cast(f,index,rank)
			if not f.p.job_state.casting.is_empty():tick(f,s.time+.04)
			check(is_equal_approx(f.p.job_state.shield,s.shield),"shield preview equals granted shield "+job)
			var amount=f.sim.combat.jobs.receive(f.p,f.enemy,2000,false)
			values.append(2000-amount)
		check(values[1]>values[0],"higher rank absorbs more damage "+job)
	for index in [0,1,3]:
		var healing=[]
		for rank in [1,5]:
			var f=fixture("healer");var s=cast(f,index,rank);tick(f,.02)
			check(absf(f.p.hp-1-roundi(s.heal)-s.regen*.02)<2.,"actual immediate healing matches preview")
			tick(f,2.);healing.append(f.p.hp)
		check(healing[1]>healing[0],"actual healing/regen increases "+str(index))
	for job in Balance.ROLES:
		var f=fixture(job)
		for n in Content.SKILLS[job]:
			check(not Balance.metrics(f.p,n,1,100,1000).is_empty(),"all nodes have effect comparisons "+n.id)
			if n.effect!="active":continue
			var original=n.duplicate(true);var a=Balance.profile(f.p,n,1,100,1000);var b=Balance.profile(f.p,n,5,100,1000,true)
			check(n==original,"shared profile never mutates catalog "+n.id)
			check(b.power>a.power and b.cooldown<a.cooldown and b.node.duration>a.node.duration,"rank and upgrade improve actual values "+n.id)
			check(b.cost>=5 and b.cooldown>=.5,"resource floor "+n.id)
			if n.mode in ["barrage","combo","field","trap","fan"]:check(a.power*a.count<8.,"multihit has a total cast damage budget "+n.id)
	# A short powerful buff must expire even when weaker buffs are refreshed.
	var f=fixture("swordsman");var jobs=f.sim.combat.jobs
	jobs.buff(f.p,"attack",.5,1.);jobs.buff(f.p,"attack",.1,10.);tick(f,1.2)
	check(is_equal_approx(jobs.value(f.p,"attack"),.1),"weak refresh cannot extend strong attack buff")
	f=fixture("thief");jobs=f.sim.combat.jobs
	jobs.buff(f.p,"attack",.5,1.);jobs.buff(f.p,"attack",.1,10.);cast(f,10,3);tick(f,1.2)
	check(is_equal_approx(jobs.value(f.p,"attack"),.1),"sharing preserves each buff's original expiry")
	f=fixture("hunter");tick(f,.1);f.p.job_state.pets[0].hp=0.;tick(f,1.)
	check(f.p.job_state.pets.is_empty() and f.p.job_state.hound_respawn>0,"dead hound waits to return")
	tick(f,8.);check(f.p.job_state.pets.size()==1,"hound returns after recovery")
	f=fixture("healer");f.p.skill_ranks.healer_p04=5
	var n=Content.SKILLS.healer.filter(func(node):return node.id=="healer_a01")[0];var s=Balance.profile(f.p,n,1,18,f.p.max_hp)
	f.p.stamina=s.cost;cast(f,0,1);check(f.p.stamina==0.,"discounted skill works with exactly the quoted stamina")
	for job in ["rogue","fighter"]:
		f=fixture(job);f.p.level=2;check(Content.can_invest(f.p,job+"_a01"),"starter has useful skill at level2 "+job)
		check(Content.SKILLS[job].filter(func(node):return node.effect=="active").size()==4,"starter offers four pre-advancement skills "+job)
	for entry in [["healer",8,"cleanse"],["thief",10,"distribute"],["breaker",10,"meditate"],["summoner",6,"pet_heal"],["summoner",9,"pet_recall"],["summoner",11,"pet_sacrifice"]]:
		var amounts=[]
		for upgraded in [false,true]:
			f=fixture(entry[0]);f.p.enemy_slow_time=5.
			if entry[0]=="summoner":f.p.job_state.pets=[{"source":"test","pos":f.p.pos,"hp":100.,"max_hp":1000.,"cd":10.,"kind":0,"power":0.}]
			cast(f,entry[1],3,upgraded);tick(f,1.25)
			match entry[2]:
				"cleanse":check(f.p.enemy_slow_time==0,"cleanse clears slow");amounts.append(f.sim.combat.jobs.value(f.p,"defense"))
				"distribute","pet_sacrifice":amounts.append(f.p.job_state.shield)
				"meditate":amounts.append(f.p.job_state.momentum)
				"pet_heal":amounts.append(f.sim.combat.jobs.value(f.p,"pet_guard"))
				"pet_recall":amounts.append(f.p.job_state.pets[0].hp)
		check(amounts[1]>amounts[0],"utility upgrade has real effect "+entry[2])
	print("JOB_BALANCE_TESTS checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
