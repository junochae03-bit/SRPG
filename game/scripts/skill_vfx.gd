extends RefCounted
const PROJECTILE_HEIGHT=70.
## Deterministic, bounded CanvasItem effects; no particle nodes or gameplay RNG.
const Catalog=preload("res://scripts/skill_vfx_catalog.gd")
const Dungeon=preload("res://scripts/dungeon.gd")
const GROUND=Vector2(1,.5)

static func projected_radius(radius:float)->float:
	# iso(x,y)=(48(x-y),24(x+y)): a world circle projects to an
	# ellipse with horizontal radius 48*sqrt(2), not the old 47px.
	return maxf(0.,radius)*48.*sqrt(2.)

static func ground_contour(e:Dictionary)->PackedVector2Array:
	var points=PackedVector2Array();var radius=maxf(0.,float(e.get("radius",0)))
	var shape=str(e.get("ground_shape",""))
	if shape not in ["circle","arc"] or not is_finite(radius) or radius<=0:return points
	var angle:float=e.get("dir",Vector2.RIGHT).angle()
	var half=PI if shape=="circle" else acos(clampf(float(e.get("arc_dot",0.)),-1.,1.))
	if shape=="arc":points.append(Vector2.ZERO)
	for i in range(65):points.append(Dungeon.iso(Vector2.from_angle(angle-half+2.*half*i/64.)*radius))
	if shape=="arc":points.append(Vector2.ZERO)
	return points

static func render_ground(g,e:Dictionary):
	if e.get("skill_phase","")=="windup":return
	var points=ground_contour(e)
	if points.is_empty():return
	var at:Vector2=g.world_point(e.get("pos",Vector2.ZERO))
	if e.get("follow_owner",false) and g.get("session")!=null:
		var p=g.session.state.get("players",{}).get(e.get("owner",-1),{})
		if not p.is_empty():at=g.world_point(p.pos+p.aim*float(e.get("follow_offset",0)))
	var duration=maxf(.001,float(e.get("max_life",e.get("duration",.8))))
	var remaining=clampf(float(e.get("life",duration))/duration,0.,1.)
	var alpha=minf(1.,remaining*4.)
	var color:Color=Catalog.profile(e).get("color",Color("c7b9ef"))
	for i in range(points.size()):points[i]+=at
	# A quiet, exact contact boundary stays visible even when decorative sparks
	# spread or contract. Fixed 65 segments; no extra particle nodes or RNG.
	var fill=points.duplicate();fill.remove_at(fill.size()-1)
	g.draw_colored_polygon(fill,tint(color,.025*alpha))
	g.draw_polyline(points,tint(color,.45*alpha),1.6,true)

static func tint(color:Color,alpha:float)->Color:
	return Color(color,clampf(alpha,0,1))

static func spark(g,at:Vector2,size:float,color:Color,angle:float=0):
	if size<.1 or color.a<=.001:return
	var points=PackedVector2Array()
	for i in range(8):points.append(at+Vector2.from_angle(angle+i*PI/4)*(size if i%2==0 else size*.23))
	g.draw_colored_polygon(points,color)

static func line(g,a:Vector2,b:Vector2,c:Color,width:float=2):
	g.draw_line(a,b,tint(c,c.a*.13),width*5,true)
	g.draw_line(a,b,tint(c,c.a*.4),width*2.4,true)
	g.draw_line(a,b,c,width,true)

static func path(g,points:PackedVector2Array,c:Color,width:float=2):
	if points.size()<2:return
	g.draw_polyline(points,tint(c,c.a*.13),width*5,true)
	g.draw_polyline(points,tint(c,c.a*.42),width*2.3,true)
	g.draw_polyline(points,c,width,true)

static func ellipse(g,at:Vector2,r:float,c:Color,width:float=2,start:float=0,end:float=TAU):
	var points=PackedVector2Array()
	for i in range(49):points.append(at+Vector2.from_angle(lerpf(start,end,i/48.0))*maxf(.1,r)*GROUND)
	path(g,points,c,width)

static func halo(g,at:Vector2,r:float,c:Color):
	# Low opacity keeps enemies and hostile ground markers readable.
	for i in range(3,0,-1):g.draw_circle(at,maxf(.1,r*(.5+i*.25)),tint(c,c.a*.035*(4-i)))

