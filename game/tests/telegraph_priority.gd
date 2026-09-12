extends SceneTree
const Priority=preload("res://scripts/telegraph_priority.gd")
const Attacks=preload("res://scripts/monster_attacks.gd")
const Sim=preload("res://scripts/simulation.gd")
var checks=0
var failures=[]
class Sight:
	var visible=true
	var active=false
	var visible_cells={}
	func sees(_pos:Vector2)->bool:return visible
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	var sim=Sim.new(1,"cave",1);sim.enemies.clear();sim.map.floor_cells.clear()
	for x in range(-20,21):
		for y in range(-20,21):sim.map.floor_cells[Vector2i(x,y)]=true
	var p=sim.add_player(1,"검사");p.pos=Vector2.ZERO
	var caster=sim.spawn_enemy("rat",Vector2(-10,0),1)
	var ally=sim.add_player(2,"궁수");ally.pos=Vector2(4,0)
	var self_area=Attacks.area("line",Vector2(-10,0),Vector2.ZERO,.4)
	var ally_area=Attacks.area("circle",Vector2(5,0),ally.pos,1.)
	var safe=Attacks.area("ring",Vector2(0,4),Vector2.ZERO,3.);safe.inner=1.5
	for area in [self_area,ally_area,safe]:area.enemy=caster.id;area.timer=.5
	check(not Priority.dangerous(safe,p,sim.map),"safe ring center is not a personal threat")
	var state=sim.snapshot(1);state.enemy_attacks=[self_area,ally_area,safe]
	var records=Priority.collect(state,sim.map,1)
	check(records.map(func(r):return r.priority)==[0,1,2],"personal threat renders over ally and ambient warnings")
	check(records[-1].area==self_area,"real line geometry identifies personal danger")
	for id in range(3,7):sim.add_player(id,"동료%d"%id).pos=Vector2(id*2,0)
	var individual=sim.snapshot(1);individual.enemy_attacks=[]
	for member in sim.players.values():
		var area=Attacks.area("circle",Vector2(member.pos.x,2),member.pos,.7);area.enemy=caster.id;area.timer=.5;individual.enemy_attacks.append(area)
	for id in range(1,7):
		var own=Priority.collect(individual,sim.map,id)
		check(own[-1].priority==2 and own[-1].area.pos==sim.players[id].pos,"same six-player snapshot prioritizes each viewer's own danger")
	for i in range(6):state.enemy_attacks.append(self_area.duplicate(true))
	var before=var_to_bytes(state);records=Priority.collect(state,sim.map,1)
	check(records.size()==3 and records[-1].count==7,"identical multiplayer geometry has one visible fill")
	check(var_to_bytes(state)==before,"presentation never mutates damage or snapshot")
	for i in range(8):
		var area=Attacks.area("circle",Vector2(i,7),Vector2(i,7),.5);area.enemy=caster.id;area.timer=.5;state.enemy_attacks.append(area)
	records=Priority.collect(state,sim.map,1)
	Priority.apply_visibility(records,Sight.new(),func(pos):return Vector2(800,450)+pos*10.,Rect2(0,0,1600,900))
	check(records.filter(func(r):return r.fill).size()==4 and records[-1].fill,"fill budget preserves highest-priority geometry")
	var source=sim.spawn_enemy("rat",Vector2(-10,0),1);source.windup=.4;source.attack_areas=[self_area.duplicate(true)];source.attack_areas[0].delay=.7
	state=sim.snapshot(1);records=Priority.collect(state,sim.map,1)
	check(records.size()==1 and is_equal_approx(records[0].time,1.1),"countdown includes windup and delayed impact")
	source.stagger={"state":"down"};state=sim.snapshot(1)
	check(Priority.collect(state,sim.map,1).is_empty(),"interrupted windup gives no stale warning")
	source.stagger={};source.windup=0.;var delayed=self_area.duplicate(true);delayed.timer=.3;delayed.enemy=source.id
	state=sim.snapshot(1);state.enemy_attacks=[delayed]
	check(is_equal_approx(Priority.collect(state,sim.map,1)[0].time,.3),"released delayed area uses remaining timer")
	source.stun_time=1.;state=sim.snapshot(1);state.enemy_attacks=[delayed]
	check(Priority.collect(state,sim.map,1).is_empty(),"stunned owner cannot retain a pending threat")
	source.stun_time=0.
	var unowned=delayed.duplicate();unowned.enemy=999;state.enemy_attacks=[unowned]
	check(Priority.collect(state,sim.map,1).is_empty(),"missing owner cannot retain a pending threat")
	source.hp=0;state=sim.snapshot(1);state.enemy_attacks=[delayed]
	check(Priority.collect(state,sim.map,1).is_empty(),"dead source removes scheduled threat")
	state.enemy_attacks=[self_area];records=Priority.collect(state,sim.map,1)
	var sight=Sight.new();var project=func(pos):return Vector2(800,450)+pos*100.
	var viewport=Rect2(0,0,1600,900)
	var local_area=Attacks.area("circle",Vector2.ZERO,Vector2(2,0),.7)
	var budgets=[{"area":local_area,"priority":0,"time":1.,"fill":false}]
	for i in range(4):budgets.append({"area":Attacks.area("circle",Vector2(18,i),Vector2(18,i),1.),"priority":1,"time":.1,"fill":false})
	Priority.apply_visibility(budgets,sight,project,viewport)
	check(budgets[0].fill and budgets.filter(func(r):return r.fill).size()==1,"off-camera party attacks do not consume local fill budget")
	sight.active=true;sight.visible_cells={Vector2i(2,0):true}
	for i in range(1,5):budgets[i].area.pos=Vector2(4,i);budgets[i].area.from=Vector2(4,i)
	Priority.apply_visibility(budgets,sight,project,viewport)
	check(budgets[0].fill and budgets.filter(func(r):return r.fill).size()==1,"fogged attacks inside viewport do not consume local fill budget")
	var rim=Attacks.area("circle",Vector2(4,0),Vector2(4,0),1.8)
	check(Priority.visible_area(rim,sight,project,viewport),"circle rim intersecting visible tile is included despite hidden center")
	var thin=Attacks.area("line",Vector2(0,.37),Vector2(8,.37),.025)
	check(Priority.visible_area(thin,sight,project,viewport),"thin line crossing visible tile cannot be lost by center sampling")
	var hole=Attacks.area("ring",Vector2(2,0),Vector2(2,0),3.);hole.inner=1.
	check(not Priority.visible_area(hole,sight,project,viewport),"only visible safe ring center does not consume fill budget")
	sight.active=false
	var warnings=Priority.warnings(records,p,sight,project,viewport,[])
	check(warnings.size()==1 and warnings[0].direction.x<0 and is_equal_approx(warnings[0].point.x,64),"known offscreen attack has correct edge arrow")
	sight.visible=false;check(Priority.warnings(records,p,sight,project,viewport,[]).is_empty(),"unknown source never reveals direction")
	sight.visible=true
	var blocked=[Rect2(0,350,160,200)]
	warnings=Priority.warnings(records,p,sight,project,viewport,blocked)
	check(warnings.size()==1 and not blocked[0].intersects(Rect2(warnings[0].point-Vector2(24,24),Vector2(48,70))),"edge marker avoids occupied HUD region")
	check(Priority.warnings(records,p,sight,project,viewport,[viewport]).is_empty(),"fully occupied edge hides marker instead of covering UI")
	var all=[]
	for i in range(16):
		var from=Vector2.from_angle(TAU*i/16)*20.
		all.append({"priority":2,"source":from,"area":self_area,"time":float(i+1)*.1,"count":1})
	warnings=Priority.warnings(all,p,sight,project,viewport,[])
	check(warnings.size()==4 and warnings[0].time<warnings[-1].time,"offscreen warnings group directions and prioritize imminent attacks")
	for warning in warnings:check(viewport.encloses(Rect2(warning.point-Vector2(24,24),Vector2(48,70))),"marker and countdown stay within viewport")
	p.hp=0;check(Priority.warnings(records,p,sight,project,viewport,[]).is_empty(),"dead player has no active risk arrows")
	p.hp=100;p.network_leaving=true;check(not Priority.dangerous(self_area,p,sim.map),"departing player is excluded")
	p.network_leaving=false
	for y in range(-20,21):sim.map.floor_cells.erase(Vector2i(-3,y))
	check(not Priority.dangerous(self_area,p,sim.map),"solid wall blocks damage priority using actual collision rule")
	var blocked_circle=Attacks.area("circle",Vector2(-10,0),p.pos,2.);blocked_circle.enemy=caster.id;blocked_circle.timer=.1
	var hitting_circle=Attacks.area("circle",Vector2(10,0),p.pos,2.);hitting_circle.enemy=caster.id;hitting_circle.timer=.8
	state=sim.snapshot(1);state.enemy_attacks=[blocked_circle,hitting_circle]
	records=Priority.collect(state,sim.map,1)
	check(records.size()==1 and records[0].count==2 and records[0].threats.size()==2,"same circle from different attackers shares fill but keeps both source records")
	check(records[0].priority==2 and is_equal_approx(records[0].time,.8),"blocked earlier circle cannot replace actual personal impact time")
	warnings=Priority.warnings(records,p,sight,project,viewport,[])
	check(warnings.size()==1 and warnings[0].direction.x>0 and is_equal_approx(warnings[0].time,.8),"merged visual retains correct unblocked source direction and time")
	print("TELEGRAPH_PRIORITY checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
