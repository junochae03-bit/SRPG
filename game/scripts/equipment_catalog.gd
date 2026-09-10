extends RefCounted
const Content=preload("res://scripts/content.gd")
const BASES={
	"sword":["여행자의 검","청동 장검","수정 세이버","여명의 은검","별자리 성검"],
	"axe":["나무꾼 도끼","강철 전투도끼","수정 양날도끼","사자의 도끼","태양 분쇄자"],
	"bow":["단풍나무 활","정찰자의 장궁","수정 복합궁","매의 저격궁","유성의 활"],
	"staff":["견습생 지팡이","나뭇잎 완드","수정 홀","달빛 마법봉","천체의 지팡이"],
	"head":["여행자 모자","강철 투구","수정 왕관","별수호자의 투구","여명의 관"],
	"chest":["여행자 조끼","강철 갑옷","수정 로브","별수호자의 갑옷","여명의 예복"],
	"hands":["천 장갑","강철 건틀릿","수정 장갑","정밀 사격 장갑","여명의 손길"],
	"legs":["여행자 바지","강철 각반","수정 바지","바람 사냥꾼 각반","여명의 각반"],
	"feet":["여행자 신발","강철 장화","수정 구두","바람걸음 장화","여명의 발걸음"],
	"accessory":["씨앗 목걸이","호박 브로치","수정 반지","별의 귀걸이","새벽빛 펜던트"]}
const SHOP_TYPES=["sword","head","chest","hands","legs","feet","accessory"]
const GRADES=["일반","레어","유니크","에픽","레전드리"]
const COLORS=[Color("d5ddd8"),Color("5aa8ed"),Color("c58ded"),Color("ecca61"),Color("f18a47")]
const UNLOCK=[0,2,3,4,5]
const FAMILY_NAMES={"warrior":"전사","mage":"마법사","ranger":"궁수","rogue":"도적","fighter":"격투가"}
const WEAPON_NAMES={"warrior":"장검","mage":"지팡이","ranger":"사냥활","rogue":"단검","fighter":"너클","tank":"수호검","swordsman":"결투검","runesword":"룬블레이드","summoner":"소환의 홀","elementalist":"원소 지팡이","healer":"치유의 성물","sniper":"저격궁","hunter":"사냥꾼 활","explorer":"탐사궁","thief":"쌍단검","reaper":"사슬낫","gambler":"마력 카드","infighter":"전투 건틀릿","breaker":"파쇄권","martialist":"연무권"}
const AFFIXES={"none":{"name":"","stat":"none","value":0},"vigor":{"name":"인내의 ","stat":"endurance","value":3},"focus":{"name":"완력의 ","stat":"strength","value":3},"guard":{"name":"숙련의 ","stat":"technique","value":3},"breath":{"name":"신속의 ","stat":"agility","value":3},"fortune":{"name":"마력의 ","stat":"magic","value":3}}
const RESONANCE={"force":"스킬 위력·회복·보호막","reach":"스킬 사거리·범위","echo":"스킬 지속시간·지원 효과"}
static func make(type:String,tier:int,rarity:int,id:String,affix:String="none",job_id:String="warrior")->Dictionary:
	Content.initialize_jobs();tier=clampi(tier,0,9);rarity=clampi(rarity,0,4)
	var weapon=type in Content.WEAPONS;var family=Content.base_class(job_id)
	if weapon:type=Content.CLASSES[job_id].weapon
	var prefix=["여행자의","청동","수정","은빛","별자리","심층","화염문양","빙하","성운","마력핵"][tier]
	var name=prefix+" "+WEAPON_NAMES[job_id] if weapon else prefix+" "+FAMILY_NAMES[family]+"의 "+BASES[type][mini(4,tier/2)]
	name=preload("res://scripts/content_names.gd").equipment("weapon" if weapon else type,job_id if weapon else family,tier,name)
	var item={"id":id,"name":name,"base_name":name,"category":"weapon" if weapon else "accessory" if type=="accessory" else "armor","slot":"weapon" if weapon else type,"weapon_type":type if weapon else "sword","bonus":(tier*6+rarity*4+4) if weapon else tier*3+rarity*2+2,"rarity":rarity,"tier":tier,"affix":"none" if rarity==0 else (affix if affix!="none" else "focus"),"upgrade":0,"family":family,"job_lock":job_id if weapon else "","required_level":maxi(1,tier*10),"resonance":["force","reach","echo"][absi(id.hash())%3] if rarity>=3 else ""}
	return item