static func motes(g,at:Vector2,r:float,t:float,c:Color,count:int,rise:float=20):
	for i in range(count):
		var seed=fposmod(i*.6180339,.99)
		var travel=fposmod(t*1.1+seed,1)
		var a=i*2.39996+t*.3
		var point=at+Vector2.from_angle(a)*r*(.3+seed*.65)*GROUND+Vector2(0,-travel*rise)
		spark(g,point,2.2+seed*3,tint(c,c.a*sin(travel*PI)),a+t)

static func render(g,e:Dictionary)->bool:
	var style=Catalog.profile(e)
	var family=str(style.get("family",""))
	if family.is_empty():return false
	var duration=maxf(.001,float(e.get("max_life",e.get("duration",.8))))
	var t=clampf(1-float(e.get("life",duration))/duration,0,1)
	# Fast appearance, sustained body, gentle tail. Exactly transparent at both ends.
	var alpha=clampf(t/.10,0,1)*pow(clampf((1-t)/.38,0,1),1.3)
	if alpha<=.001:return true
	var at:Vector2=g.world_point(e.get("pos",Vector2.ZERO))
	var r=clampf(projected_radius(float(e.get("radius",1.5))),26,360)
	var c=tint(style.get("color",Color("9eadff")),alpha)
	var core=tint(style.get("accent",Color("f4fbff")),alpha)
	var rank=clampi(int(e.get("rank",1)),1,3)
	var owner={}
	if g.get("session")!=null:
		owner=g.session.state.get("players",{}).get(e.get("owner",-1),{})
	if not owner.is_empty() and e.get("follow_owner",false):
		at=g.world_point(owner.pos+owner.aim*float(e.get("follow_offset",0)))
	if e.get("skill_phase","")=="windup":
		# Menus cancel a local cast before the next snapshot is published.
		if g.get("session")!=null and g.session.sim!=null:
			owner=g.session.sim.players.get(e.get("owner",-1),owner)
		if not owner.is_empty():
			var casting=owner.get("job_state",{}).get("casting",{})
			if casting.get("node",{}).get("id","")!=e.get("skill_id",""):return true
			at=g.world_point(owner.pos)
		# Charging gathers light inward; release renders the actual skill shape.
		ellipse(g,at,r*(1-t*.45),tint(c,alpha*.65),1.6)
		for i in range(8):
			var ray=Vector2.from_angle(i*TAU/8+t*2)
			var point=at+ray*r*(1-t*.75)*GROUND+Vector2(0,-16-t*12)
			spark(g,point,3+t*3,core,t)
		return true
	var dir=Dungeon.iso(e.get("dir",Vector2.RIGHT)).normalized()
	if dir.length_squared()<.01:dir=Vector2.RIGHT
	var angle=dir.angle()
	var center=at+Vector2(0,-14)
	var end:Vector2=g.world_point(e.get("end",e.get("pos",Vector2.ZERO)))+Vector2(0,-14)
	match family:
		"slash","spin":slash(g,center,r,t,c,core,angle,family=="spin",rank)
		"fire":fire(g,at,r,t,c,core,rank)
		"frost":frost(g,at,r,t,c,core,rank)
		"thunder":thunder(g,at,r,t,c,core,rank)
		"impact":impact(g,at,r,t,c,core,angle,rank)
		"rain":rain(g,at,r,t,c,core,rank)
		"shot":shot(g,center,r,t,c,core,dir,rank,int(e.get("count",1)))
		"poison":poison(g,at,r,t,c,core,rank)
		"heal":heal(g,at,r,t,c,core,rank)
		"barrier":barrier(g,at,r,t,c,core)
		"haste":haste(g,center,r,t,c,core,rank)
		"summon","rune":summon(g,at,r,t,c,core,family=="summon",rank)
		"cards":cards(g,center,r,t,c,core,rank)
		"chain":
			var electric=str(e.get("class_id","")) in ["mage","elementalist","runesword"] or str(e.get("fx","")).begins_with("mage_")
			chain(g,center,end,r,t,c,core,electric)
		"vortex":vortex(g,at,r,t,c,core,rank)
		"blink":blink(g,center,end,r,t,c,core,rank)
		_:return false
	return true

