extends Control
## Merchant view only. Purchases/equips go through the authoritative session.
const Wardrobe=preload("res://scripts/wardrobe.gd")
const Names=preload("res://scripts/sprite_names.gd")
const Content=preload("res://scripts/content.gd")
const Preview=preload("res://scripts/character_preview.gd")
const Art=preload("res://scripts/ui_art.gd")
const Icons=preload("res://scripts/icon_library.gd")
const PAGE_SIZE=4
var town
var game
var options=[]
var cards={}
var card_previews={}
var card_names={}
var portrait:Control
var details:Control
var selected_name:Label
var price_label:Label
var balance_label:Label
var feedback:Label
var name_field:LineEdit
var rename_button:Button
var action_button:Button
var previous_button:Button
var next_button:Button
var page_label:Label

static func equipped_id(p:Dictionary)->String:
	if p.get("costume","none")!="none":return "costume:"+str(p.costume)
	if p.get("avatar","auto")!="auto":return "avatar:"+str(p.avatar)
	return "base:"+str(p.class_id)

func setup(owner_panel,p:Dictionary):
	town=owner_panel;game=town.game;position=Vector2(0,58);size=Vector2(976,588);mouse_filter=Control.MOUSE_FILTER_IGNORE
	options=Wardrobe.options(p.class_id)
	if town.wardrobe_selection not in options:
		town.wardrobe_selection=equipped_id(p) if equipped_id(p) in options else options[0]
		town.wardrobe_page=int(options.find(town.wardrobe_selection)/PAGE_SIZE)
	var pages=maxi(1,ceili(options.size()/float(PAGE_SIZE)))
	town.wardrobe_page=clampi(town.wardrobe_page,0,pages-1)
	var first=town.wardrobe_page*PAGE_SIZE
	for i in range(PAGE_SIZE):
		if first+i>=options.size():break
		card(options[first+i],p,Vector2(i%2*277,int(i/2)*256))
	previous_button=game.button(self,"‹",Vector2(0,520),Vector2(60,44),func():turn_page(-1))
	next_button=game.button(self,"›",Vector2(480,520),Vector2(60,44),func():turn_page(1))
	previous_button.disabled=town.wardrobe_page==0;next_button.disabled=town.wardrobe_page==pages-1
	page_label=game.label(self,Content.CLASSES[p.class_id].name+"  ·  %d / %d"%[town.wardrobe_page+1,pages],Vector2(73,531),Vector2(394,26),18)
	page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	show_selected(p)

func card(id:String,p:Dictionary,at:Vector2):
	var selected=id==town.wardrobe_selection
	var b=game.button(self,"",at,Vector2(263,244),func():choose(id),selected)
	b.tooltip_text=Wardrobe.label(id);cards[id]=b
	var art=Preview.new();art.sheet=Wardrobe.preview(p,id);art.position=Vector2(20,18);art.size=Vector2(223,124);b.add_child(art);card_previews[id]=art
	var name=game.label(b,"",Vector2(20,147),Vector2(223,49),18)
	name.autowrap_mode=TextServer.AUTOWRAP_ARBITRARY;name.max_lines_visible=2;name.clip_contents=true;name.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING
	name.text=Wardrobe.label(id);name.size=Vector2(223,49);card_names[id]=name
	var state="착용 중" if id==equipped_id(p) else "보유 중" if Wardrobe.owned(p,id) else "%d G"%Wardrobe.price(id)
	game.label(b,state,Vector2(20,203),Vector2(223,23),16)
	if selected or id==equipped_id(p):Icons.picture(b,"selected" if selected else "equip",Vector2(226,15),Vector2(22,22))

