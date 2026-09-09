extends SceneTree
const C=preload("res://scripts/content.gd")
const A=preload("res://scripts/abyss_catalog.gd")
const E=preload("res://scripts/equipment_catalog.gd")
const I=preload("res://scripts/inventory_model.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func capture(name:String):
	await create_timer(.15).timeout;await process_frame;await RenderingServer.frame_post_draw
	var path=ProjectSettings.globalize_path("res://../artifacts/v02-"+name+".png");check(root.get_texture().get_image().save_png(path)==OK,"capture "+name)
func run():
	var game=load("res://main.tscn").instantiate();game.options.mute=true;root.add_child(game);await process_frame
	var local=game.session;local.save_directory=ProjectSettings.globalize_path("res://../runtime/ui-v02/"+str(Time.get_ticks_usec()));game.join_game();local.set_physics_process(false);game.set_physics_process(false)
	var p=local.sim.players[1];p.tutorial_done=true;p.level=100;p.highest_floor=100;p.cleared_floor=99;local.travel("town");p=local.sim.players[1]
	p.class_id="breaker";p.stats={"strength":100,"endurance":77,"technique":60,"agility":60,"magic":0};local.sim.combat.jobs.reset(p)
	var actives=C.SKILLS.breaker.filter(func(n):return n.effect=="active")
	for i in range(6):p.skill_ranks[actives[i].id]=5;p.skill_loadout[C.ACTIONS[i]]=actives[i].id
	p.gold=24986;p.materials={"seed":25,"ore":50,"essence":5}
	for grade in range(5):
		var item=E.make("sword",9,grade,"grade-"+str(grade),"focus",p.class_id);item.upgrade=5;I.add_gear(p,item)
	I.equip(p,"grade-3")
	for slot in ["head","chest","hands","legs","feet","accessory"]:I.add_gear(p,E.make(slot,8,2,slot,"vigor",p.class_id))
	local.sim.recalculate(p);local.refresh();game.on_entered()
	for action in ["attack","heavy","dodge"]:check(not game.action_buttons.has(action),"no basic/heavy/dodge HUD "+action)
	for i in range(6):
		var b=game.action_buttons[C.ACTIONS[i]]
		check(b.position==Vector2(1028+i%3*124,618+int(i/3)*132) and b.size==Vector2(96,96),"large 3 by 2 alignment")
		check(b.position.x+b.size.x<1400 and b.position.y+b.size.y+20<875,"safe skill bounds")
	await capture("hud")
	game.toggle_bag();game.bag.select_item("grade-4");check(game.bag.item_grade.text.begins_with("레전드리"),"legendary visible name");check("개방" in game.bag.detail_body.text,"option state visible")
	var labels=game.bag.find_children("*","Label",true,false);var buttons=game.bag.find_children("*","Button",true,false)
	for removed in ["모든 물건은 한 칸","끌어서 이동하거나","일반 · 레어 · 유니크","장착품은 가방 칸","한 묶음으로 보관","소지품을 살피는 동안","I / ESC로 닫기"]:
		check(not labels.any(func(label):return removed in label.text),"removed redundant bag instruction: "+removed)
	check(not buttons.any(func(button):return "입문 장비" in button.text or "연습 무기" in button.text),"starter claim button removed from inventory")
	await capture("inventory");game.toggle_bag()
	game.toggle_skills();game.skill_tree.mode="stats";game.skill_tree.refresh(true);check(game.skill_tree.stat_buttons.size()==5,"five stats in UI");await capture("stats");game.skill_tree.mode="skills";game.skill_tree.choice=actives[4].id;game.skill_tree.refresh(true);await capture("skills");game.toggle_skills()
	game.town_panel.open("portal");await capture("portal");check(game.town_panel.products.size()==10,"ten floors visible per biome");game.town_panel.close()
	p.pos=preload("res://scripts/world_catalog.gd").FACILITIES.smith.pos;game.town_panel.open("smith");game.town_panel.choose("upgrade",{"item":"grade-2"});await capture("smith");game.town_panel.close()
	for floor_number in [1,11,21,31,41,51,61,71,81,91,100]:
		local.travel("town");check(local.enter_floor(floor_number),"enter visual floor "+str(floor_number));p=local.sim.players[1]
		var enemy=local.sim.enemies.values().filter(func(e):return e.get("guardian",false))[0] if floor_number==100 else local.sim.enemies[1]
		p.pos=enemy.pos-Vector2(1.8,0);p.aim=Vector2.RIGHT;local.refresh();game.camera_pos=preload("res://scripts/dungeon.gd").iso(p.pos)
		if floor_number==100:enemy.phase=2;enemy.pattern=2;local.sim.monster_attacks.begin(enemy,p.pos);enemy.windup=1.;local.refresh()
		await capture("floor-"+str(floor_number))
	game.stop_audio();local.disconnect_game();game.queue_free();await process_frame;print("UI_V02_TESTS checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
