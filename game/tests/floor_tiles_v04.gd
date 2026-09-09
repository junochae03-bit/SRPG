extends SceneTree
const Tiles=preload("res://scripts/floor_tile_art_v04.gd")
const Dungeon=preload("res://scripts/dungeon.gd")
const Abyss=preload("res://scripts/abyss_catalog.gd")
var checks=0
var failures=[]
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func _initialize():run.call_deferred()
func run():
	var c=Tiles.catalog()
	check(FileAccess.get_sha256(c.atlas)==c.sha256,"runtime PNG is unchanged original")
	check(Tiles.texture().get_size()==Vector2(1536,1024),"full resolution six-material atlas")
	check(c.materials.size()==6 and c.mappings.size()==12,"six source materials, ten biomes and town/tutorial")
	var selected={}
	var mat=ShaderMaterial.new();mat.shader=load("res://shaders/forest_ground.gdshader")
	for f in range(1,101):
		var map=Dungeon.new(20260909+f,Abyss.config(f).terrain,f)
		var before=JSON.stringify(map.floor_cells);var spawn=map.spawn;var exit=map.exit_position
		var profile=Tiles.apply(mat,map.zone,f)
		check(profile.id==c.chapters[(f-1)/10],"correct decade material B%d"%f)
		check(mat.get_shader_parameter("material_atlas")==Tiles.texture(),"real shader atlas B%d"%f)
		check(mat.get_shader_parameter("ground_panel")==Tiles.panel(profile.ground),"actual ground panel B%d"%f)
		check(mat.get_shader_parameter("path_panel")==Tiles.panel(profile.path),"actual path panel B%d"%f)
		check(before==JSON.stringify(map.floor_cells) and spawn==map.spawn and exit==map.exit_position,"material selection never mutates collision B%d"%f)
		selected[profile.ground]=true;selected[profile.path]=true
	check(selected.size()==6,"all imported materials have runtime consumers")
	check(Tiles.profile("town",0).id=="town" and Tiles.profile("forest",0).id=="tutorial","town and tutorial profiles")
	for id in c.materials:
		var rect=c.materials[id].sample_rect
		var inset=Rect2(rect[0],rect[1],rect[2],rect[3]).grow(.01)
		for x in range(-23,43):
			for y in [-16.1,-10.0,-.001,0.,4.999,5.,5.001,10.,40.5]:
				var world=Vector2(x*.53,y);var uv=Tiles.sample_uv(world,id)
				check(inset.has_point(uv*Vector2(1536,1024)),"panel bleed prevented %s %s"%[id,world])
				check(uv.distance_to(Tiles.sample_uv(world+Vector2(10,10),id))<.00001,"exact world repeat %s"%id)
		for seam in [-10.,-5.,0.,5.,10.,15.]:
			for y in [1.,2.4,5.,-5.]:
				var a=Tiles.sample_uv(Vector2(seam-.0001,y),id)
				var b=Tiles.sample_uv(Vector2(seam+.0001,y),id)
				check(a.distance_to(b)<.00001,"mirror border stays continuous %s"%id)
	print("FLOOR_TILES_V04 checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
