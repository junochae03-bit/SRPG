extends SceneTree
const DB=preload("res://scripts/game_database.gd")
const Rules=preload("res://scripts/skill_build.gd")
const C=preload("res://scripts/content.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	var db=DB.snapshot()
	check(db.metadata.schema_version==2,"database schema2")
	check(db.skills.size()==610 and db.constellations.size()==900 and db.build_nodes.size()==1510,"original/constellation counts separately represented")
	check(db.exclusive_groups.size()==40 and db.effect_definitions.size()==33,"exclusive groups and supported effects")
	check(db.constellation_exclusions.size()==4,"focus and chain explicitly incompatible across ranger jobs")
	for class_id in C.CLASSES:
		check(DB.query("skills",{"class_id":class_id,"effect":"constellation"},0,100).total==45,"specialization filter "+class_id)
		check(DB.query("skills",{"class_id":class_id},0,100).total==Rules.nodes_for(class_id).size(),"codex matches all graph nodes "+class_id)
	for n in db.constellations:
		var actual=Rules.definition(n.id)
		check(actual.effects==n.effects and actual.cost==n.cost and actual.parents==n.parents,"live allocation data "+n.id)
		check(DB.asset_texture(n)!=null and not n.ranks[0].metrics.is_empty(),"real readable art/detail "+n.id)
		check(DB.detail("skills",n.id).id==n.id,"linked detail "+n.id)
		for parent in n.parents:check(not DB.detail("skills",parent).is_empty(),"original or specialization prerequisite link "+n.id)
	for e in db.constellation_edges:
		check(Rules.definition(e.node_id).class_id==Rules.definition(e.parent_id).class_id,"sameclass edge")
	var focus=DB.detail("skills","fighter:star:1:key")
	check("25%" in focus.tradeoff and "한 대상" in focus.effects_text,"tradeoff and behavior part of DB contract")
	print("DATABASE_V04_TESTS checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
