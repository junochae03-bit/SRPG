extends Control
const Balance=preload("res://scripts/job_balance.gd")
const Art=preload("res://scripts/ui_art.gd")
const Jobs=preload("res://scripts/job_combat.gd")
const Icons=preload("res://scripts/icon_library.gd")
var game
var p={}
var heading:Label
var hint:Label
var emblem:TextureRect
var hint_icon:TextureRect
var content_draw_rects:Array=[]
func content_bounds()->Rect2:return Rect2(36,40,size.x-72,size.y-64)
func setup(owner_game):
	game=owner_game;size=Vector2(430,200);mouse_filter=Control.MOUSE_FILTER_IGNORE
	Art.decorate(self,"magic",22)
	emblem=Icons.picture(self,"class_warrior",Vector2(36,40),Vector2(28,28))
	heading=game.label(self,"",Vector2(75,40),Vector2(315,28),18,Color("fff0cf"))
	heading.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	hint_icon=Icons.picture(self,"info",Vector2(36,151),Vector2(20,20))
	hint=game.label(self,"",Vector2(65,149),Vector2(324,25),14,Color("e9eedc"));hint.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
func refresh(player:Dictionary):
	p=player
	emblem.texture=Icons.texture("class_"+p.class_id)
	hint_icon.texture=Icons.texture("info")
	heading.text=preload("res://scripts/content.gd").CLASSES[p.class_id].name
	var s=p.job_state
	hint.text=""
	tooltip_text=game.session.sim.combat.jobs.resource_text(p)+"\n"+Balance.role(p.class_id)[1]
	if p.class_id=="gambler" and not s.get("candidates",[]).is_empty():hint.text="후보 선택 · TAB / 평타로 확정";hint_icon.texture=Icons.texture("card_hand")
	if not s.get("casting",{}).is_empty():hint.text=s.casting.node.name+"  ·  시전 %.1f초"%s.casting.time;hint_icon.texture=Icons.texture("charge")
	visible=p.class_id in ["runesword","infighter","martialist","breaker","gambler","reaper","summoner","hunter"] or s.shield>0 or not s.buffs.is_empty() or not hint.text.is_empty()
	hint.visible=not hint.text.is_empty();hint_icon.visible=hint.visible
	queue_redraw()