static func slash(g,at:Vector2,r:float,t:float,c:Color,core:Color,angle:float,spin:bool,rank:int):
	var sweep=angle+t*TAU*1.6 if spin else angle-1.5+t*3.0
	var size=r*(.65+.3*sin(t*PI*.8))
	for blade in range(2 if spin else 1):
		var start=sweep+blade*PI
		# Taper the ribbon to a point instead of drawing a uniform arc.
		for layer in range(3):
			var outer=PackedVector2Array();var inner=PackedVector2Array()
			for i in range(31):
				var step=i/30.0;var a=start-2.1+step*2.2
				var width=sin(step*PI)*(12-layer*3)
				var ray=Vector2.from_angle(a)*Vector2(1,.68)
				outer.append(at+ray*(size+width));inner.append(at+ray*(size-width))
			inner.reverse();outer.append_array(inner)
			g.draw_colored_polygon(outer,tint(c if layer==0 else core,c.a*(.25+layer*.3)))
		for i in range(5+rank*2):
			var a=start-1.9+i*.26;var p=at+Vector2.from_angle(a)*size*Vector2(1,.68)
			spark(g,p,(3+i%3)*(1-t*.6),core,a)
	if spin:ellipse(g,at+Vector2(0,14),r*(.6+t*.4),tint(c,c.a*.5),1.4)

static func fire(g,at:Vector2,r:float,t:float,c:Color,core:Color,rank:int):
	ellipse(g,at,r*minf(1,t*3),tint(c,c.a*.8),3)
	halo(g,at+Vector2(0,-r*.3),r*.75,c)
	for i in range(7+rank*2):
		var seed=fposmod(i*.618,1);var phase=fposmod(t*1.3+seed*.5,1)
		var base=at+Vector2((seed-.5)*r*1.5,sin(i*2.4)*r*.16)
		var h=r*(.5+seed*.8)*sin(PI*clampf(phase,.05,.98));var w=r*(.10+seed*.07)
		var tip=base+Vector2(sin(t*11+i)*w*.8,-h)
		var flame=PackedVector2Array([base+Vector2(-w,0),base+Vector2(-w*.8,-h*.38),tip,base+Vector2(w*.5,-h*.53),base+Vector2(w,0)])
		g.draw_colored_polygon(flame,tint(c,c.a*.58))
		var inner=PackedVector2Array([base+Vector2(-w*.42,0),base.lerp(tip,.73),base+Vector2(w*.42,0)])
		g.draw_colored_polygon(inner,tint(core,c.a*.88))
		var ember=base+Vector2(sin(i+t*5)*r*.15,-r*(.4+phase))
		spark(g,ember,2+seed*3,tint(core,c.a*(1-phase)),t+i)
	ellipse(g,at,r*(.3+t*.9),tint(core,c.a*.45),1.5)

static func frost(g,at:Vector2,r:float,t:float,c:Color,core:Color,rank:int):
	var grow=clampf(t*4,0,1)
	ellipse(g,at,r*grow,c,2.3)
	ellipse(g,at,r*.72*grow,tint(core,c.a*.5),1)
	for i in range(6):
		var ray=Vector2.from_angle(i*TAU/6)*GROUND
		line(g,at,at+ray*r*.72*grow,tint(c,c.a*.6),1)
	for i in range(7+rank):
		var a=i*TAU/(7+rank);var base=at+Vector2.from_angle(a)*r*.72*GROUND
		var h=r*(.30+.25*fposmod(i*.37,1))*grow*(1-t*.25);var w=r*.10
		var top=base+Vector2(-w*.25,-h)
		g.draw_colored_polygon(PackedVector2Array([base+Vector2(-w,0),top,base+Vector2(w,-h*.3),base+Vector2(w*.6,4)]),tint(c,c.a*.75))
		g.draw_colored_polygon(PackedVector2Array([base,top,base+Vector2(w,-h*.3)]),tint(core,c.a*.8))
		line(g,base,top,tint(core,c.a*.85),1)
		if i%2==0:spark(g,top,4,core,PI/4)
	motes(g,at,r,t,core,5+rank*2,r*.6)

