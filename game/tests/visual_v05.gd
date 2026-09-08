extends SceneTree
const Simulation=preload("res://scripts/simulation.gd")
const Content=preload("res://scripts/content.gd")
const Art=preload("res://scripts/combat_sprite_art.gd")
class Gallery extends Node2D:
	var font:Font
	func _draw():
		draw_rect(Rect2(0,0,1440,900),Color("c1d3bd"))
		for row in range(3):
			var key=Art.AVATARS.keys()[row];var role=Art.AVATARS[key]
			for index in range(16):
				var p={"motion":"cleave","motion_time":.4,"motion_duration":.4}
				if index<4:p={"dir":Vector2.RIGHT}
				elif index<8:p.motion_time=(1-(index-4+.1)/4)*.4
				elif index<12:p.motion="slam";p.motion_time=(1-(index-8+.1)/4)*.4
				elif index<14:p={"dodge_time":.25 if index==12 else .1}
				elif index==14:p={"hurt_time":.1}
				else:p={}
				var frame=Art.frame(key,p,index/8.0 if index<4 else 4.9 if index==15 else 0)
				var scale=94.0/frame.height;var at=Vector2(90+(index%8)*178,130+row*292+int(index/8)*141)
				draw_texture_rect(frame.texture,Rect2(at-frame.foot*scale,frame.texture.get_size()*scale),false)
				draw_string(font,at+Vector2(-34,21),role+" "+str(index),HORIZONTAL_ALIGNMENT_LEFT,150,13,Color("29494c"))
func _initialize():run.call_deferred()
class Collection extends Node2D:
	var font:Font
	var costumes=false
	func _draw():
		draw_rect(Rect2(0,0,1440,900),Color("c1d3bd"))
		var world=preload("res://scripts/world_catalog.gd")
		var keys=Content.GAT_COSTUMES.keys() if costumes else world.ENEMIES.keys().filter(func(k):return k not in ["warden","golem","sentinel"])
		for i in range(keys.size()):
			var key=keys[i];var at=Vector2(116+i%6*236,178+int(i/6)*209);var texture:Texture2D;var foot:Vector2;var scale:float;var title:String
			if costumes:
				var frame=preload("res://scripts/gat_art.gd").frame({"costume":key},0);texture=frame.texture;foot=frame.foot;scale=112.0/frame.height;title=Content.GAT_COSTUMES[key]
			else:
				var data=world.ENEMIES[key];var frame=preload("res://scripts/world_art.gd").frame(data.art_sheet,data.art);texture=frame.texture;foot=frame.foot;scale=float(data.height)/frame.height;title=data.name
				draw_string(font,at+Vector2(-78,42),"ELITE" if data.get("elite",false) else "",HORIZONTAL_ALIGNMENT_LEFT,180,13,Color("956834"))
			draw_texture_rect(texture,Rect2(at-foot*scale,texture.get_size()*scale),false)
			draw_string(font,at+Vector2(-90,24),title,HORIZONTAL_ALIGNMENT_LEFT,210,16,Color("29494c"))
func capture(name):
	await create_timer(.65).timeout;await process_frame;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/"+name+".png"))==OK);print("CAPTURE ",name)
func run():
	var game=load("res://main.tscn").instantiate();game.options.mute=true;root.add_child(game);await process_frame
	var session=game.session;session.save_directory=ProjectSettings.globalize_path("res://../runtime/visual-v05/"+str(Time.get_ticks_usec()));game.join_game();session.set_physics_process(false);game.set_physics_process(false)
	for zone in ["forest","cave","ruins"]:
		session.sim=Simulation.new(20260909,zone);var p=session.sim.add_player(1,"스프라이트 검사")
		var boss=session.sim.enemies.values().back();boss.hp=int(boss.max_hp*.65);boss.windup=.5
		p.pos=boss.pos+Vector2(1.7,1.7);session.refresh();game.on_entered();game.camera_pos=preload("res://scripts/dungeon.gd").iso(p.pos)
		await capture("boss-v05-"+zone)
	for zone in ["forest","cave","ruins"]:
		session.sim=Simulation.new(20260909,zone);var hero=session.sim.add_player(1,"배치 검사")
		var elite=session.sim.enemies.values().filter(func(e):return e.elite)[0];hero.pos=elite.pos+Vector2(1.6,.7)
		elite.windup=.8;session.sim.monster_attacks.begin(elite,hero.pos)
		session.refresh();game.on_entered();game.camera_pos=preload("res://scripts/dungeon.gd").iso(hero.pos);await capture("elite-v05-"+zone)
	var p=session.sim.players[1];p.level=60;p.pos=session.sim.map.spawn;session.refresh();game.toggle_skills();await capture("skill-web-v05")
	game.skill_tree.mode="stats";game.skill_tree.refresh(true);await capture("stats-v05");game.toggle_skills()
	session.sim=Simulation.new(20260909,"town");session.sim.add_player(1,"스프라이트 검사");session.refresh();game.on_entered();game.camera_pos=preload("res://scripts/dungeon.gd").iso(session.sim.map.spawn);await capture("town-v05")
	for facility in ["smith","shop","alchemy","guild","inn","portal"]:
		p=session.sim.players[1];p.pos=preload("res://scripts/world_catalog.gd").FACILITIES[facility].pos;session.refresh();session.act("interact");await capture("facility-v05-"+facility);game.town_panel.close()
	var layer=CanvasLayer.new();layer.layer=20;root.add_child(layer);var gallery=Gallery.new();gallery.font=game.fonts;gallery.material=preload("res://scripts/gat_art.gd").material();layer.add_child(gallery);await capture("combat-poses-v05")
	gallery.hide();var collection=Collection.new();collection.font=game.fonts;collection.material=preload("res://scripts/gat_art.gd").material();layer.add_child(collection);await capture("monsters-v05")
	collection.costumes=true;collection.queue_redraw();await capture("costumes-v05")
	game.stop_audio();await create_timer(.5).timeout;session.disconnect_game();game.queue_free();layer.queue_free();await process_frame;print("VISUAL_V05_PASS");quit()
