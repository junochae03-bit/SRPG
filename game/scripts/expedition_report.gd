extends RefCounted
const Journal=preload("res://scripts/expedition_journal.gd")
const Content=preload("res://scripts/content.gd")
const Icons=preload("res://scripts/icon_library.gd")
const Art=preload("res://scripts/ui_art.gd")

static func build(town,p:Dictionary):
	var report=p.get("expedition_report",{})
	if report.is_empty():
		town.wrapped(town.body,"아직 돌아온 원정이 없습니다.",Vector2(22,112),Vector2(678,60),25,2)
		return
	var minutes=int(float(report.elapsed)/60.);var seconds=int(report.elapsed)%60
	town.wrapped(town.body,"B%d → B%d   ·   %d분 %02d초"%[report.first_floor,report.deepest_floor,minutes,seconds],Vector2(22,85),Vector2(674,43),27,1)
	var metrics=[["gold","금화 변화","%+d G"%report.gold_delta],["experience","획득 경험치",str(report.xp)],["physical_attack","처치한 적",str(report.kills)],["chest","가져온 새 장비","%d개"%report.gear_count],["floor","돌파한 새 층","%d층"%report.unlocked],["potion","회복 물약 변화","%+d개"%report.potions_delta]]
	for index in range(metrics.size()):
		var row=metrics[index];var at=Vector2(22+(index%2)*351,159+int(index/2)*105)
		Icons.picture(town.body,row[0],at+Vector2(0,5),Vector2(35,35))
		town.wrapped(town.body,row[1],at+Vector2(49,0),Vector2(275,29),19,1)
		town.wrapped(town.body,row[2],at+Vector2(49,34),Vector2(275,42),28,1)
	town.wrapped(town.body,"재료 변화",Vector2(22,494),Vector2(674,34),23,1)
	var changes=PackedStringArray()
	for key in report.materials_delta:changes.append(Content.MATERIALS[key]+" %+d"%int(report.materials_delta[key]))
	town.wrapped(town.body," · ".join(changes) if not changes.is_empty() else "변화 없음",Vector2(22,547),Vector2(674,81),21,3)
	var panel=Art.panel(town.body,Vector2(746,0),Vector2(510,688),"paper",6)
	town.review_panel=panel
	town.wrapped(panel,"다음 준비",Vector2(32,29),Vector2(446,60),28,1)
	var rows=Journal.recommendations(p)
	for index in range(rows.size()):
		var row=rows[index];var at=Vector2(29,106+index*179)
		Icons.picture(panel,row.facility,at,Vector2(42,42))
		town.wrapped(panel,row.title,at+Vector2(57,0),Vector2(370,35),22,1)
		town.wrapped(panel,row.detail,at+Vector2(0,53),Vector2(446,35),18,1)
		var button=town.game.button(panel,"위치 안내",at+Vector2(231,103),Vector2(216,44),func():town.close();town.game.guide_to_facility(row.facility))
		button.set_meta("destination",row.facility)