static func thunder(g,at:Vector2,r:float,t:float,c:Color,core:Color,rank:int):
	ellipse(g,at,r*(.65+.2*t),tint(c,c.a*.7),1.5)
	var strike=sin(clampf((t-.10)*3.5,0,1)*PI)
	if strike>.01:
		for bolt in range(rank+1):
			var points=PackedVector2Array();var x=(bolt-rank*.5)*r*.25
			for i in range(9):
				var step=i/8.0
				points.append(at+Vector2(x*(1-step)+sin(i*7.3+bolt*2.7+floor(t*13))*r*.16*sin(step*PI),-r*1.65*(1-step)))
			path(g,points,tint(c,c.a*strike),5)
			g.draw_polyline(points,tint(core,c.a*strike),1.7,true)
			spark(g,at,18+strike*r*.15,tint(core,c.a*strike),PI/4)
	for i in range(6):
		var ray=Vector2.from_angle(i*TAU/6)
		path(g,PackedVector2Array([at+ray*r*.2*GROUND,at+ray.rotated(.15)*r*.5*GROUND,at+ray*r*.9*GROUND]),tint(c,c.a*.6),1)
	ellipse(g,at,r*clampf(t*2,0,1),tint(core,c.a*.5),2)

static func impact(g,at:Vector2,r:float,t:float,c:Color,core:Color,angle:float,rank:int):
	var expand=1-pow(1-t,3)
	ellipse(g,at,r*expand,c,3*(1-t)+1)
	ellipse(g,at,r*.7*expand,tint(core,c.a*.7),1.5)
	for i in range(8+rank*2):
		var a=angle+i*TAU/(8+rank*2);var ray=Vector2.from_angle(a)
		var base=at+ray*r*(.25+expand*.55)*GROUND
		var jump=sin(t*PI)*r*(.12+fposmod(i*.37,1)*.2)
		var p=base+Vector2(0,-jump)
		var s=(4+i%3)*(.7+rank*.1)
		g.draw_colored_polygon(PackedVector2Array([p+Vector2(-s,0),p+Vector2(-s*.3,-s*1.4),p+Vector2(s,-s*.5),p+Vector2(s*.4,s*.5)]),tint(c,c.a*.85))
		line(g,at+ray*r*.12*GROUND,at+ray*r*expand*.65*GROUND,tint(core,c.a*.55),1.5)
	if t<.5:spark(g,at+Vector2(0,-8),r*.45*(1-t*1.5),tint(core,c.a*.9),angle)

static func rain(g,at:Vector2,r:float,t:float,c:Color,core:Color,rank:int):
	ellipse(g,at,r,tint(c,c.a*.65),1.4)
	for i in range(12+rank*3):
		var phase=fposmod(t*2.4+i*.173,1)
		var dest=at+Vector2.from_angle(i*2.39996)*sqrt((i+.5)/(12+rank*3.0))*r*.9*GROUND
		var head=dest+Vector2(r*.23,-r*1.5)*(1-phase)
		var d=Vector2(-.15,1).normalized()
		line(g,head-d*20,head,tint(c,c.a*.85),1.7)
		g.draw_colored_polygon(PackedVector2Array([head+d*4,head-d*6+d.orthogonal()*3,head-d*6-d.orthogonal()*3]),core)
		if phase>.72:ellipse(g,dest,4+(phase-.72)*30,tint(core,c.a*(1-phase)*3),1)

static func shot(g,at:Vector2,r:float,t:float,c:Color,core:Color,dir:Vector2,rank:int,count:int):
	var arrows=clampi(count,1,7)
	for i in range(arrows):
		var ray=dir.rotated((i-(arrows-1)*.5)*.24)
		var head=at+ray*r*t*1.5
		line(g,head-ray*r*.7,head,c,2.5+rank*.4)
		line(g,head-ray*r*.35,head,core,1.2)
		spark(g,head,8+rank,core,ray.angle())
		g.draw_colored_polygon(PackedVector2Array([head+ray*9,head-ray*6+ray.orthogonal()*5,head-ray*6-ray.orthogonal()*5]),core)
	var ring_points=PackedVector2Array()
	for i in range(25):
		var a=i*TAU/24
		ring_points.append(at+dir*cos(a)*r*.12+dir.orthogonal()*sin(a)*r*(.2+t*.1))
	path(g,ring_points,tint(c,c.a*.6),1.3)

