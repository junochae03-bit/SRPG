extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Guild=preload("res://scripts/guild_progression.gd")
var game
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frame():
	game.session.refresh();game.hud.refresh();game.queue_redraw()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
func capture(name:String):
	await frame();check(root.get_texture().get_image().save_png("res://../artifacts/guild-"+name+".png")==OK,"capture "+name)
func nodes(node:Node)->Array:
	var result=[node]
	for child in node.get_children():result.append_array(nodes(child))
	return result
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true;game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/guild-visual/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game();game.set_process(false);game.set_physics_process(false);game.session.set_physics_process(false)
	var sim=Sim.new(7919,"town");var p=sim.add_player(1,"별하");p.gold=1000;p.tutorial_done=true;p.pos=Guild.World.FACILITIES.guild.pos
	for key in ["seed","ore","essence"]:Guild.Inventory.add_stack(p,key,50)
	game.session.sim=sim;game.session.refresh();game.on_entered();var town=game.town_panel
	town.open("guild");town.choose("guild_board");await frame()
	var buttons=nodes(town.body).filter(func(n):return n is Button and n.has_meta("contract_kind"))
	check(buttons.size()==3 and not buttons[0].disabled and buttons[1].disabled and buttons[2].disabled,"rank board exposes actual locked contracts")
	await capture("rank-novice")
	for rank in [50,150]:
		p.guild_reputation=rank;town.refresh();await frame();await capture("rank-"+str(rank))
		for label in nodes(town.body).filter(func(n):return n is Label):check(label.get_visible_line_count()>0,"rank board label visible "+label.text)
	p.guild_reputation=0;p.guild_contract={"zone":"forest","target":10,"progress":10};town.choose("claim",{"reward":"reputation"});await frame()
	check(town.preview.result.contains("정예까지 평판 25") and town.preview.result.contains("탐사 보급"),"choice preview includes concrete next unlock")
	check(town.review_labels.result.size.y<=town.review_result_scroll.size.y,"next unlock fully visible without scrolling")
	await capture("reward-unlock-preview")
	p.guild_reputation=150;p.guild_contract={};town.choose("guild_board");await frame()
	buttons=nodes(town.body).filter(func(n):return n is Button and n.has_meta("contract_kind"));buttons[1].pressed.emit();await frame()
	check(town.guild_kind=="elite" and town.preview.result.contains("3"),"elite card chooses actual advanced contract")
	town.confirm_button.pressed.emit();await frame();check(p.guild_contract.get("kind","")=="elite","actual confirmation accepts elite contract")
	for i in range(3):Guild.progress(p,"forest",{"elite":true})
	town.choose("claim");await frame();await capture("reward-choice")
	town.operation_buttons.reward_reputation.pressed.emit();await frame()
	check(town.preview.cost==0 and town.preview.result.contains("평판"),"reputation preview changes cost and exact outcome")
	var gold=p.gold;town.confirm_button.pressed.emit();await frame()
	check(p.guild_reputation==200 and p.gold==gold and town.last_receipt.contains("평판 +50"),"actual settlement receipt includes reputation not gold")
	await capture("reputation-receipt")
	town.choose("guild_board");await frame()
	var supplies=nodes(town.body).filter(func(n):return n is Button and n.get_meta("guild_service","")=="raid_supply")
	check(supplies.size()==1 and not supplies[0].disabled,"rank two actual supply available")
	supplies[0].pressed.emit();await frame();var expected=Guild.stage(p,"raid_supply").player
	await capture("supply-confirm")
	town.confirm_button.pressed.emit();await frame()
	for field in ["gold","materials","potions","consumables"]:check(p[field]==expected[field],"actual supply button outputs "+field)
	check(town.review_labels.balance.text=="금화  1000 → 920 G","receipt shows completed balance, not next purchase")
	check(town.review_labels.price.text=="지불한 금화  80 G","receipt shows actual paid amount")
	await capture("supply-receipt")
	# Receipt confirmation may precede the next player snapshot.
	var confirmed_before=p.duplicate(true);var confirmed_after=p.duplicate(true)
	confirmed_before.gold=1500;confirmed_after.gold=1420
	game.session.transaction_receipt={"before":confirmed_before,"after":confirmed_after}
	game.session.completed_sequence=123
	town.pending_receipt={"before":p.duplicate(true),"kind":"raid_supply","title":"길드 공략 보급","request_kind":"facility","serial":123}
	town.on_request_completed("facility",true);await frame()
	check(town.review_labels.balance.text=="금화  1500 → 1420 G","confirmed receipt wins over stale player snapshot")
	check(town.review_labels.price.text=="지불한 금화  80 G","confirmed receipt preserves actual cost")
	game.session.connected=false;game.queue_free();await process_frame
	print("GUILD_PROGRESSION_VISUAL checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
