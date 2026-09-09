extends SceneTree
const Content=preload("res://scripts/content.gd")
const Rules=preload("res://scripts/skill_build.gd")
const Catalog=preload("res://scripts/constellation_catalog.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func player(class_id:String,level:int=100)->Dictionary:return {"class_id":class_id,"level":level,"skill_ranks":{},"constellation_allocations":{},"skill_loadout":{}}
func run():
	Content.initialize_jobs();Rules.initialize(Content.SKILLS,Content.CLASSES)
	var total=0;var ids={};var originals=0
	for class_id in Content.CLASSES:
		var nodes=Rules.nodes_for(class_id);var added=Rules.constellation_nodes(class_id);var p=player(class_id)
		originals+=Content.SKILLS[class_id].size();total+=added.size()
		check(added.size()==45 and nodes.size()==Content.SKILLS[class_id].size()+45,"preserved original plus45 "+class_id)
		check(nodes.size()>=50,"every class at least50 "+class_id)
		check(added.filter(func(n):return n.type=="minor").size()==30 and added.filter(func(n):return n.type=="notable").size()==10 and added.filter(func(n):return n.type=="keystone").size()==5,"cluster role counts "+class_id)
		check(Rules.effects(p).is_empty() and Rules.available_points(p)==99,"legacy no allocation unchanged "+class_id)
		for n in nodes:
			check(not ids.has(n.id),"uniqueID "+n.id);ids[n.id]=true
			if n.type=="original":
				var actual=Content.SKILLS[class_id].filter(func(a):return a.id==n.id)[0]
				check(n.max_rank==Content.max_rank(actual) and n.parents==actual.parents and n.cost==1,"old rules preserved "+n.id)
			else:
				check(n.cost==({"minor":1,"notable":3,"keystone":6}[n.type]) and not n.effects.is_empty() and not n.effects_text.is_empty(),"meaningful effect/cost "+n.id)
				for effect in n.effects:check(Catalog.MINORS.has(effect) or Catalog.NOTABLES.has(effect) or Catalog.KEYS.has(effect),"only contracted effects "+n.id)
		for cluster in range(5):
			var key=Catalog.node_id(class_id,cluster,"key");var before=p.duplicate(true);var plan=Rules.path_plan(p,key)
			check(plan.ok and plan.cost>6 and plan.cost<=99,"reachable costed key "+key+" "+plan.reason)
			check(p==before,"planning never mutates player "+key)
			if not plan.ok:continue
			var allocated=p.duplicate(true)
			for step in plan.steps:
				var state=Rules.node_state(allocated,step.id);check(state.can_invest,"legal planned step "+step.id+" "+state.reason)
				var change=Rules.preview(allocated,step.id,step.rank);check(change.ok,"atomic preview step "+step.id+" "+change.reason);allocated=change.player
			check(allocated==plan.player and Rules.validate_build(allocated).ok,"valid complete path "+key)
			var key_effect=Rules.definition(key).effects.keys()[0]
			check(Rules.effects(allocated).get(key_effect,0)==1. and Rules.rank(allocated,Rules.definition(key))==1,"selected key effect "+key)
			var n0=Catalog.node_id(class_id,cluster,"n0");var removed=Rules.preview(allocated,n0,0)
			check(removed.ok and removed.removed.has(key) and not removed.player.constellation_allocations.has(key),"notable removal cascades key "+key)
			check(removed.refund==Rules.spent_points(allocated)-Rules.spent_points(removed.player) and removed.refund>=9,"refund exact cost "+key)
		var echo=Rules.path_plan(p,Catalog.node_id(class_id,0,"key"))
		var focus=Rules.path_plan(echo.player,Catalog.node_id(class_id,1,"key"))
		check(not focus.ok and not focus.conflicts.is_empty(),"exclusive delivery pair "+class_id)
		var momentum=Rules.path_plan(echo.player,Catalog.node_id(class_id,2,"key"))
		check(momentum.ok,"two nonexclusive keys "+class_id)
		if momentum.ok:check(not Rules.path_plan(momentum.player,Catalog.node_id(class_id,3,"key")).ok,"third key rejected "+class_id)
		var family_a=Rules.path_plan(p,Catalog.node_id(class_id,3,"key"))
		check(not Rules.path_plan(family_a.player,Catalog.node_id(class_id,4,"key")).ok,"exclusive family pair "+class_id)
		if Content.base_class(class_id)=="ranger":
			check(not Rules.path_plan(family_a.player,Catalog.node_id(class_id,1,"key")).ok,"chain excludes focus")
			var single=Rules.path_plan(p,Catalog.node_id(class_id,1,"key"))
			check(not Rules.path_plan(single.player,Catalog.node_id(class_id,3,"key")).ok,"focus excludes chain")
		var malformed=p.duplicate(true);malformed.constellation_allocations={"missing":1};check(not Rules.validate_build(malformed).ok,"unknown allocation rejected")
		malformed=p.duplicate(true);malformed.constellation_allocations[Catalog.node_id(class_id,0,"m0")]=1.5;check(not Rules.validate_build(malformed).ok,"fraction rank rejected")
		malformed=p.duplicate(true);malformed.constellation_allocations[Catalog.node_id(class_id,0,"key")]=1;check(not Rules.validate_build(malformed).ok,"orphan key rejected")
		var low=player(class_id,1);check(not Rules.path_plan(low,Catalog.node_id(class_id,0,"key")).ok,"level gate planner")
	check(total==900 and originals==610,"900specialization plus610original")
	var compatible=player("swordsman",60);compatible.skill_ranks={"swordsman_a03":3}
	check(Rules.validate_build(compatible).ok and Rules.available_points(compatible)==56,"old sparse ordinary ranks remain valid")
	var actual=Content.SKILLS.swordsman.filter(func(n):return n.id=="swordsman_a01")[0]
	compatible.skill_ranks={"swordsman_a01":3,"swordsman_a01_upgrade":1}
	var decrease=Rules.preview(compatible,actual.id,2)
	check(decrease.ok and decrease.refund==2 and not decrease.player.skill_ranks.has("swordsman_a01_upgrade"),"lowering rank refunds nowinvalid old upgrade")
	compatible.skill_ranks.swordsman_a01=2;check(not Rules.validate_build(compatible).ok,"old upgrade parent still required")
	var p=player("warrior");p.constellation_allocations["mage:star:0:m0"]=1;check(not Rules.validate_build(p).ok,"crossclass allocation rejected")
	p=player("warrior");p.skill_ranks={"blade":1};p.constellation_allocations=[];check(not Rules.validate_build(p).ok,"wrong allocation container rejects before semantic evaluation")
	p=player("warrior");p.constellation_allocations={"warrior:star:0:m0":"bad"};check(not Rules.validate_build(p).ok,"nonnumeric rank rejects without unsafe conversion")
	p=player("warrior");p.skill_ranks={"blade":3,"heavy_training":3};p.level=5;check(not Rules.validate_build(p).ok,"shared budget overrun rejected")
	print("SKILL_BUILD_V04_TESTS checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
