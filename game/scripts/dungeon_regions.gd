extends RefCounted
## Public biome grammar. Generated coordinates and secret pockets stay private.
const VERSION=1
const FAMILIES=["branching","circuit","great_cavern","side_hollows","split_bridges"]
const REGIONS=[
	{"id":"roots","summary":"굽은 숲길과 둥근 곁굴","weights":[5,3,2,4,1],"styles":[6,3,1,0],"bend":8.,"width":3,"lobes":true},
	{"id":"veins","summary":"큰 채굴 공동과 넓은 우회로","weights":[2,3,7,2,3],"styles":[4,5,1,0],"bend":5.,"width":4,"lobes":true},
	{"id":"flood","summary":"물길을 잇는 회랑과 석실","weights":[2,4,1,6,4],"styles":[1,1,2,6],"bend":3.,"width":3,"lobes":false},
	{"id":"spore","summary":"타원형 정원과 얽힌 샛길","weights":[5,3,3,5,1],"styles":[2,7,1,0],"bend":9.,"width":3,"lobes":true},
	{"id":"lava","summary":"넓은 화구와 갈라진 다리","weights":[1,4,5,1,7],"styles":[7,1,2,0],"bend":4.,"width":4,"lobes":false},
	{"id":"ice","summary":"각진 얼음굴과 순환 균열","weights":[2,5,2,2,7],"styles":[1,2,7,0],"bend":6.,"width":3,"lobes":false},
	{"id":"machine","summary":"각진 작업장과 연결 회랑","weights":[4,6,1,3,3],"styles":[0,1,1,8],"bend":2.,"width":4,"lobes":false},
	{"id":"twilight","summary":"긴 숲길과 겹친 공터","weights":[6,3,3,5,1],"styles":[3,6,1,0],"bend":10.,"width":3,"lobes":true},
	{"id":"nebula","summary":"넓은 별빛 공동과 고리 길","weights":[1,6,7,2,2],"styles":[6,3,1,0],"bend":7.,"width":4,"lobes":true},
	{"id":"core","summary":"깊은 성소와 갈라진 순환로","weights":[3,5,3,2,6],"styles":[1,1,4,4],"bend":5.,"width":4,"lobes":false}
]

static func profile(floor_number:int)->Dictionary:
	var index=int((clampi(floor_number,1,100)-1)/10)
	var result=REGIONS[index].duplicate(true)
	result["first_floor"]=index*10+1;result["last_floor"]=index*10+10
	return result

static func weighted_index(weights:Array,rng:RandomNumberGenerator)->int:
	var total=0
	for weight in weights:total+=int(weight)
	var roll=rng.randi_range(1,maxi(1,total))
	for index in range(weights.size()):
		roll-=int(weights[index])
		if roll<=0:return index
	return weights.size()-1

static func choose_layout(region:Dictionary,rng:RandomNumberGenerator)->String:
	return FAMILIES[weighted_index(region.weights,rng)]

static func room_style(region:Dictionary,rng:RandomNumberGenerator)->int:
	return weighted_index(region.styles,rng)

static func configuration()->Dictionary:
	return {"version":VERSION,"families":FAMILIES,"regions":REGIONS.duplicate(true),"chapter_size":10,"width_unit":"half_width_in_tiles","room_styles":["round","oval","diamond","chamber"],"raid_override":true,"selection":"seeded_weighted_draw","late_floor_room_bonus":"one tile on interior rooms when floor modulo ten is 6 to 9"}
