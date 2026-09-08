extends SceneTree
const Content=preload("res://scripts/content.gd")
const World=preload("res://scripts/world_catalog.gd")
const Icons=preload("res://scripts/icon_art.gd")
const Gat=preload("res://scripts/gat_art.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
	var game=load("res://main.tscn").instantiate();game.options.mute=true;root.add_child(game);await process_frame
	var session=game.session;session.save_directory=ProjectSettings.globalize_path("res://../runtime/polish-v05/"+str(Time.get_ticks_usec()));game.join_game();session.set_physics_process(false)
	var p=session.sim.players[1]
	for cls in Content.CLASSES:
		p.class_id=cls;p.skill_ranks={};p.skill_loadout={};p.level=100;session.refresh();game.skill_tree.choice="";game.skill_tree.refresh(true)
		check(game.skill_tree.nodes.size()==50,"50 illustrated nodes "+cls)
		for node in Content.SKILLS[cls]:
			check(game.skill_tree.nodes[node.id].icon==Icons.skill(node) and Icons.skill(node).region.size.x>80,"skill has readable raster icon "+node.id)
			if node.effect=="active":
				p.skill_ranks[node.id]=1;check(session.act("bind_skill","skill_f:"+node.id),"active bind "+node.id)
				check(game.hud.circles.skill_f.picture==Icons.skill(node),"HUD follows assigned skill artwork "+node.id)
	p.class_id="warrior";p.skill_ranks={};p.skill_loadout={};p.avatar="gat_role_tank_2";p.level=1
	for key in Content.GAT_COSTUMES:
		check(session.act("costume",key),"new costume selectable "+key);game.bag.refresh(true)
		check(Gat.avatar(p)==key and game.bag.portrait.texture==Gat.texture(key,0) and game.hud.portrait==Gat.portrait(p),"field bag and HUD agree "+key)
		check(p.avatar=="gat_role_tank_2" and session.sim.damage_for(p)==18,"cosmetic preserves base and combat stats "+key)
		session.save_game();check(session.parse_save(session.save_path()).costume==key,"costume saved "+key)
	var last=p.costume;session.disconnect_game();session.start_game("복원",1);p=session.sim.players[1]
	check(p.costume==last and Gat.avatar(p)==last,"costume restored on restart")
	for key in World.RESIDENTS:
		p.pos=World.resident_pos(key);session.refresh()
		check(session.sim.map.walkable(p.pos) and World.nearest(p.pos)==key,"resident reachable and nearest "+key)
		check(session.act("interact") and game.town_panel.visible and session.paused,"E opens resident service "+key)
		check(game.town_panel.facility==key and game.town_panel.greeting.text.contains(World.RESIDENTS[key].name) and game.town_panel.resident_portrait.texture==Gat.texture(World.RESIDENTS[key].avatar,0),"named resident greeting and portrait "+key)
		game.town_panel.close();check(not session.paused,"closing returns to gameplay "+key)
	check(game.bold_font.resource_path.ends_with("dnf_bitbit_v2.ttf") and game.fonts.resource_path.ends_with("dnf_forged_blade_medium.ttf"),"requested fonts wired")
	game.stop_audio();await create_timer(.5).timeout;session.disconnect_game();game.queue_free();await process_frame
	print("POLISH_V05_TESTS checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
