extends SceneTree

const Session = preload("res://scripts/local_session.gd")
var checks=0
var failures=[]

func _initialize(): run.call_deferred()

func check(condition: bool, message: String):
	checks+=1
	if not condition:
		failures.append(message)
		push_error("FAIL: "+message)

func run():
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.session.save_directory=ProjectSettings.globalize_path("res://../runtime/single-tests/"+str(Time.get_ticks_usec()))
	game.name_input.text="검증 모험가"
	game.join_game()
	check(game.session.connected and game.session.state.players.size()==1,"single player starts without peers")
	check(game.multiplayer.multiplayer_peer is OfflineMultiplayerPeer,"no network socket peer")
	check(not game.menu.visible and game.hud.visible,"title opens game HUD")
	var session=game.session
	var p=session.sim.players[1]
	check(p.name=="검증 모험가","chosen name stored")
	game.toggle_bag()
	check(session.paused and game.bag.visible,"inventory pauses simulation")
	var before=session.sim.clock
	await create_timer(0.2).timeout
	check(is_equal_approx(before,session.sim.clock),"paused clock does not advance")
	game.toggle_bag()
	game.toggle_help()
	check(session.paused and game.help_panel.visible,"escape menu pauses simulation")
	game.continue_game()
	check(not session.paused,"resume clears pause")
	await create_timer(0.2).timeout
	check(session.sim.clock>before,"simulation resumes")
	session.travel("forest");p=session.sim.players[1]
	var boss=session.sim.enemies[session.sim.enemies.size()]
	p.pos=boss.pos+Vector2(0.4,0)
	p.aim=Vector2.LEFT
	var boss_before=boss.hp
	p.level=10;p.skill_ranks={"blade":1,"heavy_training":1,"blade_wave":1};p.skill_loadout={"skill_q":"blade_wave"};session.refresh()
	game.action_buttons.skill_q.pressed.emit()
	session.sim.combat.tick_projectiles(.1)
	check(boss.hp<boss_before and p.skill_q_cd>0 and not game.action_badges.skill_q.text.is_empty(),"icon skill button damages and displays cooldown")
	p.kills=4
	boss.hp=1
	game.action_buttons.attack.pressed.emit()
	var weapon_drop=session.sim.drops.values().filter(func(d):return d.item.category=="weapon")[0]
	p.pos=weapon_drop.pos
	var key=InputEventKey.new()
	key.physical_keycode=KEY_E;key.pressed=true
	game._unhandled_input(key)
	check(p.inventory.size()==1 and p.equipped==p.inventory[0].id,"UI key collects and autoequips loot")
	check(p.quest_done,"quest completion retained")
	game.toggle_bag()
	await process_frame
	check(game.bag.grid.get_child_count()>0 and game.bag.equipment_controls.weapon.item.id==p.equipped,"inventory creates grid and equipment controls")
	p.inventory.append({"id":"spare","name":"예비 무기","rarity":0,"bonus":2})
	session.refresh()
	var gold=p.gold
	session.act("discard","spare")
	check(p.inventory.size()==1 and p.gold==gold+3,"discard works while bag paused")
	session.act("discard",p.equipped)
	check(p.inventory.size()==1,"equipped item protected from discard")
	game.toggle_bag()
	var saved=session.sim.persistent(1)
	var old_seed=session.world_seed
	p.pos=session.sim.map.spawn
	session.new_expedition()
	check(session.world_seed!=old_seed,"new expedition changes map seed")
	check(session.sim.players[1].inventory==saved.inventory,"new expedition retains inventory")
	session.disconnect_game()
	check(game.menu.visible and not game.hud.visible,"save and title returns to menu")
	var second=Session.new();root.add_child(second)
	second.save_directory=session.save_directory
	second.start_game("불러오기",1)
	var restored=second.sim.players[1]
	check(restored.name==saved.name,"existing slot restores name")
	for field in ["level","xp","gold","potions","inventory","equipped","kills","boss_kills","quest_done"]:
		check(restored[field]==saved[field],"disk persistence "+field)
	second.disconnect_game()
	second.start_game("두 번째 모험가",2)
	check(second.sim.players[1].level==1 and second.sim.players[1].inventory.is_empty(),"slots remain independent")
	second.disconnect_game()
	second.start_game("불러오기",1)
	second.save_game()
	var f=FileAccess.open(second.save_path(),FileAccess.WRITE)
	f.store_string("invalid-json");f.close()
	check(second.load_slot().inventory==saved.inventory,"corrupt save recovers backup")
	second.disconnect_game()
	game.stop_audio()
	await create_timer(0.5).timeout
	second.queue_free();game.queue_free()
	await process_frame
	print("SINGLE_PLAYER_TESTS checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
