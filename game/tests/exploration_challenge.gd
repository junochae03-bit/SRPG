extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Rooms=preload("res://scripts/exploration_rooms.gd")
const Challenge=preload("res://scripts/exploration_challenge.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func use_site(sim,p,site,choice):
	return sim.action(p.id,"explore",site.generation+":"+site.id+":"+choice)
func _initialize():run.call_deferred()
func party_scaling():
	for count in [1,6]:
		var sim=Sim.new(801,"cave",12)
		for id in range(1,count+1):sim.add_player(id,"동료")
		for enemy in sim.enemies.values():enemy.hp=0
		var site=sim.map.exploration_sites[4];sim.players[1].pos=site.pos
		check(use_site(sim,sim.players[1],site,"challenge"),"party starts optional encounter")
		for id in sim.exploration_challenges[site.id]:
			var enemy=sim.enemies[id]
			check(enemy.max_hp==roundi(enemy.solo_health*Sim.Party.health_factor(count)),"new wave uses current party endurance")
			enemy.hp=roundi(enemy.max_hp*.5)
		if count==6:
			sim.players.erase(6)
			Sim.Party.rescale(sim)
			for id in sim.exploration_challenges[site.id]:
				var enemy=sim.enemies[id]
				check(enemy.max_hp==roundi(enemy.solo_health*Sim.Party.health_factor(5)) and absf(float(enemy.hp)/enemy.max_hp-.5)<.01,"departure preserves health fraction with five-player scale")
func run():
	var variants={}
	for seed in range(12):
		var sim=Sim.new(seed,"cave",12);var p=sim.add_player(1,"탐사 검사");var guest=sim.add_player(2,"동료")
		var site=sim.map.exploration_sites[4];var spec=Challenge.variant(sim.map)
		variants[spec.id]=true
		check(site.kind=="challenge" and sim.map.encounters.any(func(e):return e.room==site.room and e.role=="elite"),"optional challenge shares elite wing")
		check(sim.enemies.size()==23,"no extra enemies before voluntary challenge")
		p.pos=site.pos;guest.pos=site.pos+Vector2(.5,0)
		check(not use_site(sim,p,site,"challenge"),"guards must be cleared before risk choice")
		for enemy in sim.enemies.values():enemy.hp=0
		p.pos=sim.map.spawn
		check(not use_site(sim,p,site,"challenge") and sim.enemies.size()==23,"remote activation rejected")
		p.pos=site.pos;p.network_leaving=true
		check(not use_site(sim,p,site,"challenge"),"departing player cannot start encounter")
		p.network_leaving=false
		check(use_site(sim,p,site,"salvage") and p.materials.ore==3,"safe choice grants exact material reward")
		check(not use_site(sim,p,site,"challenge"),"safe claimant cannot double dip by starting challenge")
		check(use_site(sim,guest,site,"challenge"),"another player can choose shared extra combat")
		check(not use_site(sim,guest,site,"challenge") and sim.enemies.size()==23+int(spec.count),"repeated requests cannot spawn extra waves")
		check(not use_site(sim,guest,site,"collect") and not use_site(sim,guest,site,"salvage"),"active challenge offers no early or fallback reward")
		var view=Rooms.snapshot(sim,2)[4]
		check(view.challenge_state=="active" and view.challenge_remaining==spec.count and Challenge.choices(view).is_empty(),"snapshot describes current wave and no actionable reward")
		for id in sim.exploration_challenges[site.id]:
			var enemy=sim.enemies[id]
			check(sim.map.walkable(enemy.pos) and sim.map.line_clear(site.pos,enemy.pos) and enemy.pos.distance_to(guest.pos)>=3.,"reachable wave leaves personal reaction space")
			check(enemy.stun_time==1.5 and not enemy.get("guardian",false),"arrival grace and no progression guardian")
			enemy.pos=sim.map.spawn
		check(Challenge.state(sim,site)=="active" and not use_site(sim,guest,site,"collect"),"luring encounter away cannot clear reward")
		for id in sim.exploration_challenges[site.id]:sim.enemies[id].hp=0
		guest.materials.essence=Inventory.MAX_MATERIALS
		check(not use_site(sim,guest,site,"collect") and not sim.exploration_claims.get(2,{}).has(site.id),"full stack preserves cleared reward for retry")
		guest.materials.erase("essence")
		check(use_site(sim,guest,site,"collect") and guest.materials.essence==int(spec.essence)+1,"cleared challenge grants previewed personal reward")
		check(not use_site(sim,guest,site,"collect") and not use_site(sim,p,site,"collect"),"reward is personal and exclusive with safe salvage")
		var late=sim.add_player(3,"합류한 동료");late.pos=site.pos
		check(Rooms.snapshot(sim,3)[4].challenge_state=="cleared" and use_site(sim,late,site,"collect"),"late human sees shared completion with own claim")
		var next=Sim.new(seed+7919,"cave",13);var other=next.add_player(1,"다음 층")
		check(next.exploration_challenges.is_empty() and not use_site(next,other,site,"collect"),"new floor resets encounter and rejects stale generation")
	party_scaling()
	check(variants.size()==2,"different expeditions offer distinct encounter compositions")
	print("EXPLORATION_CHALLENGE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
