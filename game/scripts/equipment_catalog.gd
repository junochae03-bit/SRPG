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
const AFFIXES={"none":{"name":"","stat":"none","value":0},"vigor":{"name":"활력의 ","stat":"health","value":12},"focus":{"name":"집중의 ","stat":"damage","value":2},"guard":{"name":"수호의 ","stat":"defense","value":1},"breath":{"name":"숨결의 ","stat":"stamina","value":8},"fortune":{"name":"행운의 ","stat":"gold_bonus","value":.04}}
static func make(type:String,tier:int,rarity:int,id:String,affix:String="none")->Dictionary:
	tier=clampi(tier,0,4);rarity=clampi(rarity,0,2)
	var weapon=type in Content.WEAPONS
	return {"id":id,"name":AFFIXES[affix].name+BASES[type][tier],"base_name":BASES[type][tier],"category":"weapon" if weapon else "accessory" if type=="accessory" else "armor","slot":"weapon" if weapon else type,"weapon_type":type if weapon else "sword","bonus":(tier*4+rarity*3+2) if weapon else tier*2+rarity+1,"rarity":rarity,"tier":tier,"affix":affix,"upgrade":0}
static func bonus(p:Dictionary,stat:String)->float:
	var result=0.0
	for item in p.inventory:
		if not preload("res://scripts/inventory_model.gd").is_equipped(p,item.id):continue
		var affix=AFFIXES.get(item.get("affix","none"),AFFIXES.none)
		if affix.stat==stat:result+=affix.value
	return result
