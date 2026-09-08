extends RefCounted
const World=preload("res://scripts/world_catalog.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
const Equipment=preload("res://scripts/equipment_catalog.gd")
static func price(p:Dictionary,index:int)->int:return 35+mini(4,int(p.level/5))*45+(10 if index<4 else 0)
static func transact(sim,p:Dictionary,request:Dictionary)->bool:
	var facility=str(request.get("facility",""));var operation=str(request.get("operation",""))
	if sim.map.zone!="town" or World.nearest(p.pos)!=facility:return false
	var staged=p.duplicate(true);var success=false;var message=""
	match facility+":"+operation:
		"shop:buy":
			var index=int(request.get("index",-1));var keys=Equipment.BASES.keys()
			if index<0 or index>=keys.size():return false
			var cost=price(p,index)
			if staged.gold<cost:return false
			var id="shop-"+str(Time.get_ticks_usec())+"-"+str(sim.serial);sim.serial+=1
			var item=Equipment.make(keys[index],mini(4,int(p.level/5)),0,id)
			if not Inventory.add_gear(staged,item):return false
			staged.gold-=cost;success=true;message=item.name+" 구매"
		"shop:potion":
			if staged.gold<15 or not Inventory.add_stack(staged,"potion",1):return false
			staged.gold-=15;success=true;message="회복 물약 구매"
		"shop:sell":
			var id=str(request.get("item",""));var item=Inventory.find_item(staged,id)
			if item.is_empty() or item.get("category","") not in ["weapon","armor","accessory"] or Inventory.is_equipped(staged,id):return false
			staged.gold+=5+int(item.bonus)*4+int(item.rarity)*12
			staged.inventory=staged.inventory.filter(func(e):return e.id!=id);staged.bag_positions.erase(id);success=true;message=item.name+" 판매"
		"smith:upgrade","smith:reforge":
			var item=Inventory.find_item(staged,str(request.get("item","")))
			if item.is_empty() or item.get("category","") not in ["weapon","armor","accessory"]:return false
			var rank=int(item.get("upgrade",0));var upgrading=operation=="upgrade"
			if upgrading and rank>=5:return false
			var cost=(rank+1)*50 if upgrading else 80;var material="ore" if upgrading else "essence";var quantity=rank+1 if upgrading else 1
			if staged.gold<cost or staged.materials.get(material,0)<quantity:return false
			staged.gold-=cost;staged.materials[material]-=quantity
			if upgrading:item.upgrade=rank+1;item.bonus+=2 if item.slot=="weapon" else 1
			else:
				var choices=Equipment.AFFIXES.keys().filter(func(k):return k!="none" and k!=item.get("affix","none"))
				item.affix=choices[sim.rng.randi_range(0,choices.size()-1)]
			item.base_name=item.get("base_name",item.name);item.name=Equipment.AFFIXES[item.get("affix","none")].name+item.base_name+(" +"+str(item.upgrade) if item.get("upgrade",0)>0 else "")
			success=true;message="장비 "+("강화" if upgrading else "재련")+" 완료 · "+item.name
		"alchemy:potion":
			if staged.gold<10 or staged.materials.get("seed",0)<3 or staged.potions+3>Inventory.MAX_POTIONS:return false
			if not Inventory.add_stack(staged,"potion",3):return false
			staged.gold-=10;staged.materials.seed-=3;success=true;message="물약 3개 조제"
		"alchemy:essence":
			if staged.gold<40 or staged.materials.get("ore",0)<5 or staged.materials.get("seed",0)<5:return false
			if not Inventory.add_stack(staged,"essence",1):return false
			staged.gold-=40;staged.materials.ore-=5;staged.materials.seed-=5;success=true;message="정원의 정수 합성"
		"guild:accept":
			if not staged.guild_contract.is_empty():return false
			var zone=str(request.get("zone","forest"))
			if zone not in World.DUNGEONS:return false
			staged.guild_contract={"zone":zone,"progress":0,"target":10};success=true;message=World.DUNGEONS[zone].name+" 토벌 의뢰 수락 · 10마리"
		"guild:claim":
			if staged.guild_contract.is_empty() or staged.guild_contract.progress<staged.guild_contract.target:return false
			if not Inventory.add_stack(staged,"essence",1):return false
			staged.gold+=180;staged.guild_contract={};success=true;message="길드 의뢰 보상 · 180금화 / 정수 1"
		"inn:rest":
			if staged.gold<10:return false
			staged.gold-=10;staged.hp=staged.max_hp;staged.stamina=staged.max_stamina;success=true;message="여관에서 푹 쉬었습니다. 생명력·기력 회복"
	if success:
		for key in ["inventory","equipment","equipped","bag_positions","materials","potions","gold","guild_contract","hp","stamina"]:p[key]=staged[key]
		Inventory.initialize(p);sim.gear_changed(p);sim.notice(p.id,message)
	return success
