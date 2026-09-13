extends Control
const Craft=preload("res://scripts/exploration_crafting.gd")
const Icons=preload("res://scripts/icon_library.gd")
const Art=preload("res://scripts/ui_art.gd")
var town
var game
var search:LineEdit
var tier:OptionButton
var grade:OptionButton
var mine:CheckButton
var content:Control
var page=0
var selected=""
var pending=0
var notice=""
var buttons=[]
var confirm:Button
func setup(owner_town):
	town=owner_town;game=town.game;position=Vector2(0,58);size=Vector2(1258,630)
	search=LineEdit.new();search.position=Vector2(10,4);search.size=Vector2(278,44);search.placeholder_text="장비 · 재료 검색";search.add_theme_font_size_override("font_size",20);add_child(search)
	tier=OptionButton.new();tier.position=Vector2(300,4);tier.size=Vector2(144,44);tier.add_item("모든 단계")
	for i in range(10):tier.add_item("B%d–%d"%[i*10+1,i*10+10])
	add_child(tier)
	grade=OptionButton.new();grade.position=Vector2(452,4);grade.size=Vector2(136,44);grade.add_item("모든 등급")
	for value in Craft.Equipment.GRADES:grade.add_item(value)
	add_child(grade);grade.item_selected.connect(func(_i):page=0;rebuild())
	mine=CheckButton.new();mine.text="내 직업";mine.position=Vector2(592,4);mine.size=Vector2(128,44);mine.button_pressed=true;add_child(mine)
	search.text_changed.connect(func(_s):page=0;rebuild());tier.item_selected.connect(func(_i):page=0;rebuild());mine.toggled.connect(func(_b):page=0;rebuild())
	for field in [search,tier,grade,mine]:
		field.add_theme_font_override("font",game.fonts);field.add_theme_font_size_override("font_size",18)
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:field.add_theme_color_override(state,Color("29434a"))
		if field==mine:continue
		var style=StyleBoxTexture.new();style.texture=Art.plain_paper()
		for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:style.set_texture_margin(side,4);style.set_content_margin(side,10 if side in [SIDE_LEFT,SIDE_RIGHT] else 2)
		for state in ["normal","hover","pressed","focus"]:field.add_theme_stylebox_override(state,style)
	search.add_theme_color_override("font_placeholder_color",Color("617776"))
	content=Control.new();content.position=Vector2(0,62);content.size=size-Vector2(0,62);add_child(content)
	if game.session.has_signal("request_completed"):game.session.request_completed.connect(completed)
	rebuild()
func completed(kind:String,success:bool):
	if kind=="facility" and pending>0 and game.session.completed_sequence==pending:
		pending=0;notice="제작 완료" if success else "제작 조건이 변경됐습니다.";rebuild()
func rows()->Array:
	var p=town.player();var result=[];var query=search.text.strip_edges().to_lower()
	for key in Craft.Data.recipes():
		var row=Craft.Data.recipes()[key]
		if tier.selected>0 and int(row.tier)!=tier.selected-1:continue
		if grade.selected>0 and int(row.rarity)!=grade.selected-1:continue
		var output=Craft.item(row,"@preview")
		if mine.button_pressed and (output.job_lock!=p.class_id if output.category=="weapon" else output.family!=Craft.Content.base_class(p.class_id)):continue
		var words=output.name
		for material in row.materials:words+=" "+Craft.Content.MATERIALS[material]
		if not query.is_empty() and not words.to_lower().contains(query):continue
		result.append({"id":key,"definition":row,"item":output})
	return result
func label(parent,value,at,dimensions,font_size=20,lines=2):return town.wrapped(parent,value,at,dimensions,font_size,lines)
func rebuild():
	for child in content.get_children():content.remove_child(child);child.queue_free()
	buttons.clear();confirm=null
	var entries=rows();page=clampi(page,0,maxi(0,ceili(entries.size()/8.)-1))
	if not entries.any(func(row):return row.id==selected):selected=entries[0].id if not entries.is_empty() else ""
	for i in range(page*8,mini(entries.size(),page*8+8)):
		var row=entries[i];var index=i-page*8
		var button=town.item_card(content,row.item,Vector2(index%2*352,int(index/2)*126),"LV.%d · %d G"%[row.definition.level,row.definition.gold],func():selected=row.id;notice="";rebuild(),row.id==selected)
		buttons.append(button)
	if entries.is_empty():label(content,"일치하는 제작법이 없습니다.",Vector2(24,65),Vector2(675,70),23)
	game.button(content,"이전",Vector2(10,512),Vector2(130,44),func():page-=1;rebuild()).disabled=page==0
	label(content,"%d / %d · %d종"%[page+1,maxi(1,ceili(entries.size()/8.)),entries.size()],Vector2(200,518),Vector2(320,37),20)
	game.button(content,"다음",Vector2(568,512),Vector2(130,44),func():page+=1;rebuild()).disabled=(page+1)*8>=entries.size()
	var panel=Art.panel(content,Vector2(744,-62),Vector2(510,626),"paper",6)
	if selected.is_empty():return
	var q=Craft.quote(town.player(),selected)
	Art.picture(panel,Craft.Content.icon_texture(q.item),Vector2(28,24),Vector2(86,86))
	label(panel,q.title,Vector2(134,24),Vector2(336,80),24,2)
	var detail_scroll=ScrollContainer.new();detail_scroll.position=Vector2(28,124);detail_scroll.size=Vector2(446,132);detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(detail_scroll)
	var detail=Label.new();detail_scroll.add_child(detail)
	detail.text=q.result;detail.custom_minimum_size.x=425;detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.add_theme_font_override("font",game.fonts);detail.add_theme_font_size_override("font_size",20);detail.add_theme_color_override("font_color",Color("29434a"))
	label(panel,"재료",Vector2(28,259),Vector2(446,40),24)
	var ingredients=ScrollContainer.new();ingredients.position=Vector2(28,305);ingredients.size=Vector2(449,184);ingredients.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(ingredients)
	var list=Control.new();list.custom_minimum_size=Vector2(426,q.materials.size()*36);ingredients.add_child(list)
	var y=0
	for key in q.materials:
		Icons.picture(list,Craft.Data.icon(key),Vector2(0,y+3),Vector2(26,26))
		label(list,"%s  %d / %d"%[Craft.Content.MATERIALS[key],town.player().materials.get(key,0),q.materials[key]],Vector2(36,y),Vector2(386,33),18,1);y+=36
	label(panel,"%d G"%q.cost,Vector2(28,497),Vector2(446,36),23)
	confirm=game.button(panel,"확인 중…" if pending>0 else "장비 제작",Vector2(28,553),Vector2(446,46),craft)
	confirm.disabled=pending>0 or not q.reason.is_empty()
	label(panel,q.reason if not q.reason.is_empty() else notice,Vector2(150,501),Vector2(325,36),16,1)
func craft():
	if pending>0 or selected.is_empty():return
	if game.session.get("network_role")=="client":pending=game.session.sequence+1
	var ok=game.session.act("facility",JSON.stringify({"facility":"smith","operation":"craft_equipment","recipe":selected}))
	if not ok:pending=0
	notice="제작 완료" if ok and pending==0 else "";rebuild()
