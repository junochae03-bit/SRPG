extends RefCounted
## Builds use the same prerequisite, exclusion and shared-point rules as manual investment.
const Rules=preload("res://scripts/skill_build.gd")
const ACTIONS=["skill_q","skill_f","skill_v","skill_c","skill_z","skill_x"]

static func fingerprint(p:Dictionary)->String:
	return JSON.stringify([p.class_id,p.level,p.skill_ranks,p.get("constellation_allocations",{}),p.skill_loadout]).sha256_text()

static func choices(p:Dictionary)->Array:
	return Rules.nodes_for(p.class_id).filter(func(n):return n.get("type","")=="keystone")

static func preview(p:Dictionary,target:String)->Dictionary:
	var key=Rules.definition(target)
	var result={"ok":false,"reason":"현재 직업의 빌드를 선택하세요.","player":{},"target":target,"spent":0,"loadout":[],"signature":fingerprint(p)}
	if key.is_empty() or key.class_id!=p.class_id or key.type!="keystone":return result
	var candidate=p.duplicate(true)
	candidate.skill_ranks={};candidate.constellation_allocations={};candidate.skill_loadout={}
	var route=Rules.path_plan(candidate,target)
	if not route.ok:result.reason=route.reason;return result
	candidate=route.player
	var nodes=Rules.nodes_for(p.class_id)
	var actives=nodes.filter(func(n):return n.get("effect","")=="active")
	# Keep the keystone's anchored skill first; fill with the class's own actions.
	var cluster=int(key.cluster)
	var order=[]
	if not actives.is_empty():order.append(actives[cluster%actives.size()])
	for node in actives:
		if int(candidate.skill_ranks.get(node.id,0))>0 and not order.has(node):order.append(node)
	for node in actives:
		if not order.has(node):order.append(node)
	for node in order:
		if candidate.skill_loadout.size()>=6:break
		var plan=Rules.path_plan(candidate,node.id)
		if not plan.ok:continue
		candidate=plan.player
		candidate.skill_loadout[ACTIONS[candidate.skill_loadout.size()]]=node.id
	# Upgrade the actual equipped actions before spending on their connected modules.
	var priorities=[]
	for id in candidate.skill_loadout.values():priorities.append(Rules.definition(id))
	for node in nodes:
		if node.get("node_kind","")=="active_module" and candidate.skill_loadout.values().has(node.get("target_active_id","")):priorities.append(node)
	for node in nodes:
		if node.get("type","")!="keystone" and int(node.get("cluster",-1))==cluster and not priorities.has(node):priorities.append(node)
	for node in priorities:
		var plan=Rules.path_plan(candidate,node.id)
		if plan.ok:candidate=plan.player
		while Rules.node_state(candidate,node.id).can_invest:
			var upgraded=Rules.preview(candidate,node.id,Rules.rank(candidate,node)+1)
			if not upgraded.ok:break
			candidate=upgraded.player
	var valid=Rules.validate_build(candidate)
	result.ok=valid.ok and not candidate.skill_loadout.is_empty()
	result.reason=valid.reason if not valid.ok else ""
	result.player=candidate;result.spent=Rules.spent_points(candidate)
	result.loadout=candidate.skill_loadout.values()
	return result

static func apply(sim,p:Dictionary,argument:String)->bool:
	if sim.map.zone!="town":sim.notice(p.id,"빌드 변경은 마을에서 가능합니다.");return false
	var request=JSON.parse_string(argument)
	if not request is Dictionary or request.get("signature","")!=fingerprint(p):return false
	var quote=preview(p,str(request.get("target","")))
	if not quote.ok:sim.notice(p.id,quote.reason);return false
	sim.clear_build_runtime(p)
	for field in ["skill_ranks","constellation_allocations","skill_loadout"]:p[field]=quote.player[field]
	sim.gear_changed(p);sim.notice(p.id,"빌드 적용 · "+str(Rules.definition(quote.target).name))
	return true