static func poison(g,at:Vector2,r:float,t:float,c:Color,core:Color,rank:int):
	for pool in range(3):ellipse(g,at+Vector2(sin(pool*3.1)*r*.15,cos(pool*2)*r*.07),r*(.6+pool*.14),tint(c,c.a*.35),4)
	for i in range(9+rank*2):
		var phase=fposmod(t+i*.127,1);var seed=fposmod(i*.618,1)
		var p=at+Vector2.from_angle(i*2.4)*r*(.25+seed*.65)*GROUND+Vector2(0,-phase*r*.7)
		var size=(3+seed*7)*sin(PI*phase)
		g.draw_circle(p,maxf(.1,size),tint(c,c.a*.18))
		g.draw_arc(p,maxf(.1,size),0,TAU,16,tint(core,c.a*(1-phase)*.7),1,true)
		g.draw_circle(p+Vector2(-size*.3,-size*.3),maxf(.1,size*.18),tint(core,c.a*.8))
	for i in range(4):
		var ray=Vector2.from_angle(i*PI/2+t*.7)
		path(g,PackedVector2Array([at+ray*r*.2*GROUND,at+ray.rotated(.5)*r*.5*GROUND,at+ray*r*.8*GROUND]),tint(c,c.a*.7),2)

static func heal(g,at:Vector2,r:float,t:float,c:Color,core:Color,rank:int):
	ellipse(g,at,r*.7,c,2)
	ellipse(g,at+Vector2(0,-t*r*.55),r*(.5+t*.15),tint(core,c.a*.4),1)
	for i in range(5+rank):
		var phase=fposmod(t+i*.153,1)
		var p=at+Vector2((fposmod(i*.618,1)-.5)*r*1.25,-10-phase*r*.95)
		var col=tint(core,c.a*sin(phase*PI));var size=4+float(i%3)
		line(g,p-Vector2(size,0),p+Vector2(size,0),col,2.4)
		line(g,p-Vector2(0,size),p+Vector2(0,size),col,2.4)
	motes(g,at,r*.75,t,c,8,r*.8)

static func barrier(g,at:Vector2,r:float,t:float,c:Color,core:Color):
	var size=clampf(r*.7,30,76)*(1+.04*sin(t*TAU*2));var mid=at+Vector2(0,-size*.65)
	var shield=PackedVector2Array([mid+Vector2(-size*.65,-size*.5),mid+Vector2(0,-size*.8),mid+Vector2(size*.65,-size*.5),mid+Vector2(size*.55,size*.3),mid+Vector2(0,size*.75),mid+Vector2(-size*.55,size*.3)])
	g.draw_colored_polygon(shield,tint(c,c.a*.10));shield.append(shield[0]);path(g,shield,c,2.7)
	var inner=PackedVector2Array()
	for p in shield:inner.append(mid+(p-mid)*.78)
	path(g,inner,tint(core,c.a*.65),1)
	line(g,mid+Vector2(0,-size*.40),mid+Vector2(0,size*.30),core,2)
	line(g,mid+Vector2(-size*.23,-size*.08),mid+Vector2(size*.23,-size*.08),core,2)
	ellipse(g,at,size*.9,tint(c,c.a*.75),2)
	for i in range(4):spark(g,mid+Vector2.from_angle(i*PI/2+t)*size*.85*Vector2(.8,1),3,core,t)

static func haste(g,at:Vector2,r:float,t:float,c:Color,core:Color,rank:int):
	for i in range(3):
		var y=-fposmod(t+i*.22,1)*r*.9;var p=at+Vector2(0,y)
		path(g,PackedVector2Array([p+Vector2(-r*.24,10),p,p+Vector2(r*.24,10)]),tint(core,c.a*(1-i*.18)),2.5)
	for side in [-1,1]:
		var points=PackedVector2Array()
		for i in range(20):
			var s=i/19.0;points.append(at+Vector2(side*r*(.3+sin(s*PI)*.18),r*.15-s*r))
		path(g,points,tint(c,c.a*.65),2)
	motes(g,at,r*.6,t,core,5+rank,r)

