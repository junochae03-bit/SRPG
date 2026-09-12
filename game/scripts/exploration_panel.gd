extends Control

const Rooms=preload("res://scripts/exploration_rooms.gd")
const Icons=preload("res://scripts/icon_library.gd")
var game
var card:Control
var emblem:TextureRect
var heading:Label
var detail:Label
var first:Button
var second:Button
var active:Dictionary={}
var pending=0
var last_context:Array=[]

func setup(owner_game):
	game=owner_game;mouse_filter=Control.MOUSE_FILTER_IGNORE
	card=preload("res://scripts/ui_art.gd").panel(self,Vector2(447,558),Vector2(540,175),"paper",5)
	card.mouse_filter=Control.MOUSE_FILTER_STOP
	emblem=Icons.picture(card,"ore",Vector2(20,22),Vector2(62,62))
	heading=game.label(card,"",Vector2(99,18),Vector2(412,37),25)
	detail=game.label(card,"",Vector2(100,62),Vector2(413,33),18)
	first=game.button(card,"",Vector2(26,112),Vector2(236,42),func():choose(0))
	second=game.button(card,"",Vector2(277,112),Vector2(236,42),func():choose(1))
	if game.session.has_signal("request_completed"):game.session.request_completed.connect(completed)
	hide()

func completed(kind:String,_success:bool):
	if kind=="explore" and game.session.completed_sequence==pending:pending=0;last_context=[]

func choose(index:int):
	if pending>0 or active.is_empty():return
	var choices=["collect" if active.get("opened",false) else "open"] if active.kind=="secret" else Rooms.DEFINITIONS[active.kind].choices
	if index>=choices.size():return
	var remote=game.session.get("network_role")=="client"
	if remote:pending=game.session.sequence+1
	if not game.session.act("explore",active.generation+":"+active.id+":"+str(choices[index])):pending=0
	last_context=[]

func _process(_delta):
	if game==null:return
	if not game.session.connected:pending=0;hide();return
	if game.session.paused or game.hud.chrome_hidden:hide();return
	var p=game.session.state.players.get(game.session.local_id,{})
	if p.is_empty() or p.hp<=0:hide();return
	active=Rooms.nearest(game.session.state.get("exploration_sites",[]),p.pos)
	if active.is_empty() or active.claimed:hide();return
	show()
	var context=[active.generation,active.id,active.kind,active.name,active.icon,active.material,active.remaining,active.tier,p.hp,p.max_hp,p.potions,p.stamina,p.max_stamina,pending]
	context.append(active.get("opened",false));context.append(p.get("materials",{}).get("tool",0))
	if context==last_context:return
	last_context=context
	emblem.texture=Icons.texture(active.icon);heading.text=active.name
	var blocked=active.remaining>0
	detail.text="주변 적 %d"%active.remaining if blocked else "각자 한 번 이용" if game.session.state.players.size()>1 else ""
	first.disabled=blocked or pending>0;second.disabled=blocked or pending>0;second.visible=active.kind=="shrine"
	match active.kind:
		"secret":
			first.size.x=487
			first.text="보물 회수 · 정수 +%d"%(3+int(active.tier)) if active.opened else "봉인 해제 · 탐사 도구 1" if active.tool else "틈새 열기"
			if not blocked:detail.text="금화 +%d"%(40+active.tier*20) if active.opened else "보유 도구 %d"%p.get("materials",{}).get("tool",0) if active.tool else "벽 너머에 숨겨진 공간"
			first.disabled=first.disabled or (not active.opened and active.tool and p.get("materials",{}).get("tool",0)<1)
		"gather":
			first.text="채집 · %s +%d"%[Rooms.Content.MATERIALS[active.material],3+int(active.tier)]
			first.size.x=487
		"rest":
			first.text="휴식 · 생명력과 기력 회복";first.size.x=487
			first.disabled=first.disabled or (p.hp>=p.max_hp and p.stamina>=p.max_stamina)
			if not blocked:detail.text="HP %d / %d"%[p.hp,p.max_hp]
		"shrine":
			first.size.x=236;first.text="생명력 +35%";second.text="물약 1 → 정수 %d"%(2+int(active.tier))
			first.disabled=first.disabled or p.hp>=p.max_hp;second.disabled=second.disabled or p.potions<1
			if not blocked:detail.text="택 1 · 보유 물약 %d"%p.potions
	if pending>0:detail.text="선택 확인 중…"
