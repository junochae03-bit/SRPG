extends Control
const Brief=preload("res://scripts/expedition_brief.gd")
const Art=preload("res://scripts/ui_art.gd")
const Library=preload("res://scripts/icon_library.gd")
const DB=preload("res://scripts/game_database.gd")
var town
var summary:Label
var party:Control
var party_rows=[]
var ready_button:Button
var stamp=""
func setup(owner_town):
	town=owner_town;position=Vector2(746,0);size=Vector2(510,688)
	Art.decorate(self,"paper",6)
	var game=town.game;var info=Brief.floor_info(town.player(),town.selected_floor)
	town.preview={"reason":info.reason,"title":info.name,"result":info.goal+"\n"+info.reward}
	town.wrapped(self,info.name,Vector2(32,26),Vector2(446,68),27,2)
	town.wrapped(self,"권장 LV.%d · %s"%[info.level,"레이드" if info.raid else "자유 탐사"],Vector2(32,100),Vector2(446,30),19,1)
	town.wrapped(self,info.lore,Vector2(32,139),Vector2(446,47),18,2)
	var monsters=info.monsters.duplicate();monsters.append(info.guardian)
	for i in range(mini(6,monsters.size())):
		var id=str(monsters[i]);var row=DB.detail("monsters",id)
		var b=game.button(self,"",Vector2(30+i*75,202),Vector2(68,72),func():town.close();game.codex.open("monsters");game.codex.select_record(id))
		Art.picture(b,DB.asset_texture(row),Vector2(9,6),Vector2(50,57)).material=preload("res://scripts/gat_art.gd").material()
		b.tooltip_text=str(row.get("name",id))+" · 도감"
	Library.picture(self,"boss" if info.raid else "quest",Vector2(30,301),Vector2(29,29))
	town.wrapped(self,info.goal,Vector2(72,298),Vector2(406,38),20,1)
	Library.picture(self,"quest_reward",Vector2(30,345),Vector2(29,29))
	town.wrapped(self,info.reward,Vector2(72,342),Vector2(406,36),18,1)
	summary=town.wrapped(self,"",Vector2(32,398),Vector2(446,62),19,2)
	party=Control.new();party.position=Vector2(32,479);party.size=Vector2(446,108);add_child(party)
	for i in range(6):
		var at=Vector2((i%2)*223,int(i/2)*36)
		var name_label=town.wrapped(party,"",at,Vector2(153,30),17,1)
		var status_label=town.wrapped(party,"",at+Vector2(155,0),Vector2(64,30),16,1)
		party_rows.append({"name":name_label,"status":status_label})
	ready_button=game.button(self,"준비",Vector2(32,613),Vector2(153,49),func():game.session.act("ready","false" if game.session.ready_players.get(game.session.local_id,false) else "true");stamp="";refresh())
	town.confirm_button=game.button(self,"던전 입장",Vector2(202,613),Vector2(276,49),func():if game.session.enter_floor(town.selected_floor):town.close(),true)
	town.review_panel=self;refresh()

func _process(_delta):
	if is_visible_in_tree():refresh()

func refresh():
	var session=town.game.session;var p=town.player()
	if p.is_empty():return
	var pack=Brief.supplies(p);var online=session.get("network_role")!="offline"
	var rows=Brief.party_status(session.state.players,session.ready_players,town.selected_floor) if online else []
	var next=JSON.stringify([pack,rows,session.get("leaving"),p.level,p.highest_floor])
	if next==stamp:return
	stamp=next
	summary.text="물약 %d · 탐사 도구 %d · 가방 여유 %d칸\n무기 %s · 액티브 %d / 6"%[pack.potions,pack.tools,pack.free,"착용" if pack.weapon else "미착용",pack.skills]
	summary.tooltip_text="탐사 도구는 선택 보관실을 열 때만 필요합니다."
	var reason=Brief.floor_info(p,town.selected_floor).reason
	for i in range(party_rows.size()):
		var controls=party_rows[i];var exists=i<rows.size()
		controls.name.visible=exists;controls.status.visible=exists
		if not exists:continue
		var row=rows[i]
		controls.name.text=row.name;controls.name.tooltip_text=row.name
		controls.status.text="잠김" if not row.reason.is_empty() else "준비" if row.ready else "대기"
		controls.status.tooltip_text=row.reason
		controls.status.add_theme_color_override("font_color",Color("98523b") if not row.reason.is_empty() else Color("267466") if row.ready else Color("686b62"))
		if reason.is_empty() and not row.reason.is_empty():reason=row.name+" · "+row.reason
		if reason.is_empty() and rows.size()>1 and not row.ready:reason="파티원 준비 대기"
	party.visible=online;ready_button.visible=online
	ready_button.text="준비 취소" if session.ready_players.get(session.local_id,false) else "출발 준비"
	town.confirm_button.text="방장이 입장" if session.get("network_role")=="client" else "던전 입장"
	town.confirm_button.disabled=not reason.is_empty() or session.get("network_role")=="client" or session.get("leaving")==true
	town.confirm_button.tooltip_text=reason
