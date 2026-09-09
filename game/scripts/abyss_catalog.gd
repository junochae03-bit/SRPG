extends RefCounted
const World=preload("res://scripts/world_catalog.gd")
const BIOMES=[
	{"name":"뿌리 내린 동굴숲","terrain":"forest","mobs":["shade","imp","fairy","rat","goblin_archer"],"elite":"goblin_captain","boss":"warden","title":"뿌리의 문지기","lore":"천장의 마력석 아래에 뿌리내린 지하 숲"},
	{"name":"수정 광맥","terrain":"cave","mobs":["beetle","cave_bat","mole","spider"],"elite":"orc_champion","boss":"golem","title":"광맥의 심장","lore":"수정 가루가 빛나는 거대한 채굴 공동"},
	{"name":"잠긴 회랑","terrain":"ruins","mobs":["frost_slime","skeleton","goblin_shaman","spider"],"elite":"centurion","boss":"sentinel","title":"침수 성채의 파수기사","lore":"지하 호수 위로 드러난 고대 회랑"},
	{"name":"포자 정원","terrain":"forest","mobs":["spider","fairy","goblin_shaman","ember_slime"],"elite":"goblin_captain","boss":"warden","title":"균사의 군주","lore":"거대 수목과 발광 포자가 공생하는 공간"},
	{"name":"잿불 용암굴","terrain":"cave","mobs":["ember_slime","orc_axeman","bat","beetle"],"elite":"orc_champion","boss":"golem","title":"용암 심장 거인","lore":"굳은 현무암 길 아래 용암이 흐르는 화구"},
	{"name":"빙하의 균열","terrain":"cave","mobs":["frost_slime","cave_bat","fox","mole"],"elite":"orc_champion","boss":"golem","title":"영구빙의 지배자","lore":"푸른 얼음과 가라앉은 마력의 결정"},
	{"name":"버려진 기계도시","terrain":"ruins","mobs":["clockwork","spellbook","skeleton","beetle"],"elite":"centurion","boss":"sentinel","title":"철의 지휘관","lore":"마력으로 움직이는 기계가 점령한 공장"},
	{"name":"황혼의 수림","terrain":"forest","mobs":["fox","orc_axeman","goblin_shaman","imp"],"elite":"goblin_captain","boss":"warden","title":"황혼의 고목왕","lore":"마력의 왜곡으로 해가 지지 않는 깊은 숲"},
	{"name":"성운의 공동","terrain":"cave","mobs":["spellbook","frost_slime","spider","clockwork"],"elite":"centurion","boss":"golem","title":"별을 삼킨 거상","lore":"암벽 사이에 별빛 같은 마력 입자가 떠도는 공동"},
	{"name":"뒤틀린 마력핵","terrain":"ruins","mobs":["orc_axeman","skeleton","goblin_shaman","spellbook","clockwork"],"elite":"centurion","boss":"sentinel","title":"심연의 왕 · 아스트라","lore":"100층 최종 레이드. 생태계를 뒤튼 마력의 근원"}]
static func config(floor_number:int)->Dictionary:
	var f=clampi(floor_number,1,100);var c=BIOMES[int((f-1)/10)].duplicate(true)
	c["floor"]=f;c["chapter"]=int((f-1)/10);c["level"]=maxi(3,f);c["raid"]=f%10==0
	c["name"]="B%d · %s"%[f,c.name];return c
static func expected_attack(level:int)->float:return 18.+4.5*(level-1)+6.*int(level/10)
static func enemy_stats(kind:String,floor_number:int,raid:bool=false,guardian:bool=false)->Dictionary:
	var f=clampi(floor_number,1,100);var level=maxi(3,f);var base=World.ENEMIES[kind]
	var bulk=clampf(float(base.health)/130.,.68,1.55);var elite=base.get("elite",false) or guardian
	var hp=expected_attack(level)*(2.6+f*.01)*bulk*(6.3 if elite else 1.7)
	if raid:hp=expected_attack(level)*(80.+f*.7)*3.4*(1.5 if f==100 else 1.)
	var player_hp=120.+18.*(level-1)
	var damage=player_hp*(.09 if not elite else .15)*clampf(float(base.damage)/20.,.65,1.25)
	if raid:damage=player_hp*(.50 if f<100 else .65)
	var xp=preload("res://scripts/progression.gd").xp_required(level)/28.
	return {"health":roundi(hp),"damage":roundi(damage),"xp":roundi(xp*(16 if raid else 4 if elite else 1)),"gold":6+f*2+(f*10 if raid else f*2 if elite else 0),"speed":minf(2.8,float(base.speed)*(1.+f*.002))}
static func raid_grade(floor_number:int,roll:float)->int:
	if floor_number==100 and roll<.12:return 4
	if floor_number>=70 and roll<.04:return 4
	if roll<(.38 if floor_number>=50 else .25):return 3
	return 2
static func locked_reason(p:Dictionary,floor_number:int)->String:
	if floor_number<1 or floor_number>100:return "존재하지 않는 층입니다."
	if not p.get("tutorial_done",false):return "꽃바람 숲 튜토리얼을 마치세요."
	if floor_number>int(p.get("highest_floor",1)):return "이전 층의 수문장 또는 보스를 격파하세요."
	if p.level<maxi(1,floor_number-7):return "입장 LV.%d 필요 · 이전 층에서 성장하세요."%maxi(1,floor_number-7)
	return ""
