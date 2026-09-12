extends SceneTree
const C=preload("res://scripts/content.gd")
const W=preload("res://scripts/world_catalog.gd")
const E=preload("res://scripts/equipment_catalog.gd")
const I=preload("res://scripts/inventory_model.gd")
var checks=0
var failures=[]
var metrics=[]
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func audit_label(label:Label,context:String):
	var count=label.get_line_count();var intended=count if label.max_lines_visible<0 else mini(count,label.max_lines_visible)
	var required=intended*label.get_line_height()+maxi(0,intended-1)*label.get_theme_constant("line_spacing")
	check(required<=label.size.y+1,"glyph line height fits allocated text area: "+context+" / "+label.text)
	check(label.get_visible_line_count()>=intended,"intended lines are actually visible: "+context+" / "+label.text)
	if label.max_lines_visible>0 and count>label.max_lines_visible:
		check(label.clip_contents and (label.tooltip_text==label.text or label.text in label.get_parent().tooltip_text),"truncated name keeps complete hover text: "+context)
	if label.autowrap_mode==TextServer.AUTOWRAP_OFF and not label.clip_text:
		for line in label.text.split("\n"):
			check(label.get_theme_font("font").get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x<=label.size.x+1,"unwrapped glyph width fits: "+context+" / "+line)
func audit_buttons(control:Control,context:String):
	for button in control.find_children("*","Button",true,false):
		if not button.is_visible_in_tree() or button.text.is_empty():continue
		if button is not OptionButton and (not button.has_meta("rpg_frame") or not button.get_meta("rpg_frame").visible):continue
		var style=button.get_theme_stylebox("normal");var left=style.content_margin_left;var right=style.content_margin_right
		# Inspected paper corners reach 12 logical pixels; 16 is the minimum icon inset.
		check(left>=16 and right>=12,"paper ornament inset, not merely outer bounds: "+context+" / "+button.text)
		var font=button.get_theme_font("font");var font_size=button.get_theme_font_size("font_size")
		var icon_space=button.get_theme_constant("icon_max_width")+button.get_theme_constant("h_separation") if button.icon!=null else 0
		var arrow_space=button.get_theme_icon("arrow").get_width()+button.get_theme_constant("arrow_margin") if button is OptionButton else 0
		var width=font.get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		check(width+icon_space+arrow_space<=button.size.x-left-right+1,"full caption + icon + arrow fit inside ornament: "+context+" / "+button.text)
		check(maxf(font.get_height(font_size),button.get_theme_constant("icon_max_width") if button.icon!=null else 0)<=button.size.y-maxf(0,style.content_margin_top)-maxf(0,style.content_margin_bottom)+1,"button glyph vertical inset: "+context+" / "+button.text)
func audit_review(panel,context:String):
	if panel.review_panel==null:
		# The dedicated boutique retains its existing wardrobe transaction view.
		# Audit its own name/portrait/price/input/action layout, rather than impose
		# the ordinary material recipe's unrelated result-scroll contract on it.
		check(panel.wardrobe_view!=null and (panel.facility=="costume" or panel.shop_mode=="costume"),"custom review exists only for boutique: "+context)
		if panel.wardrobe_view==null:return
		var view=panel.wardrobe_view;var safe=Rect2(Vector2(32,22),view.details.size-Vector2(64,42))
		for child in view.details.get_children():
			if child is Label or child is Button or child is LineEdit:check(safe.encloses(child.get_rect()),"boutique controls remain inside paper: "+context)
		check(view.selected_name.get_rect().end.y+14<=view.portrait.position.y,"boutique name never covers portrait: "+context)
		check(view.portrait.get_rect().end.y+12<=view.price_label.position.y,"portrait clear of price: "+context)
		check(view.name_field.get_rect().end.y+12<=view.feedback.position.y and view.feedback.get_rect().end.y+12<=view.action_button.position.y,"name editor, receipt and purchase have separate rows: "+context)
		check(Rect2(Vector2.ZERO,panel.body.size).encloses(view.get_rect()),"boutique fits expanded work area: "+context)
		return
	# The actual gold leaf corners extend 26 px. Insets include another 6 px of paper.
	# V0.5.2 widens the transaction panel; preserve the same safe inner margins.
	var safe=Rect2(Vector2(32,26),panel.review_panel.size-Vector2(64,52))
	for child in panel.review_panel.get_children():
		if child is Label and not child.text.is_empty():check(safe.encloses(child.get_rect()),"review content remains on inner paper: "+context+" / "+child.text)
	check(safe.encloses(panel.confirm_button.get_rect()),"transaction button clear of outer frame: "+context)
	if panel.facility=="portal":
		check(panel.review_result_scroll==null and panel.review_panel.party.get_rect().end.y+12<=panel.confirm_button.position.y,"departure information and party state leave the entrance action clear")
		return
	check(safe.encloses(panel.review_result_scroll.get_rect()),"result viewport clear of outer frame: "+context)
	check(panel.review_result_scroll.get_rect().end.y+8<=panel.review_labels.feedback.position.y,"result never paints over transaction feedback: "+context)
	check(panel.review_labels.feedback.get_rect().end.y+12<=panel.confirm_button.position.y,"feedback clear of confirmation button: "+context)
	check(panel.review_labels.name.get_rect().end.y+10<=panel.review_labels.price.position.y,"long item name clear of price: "+context)
