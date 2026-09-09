extends SceneTree
const Content=preload("res://scripts/content.gd")
const Quote=preload("res://scripts/service_quote.gd")
const World=preload("res://scripts/world_catalog.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
	var game=load("res://main.tscn").instantiate();game.options.mute=true;root.add_child(game);await process_frame
	var session=game.session;session.save_directory=ProjectSettings.globalize_path("res://../runtime/ui-v01/"+str(Time.get_ticks_usec()));game.join_game();session.sim.players[1].tutorial_done=true;session.travel("town");session.set_physics_process(false)
	var p=session.sim.players[1];p.level=100;p.gold=5000;p.materials={"seed":100,"ore":100,"essence":100};session.act("claim_starters");session.refresh()
	game.toggle_skills();var tree=game.skill_tree
	for cls in ["warrior","ranger","mage"]:
		session.act("class",cls);tree.filter_index=0;tree.choice="";tree.refresh(true)
		check(tree.nodes.size()==95 and tree.graph.size.x>=900 and tree.graph.size.y>=460,"large pannable original and specialization web "+cls)
		for node in Content.SKILLS[cls]:check(tree.nodes[node.id].size.x>=26 and tree.nodes[node.id].icon!=null,"illustrated zoomable node "+node.id)
		var active=Content.SKILLS[cls].filter(func(n):return n.effect=="active")[0]
		tree.search.text=active.name;tree.apply_search()
		check(tree.choice==active.id,"search selects and reveals matching skill "+cls)
		tree.search.text="";tree.filter_index=1;tree.refresh(true)
		check(Content.SKILLS[cls].filter(func(n):return tree.matches(n,p)).size()==12,"active filter finds twelve skills "+cls)
		p.skill_ranks[active.parents[0]]=1;session.refresh();tree.choice=active.id;tree.refresh(true)
		tree.invest.pressed.emit();check(p.skill_ranks[active.id]==1,"real UI learns selected skill "+cls)
		var current=tree.comparison_rows.duplicate(true);tree.invest.pressed.emit()
		check(p.skill_ranks[active.id]==2 and tree.comparison_rows!=current,"investment updates current and next effect values "+cls)
		tree.bind_buttons[1].pressed.emit();check(Content.active_node(p,"skill_f").id==active.id,"explicit hotbar assignment "+cls)
	game.toggle_skills();game.toggle_bag();game.bag.select_item("training-axe")
	check(game.bag.detail_body.text.contains("→") and game.bag.portrait.size.y>=200,"equipment comparison and large character display")
	check(game.bag.grid.CELL==64 and game.bag.size.x==1560,"Full HD illustrated inventory with readable item cells")
	game.toggle_bag()
	p.inventory.filter(func(i):return i.id=="training-sword")[0].rarity=1
	var panel=game.town_panel
	for facility in ["shop","smith","alchemy","guild","inn"]:
		p.pos=World.resident_pos(facility);session.refresh();session.act("interact")
		check(game.npc_dialogue.visible,"resident greeting before service "+facility);game.npc_dialogue.service_button.pressed.emit()
		check(panel.visible and panel.counter.texture!=null and panel.greeting.text.contains(World.RESIDENTS[facility].name),"painted workspace and NPC "+facility)
		check(panel.confirm_button!=null and panel.preview.has("result"),"explicit review before transaction "+facility)
		var operations=[]
		match facility:
			"shop":operations=[["buy",{"index":1}],["potion",{}]]
			"smith":operations=[["upgrade",{"item":"training-sword"}],["reforge",{"item":"training-sword"}]]
			"alchemy":operations=[["potion",{}],["essence",{}]]
			"guild":operations=[["accept",{"zone":"cave"}]]
			"inn":p.hp=15;p.stamina=3;operations=[["rest",{}]]
		for op in operations:
			var old=p.duplicate(true);var q=Quote.quote(p,facility,op[0],op[1]);var gold=p.gold
			check(q.reason.is_empty() and p==old,"transaction preview is pure and eligible "+facility+op[0])
			check(panel.request(op[0],op[1]),"real transaction succeeds "+facility+op[0])
			check(gold-p.gold==q.cost,"quoted gold matches actual cost "+facility+op[0])
			for key in q.materials:check(old.materials[key]-p.materials[key]==q.materials[key],"quoted material matches actual consumption "+key)
			check(panel.last_receipt.contains("완료"),"successful transaction gives receipt "+facility+op[0])
		panel.close()
	p.pos=World.resident_pos("shop");session.refresh();session.act("interact");game.npc_dialogue.service_button.pressed.emit();panel.shop_mode="sell";panel.choose("sell",{"item":"training-axe"})
	var q=panel.preview;var before=p.gold;panel.confirm_button.pressed.emit()
	check(p.gold-before==-q.cost and not p.inventory.any(func(i):return i.id=="training-axe"),"sale review and confirmation transfer exact item and money")
	check(panel.selected_item=="" and panel.confirm_button.disabled,"sale requires a fresh selection for another item")
	p.gold=0;panel.shop_mode="buy";panel.choose("buy",{"index":0});var saved=session.sim.persistent(1).duplicate(true)
	check(panel.confirm_button.disabled and panel.preview.reason.contains("부족"),"unaffordable order explains shortage")
	check(not panel.request("buy",{"index":0}) and session.sim.persistent(1)==saved,"failed transaction does not consume anything")
	panel.close()
	p.highest_floor=21;p.cleared_floor=20
	for floor_number in [1,11,21]:
		p.pos=World.FACILITIES.portal.pos;session.refresh();session.act("interact")
		check(panel.visible and panel.products.size()==10,"ten illustrated floor choices")
		panel.selected_floor=floor_number;panel.refresh();panel.confirm_button.pressed.emit()
		check(session.sim.map.floor_number==floor_number and not panel.visible,"portal confirmation enters selected unlocked floor")
		session.travel("town");p=session.sim.players[1]

	game.stop_audio();await create_timer(.5).timeout;session.disconnect_game();game.queue_free();await process_frame
	print("UI_V01_TESTS checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
