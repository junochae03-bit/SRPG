extends SceneTree
const Env=preload("res://scripts/expedition_environment.gd")
const Sim=preload("res://scripts/simulation.gd")
const Vision=preload("res://scripts/dungeon_vision.gd")
const Rooms=preload("res://scripts/exploration_rooms.gd")
const Inv=preload("res://scripts/inventory_model.gd")
const Brief=preload("res://scripts/expedition_brief.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func run():
 var variants={};var p={"level":100,"highest_floor":100,"tutorial_done":true}
 for depth in range(1,101):
  for seed_value in range(1,13):
   var condition=Env.select(seed_value,depth)
   check(condition==Env.select(seed_value,depth),"reproducible public condition")
   check(condition.sight>=6 and condition.sight<=8 and condition.noise_bonus<=3,"bounded exploration pressure")
   if depth<=10 or depth%10==0:check(condition.id=="still" and condition.gather_bonus==0,"first chapter and raids stay stable")
   else:variants[condition.id]=seed_value
   var info=Brief.floor_info(p,depth,seed_value)
   check(info.environment==condition and not info.environment.has("seed") and not info.has("hidden_regions"),"preview exposes only public condition")
 check(variants.size()==3,"seeds provide all three conditions")
 # Find each real generated condition and use authoritative collection, not a display-only modifier.
 var seeds={}
 for value in range(1,100):seeds[Env.select(value,12).id]=value
 for id in seeds:
  var sim=Sim.new(seeds[id],"cave",12);var player=sim.add_player(1,"탐사자");var other=sim.add_player(2,"동료")
  var env=sim.map.environment;var site=sim.map.exploration_sites.filter(func(s):return s.kind=="gather")[0]
  check(sim.enemies.size()==23,"environment does not inflate enemy count")
  var health=sim.enemies[1].max_hp
  preload("res://scripts/party_rules.gd").rescale(sim)
  check(sim.enemies[1].max_hp==roundi(health*preload("res://scripts/party_rules.gd").health_factor(2)),"party endurance remains separate")
  for enemy in sim.enemies.values():enemy.hp=0
  player.pos=site.pos;other.pos=site.pos
  var amount=4+int(env.gather_bonus)
  check(Rooms.snapshot(sim,1).filter(func(s):return s.id==site.id)[0].gather_amount==amount,"displayed collection equals condition")
  player.materials.ore=Inv.MAX_MATERIALS-amount+1
  check(not sim.action(1,"explore",site.generation+":"+site.id+":gather") and not sim.exploration_claims.has(1),"overflow keeps unclaimed reward")
  player.materials.ore=0
  check(sim.action(1,"explore",site.generation+":"+site.id+":gather") and player.materials.ore==amount,"real condition collection")
  check(not sim.action(1,"explore",site.generation+":"+site.id+":gather") and player.materials.ore==amount,"duplicate cannot multiply condition reward")
  check(sim.action(2,"explore",site.generation+":"+site.id+":gather") and other.materials.ore==amount,"same shared condition with personal claims")
  sim.map.floor_cells.clear()
  for x in range(-13,14):
   for y in range(-13,14):sim.map.floor_cells[Vector2i(x,y)]=true
  player.pos=Vector2.ZERO;other.hp=0
  var vision=Vision.new();vision.update(sim.map,sim.players,0.)
  check(vision.sees(Vector2(env.sight,0)) and not vision.sees(Vector2(env.sight+1,0)),"condition changes actual sight boundary")
  sim.enemies.clear();var listener=sim.spawn_enemy("rat",Vector2(8,0),12)
  sim.awareness.emit(1,player.pos,6)
  check((listener.get("awareness_state","")=="search")== (id=="echo"),"echo extends real walkable-cell sound propagation")
  player.hp=0;sim.clock=2.;check(sim.awareness.emit(1,player.pos,6)==0,"condition does not bypass dead-owner guard")
 print("EXPEDITION_ENVIRONMENT checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
