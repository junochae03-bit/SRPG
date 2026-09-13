extends "res://scripts/job_resource_hud.gd"
## A compact view of real class state. No presentation-only combat resources.
const BUFF_ICONS={"attack":"physical_attack","crit":"critical","crit_damage":"critical_damage","haste":"attack_speed","speed":"agility","guard":"shield"}
func setup(owner_game):
	game=owner_game;size=Vector2(546,112);mouse_filter=Control.MOUSE_FILTER_STOP
	heading=game.label(self,"",Vector2(42,4),Vector2(470,30),17,Color("fff0cf"))
	emblem=Icons.picture(self,"class_warrior",Vector2(10,6),Vector2(25,25))
	hint=game.label(self,"",Vector2(12,84),Vector2(520,26),14,Color("b8eed8"));hint.hide()
	hint_icon=Icons.picture(self,"info",Vector2.ZERO,Vector2(1,1));hint_icon.hide()
func content_bounds()->Rect2:return Rect2(2,2,size.x-4,size.y-4)
func refresh(player:Dictionary):
	p=player;display_mode=1
	heading.text=preload("res://scripts/content.gd").CLASSES[p.class_id].name
	emblem.texture=Icons.texture("class_"+p.class_id)
	var s=p.job_state;size.y=216 if p.class_id=="gambler" and not s.get("candidates",[]).is_empty() else 138 if p.class_id=="gambler" else 112
	tooltip_text=game.session.sim.combat.jobs.resource_text(p)+"\n"+Balance.role(p.class_id)[1]
	if p.class_id=="infighter":tooltip_text+="\n몰아침 %.1f초 · 회피 충전 %.1f초"%[s.rush_time,s.dash_timer]
	var aftereffects=preload("res://scripts/revival_aftereffects.gd").summary(p)
	if not aftereffects.is_empty():tooltip_text+="\n"+aftereffects
	hint.hide();hint_icon.hide();visible=true;queue_redraw()
func row(text:String,key:String="info",value:String=""):
	icon(key,Rect2(12,43,25,25));write(Vector2(46,63),text,17)
	if not value.is_empty():write(Vector2(360,63),value,16,Color("b8eed8"))
func resource(label:String,amount:int,maximum:int,key:String):
	row(label,key,"%d / %d"%[amount,maximum])
	for i in range(maximum):icon(key,Rect2(14+i*minf(33,510./maxi(1,maximum)),79,23,23),Color.WHITE if i<amount else Color(.45,.45,.45,.45))
func _draw():
	content_draw_rects.clear()
	if p.is_empty():return
	draw_line(Vector2(8,34),Vector2(size.x-8,34),Color("bd9b6570"),1)
	var s=p.job_state
	if p.class_id=="gambler":draw_cards(s);return
	match p.class_id:
		"runesword":resource("룬",s.runes,6+Balance.passive(p,0),"rune")
		"infighter":
			resource("몰아침",s.rush,10,"rush_resource")
			write(Vector2(360,98),"회피 %d / 2"%s.dash_charges,16)
		"martialist":
			resource("연무",s.combo,3,"combo_resource")
			if s.combo_time>0:write(Vector2(160,98),"%.1f초"%s.combo_time,16)
		"breaker":
			row("기세 %d + 피격 %d"%[s.momentum,Jobs.grit(p)],"momentum","반격 %.1f초"%s.counter if s.counter>0 else "반격 대기")
			meter(Rect2(14,88,514,9),(s.momentum+Jobs.grit(p))/100.)
		"reaper":row("즉결 준비" if s.instant>0 else "즉결 대기","charge","%.1f초"%s.instant if s.instant>0 else "")
		"summoner","hunter":
			var alive=s.pets.filter(func(pet):return pet.hp>0)
			row("동료 %d"%alive.size(),"companion","복귀 %.1f초"%s.hound_respawn if s.get("hound_respawn",0)>0 else "")
			var width=(514.-maxi(0,alive.size()-1)*8)/maxi(1,alive.size())
			for i in range(alive.size()):meter(Rect2(14+i*(width+8),88,width,9),alive[i].hp/maxf(1,alive[i].get("max_hp",100.)))
		"thief":
			var marks=0
			for id in s.marks:
				var enemy=game.session.state.enemies.get(int(id),{})
				if not enemy.is_empty() and enemy.hp>0 and game.vision.sees(enemy.pos) and float(s.marks[id])>0:marks+=1
			row("표식 %d"%marks,"mark")
		_:
			var casting=s.get("casting",{})
			if not casting.is_empty():row(casting.node.name,"charge","%.1f초"%casting.time)
			elif s.shield>0:row("보호막 %d"%s.shield,"shield","%.1f초"%s.shield_time)
			elif p.class_id=="swordsman" and Balance.passive(p,2)>0:row("집중 공격 %d / 5"%int(s.get("same_hits",0)),"physical_attack")
			else:row(Balance.role(p.class_id)[0],"class_"+p.class_id)
			var i=0
			for key in s.buffs:
				if float(s.buffs[key].time)<=0:continue
				if i>=8:break
				icon(BUFF_ICONS.get(key,"rune"),Rect2(14+i*62,79,23,23));write(Vector2(39+i*62,98),str(ceili(s.buffs[key].time)),12);i+=1
func card(value:int,rect:Rect2,chosen:bool,held:bool):
	content_draw_rects.append(rect)
	draw_texture_rect(Art.plain_paper(),rect,false)
	draw_rect(rect,Color("e6c274") if chosen else Color("8b795c"),false,2 if chosen else 1)
	write(rect.position+Vector2(9,22),["A","2","3","4","5","6","7","8","9","10","J","Q","K"][value%13],17,Color("523c32"))
	write(rect.position+Vector2(10,41),["♠","♥","♣","♦"][int(value/13)],13,Color("ab3b31") if int(value/13) in [1,3] else Color("343d42"))
	if held:icon("card_hold",Rect2(rect.position+Vector2(23,-3),Vector2(16,16)))
func draw_cards(s:Dictionary):
	for i in range(s.hand.size()):card(int(s.hand[i]),Rect2(12+i*44,42,37,52),i==int(s.selected),s.hand[i]==s.held)
	write(Vector2(252,62),"합계 %d"%Jobs.hand_total(s.hand),18,Color("ffa69a") if Jobs.hand_total(s.hand)>21 else Color("fff0cf"))
	write(Vector2(252,87),"정산 ×%.2f"%Jobs.payout(s.hand),16)
	write(Vector2(12,119),"덱 %d · 버림 %d"%[s.deck.size(),s.discard.size()],14)
	if s.dice_time>0:write(Vector2(365,62),"주사위 %d"%s.dice,16);write(Vector2(365,86),"%.1f초"%s.dice_time,14)
	if int(s.get("peek",-1))>=0:card(int(s.peek),Rect2(478,42,37,52),false,false)
	if not s.get("candidates",[]).is_empty():
		for i in range(s.candidates.size()):card(int(s.candidates[i]),Rect2(12+i*44,145,37,52),i==int(s.get("candidate_index",0)),false)
		write(Vector2(115,168),"후보 선택 · "+game.keybindings.label("card_next"),15)
		write(Vector2(115,192),"기본 공격으로 확정",14,Color("b8eed8"))