func show_selected(p:Dictionary):
	var id=town.wardrobe_selection
	var owned=Wardrobe.owned(p,id);var wearing=equipped_id(p)==id;var cost=Wardrobe.price(id)
	details=Art.panel(self,Vector2(572,0),Vector2(403,588),"paper",20)
	selected_name=game.label(details,"",Vector2(36,22),Vector2(331,54),22)
	selected_name.autowrap_mode=TextServer.AUTOWRAP_ARBITRARY;selected_name.max_lines_visible=2;selected_name.clip_contents=true;selected_name.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING
	selected_name.text=Wardrobe.label(id);selected_name.size=Vector2(331,54)
	selected_name.size.y=maxf(54,selected_name.get_minimum_size().y)
	selected_name.tooltip_text=selected_name.text;selected_name.mouse_filter=Control.MOUSE_FILTER_PASS
	var portrait_top=maxf(94,selected_name.get_rect().end.y+16)
	portrait=Preview.new();portrait.sheet=Wardrobe.preview(p,id);portrait.position=Vector2(64,portrait_top);portrait.size=Vector2(276,324-portrait_top);details.add_child(portrait)
	price_label=game.label(details,"착용 중" if wearing else "보유한 외형" if owned else "가격  %d G"%cost,Vector2(32,338),Vector2(339,28),19)
	balance_label=game.label(details,"기본 외형" if id.begins_with("base:") else "코스튬" if id.begins_with("costume:") else "대체 외형",Vector2(32,371),Vector2(339,25),17)
	if not owned:balance_label.text="구매 후  %d G"%(int(p.gold)-cost) if int(p.gold)>=cost else "보유  %d G / 필요  %d G"%[p.gold,cost]
	name_field=game.line_edit(details,Wardrobe.label(id),Vector2(32,408),Vector2(216,45));name_field.max_length=24
	name_field.tooltip_text="외형 이름 · 1~24자";name_field.placeholder_text="외형 이름"
	rename_button=game.button(details,"이름 저장",Vector2(256,408),Vector2(115,45),save_name)
	feedback=game.label(details,town.last_receipt,Vector2(32,466),Vector2(339,42),16)
	feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;feedback.max_lines_visible=2;feedback.clip_text=true;feedback.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	name_field.text_changed.connect(update_name_action);name_field.text_submitted.connect(func(_value):save_name());update_name_action(name_field.text)
	action_button=game.button(details,"착용 중" if wearing else "착용하기" if owned else "구매하기",Vector2(32,521),Vector2(339,46),func():transact("wear_appearance" if owned else "buy_appearance"),true)
	action_button.disabled=wearing or (not owned and int(p.gold)<cost)
	Icons.attach(action_button,"selected" if wearing else "equip" if owned else "buy")
	if not owned and int(p.gold)<cost and town.last_receipt.is_empty():feedback.text="금화가 부족합니다."

func choose(id:String):
	if id not in options:return
	town.wardrobe_selection=id;town.wardrobe_page=int(options.find(id)/PAGE_SIZE);town.last_receipt="";town.refresh()

func turn_page(direction:int):
	var pages=maxi(1,ceili(options.size()/float(PAGE_SIZE)))
	var page=clampi(town.wardrobe_page+direction,0,pages-1)
	if page==town.wardrobe_page:return
	town.wardrobe_page=page;town.wardrobe_selection=options[page*PAGE_SIZE];town.last_receipt="";town.refresh()

func transact(kind:String)->bool:
	if town.facility not in ["shop","costume"] or town.shop_mode!="costume" or kind not in ["buy_appearance","wear_appearance"]:return false
	var id=town.wardrobe_selection;var before=int(town.player().gold)
	var success=game.session.act(kind,id)
	if success:
		town.last_receipt="구매 완료 · %d G 지불"%(before-int(town.player().gold)) if kind=="buy_appearance" else "착용 완료"
		game.audio_director.play_sound("pickup" if kind=="buy_appearance" else "equip")
	else:town.last_receipt="현재 상태에서는 거래할 수 없습니다."
	town.refresh();return success

func update_name_action(value:String):
	rename_button.disabled=not Names.valid_name(value) or value.strip_edges()==Wardrobe.label(town.wardrobe_selection)
	name_field.tooltip_text=value+"\n외형 이름 · 1~24자"
	if not Names.valid_name(value):feedback.text="이름은 1~24자로 입력해 주세요."
	elif feedback.text.begins_with("이름은 "):feedback.text=town.last_receipt

func save_name():
	if rename_button.disabled:return
	if Names.rename(town.wardrobe_selection,name_field.text):
		town.last_receipt="외형 이름 저장 완료";town.refresh()
	else:feedback.text="이름을 저장하지 못했습니다."
