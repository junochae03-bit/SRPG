extends Control
const Balance=preload("res://scripts/job_balance.gd")
const Art=preload("res://scripts/ui_art.gd")
const Jobs=preload("res://scripts/job_combat.gd")
var game
var p={}
var heading:Label
var hint:Label
func setup(owner_game):
	game=owner_game;size=Vector2(405,180);mouse_filter=Control.MOUSE_FILTER_STOP
	Art.decorate(self,"magic",22)
	Art.picture(self,Art.texture("crest"),Vector2(12,13),Vector2(43,43))
	heading=game.label(self,"",Vector2(62,17),Vector2(323,28),19,Color("fff0cf"))
	hint=game.label(self,"",Vector2(21,136),Vector2(363,31),13,Color("c7e6de"));hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
func refresh(player:Dictionary):
	p=player
	heading.text=preload("res://scripts/content.gd").CLASSES[p.class_id].name+(" · 전투 중" if p.combat_time>0 else " · 전투 준비")
	var s=p.job_state
	hint.text=Balance.role(p.class_id)[1]
	tooltip_text=game.session.sim.combat.jobs.resource_text(p)+"\n"+hint.text
	if p.class_id=="gambler":hint.text="TAB 선택 · 평타 교체 · 정산으로 패 소비"
	if not s.get("casting",{}).is_empty():hint.text="시전 중 · "+s.casting.node.name+"  %.1f초"%s.casting.time
	elif p.charge_time>=0:hint.text="강공격 충전 %d%% · RMB를 놓아 발동"%clampi(p.charge_time/.9*100,0,100)
	queue_redraw()
func write(at:Vector2,value:String,font_size:int=16,color:Color=Color("fff0cf")):
	draw_string(game.fonts,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
func pips(label:String,amount:int,maximum:int):
	write(Vector2(23,76),label+"  %d / %d"%[amount,maximum])
	for i in range(maximum):
		var center=Vector2(31+i*minf(32,338./maximum),107)
		draw_texture_rect(Art.texture("medallion"),Rect2(center-Vector2(11,11),Vector2(22,22)),false,Color.WHITE if i<amount else Color(.45,.5,.55,.7))
		if i<amount:draw_circle(center,4,Color("7ee7d0"))
func _draw():
	if p.is_empty():return
	var s=p.job_state
	match p.class_id:
		"runesword":pips("룬",s.runes,6+Balance.passive(p,0))
		"infighter":pips("몰아침",s.rush,10)
		"martialist":pips("연무 · 다른 기술 적중",s.combo,3)
		"breaker":
			write(Vector2(23,74),"기세 %d  +  피격 %d"%[s.momentum,Jobs.grit(p)])
			write(Vector2(23,103),"반격 준비" if s.counter>0 else "정면 패링으로 반격 준비",16,Color("8de3d0") if s.counter>0 else Color("c7d1cf"))
			meter(Rect2(23,115,353,7),(s.momentum+Jobs.grit(p))/100.)
		"gambler":cards(s)
		"reaper":
			write(Vector2(23,78),"즉결 강공격 준비 · %.1f초"%s.instant if s.instant>0 else "사슬 적중 → 즉결 강공격",19)
			write(Vector2(23,113),"차지 생략 가능" if s.instant>0 else "긴 차지를 사슬로 줄이세요",15,Color("8de3d0"))
		"summoner","hunter":
			var alive=s.pets.filter(func(pet):return pet.hp>0)
			write(Vector2(23,75),"동료 %d · 보호막 %d"%[alive.size(),s.shield])
			for i in range(alive.size()):meter(Rect2(23+i*115,96,104,9),alive[i].hp/alive[i].get("max_hp",100.))
			if p.class_id=="hunter" and s.get("hound_respawn",0)>0:write(Vector2(23,119),"사냥개 복귀 %.1f초"%s.hound_respawn,14)
		_:
			write(Vector2(23,78),Balance.role(p.class_id)[0].split(" · ")[-1],18)
			write(Vector2(23,113),"보호막 %d  ·  강화 효과 %d"%[s.shield,s.buffs.size()],15,Color("8de3d0"))
	if p.charge_time>=0:meter(Rect2(23,127,353,5),p.charge_time/.9)
func meter(rect:Rect2,ratio:float):
	draw_rect(rect,Color("18262f"));draw_rect(Rect2(rect.position,Vector2(rect.size.x*clampf(ratio,0,1),rect.size.y)),Color("85dab9"))
func cards(s:Dictionary):
	var hand=s.get("candidates",[]) if not s.get("candidates",[]).is_empty() else s.hand
	for i in range(hand.size()):
		var rect=Rect2(23+i*46,53,39,53);var selected=i==int(s.get("candidate_index",0) if not s.get("candidates",[]).is_empty() else s.selected)
		draw_texture_rect(Art.texture("paper"),rect,false)
		if selected:draw_texture_rect(Art.texture("rare"),rect.grow(2),false,Color(1,1,1,.5))
		var face=["A","2","3","4","5","6","7","8","9","10","J","Q","K"][int(hand[i])%13]
		write(rect.position+Vector2(11,25),face,18,Color("744832"))
		write(rect.position+Vector2(11,42),"★" if hand[i]==s.held else ["♠","♥","♣","♦"][int(hand[i])/13],12,Color("744832"))
	write(Vector2(267,75),"합계 %d"%Jobs.hand_total(s.hand),18)
	write(Vector2(267,98),"정산 ×%.2f"%Jobs.payout(s.hand),15,Color("8de3d0"))
	write(Vector2(23,126),"후보 선택 · 평타로 확정" if not s.get("candidates",[]).is_empty() else "덱 %d · 버림 %d · 주사위 %s"%[s.deck.size(),s.discard.size(),str(s.dice) if s.dice_time>0 else "—"],14)