static func summon(g,at:Vector2,r:float,t:float,c:Color,core:Color,portal:bool,rank:int):
	var size=r*(.85+.04*sin(t*TAU))
	ellipse(g,at,size,c,2)
	ellipse(g,at,size*.78,tint(core,c.a*.7),1)
	var points=PackedVector2Array()
	for i in range(7):points.append(at+Vector2.from_angle(t*.7+i*TAU/6)*size*.72*GROUND)
	path(g,points,tint(c,c.a*.75),1.5)
	for i in range(6):
		var a=i*TAU/6+t*.7;var pos=at+Vector2.from_angle(a)*size*.88*GROUND
		spark(g,pos,5,core,a)
		line(g,pos+Vector2(-3,-3),pos+Vector2(3,3),core,1)
	if portal:
		var height=r*.95*clampf(t*4,0,1)
		for i in range(5):
			var x=(i-2)*size*.23
			line(g,at+Vector2(x,0),at+Vector2(x,-height*(.6+.4*cos(i-2))),tint(c,c.a*.3),3)
		ellipse(g,at+Vector2(0,-height),size*.58,tint(core,c.a*.75),1.5)
	else:
		var p=at+Vector2(0,-r*.48);var s=r*.26
		path(g,PackedVector2Array([p+Vector2(0,-s),p+Vector2(s,0),p+Vector2(0,s),p+Vector2(-s,0),p+Vector2(0,-s)]),core,2)
		line(g,p-Vector2(0,s*1.3),p+Vector2(0,s*1.3),core,1.5)
	motes(g,at,r*.8,t,core,6+rank*2,r)

static func cards(g,at:Vector2,r:float,t:float,c:Color,core:Color,rank:int):
	var count=4+rank
	for i in range(count):
		var a=i*TAU/count+t*2;var p=at+Vector2.from_angle(a)*r*(.45+t*.35)*Vector2(1,.6)+Vector2(0,-15)
		var rotation=a+sin(t*5+i)*.15;var corners=PackedVector2Array()
		for off in [Vector2(-7,-10),Vector2(7,-10),Vector2(7,10),Vector2(-7,10)]:corners.append(p+off.rotated(rotation))
		g.draw_colored_polygon(corners,tint(core,c.a*.86));corners.append(corners[0]);path(g,corners,tint(c,c.a*.9),1)
		var suit=tint(c,c.a) if i%2 else tint(Color("dc527c"),c.a)
		spark(g,p,4,suit,rotation+PI/4)
		line(g,p+Vector2(-3,-6).rotated(rotation),p+Vector2(0,-6).rotated(rotation),suit,1)
	motes(g,at,r,t,c,8,r*.3)

static func chain(g,at:Vector2,end:Vector2,r:float,t:float,c:Color,core:Color,electric:bool=false):
	if at.distance_to(end)<3:end=at+Vector2(r*1.1,0)
	var d=at.direction_to(end);var length=at.distance_to(end);var travel=clampf(t*5,0,1)
	if electric:
		var bolt=PackedVector2Array()
		for i in range(13):
			var s=i/12.0;bolt.append(at.lerp(end,s*travel)+d.orthogonal()*sin(i*8.7+floor(t*14))*minf(16,r*.22)*sin(s*PI))
		path(g,bolt,c,4);g.draw_polyline(bolt,core,1.5,true)
		spark(g,at.lerp(end,travel),13,core,PI/4)
		return
	var count=clampi(int(length/11),3,28)
	for i in range(count):
		var s=(i+.5)/count
		if s>travel:continue
		var p=at.lerp(end,s)+d.orthogonal()*sin(s*PI)*sin(t*10)*r*.07
		var link=PackedVector2Array()
		for j in range(13):
			var a=j*TAU/12;link.append(p+d*cos(a)*7+d.orthogonal()*sin(a)*(3.4 if i%2 else 1.4))
		path(g,link,tint(c,c.a*.9),1.5)
	line(g,at,at.lerp(end,travel),tint(core,c.a*.25),1)
	spark(g,at.lerp(end,travel),12,core,t)

static func vortex(g,at:Vector2,r:float,t:float,c:Color,core:Color,rank:int):
	halo(g,at,r*.45,c)
	for arm in range(3+rank):
		var points=PackedVector2Array()
		for i in range(37):
			var s=i/36.0;var a=arm*TAU/(3+rank)+s*TAU*1.2-t*5
			points.append(at+Vector2.from_angle(a)*r*(1-s)*GROUND)
		path(g,points,tint(c,c.a*.7),2)
		var tip=at+Vector2.from_angle(arm*TAU/(3+rank)-t*5)*r*GROUND
		spark(g,tip,4,core,t)
	ellipse(g,at,r*.17,tint(core,c.a*.85),2)
	spark(g,at,8,core,-t*3)

