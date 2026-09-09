extends RefCounted
const Dungeon=preload("res://scripts/dungeon.gd")

static func ring(game,at:Vector2,radius:float,color:Color,width:float=3):
	game.draw_set_transform(at,0,Vector2(1,0.5))
	game.draw_arc(Vector2.ZERO,radius,0,TAU,64,color,width,true)
	game.draw_set_transform(Vector2.ZERO)

static func star(game,at:Vector2,radius:float,color:Color,angle:float=0):
	var points=PackedVector2Array()
	for i in range(8):points.append(at+Vector2.from_angle(i*PI/4+angle)*(radius if i%2==0 else radius*.25))
	game.draw_colored_polygon(points,color)

static func render(game,e:Dictionary):
	if preload("res://scripts/job_art.gd").render(game,e):return
	var t=clampf(1.0-e.life/e.max_life,0,1)
	var at=game.world_point(e.pos)
	var radius=float(e.get("radius",2))*47
	var kind=e.get("fx","starburst")
	var alpha=sin(PI*pow(t,.55))
	var gold=Color(1,.84,.38,alpha)
	var blue=Color(.5,.86,1,alpha)
	var angle=Dungeon.iso(e.get("dir",Vector2.RIGHT)).angle()
	var rank=int(e.get("rank",1))
	if rank>1:
		for i in range(rank*6):
			var spark=at+Vector2.from_angle(i*TAU/(rank*6)+t)*(radius*(.45+t*.55))*Vector2(1,.5)
			star(game,spark,3+rank,Color(.94,1,.82,alpha*.7),t*3)
	if kind.begins_with("warrior_") or kind.begins_with("ranger_") or kind.begins_with("mage_"):
		extended(game,e,at,t,radius,angle,alpha);return
	match kind:
		"sun_cleave","blade_wave","whirlwind":
			var spin=t*TAU*2 if kind=="whirlwind" else lerpf(-1.6,1.5,t)
			var r=radius*(.65+t*.35)
			game.draw_set_transform(at+Vector2(0,-20),0,Vector2(1,.6))
			for i in range(3):
				game.draw_arc(Vector2.ZERO,r-i*7,angle+spin-1.9,angle+spin+.4,36,Color(1,.88-i*.1,.48,alpha*(1-i*.22)),6-i,true)
			game.draw_set_transform(Vector2.ZERO)
			for i in range(7):star(game,at+Vector2.from_angle(angle+spin+i*.3)*r*Vector2(1,.6),4,gold)
		"arrow_rain":
			ring(game,at,radius,Color(.62,.93,.68,alpha*.7),2)
			for i in range(19):
				var phase=fposmod(t*3+float(i)*.173,1.0)
				var destination=at+Vector2.from_angle(i*2.399)*sqrt(float(i)/19)*radius*Vector2(1,.5)
				var head=destination+Vector2(30,-170)*(1-phase)
				game.draw_line(head+Vector2(9,-40),head,Color(1,.96,.68,alpha),2,true)
				game.draw_colored_polygon(PackedVector2Array([head,head+Vector2(0,-9),head+Vector2(6,-7)]),gold)
				if phase>.75:ring(game,destination,9*phase,Color(.82,1,.76,alpha*.65),1)
		"frost":
			ring(game,at,radius*minf(1,t*3),blue,4)
			ring(game,at,radius*.72*minf(1,t*3),Color(.8,.98,1,alpha*.6),2)
			for i in range(12):
				var base=at+Vector2.from_angle(i*TAU/12)*radius*.83*Vector2(1,.5)
				var height=32*sin(PI*minf(1,t*1.1))
				game.draw_colored_polygon(PackedVector2Array([base+Vector2(-9,0),base+Vector2(-3,-height),base+Vector2(5,-height*.75),base+Vector2(10,0)]),Color(.48,.8,1,alpha*.8))
				game.draw_line(base,base+Vector2(-3,-height),Color(.91,1,1,alpha),2,true)
		"thunder":
			ring(game,at,radius,Color(.81,.73,1,alpha*.85),3)
			var strike=absf(t-.33)<.16 or absf(t-.58)<.08
			if strike:
				for bolt in range(3):
					var points=PackedVector2Array()
					for i in range(8):points.append(at+Vector2(sin(i*7.3+bolt*1.9)*19*(1-i/8.0)+bolt*17-17,-230+i*33))
					game.draw_polyline(points,Color(.65,.56,1,.6),10,true)
					game.draw_polyline(points,Color(.94,.97,1,alpha),3,true)
				star(game,at,42,Color(.9,.9,1,alpha),PI/4)
		"rush","leap","blink":
			var end=game.world_point(e.get("end",e.pos))
			for i in range(7):
				var sample=at.lerp(end,float(i)/6)
				var color=Color(.51,.95,.91,alpha*(.3+i*.1)) if kind!="blink" else Color(.84,.71,1,alpha)
				if kind=="blink":star(game,sample+Vector2(0,-28-sin(i)*18),9,color,t*3)
				else:
					game.draw_arc(sample+Vector2(0,-22),16,angle+PI*.5,angle+PI*1.5,20,color,3,true)
			ring(game,end,24+t*18,blue,2)
		"piercing","volley":
			game.draw_arc(at+Vector2(0,-28),24+t*40,angle-.65,angle+.65,28,gold,3,true)
			for i in range(5):
				var dir=Vector2.from_angle(angle+(i-2)*.16)
				game.draw_line(at+Vector2(0,-28)+dir*t*60,at+Vector2(0,-28)+dir*(t*60+16),gold,2,true)
		_:
			ring(game,at,radius*minf(1,t*2),Color(.68,.72,1,alpha),4)
			for i in range(10):
				var offset=Vector2.from_angle(i*TAU/10+t*.5)*radius*t*Vector2(1,.6)
				star(game,at+offset+Vector2(0,-20*(1-t)),(8 if i%2 else 14)*(1-t*.6),Color(.95,.88,1,alpha),t*2+i)

