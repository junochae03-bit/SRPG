extends SceneTree
const World=preload("res://scripts/world_catalog.gd")
const Geometry=preload("res://scripts/enemy_hit_geometry.gd")
const Art=preload("res://scripts/world_art.gd")
const Hero=preload("res://scripts/character_presentation.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():
	var original=World.ENEMIES.duplicate(true)
	for kind in ["mole","orc_axeman","clockwork"]:
		check(World.display_height(kind)>=Hero.BODY_PIXELS*1.5,"bulky normal body exceeds hero "+kind)
		check(World.display_height(kind)<World.display_height("orc_champion"),"elite remains larger than common heavy")
	for kind in ["orc_champion","centurion"]:
		check(World.display_height(kind)>=Hero.BODY_PIXELS*2.,"heavy elite is visibly imposing")
		check(World.display_height(kind)<World.display_height("golem"),"raid/boss silhouette remains dominant")
	check(World.display_height("skeleton",62)<World.display_height("centurion",62),"same foundry ogre art keeps normal elite size hierarchy")
	for kind in ["shade","fairy","cave_bat","fox","spider"]:
		var c=World.ENEMIES[kind];var previous=maxf(92.,float(c.get("height",86))*1.3)
		check(is_equal_approx(World.display_height(kind),previous),"small agile species unchanged "+kind)
	for depth in range(1,101):
		for kind in World.ENEMIES:
			var e={"kind":kind,"floor":depth,"pos":Vector2.ZERO};var height=World.display_height(kind,depth);var radius=Geometry.radius(e)
			check(height>0. and height<=335.,"finite bounded display height")
			check(radius>=1. and radius<=2.15,"receiving radius bounded by boss")
			check(Geometry.circle(e,Vector2(radius+2.-.01,0),2.) and not Geometry.circle(e,Vector2(radius+2.+.01,0),2.),"expanded hit edge is actual hit edge")
			var variant=Art.variant(kind,depth)
			if variant.is_empty():continue
			var source=World.ENEMIES[kind]
			var previous=335. if source.ai=="boss" else float(source.get("height",160))*1.12 if source.get("elite",false) else maxf(92.,float(source.get("height",86))*1.3)
			if not World.HEAVY_SPECIES_HEIGHTS.has(variant.species):check(is_equal_approx(height,previous),"themed agile art never inherits heavy base-kind enlargement")
	check(World.ENEMIES==original,"size lookups do not modify HP damage speed count or attack range")
	print("MONSTER_SCALE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
