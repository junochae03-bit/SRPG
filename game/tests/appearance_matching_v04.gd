extends SceneTree
const Content=preload("res://scripts/content.gd")
const Rules=preload("res://scripts/appearance_rules.gd")
const Costumes=preload("res://scripts/costume_art_v04.gd")
const Creation=preload("res://scripts/character_creation.gd")
const Sim=preload("res://scripts/simulation.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func run():
	Content.initialize_jobs();Rules.initialize()
	check(Content.CLASSES.warrior.name=="검사" and Content.CLASSES.ranger.name=="궁수" and Content.CLASSES.mage.name=="마법사","plain first job names")
	var sim=Sim.new(20260909,"town");var p=sim.add_player(1,"직업 외형 검사")
	p.level=100
	for cls in Content.CLASSES:
		p.class_id=cls;Content.normalize_appearance(p);sim.recalculate(p)
		var avatars=Content.avatar_options(cls);var costumes=Content.costume_options(cls)
		# This test isolates class eligibility. Purchase/ownership is exercised by wardrobe_v05.
		p.owned_appearances=[]
		for avatar in Content.AVATARS:p.owned_appearances.append("avatar:"+avatar)
		for costume in Content.COSTUMES:
			if costume!="none":p.owned_appearances.append("costume:"+costume)
		check(avatars[0]=="auto" and costumes[0]=="none","every job retains its own default "+cls)
		for avatar in Content.AVATARS:
			var before=sim.persistent(1).duplicate(true)
			var success=sim.action(1,"avatar",avatar)
			check(success==(avatar in avatars),"model enforces avatar compatibility "+cls+":"+avatar)
			if not success:check(before==sim.persistent(1),"rejected avatar preserves the save")
		for costume in Content.COSTUMES:
			var before=sim.persistent(1).duplicate(true)
			var success=sim.action(1,"costume",costume)
			check(success==(costume in costumes),"model enforces costume compatibility "+cls+":"+costume)
			if not success:check(before==sim.persistent(1),"rejected costume preserves the save")
	var player_count=0;var npc_count=0
	for id in Costumes.ids():
		check(Rules.custom.has(id),"reviewed weapon and motion match "+id)
		var rule=Rules.custom[id]
		if rule.runtime_role=="town_npc":
			npc_count+=1
			check(preload("res://scripts/town_visitors.gd").RESIDENTS.any(func(row):return row.costume==id),"unsupported gun sprite is used by a town visitor")
		else:
			player_count+=1;check(not rule.allowed_base_classes.is_empty(),"player costume has an explicit job match")
		for cls in Creation.CLASSES:
			var sheet={"name":"외형", "class_id":cls,"avatar":"auto","costume":id,"stats":Creation.suggested(cls)}
			check(not Creation.reason(sheet).is_empty(),"creation keeps default; matching costume is purchased later "+cls+":"+id)
	check(player_count==30 and npc_count==3,"all 33 sprites have a supported runtime role")
	var save={"schema_version":7,"class_id":"warrior","avatar":"gat_role_aoe_1","costume":"witch","gold":777,"level":30,"materials":{"ore":8}}
	var restored=sim.add_player(2,"복원",save)
	check(restored.avatar=="auto" and restored.costume=="none","old incompatible appearance uses the job default")
	check(restored.gold==777 and restored.level==30 and restored.materials.ore==8,"appearance migration preserves property")
	print("APPEARANCE_MATCHING_V04_TESTS checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