static func blink(g,at:Vector2,end:Vector2,r:float,t:float,c:Color,core:Color,rank:int):
	var distance=at.distance_to(end)
	if distance>3:
		var direction=at.direction_to(end)
		for i in range(8+rank*2):
			var s=i/(7+rank*2.0);var p=at.lerp(end,s)+direction.orthogonal()*sin(i*2.4)*r*.13
			var fade=clampf(1-absf(s-t*1.3)*2,0,1)
			spark(g,p,3+fade*5,tint(core,c.a*fade),t*2+i)
		line(g,at.lerp(end,clampf(t-.15,0,1)),at.lerp(end,minf(1,t+.25)),tint(c,c.a*.6),2)
	for p in [at,end]:
		var points=PackedVector2Array()
		for i in range(33):points.append(p+Vector2.from_angle(i*TAU/32)*r*.38*Vector2(.6,1))
		path(g,points,c,2)
		spark(g,p,10*(1-t*.5),core,PI/4)

static func projectile(g,shot_data:Dictionary)->bool:
	# Basic attacks retain their existing art. Learned shots carry their own palette.
	if not shot_data.has("skill_id"):return false
	var style=Catalog.profile(shot_data)
	var family=str(style.family)
	if family.is_empty():return false
	var at:Vector2=g.world_point(shot_data.pos)+preload("res://scripts/character_presentation.gd").projectile_offset(shot_data)
	var direction=Dungeon.iso(shot_data.dir).normalized()
	var scale=clampf(float(shot_data.get("visual_scale",1)),1,1.6)
	var c:Color=style.color;var core:Color=style.accent
	var time=float(g.get("visual_time"))
	if family=="cards":
		var corners=PackedVector2Array()
		for off in [Vector2(-7,-10),Vector2(7,-10),Vector2(7,10),Vector2(-7,10)]:corners.append(at+off.rotated(time*7)*scale)
		line(g,at-direction*35,at,tint(c,.45),3)
		g.draw_colored_polygon(corners,core);corners.append(corners[0]);path(g,corners,c,1.3)
		spark(g,at,4*scale,c,time*7+PI/4)
	elif family in ["fire","frost","thunder","rune","poison","summon"]:
		line(g,at-direction*42*scale,at,tint(c,.6),6*scale)
		halo(g,at,15*scale,c)
		if family=="frost":
			g.draw_colored_polygon(PackedVector2Array([at+direction*15*scale,at+direction.orthogonal()*8*scale,at-direction*11*scale,at-direction.orthogonal()*8*scale]),c)
			line(g,at-direction*9*scale,at+direction*14*scale,core,2)
		elif family=="fire":
			g.draw_circle(at,8*scale,c);g.draw_circle(at+direction*2,5*scale,core)
			for i in range(4):
				var p=at-direction*(14+i*8)+direction.orthogonal()*sin(time*12+i)*5
				spark(g,p,(5-i)*scale,tint(c,1-i*.2),time+i)
		elif family=="poison":
			g.draw_circle(at,7*scale,c);g.draw_circle(at-direction.orthogonal()*2,3*scale,core)
			for i in range(3):g.draw_circle(at-direction*(15+i*9)+direction.orthogonal()*sin(time*8+i)*6,(3-i*.5)*scale,tint(c,.7-i*.16))
		else:
			spark(g,at,12*scale,core,time*5)
			spark(g,at-direction*20,6*scale,c,-time*4)
	elif family=="slash":
		var points=PackedVector2Array()
		for i in range(25):points.append(at+Vector2.from_angle(direction.angle()-1.25+i*2.5/24)*30*scale)
		path(g,points,c,5*scale);g.draw_polyline(points,core,2*scale,true)
	else:
		line(g,at-direction*45*scale,at,tint(c,.65),3*scale)
		line(g,at-direction*22*scale,at,core,1.7*scale)
		g.draw_colored_polygon(PackedVector2Array([at+direction*8,at-direction*7+direction.orthogonal()*5,at-direction*7-direction.orthogonal()*5]),core)
	return true
