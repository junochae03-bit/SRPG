extends SceneTree
const DB=preload("res://scripts/game_database.gd")
var checks=0
var failures=[]
func _initialize():
	run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func capture(name:String):
	await create_timer(.12).timeout;await process_frame;await RenderingServer.frame_post_draw
	var path=ProjectSettings.globalize_path("res://../artifacts/v03-codex-"+name+".png")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	check(root.get_texture().get_image().save_png(path)==OK,"capture "+name)
func key(code:int,unicode_value:int=0):
	var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.unicode=unicode_value;event.pressed=true;root.push_input(event,true)
	event=event.duplicate();event.pressed=false;root.push_input(event,true)
func run():
	# Full HD client area, independent of desktop title-bar constraints.
	root.borderless=true;root.size=Vector2i(1920,1080)
	var game=load("res://main.tscn").instantiate();game.options.mute=true;root.add_child(game);await process_frame
	var local=game.session;local.save_directory=ProjectSettings.globalize_path("res://../runtime/codex-v03/"+str(Time.get_ticks_usec()));game.join_game();local.set_physics_process(false);game.set_physics_process(false)
	var p=local.sim.players[1];p.tutorial_done=true;p.level=100;p.stats={"strength":80,"endurance":80,"technique":100,"agility":37,"magic":0};local.sim.recalculate(p);local.refresh()
	var before=JSON.stringify(p)
	key(KEY_B);await process_frame;var panel=game.codex
	check(panel.visible and local.paused,"B journal pauses game")
	check(panel.selected_tab=="equipment","starts with equipment")
	check(panel.result.total==2500,"2500 gear records")
	check(panel.row_buttons.size()==8,"eight records per page")
	check(panel.previous_button.disabled and not panel.next_button.disabled,"first-page controls")
	var first_id=panel.result.items[0].id;panel.change_page(1)
	check(panel.page==1 and panel.result.items[0].id!=first_id,"page advances to distinct gear")
	panel.page=99999;panel.refresh();check(panel.next_button.disabled,"last page clamps safely")
	panel.set_filter("rarity",0);check(panel.result.total>0,"normal rarity zero is a real filter")
	for item in panel.result.items:check(item.rarity==0,"normal grade row")
	panel.set_filter("class_id","reaper");panel.set_filter("slot","weapon")
	check(panel.result.total==10,"exact reaper normal weapon filter")
	for item in panel.result.items:check(item.job_lock=="reaper","weapon exact job")
	panel.set_filter("slot","chest");check(panel.result.total==10,"first-family armor included")
	for item in panel.result.items:check(item.family=="rogue","reaper family armor")
	panel.reset_filters();panel.search.text="존재하지않는기록_xx";panel.search.text_changed.emit(panel.search.text);await create_timer(.32).timeout
	check(panel.result.total==0 and panel.row_buttons.is_empty(),"debounced search empty state")
	check(panel.previous_button.disabled and panel.next_button.disabled,"empty page controls")
	panel.reset_filters();panel.search.text="사신";panel.apply_search();check(panel.result.total>0 and panel.result.total<2500,"Korean equipment search")
	panel.open("equipment",{"class_id":"reaper","rarity":4,"slot":"weapon"});panel.select_record("eq:reaper:weapon:09:4");await capture("equipment")
	check(panel.detail_icon.texture!=null,"gear icon preview")
	check("강화" in panel.detail_body.text,"option gate description")
	panel.follow_link();check(panel.selected_tab=="drops","item to drop sources")
	check(panel.result.total>0,"item source query returns eligible tables")
	check("부위까지 맞을 확률" in panel.detail_body.text,"exact gear source shows joint slot probability")
	panel.open("monsters",{"role":"normal","floor":1});check("1층 실제 능력치" in panel.detail_body.text,"selected floor displays scaled monster stats")
	check(panel.detail_icon.material!=null,"monster preview uses game chroma shader")
	panel.open("monsters",{"role":"raid","floor":100});check(panel.result.total==1,"floor 100 raid filter")
	check(panel.detail_icon.texture!=null,"raid sprite preview")
	check("100층" in panel.detail_body.text,"raid floor detail")
	check("일반 게이지" in panel.detail_body.text and "제한시간 체크" in panel.detail_body.text,"boss stagger requirements displayed")
	await capture("monster")
	panel.follow_link();check(panel.selected_tab=="drops","monster to drops link")
	check(panel.filters.monster_id=="raid:100","raid link preserves floor identity")
	check(panel.result.items.any(func(row):return row.get("roll_mode","")=="guaranteed_extra_conditional_grade"),"raid extras present")
	check(panel.result.items.any(func(row):return row.get("roll_mode","")=="independent_per_entry"),"independent drops also present")
	panel.select_record(panel.result.items.filter(func(row):return row.get("roll_mode","")=="independent_per_entry")[0].id);check(panel.link_target.id=="raid:100","raid base drop keeps encounter source identity")
	var legend=DB.query("drops",{"monster_id":"raid:100","rarity":4}).items[0]
	panel.select_record(legend.id);check("1개는 확정" in panel.detail_body.text,"conditional grade distinguished from independent roll")
	check("당첨 시 수량 ×1" in panel.detail_body.text and "보너스의 영향을 받지 않습니다" in panel.detail_body.text,"raid quantity and fixed grade odds explained")
	await capture("drops");panel.follow_link();check(panel.selected_tab=="monsters" and panel.selected_id=="raid:100","drop back-link exact raid")
	var stack=DB.snapshot().drops.filter(func(row):return int(row.amount)>1)[0];panel.open("drops",{"q":stack.id});panel.select_record(stack.id)
	check("당첨 시 수량 ×%d"%int(stack.amount) in panel.detail_body.text and "보너스를 적용하기 전" in panel.detail_body.text,"stack amount and base drop chance shown")
	panel.open("skills",{"class_id":"breaker","effect":"active"});check(panel.result.total>0,"class skill filter")
	var skill=panel.result.items[0];panel.select_record(skill.id);var rank_one=panel.detail_body.text
	panel.rank_index=int(skill.max_rank)-1;panel.refresh_detail();check(panel.detail_body.text!=rank_one,"rank changes displayed values")
	check(panel.rank_picker.visible and panel.reference_picker.visible,"rank and technique controls")
	var reference=panel.detail_body.text;panel.use_player_stats=true;panel.refresh_detail();check(reference!=panel.detail_body.text,"current technique changes stagger display")
	check("공격력 100" in panel.detail_body.text and "내 기술 선택" in panel.detail_body.text,"reference assumptions explicit")
	await capture("skills")
	var with_parent=DB.query("skills",{"class_id":"breaker"},0,100).items.filter(func(row):return not row.parents.is_empty())[0]
	panel.select_record(with_parent.id);panel.follow_link();check(panel.selected_id==str(with_parent.parents[0]),"parent skill navigation")
	panel.open("skills",{"class_id":"warrior","effect":"passive"});check(panel.result.total>0,"legacy passive effect filter supported")
	for skill_row in panel.result.items:check(skill_row.effect not in ["active","upgrade"],"passive filter excludes active upgrade")
	panel.switch_tab("equipment");check(panel.filters.is_empty() and panel.page==0,"switch tab clears unrelated filters")
	check(panel.position+panel.size==Vector2(1416,876),"journal fits 1440 by 900 viewport")
	for button in panel.row_buttons.values():check(button.position.x+button.size.x<=panel.list.size.x and button.position.y+button.size.y<=panel.list.size.y,"list card bounds")
	check(panel.detail_scroll.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED,"detail wraps instead of horizontal scroll")
	check(panel.detail_body.fit_content and not panel.detail_body.scroll_active,"single vertical detail scroller")
	check(JSON.stringify(p)==before,"browsing never changes player inventory stats or skill points")
	var original_hp=p.hp;var original_potions=p.potions;p.hp=p.max_hp-100;p.potions=3;local.refresh();panel.search.release_focus()
	key(KEY_1);await process_frame
	check(p.hp==p.max_hp-100 and p.potions==3,"journal blocks unfocused potion hotkey at low HP")
	p.hp=original_hp;p.potions=original_potions;local.refresh()
	key(KEY_B);await process_frame;check(not panel.visible and not local.paused,"B closes and resumes")
	key(KEY_B);await process_frame;panel.search.grab_focus();await process_frame;key(KEY_B,98);await process_frame
	check(panel.visible and panel.search.text=="b","typing B searches without closing")
	panel.search.release_focus();key(KEY_ESCAPE);await process_frame;check(not panel.visible and not local.paused,"Escape closes journal")
	game.toggle_codex();key(KEY_I);await process_frame;check(not panel.visible and game.bag.visible and local.paused,"I opens bag and closes journal");game.toggle_bag()
	game.toggle_codex();key(KEY_K);await process_frame;check(not panel.visible and game.skill_tree.visible and local.paused,"K opens growth and closes journal");game.toggle_skills()
	game.toggle_codex();game.town_panel.open("shop");check(not panel.visible and game.town_panel.visible and local.paused,"town counter closes journal");game.town_panel.close()
	game.toggle_codex();game.help_panel.show();panel.close();check(local.paused,"closing preserves another modal pause");game.help_panel.hide();local.paused=false
	game.stop_audio();local.disconnect_game();game.queue_free();await process_frame
	print("CODEX_UI_V03_TESTS checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