func capture(game,name:String,control:Control):
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var frame=root.get_texture().get_image();check(frame.get_size()==Vector2i(1920,1080),"actual FullHD framebuffer "+name)
	check(frame.save_png(ProjectSettings.globalize_path("res://../artifacts/legibility-v04-"+name+".png"))==OK,"FullHD framebuffer "+name)
	if control!=game.hud:audit_buttons(control,name)
	if control==game.town_panel:audit_review(control,name)
	for label in control.find_children("*","Label",true,false):
		if not label.is_visible_in_tree() or label.text.is_empty():continue
		metrics.append({"screen":name,"text":label.text,"rect":str(label.get_rect()),"lines":label.get_line_count(),"line_height":label.get_line_height(),"visible_lines":label.get_visible_line_count(),"max_lines":label.max_lines_visible})
		if control!=game.hud:audit_label(label,name)
func run():
	root.borderless = true
	root.size = Vector2i(1920, 1080)
	var game=load("res://main.tscn").instantiate();game.options.mute=true;root.add_child(game);await process_frame
	var session=game.session;session.save_directory=ProjectSettings.globalize_path("res://../runtime/ui-legibility-v04/"+str(Time.get_ticks_usec()))
	game.join_game();session.set_physics_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false)
	var p=session.sim.players[1];p.level=100;p.tutorial_done=true;p.highest_floor=100;p.cleared_floor=99
	session.travel("town");p=session.sim.players[1];p.gold=999999999;p.materials={"seed":999999,"ore":999999,"essence":999999}
	var names=preload("res://scripts/content_names.gd");var name_key="chest:"+C.base_class(p.class_id)+":9";var saved_name=names.data.equipment[name_key]
	names.data.equipment[name_key]="태초의 별빛을 머금은 영겁의 성운 수호자 예복"
	var longest=E.make("chest",9,4,"legibility-long","focus",p.class_id)
	longest.upgrade=3;I.add_gear(p,longest)
	session.sim.recalculate(p);session.refresh();game.on_entered()
	await capture(game,"town",game.hud)
	for facility in W.FACILITIES:
		p.pos=W.FACILITIES[facility].pos;session.refresh()
		if facility in W.RESIDENTS:
			game.npc_dialogue.open(facility);game.npc_dialogue.tell_story();await capture(game,"dialogue-"+facility,game.npc_dialogue)
			var talk=game.npc_dialogue
			check(talk.dialogue.get_line_count()*talk.dialogue.get_line_height()<=talk.dialogue.size.y,"full longest story fits "+facility)
			check(not talk.dialogue.get_rect().intersects(talk.service_button.get_rect()),"story stays left of actions "+facility)
			check(talk.speaker.get_rect().end.y+4<=talk.dialogue.position.y,"speaker separated from story "+facility)
			game.npc_dialogue.open_service()
		else:game.town_panel.open(facility)
		check(game.town_panel.visible and session.paused,"actual service open "+facility)
		if facility=="smith":game.town_panel.choose("upgrade",{"item":longest.id})
		if facility=="alchemy":game.town_panel.choose("essence")
		if facility=="inn":p.hp=45;p.stamina=20;game.town_panel.refresh()
		if facility=="portal":game.town_panel.chapter=9;game.town_panel.selected_floor=100;game.town_panel.refresh()
		await capture(game,"service-"+facility,game.town_panel)
		if facility=="smith":
			game.town_panel.choose("reforge",{"item":longest.id});await capture(game,"service-smith-reforge",game.town_panel)
			I.find_item(p,longest.id).upgrade=4;game.town_panel.choose("upgrade",{"item":longest.id});await capture(game,"service-smith-unlock",game.town_panel)
			var unlock_scroll=game.town_panel.review_result_scroll
			check(unlock_scroll.get_v_scroll_bar().max_value>unlock_scroll.get_v_scroll_bar().page,"actual four-line option unlock needs vertical scrolling")
			unlock_scroll.scroll_vertical=10000;await capture(game,"service-smith-unlock-bottom",game.town_panel)
			check(unlock_scroll.get_v_scroll_bar().value+unlock_scroll.get_v_scroll_bar().page>=unlock_scroll.get_v_scroll_bar().max_value-1,"option unlock final line reachable without covering feedback")
			I.find_item(p,longest.id).upgrade=5;game.town_panel.choose("upgrade",{"item":longest.id});await capture(game,"service-smith-max",game.town_panel)
			check(game.town_panel.confirm_button.disabled,"max upgrade has readable disabled reason")
			game.town_panel.review_result_scroll.scroll_vertical=10000;await capture(game,"service-smith-max-bottom",game.town_panel)
			var scroll=game.town_panel.review_result_scroll
			check(scroll.get_v_scroll_bar().value+scroll.get_v_scroll_bar().page>=scroll.get_v_scroll_bar().max_value-1,"long option result last line reachable by scroll")
		if facility=="shop":game.town_panel.shop_mode="sell";game.town_panel.choose("sell",{"item":longest.id});await capture(game,"service-shop-sell",game.town_panel)
		if facility=="guild":p.guild_contract={"zone":"forest","progress":10,"target":10};game.town_panel.refresh();await capture(game,"service-guild-claim",game.town_panel)
		game.town_panel.close()
	for tab in ["equipment","monsters","drops","skills"]:
		var filters={"class_id":"reaper","rarity":4} if tab=="equipment" else {"role":"raid","floor":100} if tab=="monsters" else {"monster_id":"raid:100","rarity":4} if tab=="drops" else {"class_id":"breaker","effect":"active"}
		game.toggle_codex(tab);game.codex.open(tab,filters)
		await capture(game,"codex-"+tab,game.codex)
		check(game.codex.detail_name.get_rect().end.y+4<=game.codex.detail_subtitle.position.y,"codex name and subtitle separated "+tab)
		check(game.codex.detail_subtitle.get_rect().end.y+6<=game.codex.rank_picker.position.y if game.codex.rank_picker.visible else game.codex.detail_subtitle.get_rect().end.y+6<=game.codex.detail_scroll.position.y,"codex header clear of body "+tab)
		for button in game.codex.row_buttons.values():
			var labels=button.find_children("*","Label",false,false)
			if labels.size()==2:check(labels[0].get_rect().end.y+4<=labels[1].position.y,"codex row title clear of subtitle "+tab+" "+labels[0].text)
		game.codex.detail_scroll.scroll_vertical=10000;await capture(game,"codex-"+tab+"-bottom",game.codex)
		game.codex.close()
	var longest_class="warrior"
	for class_id in C.CLASSES:
		if str(C.CLASSES[class_id].name).length()>str(C.CLASSES[longest_class].name).length():longest_class=class_id
	game.toggle_codex("skills");game.codex.open("skills",{"class_id":longest_class,"effect":"active"})
	game.codex.rank_index=2;game.codex.refresh_detail();await capture(game,"codex-skills-long-class",game.codex)
	game.codex.open("skills",{"class_id":longest_class,"effect":"constellation"})
	var keystones=preload("res://scripts/game_database.gd").query("skills",{"class_id":longest_class,"effect":"constellation"},0,100).items.filter(func(row):return row.get("type","")=="keystone")
	if not keystones.is_empty():game.codex.select_record(keystones[0].id)
	await capture(game,"codex-specialization",game.codex);game.codex.detail_scroll.scroll_vertical=10000;await capture(game,"codex-specialization-bottom",game.codex);game.codex.close()
	var file=FileAccess.open("res://../artifacts/ui-legibility-v04-metrics.json",FileAccess.WRITE);file.store_string(JSON.stringify(metrics,"\t"));file.close()
	names.data.equipment[name_key]=saved_name
	game.stop_audio();session.disconnect_game();game.queue_free();await process_frame;await process_frame
	print("UI_LEGIBILITY_V04_TESTS checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