static func normalize(item:Dictionary,p:Dictionary):
	Content.normalize_item(item)
	if not item.has("family"):item.family=Content.base_class(p.get("class_id","warrior"))
	if not item.has("job_lock"):item.job_lock=p.get("class_id","warrior") if item.category=="weapon" else ""
	if not item.has("required_level"):item.required_level=1
	if not item.has("resonance"):item.resonance="force" if item.rarity>=3 else ""
	if item.rarity==0:item.affix="none"
	elif item.rarity<3 and item.get("affix","none")=="none":item.affix="fortune" if item.family=="mage" else "focus"
	if item.get("category","") in ["weapon","armor","accessory"]:
		var base=preload("res://scripts/content_names.gd").equipment(str(item.get("slot","weapon")),str(item.job_lock if item.category=="weapon" else item.family),int(item.get("tier",0)),str(item.get("base_name",item.get("name",""))))
		item.base_name=base
		item.name=AFFIXES.get(item.get("affix","none"),AFFIXES.none).name+base+(" +"+str(item.upgrade) if int(item.get("upgrade",0))>0 else "")
static func reason(p:Dictionary,item:Dictionary)->String:
	if item.get("category","") not in ["weapon","armor","accessory"]:return "장비가 아닙니다."
	if int(p.get("level",1))<int(item.get("required_level",1)):return "LV.%d부터 착용"%item.required_level
	if item.get("category")=="weapon" and item.get("job_lock",p.get("class_id","warrior"))!=p.get("class_id","warrior"):return "무기 전용 직업: "+Content.CLASSES.get(item.get("job_lock",""),{}).get("name","알 수 없음")
	if item.get("family",Content.base_class(p.get("class_id","warrior")))!=Content.base_class(p.get("class_id","warrior")):return FAMILY_NAMES.get(item.get("family",""),"")+" 계열 전용"
	return ""
static func active(item:Dictionary)->bool:return int(item.get("rarity",0))>0 and int(item.get("upgrade",0))>=UNLOCK[clampi(int(item.get("rarity",0)),0,4)]
static func equipped(p:Dictionary)->Array:
	return p.get("inventory",[]).filter(func(i):return p.get("equipment",{}).values().has(i.id) and reason(p,i).is_empty())
static func stat_values(p:Dictionary)->Dictionary:
	var values={}
	for item in equipped(p):
		if not active(item) or item.rarity>=3:continue
		var affix=AFFIXES.get(item.get("affix","none"),AFFIXES.none)
		if affix.stat!="none":values[affix.stat]=int(values.get(affix.stat,0))+3*int(item.rarity)+int(item.get("tier",0))*2
	return values
static func bonus(_p:Dictionary,_stat:String)->float:return 0.
static func skill_modifiers(p:Dictionary)->Dictionary:
	var mods={"force":0.,"reach":0.,"echo":0.}
	for item in equipped(p):
		if not active(item) or item.rarity<3:continue
		var key=item.get("resonance","force")
		if mods.has(key):mods[key]+=.08 if item.rarity==3 else .12
	for key in mods:mods[key]=minf(mods[key],.48)
	return mods
static func option_text(item:Dictionary)->String:
	var grade=int(item.get("rarity",0))
	if grade==0:return "일반 장비 · 추가 옵션 없음"
	var text=("개방" if active(item) else "잠김 · +%d 강화 필요"%UNLOCK[grade])+"\n"
	if grade<3:
		var a=AFFIXES.get(item.get("affix","none"),AFFIXES.none)
		text+=preload("res://scripts/progression.gd").NAMES.get(a.stat,"능력치")+" +"+str(3*grade+int(item.get("tier",0))*2)
	else:
		var key=item.get("resonance","force");text+=RESONANCE.get(key,RESONANCE.force)+(" +8%" if grade==3 else " +12%")
		if key=="reach":text+=" (범위 계수)"
	return text
static func restriction_text(item:Dictionary)->String:
	return (Content.CLASSES.get(item.get("job_lock",""),{}).get("name","모험가")+" 전용" if item.get("category","")=="weapon" else FAMILY_NAMES.get(item.get("family","warrior"),"전사")+" 계열 공용")+" · LV."+str(item.get("required_level",1))
