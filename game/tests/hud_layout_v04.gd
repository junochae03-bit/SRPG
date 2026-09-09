extends SceneTree
const C=preload("res://scripts/content.gd")
var checks=0
var failures=[]
func _initialize():
	run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func capture(name:String):
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var path=ProjectSettings.globalize_path("res://../artifacts/hud-v04-"+name+".png")
	check(root.get_texture().get_image().save_png(path)==OK,"actual framebuffer "+name)
func check_resource_interior(resource,job:String):
	var inner=resource.content_bounds()
	check(inner.position.x>=36 and inner.position.y>=40,"ornament inset contract "+job)
	for control in [resource.emblem,resource.heading,resource.hint_icon,resource.hint]:
		if control.visible:check(inner.encloses(control.get_rect()),"child fits inside decorative frame "+job+" "+str(control.get_rect()))
	check(not resource.content_draw_rects.is_empty(),"resource draw geometry recorded "+job)
	for rect in resource.content_draw_rects:check(inner.encloses(rect),"actual text/icon fits decorative interior "+job+" "+str(rect))
func run():
	# Full HD client area, independent of desktop title-bar constraints.
	root.borderless=true;root.size=Vector2i(1920,1080)
	var game=load("res://main.tscn").instantiate();game.options.mute=true;root.add_child(game);await process_frame
	var local=game.session;local.save_directory=ProjectSettings.globalize_path("res://../runtime/hud-layout-v04/"+str(Time.get_ticks_usec()))
	game.join_game();local.set_physics_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false)
	var p=local.sim.players[1];p.name="별빛을따라걷는아주긴모험가이름";p.tutorial_done=true;p.level=100;p.highest_floor=100;p.cleared_floor=99
	local.travel("town");p=local.sim.players[1];local.sim.action(1,"class","runesword");p=local.sim.players[1]
	var actives=C.SKILLS.runesword.filter(func(n):return n.effect=="active")
	for i in range(6):p.skill_ranks[actives[i].id]=3;p.skill_loadout[C.ACTIONS[i]]=actives[i].id
	local.sim.recalculate(p);local.refresh();game.hud.refresh()
	var hud=game.hud
	check(hud.name_label.text_overrun_behavior==TextServer.OVERRUN_TRIM_ELLIPSIS and hud.name_label.tooltip_text==p.name,"long name truncates with full tooltip")
	check(not hud.name_label.get_rect().intersects(hud.class_label.get_rect()),"name and class occupy separate readable rows")
	check(hud.hp_label.get_rect().position.y>hud.class_label.get_rect().end.y,"HP number has its own row")
	check(hud.quest_panel.size.y==112 and hud.quest.visible,"objective starts compact and expanded")
	hud.quest_toggle.pressed.emit();check(hud.quest_collapsed and not hud.quest.visible and hud.quest_panel.size.y==44,"objective folds through actual button")
	hud.refresh();check(hud.quest_collapsed and not hud.quest.visible,"objective refresh preserves fold preference")
	await capture("compact")
	hud.quest_toggle.pressed.emit();check(not hud.quest_collapsed and hud.quest.visible,"objective reopens")
	var menu_rects=[]
	for button in [hud.bag_button,hud.growth_button,hud.codex_button]:
		check(button.size==Vector2(90,108),"large top menu target "+button.hotkey)
		check(button.get_rect().end.x<1246,"top menu leaves minimap clear "+button.hotkey)
		for other in menu_rects:check(not other.intersects(button.get_rect()),"top menu targets do not overlap")
		menu_rects.append(button.get_rect())
	hud.bag_button.pressed.emit();check(game.bag.visible and local.paused,"bag target opens paused inventory");hud.bag_button.pressed.emit()
	hud.growth_button.pressed.emit();check(game.skill_tree.visible and local.paused,"growth target opens paused tree");hud.growth_button.pressed.emit()
	hud.codex_button.pressed.emit();check(game.codex.visible and local.paused,"codex target opens paused encyclopedia");hud.codex_button.pressed.emit()
	var rects=[]
	for key in hud.circles:
		var circle=hud.circles[key];var rect=circle.get_rect();rect.position.x-=8;rect.size+=Vector2(16,24)
		for other in rects:check(not rect.intersects(other),"action and caption bounds separated "+key)
		rects.append(rect)
		check(rect.end.y<891 and rect.end.x<1404,"action safe margin "+key)
		check(circle._has_point(Vector2(3,3)),"full square target accepts corner "+key)
		if key in C.ACTIONS:
			check(circle.size==Vector2(96,96),"96px skill target "+key)
			check(not circle.locked and circle.picture!=null,"learned slot keeps actual art "+key)
			check(game.fonts.get_string_size(circle.caption_text(),HORIZONTAL_ALIGNMENT_LEFT,-1,15).x<=circle.size.x+16,"caption respects measured width "+key)
	for i in range(6):check(hud.circles[C.ACTIONS[i]].position==Vector2(1028+i%3*124,618+int(i/3)*132),"Q F V above C Z X "+str(i))
	check(hud.circles.interact.size.x>hud.circles.potion.size.x and hud.circles.potion.size.x>hud.circles.return.size.x,"interaction and potion have larger targets than return")
	p.skill_cooldowns[actives[0].id]=12.3;local.refresh();hud.refresh();check(hud.circles.skill_q.cooldown_text()=="13","long cooldown uses readable whole seconds")
	p.skill_cooldowns[actives[0].id]=.35;local.refresh();hud.refresh();check(hud.circles.skill_q.cooldown_text()=="0.3" or hud.circles.skill_q.cooldown_text()=="0.4","last cooldown second keeps decimal precision")
	p.skill_cooldowns[actives[0].id]=12.3;p.job_state.runes=4;local.refresh();hud.refresh()
	check(hud.job_resource.visible and hud.job_resource.size.y==200,"rune class keeps readable resource display with ornament inset")
	check(hud.job_resource.get_rect().end.x<hud.circles.potion.position.x,"resource panel leaves utilities clear")
	await capture("runesword")
	check_resource_interior(hud.job_resource,"runesword")
	p.pos=preload("res://scripts/world_catalog.gd").FACILITIES.smith.pos;local.refresh();hud.refresh();check(hud.circles.interact.caption=="대화","interaction label follows nearby town NPC")
	p.hp=maxi(1,p.max_hp-40);p.potion_cd=0.;var before=p.hp;hud.circles.potion.pressed.emit();check(p.hp>before,"larger potion target still invokes real healing")
	check(local.sim.action(1,"class","rogue"),"switch to gambler base family in town")
	check(local.sim.action(1,"class","gambler"),"advance to gambler in town")
	p=local.sim.players[1];local.refresh();hud.refresh();check(p.class_id=="gambler" and hud.job_resource.visible,"gambler keeps card resource display");await capture("gambler")
	check_resource_interior(hud.job_resource,"gambler")
	var advanced_count=0
	for job in C.CLASSES:
		var definition=C.CLASSES[job]
		if not definition.has("base") or definition.get("starter",false):continue
		check(local.sim.action(1,"class",definition.base),"resource fixture base "+job)
		check(local.sim.action(1,"class",job),"resource fixture advanced "+job)
		p=local.sim.players[1];p.name="별빛을따라걷는아주긴모험가이름"
		p.job_state.shield=999;p.job_state.runes=5;p.job_state.rush=8;p.job_state.combo=3;p.job_state.momentum=80.;p.job_state.counter=2.;p.job_state.instant=3.
		local.sim.combat.jobs.buff(p,"guard",.2,5.)
		# Freeze a valid skill definition in the visual casting state to exercise
		# the lowest status row as well as the title and resource rows.
		p.job_state.casting={"node":C.SKILLS[job].filter(func(n):return n.effect=="active")[0],"time":12.3}
		local.refresh();hud.refresh();await capture("resource-"+job)
		check(hud.job_resource.heading.text==definition.name,"actual advanced resource title "+job)
		check_resource_interior(hud.job_resource,job)
		advanced_count+=1
	check(advanced_count==15,"all fifteen advanced class resource interiors captured")
	local.sim.action(1,"class","warrior");p=local.sim.players[1];local.refresh();hud.refresh();check(not hud.job_resource.visible,"no always-visible empty resource panel for basic job")
	p.charge_time=.5;local.refresh();hud.refresh();game.combat_feedback.refresh(0.);check(game.combat_feedback.charge_visible and is_equal_approx(game.combat_feedback.charge_ratio,.5/.9) and not hud.charge_label.visible,"실제 충전량은 캐릭터 우측 게이지로 표시")
	p.charge_time=-1.;local.refresh();hud.refresh();game.combat_feedback.refresh(0.);check(not game.combat_feedback.charge_visible and not hud.charge_label.visible,"충전 종료 후 게이지와 기존 문구 모두 숨김")
	var labels=hud.find_children("*","Label",true,false)
	check(not labels.any(func(label):return label.text.contains("별빛을 따라 걷는 모험가")),"removed persistent HUD slogan")
	game.stop_audio();local.disconnect_game();game.queue_free();await process_frame;await process_frame
	print("HUD_LAYOUT_V04_TESTS checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