func write(at:Vector2,value:String,font_size:int=16,color:Color=Color("fff0cf")):
	var dimensions=game.fonts.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	content_draw_rects.append(Rect2(at-Vector2(0,game.fonts.get_ascent(font_size)),Vector2(dimensions.x,game.fonts.get_ascent(font_size)+game.fonts.get_descent(font_size))).grow(2))
	draw_string_outline(game.fonts,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,2,Color("243d39"))
	draw_string(game.fonts,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
func icon(key:String,rect:Rect2,tint:Color=Color.WHITE):
	content_draw_rects.append(rect);Icons.draw(self,key,rect,tint)
func pips(label:String,amount:int,maximum:int,key:String):
	icon(key,Rect2(36,81,23,23))
	write(Vector2(70,102),label+"  %d / %d"%[amount,maximum],17)
	for i in range(maximum):
		var center=Vector2(47+i*minf(32,(content_bounds().size.x-22)/maxi(1,maximum-1)),130)
		icon(key,Rect2(center-Vector2(11,11),Vector2(22,22)),Color.WHITE if i<amount else Color(.48,.44,.4,.55))
func _draw():
	content_draw_rects.clear()
	if p.is_empty():return
	var s=p.job_state
	match p.class_id:
		"runesword":pips("룬",s.runes,6+Balance.passive(p,0),"rune")
		"infighter":pips("몰아침",s.rush,10,"rush_resource")
		"martialist":pips("연무 · 다른 기술 적중",s.combo,3,"combo_resource")
		"breaker":
			icon("momentum",Rect2(36,81,23,23));icon("counter" if s.counter>0 else "guard",Rect2(36,113,23,23))
			write(Vector2(70,102),"기세 %d  +  피격 %d"%[s.momentum,Jobs.grit(p)],17)
			write(Vector2(70,135),"반격 준비" if s.counter>0 else "반격 대기",16,Color("8de3d0") if s.counter>0 else Color("d9e1d8"))
			meter(Rect2(217,123,172,8),(s.momentum+Jobs.grit(p))/100.)
		"gambler":cards(s)
		"reaper":
			icon("charge" if s.instant>0 else "chain",Rect2(36,81,23,23))
			write(Vector2(70,102),"즉결 강공격 · %.1f초"%s.instant if s.instant>0 else "즉결 대기",17)
			if s.instant>0:write(Vector2(70,135),"강공격 차지 생략",15,Color("8de3d0"))
		"summoner","hunter":
			var alive=s.pets.filter(func(pet):return pet.hp>0)
			icon("companion",Rect2(36,81,23,23));write(Vector2(70,102),"동료 %d"%alive.size(),17)
			icon("shield",Rect2(210,81,23,23));write(Vector2(244,102),"보호막 %d"%s.shield,17)
			var width=(content_bounds().size.x-maxi(0,alive.size()-1)*8)/maxi(1,alive.size())
			for i in range(alive.size()):meter(Rect2(36+i*(width+8),125,width,9),alive[i].hp/alive[i].get("max_hp",100.))
			if p.class_id=="hunter" and s.get("hound_respawn",0)>0:write(Vector2(38,139),"사냥개 복귀 %.1f초"%s.hound_respawn,15)
		_:
			icon("shield",Rect2(36,81,23,23));write(Vector2(70,102),"보호막 %d"%s.shield,17,Color("b8eed8"))
			icon("rune",Rect2(222,81,23,23));write(Vector2(256,102),"강화 %d"%s.buffs.size(),17,Color("b8eed8"))
func meter(rect:Rect2,ratio:float):
	content_draw_rects.append(rect)
	draw_rect(rect,Color("18262f"));draw_rect(Rect2(rect.position,Vector2(rect.size.x*clampf(ratio,0,1),rect.size.y)),Color("85dab9"))
func cards(s:Dictionary):
	var hand=s.get("candidates",[]) if not s.get("candidates",[]).is_empty() else s.hand
	for i in range(hand.size()):
		var rect=Rect2(40+i*44,81,37,54);var selected=i==int(s.get("candidate_index",0) if not s.get("candidates",[]).is_empty() else s.selected)
		content_draw_rects.append(rect.grow(2))
		draw_texture_rect(Art.texture("paper"),rect,false)
		if selected:draw_texture_rect(Art.texture("rare"),rect.grow(2),false,Color(1,1,1,.5))
		if selected:icon("selected",Rect2(rect.position+Vector2(-4,-6),Vector2(15,15)))
		var face=["A","2","3","4","5","6","7","8","9","10","J","Q","K"][int(hand[i])%13]
		write(rect.position+Vector2(11,25),face,18,Color("744832"))
		write(rect.position+Vector2(11,42),["♠","♥","♣","♦"][int(hand[i])/13],12,Color("744832"))
		if hand[i]==s.held:icon("card_hold",Rect2(rect.position+Vector2(27,-6),Vector2(15,15)))
	icon("card_hand",Rect2(276,81,20,20))
	write(Vector2(305,102),"합계 %d"%Jobs.hand_total(s.hand),17)
	write(Vector2(278,132),"정산 ×%.2f"%Jobs.payout(s.hand),16,Color("b8eed8"))
	if s.get("candidates",[]).is_empty() and hint.text.is_empty():
		icon("card_draw",Rect2(36,151,18,18));write(Vector2(62,166),"덱 %d"%s.deck.size(),14)
		icon("card_discard",Rect2(138,151,18,18));write(Vector2(164,166),"버림 %d"%s.discard.size(),14)
		icon("dice",Rect2(263,151,18,18));write(Vector2(289,166),"주사위 %s"%(str(s.dice) if s.dice_time>0 else "—"),14)