static func projectile(game,shot:Dictionary):
	var at=game.world_point(shot.pos)+Vector2(0,-28)
	var direction=Dungeon.iso(shot.dir).normalized()
	var angle=direction.angle()
	var scale=float(shot.get("visual_scale",1))
	match shot.type:
		"wave":
			game.draw_arc(at,33*scale,angle-1.2,angle+1.2,24,Color("ffe9a6"),6*scale,true)
			game.draw_arc(at-direction*10,29*scale,angle-1.1,angle+1.1,24,Color("e8b96580"),4,true)
		"staff":
			game.draw_line(at-direction*33,at,Color("9fb8ee70"),10,true)
			star(game,at,13*scale,Color("effaff"),game.visual_time*5)
			star(game,at-direction*20,5,Color("bcdcff"),-game.visual_time*4)
		_:
			var piercing=shot.type=="piercing"
			if piercing:game.draw_line(at-direction*65,at,Color("93f5bb70"),8,true)
			game.draw_line(at-direction*29*scale,at,Color("f5e6b7"),3*scale,true)
			game.draw_line(at-direction*24+direction.orthogonal()*5,at-direction*18,Color("7bced1"),3,true)
			game.draw_colored_polygon(PackedVector2Array([at+direction*4,at-direction*8+direction.orthogonal()*5,at-direction*8-direction.orthogonal()*5]),Color("ecffff"))

static func extended(game,e:Dictionary,at:Vector2,t:float,r:float,angle:float,alpha:float):
	var kind=str(e.fx);var parts=kind.split("_");var mode=kind.trim_prefix(parts[0]+"_")
	var color=Color("ffd275") if parts[0]=="warrior" else Color("8ae9b0") if parts[0]=="ranger" else Color("b4a2ff")
	color.a=alpha
	match mode:
		"fan":
			for i in range(5):
				var dir=Vector2.from_angle(angle+(i-2)*.2)
				game.draw_line(at+dir*t*r,at+dir*(t*r+40),color,5,true)
		"burst":
			var target=at+Vector2(0,-220*(1-minf(1,t*2)))
			star(game,target,30,color,t*4);game.draw_line(target+Vector2(25,-70),target,color,9,true)
			if t>.4:ring(game,at,r*(t-.4)*1.6,color,6)
		"field":
			ring(game,at,r,color,2)
			for i in range(16):
				var pos=at+Vector2.from_angle(i*2.4)*sqrt((i+.5)/16.0)*r*Vector2(1,.5)
				star(game,pos+Vector2(0,-20-20*sin(t*TAU+i)),8,color,i+t*4)
		"chain":
			var end=game.world_point(e.get("end",e.pos));var line=PackedVector2Array()
			for i in range(9):line.append(at.lerp(end,i/8.0)+Vector2(0,sin(i*4+t*30)*12-20))
			game.draw_polyline(line,color,4,true);star(game,end+Vector2(0,-20),18,color)
		"pull":
			for arm in range(3):
				var line=PackedVector2Array()
				for i in range(32):
					var step=i/31.0;line.append(at+Vector2.from_angle(arm*TAU/3+step*TAU+t*5)*r*(1-step)*Vector2(1,.5))
				game.draw_polyline(line,color,3,true)
		"heal":
			ring(game,at,r*.55,color,3)
			for i in range(5):
				var pos=at+Vector2((i-2)*19,-20-t*90+i%2*20)
				game.draw_line(pos-Vector2(7,0),pos+Vector2(7,0),color,4,true);game.draw_line(pos-Vector2(0,7),pos+Vector2(0,7),color,4,true)
		"barrier":
			var vertices=PackedVector2Array()
			for i in range(7):vertices.append(at+Vector2(0,-45)+Vector2.from_angle(i*TAU/6)*65*Vector2(.7,1))
			game.draw_polyline(vertices,color,5,true);ring(game,at,65,color,3)
		"haste":
			for i in range(5):
				var pos=at+Vector2(0,-25-i*17-t*25)
				game.draw_polyline(PackedVector2Array([pos+Vector2(-18,8),pos,pos+Vector2(18,8)]),color,4,true)
		"nova_ring":
			for i in range(3):ring(game,at,r*fposmod(t+i*.25,1),color,4)
			for i in range(8):star(game,at+Vector2.from_angle(i*TAU/8+t)*r*t*Vector2(1,.5),12,color,t*3)
