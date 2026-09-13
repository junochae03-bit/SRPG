extends RefCounted
const Guild=preload("res://scripts/guild_progression.gd")
const Art=preload("res://scripts/ui_art.gd")
const Icons=preload("res://scripts/icon_library.gd")
static func build(town,p:Dictionary):
	var rank=Guild.rank(p);var reputation=int(p.get("guild_reputation",0))
	var header=Art.panel(town.body,Vector2(0,64),Vector2(1254,104),"paper",4)
	Icons.picture(header,"guild",Vector2(22,25),Vector2(48,48))
	town.wrapped(header,Guild.RANKS[rank].name+" 모험가",Vector2(86,14),Vector2(460,44),27,1)
	var next="최고 등급" if rank==2 else "다음 등급 · "+Guild.RANKS[rank+1].name+" %d / %d"%[reputation,Guild.RANKS[rank+1].required]
	town.wrapped(header,"길드 평판 %d · %s"%[reputation,next],Vector2(86,58),Vector2(1115,31),20,1)
	var contracts=Art.panel(town.body,Vector2(0,184),Vector2(614,500),"paper",4)
	var services=Art.panel(town.body,Vector2(638,184),Vector2(616,500),"paper",4)
	town.wrapped(contracts,"등급 의뢰",Vector2(24,16),Vector2(560,45),26,1)
	town.wrapped(services,"길드 보급",Vector2(24,16),Vector2(560,45),26,1)
	var index=0
	for key in Guild.CONTRACTS:
		var row=Guild.CONTRACTS[key];var y=80+index*134
		var button=town.game.button(contracts,"",Vector2(20,y),Vector2(572,120),func():town.choose("accept",{"contract_kind":key}))
		Icons.picture(button,row.icon,Vector2(18,30),Vector2(46,46))
		town.wrapped(button,row.name,Vector2(82,13),Vector2(454,36),23,1)
		town.wrapped(button,"%d회 · %d G 또는 평판 %d"%[row.target,row.gold,row.reputation],Vector2(82,51),Vector2(454,30),18,1)
		var locked=rank<row.rank
		Icons.picture(button,"locked" if locked else "success",Vector2(82,86),Vector2(22,22))
		town.wrapped(button,Guild.RANKS[row.rank].name+" 필요" if locked else "해금됨",Vector2(112,85),Vector2(424,26),17,1)
		button.disabled=rank<row.rank or not p.guild_contract.is_empty();button.tooltip_text="진행 중인 의뢰를 먼저 정산하세요." if not p.guild_contract.is_empty() else Guild.RANKS[row.rank].name+" 등급 필요" if rank<row.rank else "의뢰 지역 선택"
		button.set_meta("contract_kind",key);index+=1
	index=0
	for key in Guild.SERVICES:
		var row=Guild.SERVICES[key];var y=80+index*194;var quote=Guild.quote(p,key)
		var button=town.game.button(services,"",Vector2(20,y),Vector2(574,177),func():town.choose(key))
		Icons.picture(button,row.icon,Vector2(18,24),Vector2(46,46))
		town.wrapped(button,row.name,Vector2(83,16),Vector2(457,37),23,1)
		var outputs=[]
		for item in row.outputs:outputs.append(preload("res://scripts/town_operations.gd").LABELS[item]+" %d"%row.outputs[item])
		town.wrapped(button," · ".join(outputs),Vector2(83,61),Vector2(457,59),18,2)
		var locked=rank<row.rank
		Icons.picture(button,"locked" if locked else "success",Vector2(83,130),Vector2(22,22))
		var state=Guild.RANKS[row.rank].name+" 필요" if locked else "해금됨"
		town.wrapped(button,"%s · %d G · 비용 확인"%[state,row.gold],Vector2(113,128),Vector2(427,30),18,1)
		button.disabled=rank<row.rank;button.tooltip_text=quote.reason;button.set_meta("guild_service",key);index+=1
