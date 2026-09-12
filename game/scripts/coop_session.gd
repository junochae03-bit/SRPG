extends "res://scripts/local_session.gd"

# The host owns Simulation. A guest Simulation is a read-only presentation mirror.
const PROTOCOL=4
const MAX_PLAYERS=preload("res://scripts/party_rules.gd").MAX_PLAYERS
const DEFAULT_PORT=24554
var network_role="offline"
var network_peer:ENetMultiplayerPeer
var ready_players={}
var last_sequence={}
var action_budget={}
var sequence=0
var snapshot_time=0.
var checkpoint_time=0.
var pending_character={}
var latest_checkpoint={}
var room_status=""
var join_time=0.
var network_signals=false
var recovery_checkpoint={}
var recovery_path=""
var snapshot_revision=0
var accepted_revision=-1
var transaction_receipt={}
var leaving=false
var exit_token=""
var exit_saved=false
var exit_result=false
var departures={}
var checkpoint_revision=0
var accepted_checkpoint_revision=-1
var completed_sequence=0
const COMBAT_ACTIONS=["attack","heavy","heavy_begin","cancel_charge","dodge","nova","card_next","skill_q","skill_f","skill_v","skill_c","skill_z","skill_x"]
signal request_completed(kind:String,success:bool)

func prepare_network():
	if network_signals:return
	network_signals=true
	multiplayer.connected_to_server.connect(func():register_player.rpc_id(1,PROTOCOL,pending_character))
	multiplayer.connection_failed.connect(func():close_network("방에 연결할 수 없습니다."))
	multiplayer.server_disconnected.connect(func():
		if exit_saved:exit_result=true
		close_network("방장이 연결을 종료했습니다. 기록을 보존했습니다."))
	multiplayer.peer_disconnected.connect(peer_left)

func peer_ready(id:int)->bool:
	if network_peer==null or id not in multiplayer.get_peers():return false
	var peer=network_peer.get_peer(id)
	return peer!=null and peer.get_state()==ENetPacketPeer.STATE_CONNECTED

func room_character(slot_number:int)->Dictionary:
	if not recover_save():return {}
	if slot_number<1 or slot_number>3:return {}
	var data=parse_save(save_directory.path_join("slot-%d.json"%slot_number))
	if data==null:data=parse_save(save_directory.path_join("slot-%d.json.bak"%slot_number))
	return data if data!=null and data.get("tutorial_done",false) else {}

func host_room(slot_number:int,port:int=DEFAULT_PORT)->bool:
	if connected or network_role!="offline" or port<1024 or port>65535:return false
	var character=room_character(slot_number)
	if character.is_empty():status_changed.emit("마을에 도착한 캐릭터를 선택하세요.");return false
	prepare_network();network_peer=ENetMultiplayerPeer.new()
	if network_peer.create_server(port,MAX_PLAYERS-1)!=OK:network_peer=null;status_changed.emit("방을 열 수 없습니다. 포트를 확인하세요.");return false
	multiplayer.server_relay=false
	multiplayer.multiplayer_peer=network_peer;network_role="host";local_id=1;slot=slot_number
	if not enter_saved(character,character.name):close_network("저장 실패로 방을 열지 못했습니다.");return false
	ready_players={1:false};room_status="협동 방 · 포트 %d"%port
	status_changed.emit(room_status);return true

func join_room(address:String,slot_number:int,port:int=DEFAULT_PORT)->bool:
	if connected or network_role!="offline" or address.strip_edges().is_empty() or port<1024 or port>65535:return false
	pending_character=room_character(slot_number)
	if pending_character.is_empty():status_changed.emit("마을에 도착한 캐릭터를 선택하세요.");return false
	prepare_network();network_peer=ENetMultiplayerPeer.new()
	if network_peer.create_client(address.strip_edges(),port)!=OK:network_peer=null;return false
	network_role="client";slot=slot_number;join_time=0.;latest_checkpoint={};multiplayer.multiplayer_peer=network_peer
	room_status="방에 연결 중…";status_changed.emit(room_status);return true

@rpc("any_peer","call_remote","reliable")
func register_player(protocol:int,data:Dictionary):
	if network_role!="host":return
	var sender=multiplayer.get_remote_sender_id()
	if sim.players.has(sender):return
	if leaving:reject_join.rpc_id(sender,"방을 닫는 중입니다. 잠시 후 다시 참가하세요.");return
	if protocol!=PROTOCOL or sim.map.zone!="town" or sim.players.size()>=MAX_PLAYERS or var_to_bytes(data).size()>262144:
		reject_join.rpc_id(sender,"마을에 있는 호환 버전의 방에만 참가할 수 있습니다.");return
	# JSON roundtrip rejects non-save Variant types before the existing save validator.
	var valid=validate_save(JSON.parse_string(JSON.stringify(data)))
	if valid==null or not valid.get("tutorial_done",false):reject_join.rpc_id(sender,"캐릭터 기록을 읽을 수 없습니다.");return
	sim.add_player(sender,valid.name,valid);ready_players[sender]=false;last_sequence[sender]=0
	publish_snapshot();publish_checkpoints();room_status="협동 방 · %d / 6"%sim.players.size();status_changed.emit(room_status)

@rpc("authority","call_remote","reliable")
func reject_join(reason:String):
	if network_role=="client":close_network(reason)

func peer_left(id:int):
	if network_role!="host" or sim==null:return
	if sim.players.has(id):
		sim.reset_after_defeat(id);sim.players.erase(id)
	ready_players.erase(id);last_sequence.erase(id);action_budget.erase(id)
	if not leaving:departures.erase(id)
	for key in sim.drops.keys():
		if sim.drops[key].owner==id:sim.drops.erase(key)
	preload("res://scripts/party_rules.gd").rescale(sim)
	room_status="협동 방 · %d / 6"%sim.players.size();publish_snapshot();status_changed.emit(room_status)

func close_network(message:String):
	if network_role=="client" and not exit_saved and not latest_checkpoint.is_empty() and not save_game():
		recovery_checkpoint=latest_checkpoint.duplicate(true);recovery_path=save_path();message="연결 종료 · 저장에 실패해 기록을 메모리에 보존하고 다시 시도합니다."
	network_role="offline"
	if network_peer!=null:network_peer.close()
	multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new();network_peer=null;network_role="offline";connected=false;paused=false;local_id=1
	ready_players.clear();last_sequence.clear();action_budget.clear();pending_character={};latest_checkpoint={}
	sequence=0;snapshot_revision=0;accepted_revision=-1;transaction_receipt={}
	leaving=false;exit_token="";exit_saved=false;departures={};checkpoint_revision=0;accepted_checkpoint_revision=-1
	state={"players":{},"enemies":{},"drops":{},"clock":0.};room_status=message;status_changed.emit(message);changed.emit()

func recover_save()->bool:
	if recovery_checkpoint.is_empty():return true
	if not write_save(recovery_checkpoint,recovery_path):return false
	recovery_checkpoint={};recovery_path="";status_changed.emit("보존한 협동 기록을 저장했습니다.");return true

func start_game(chosen_name:String,slot_number:int):
	if recover_save():super.start_game(chosen_name,slot_number)

func create_character(sheet:Dictionary,slot_number:int)->bool:
	return super.create_character(sheet,slot_number) if recover_save() else false

func send_input(direction:Vector2,aim:Vector2,sprint:bool=false):
	if network_role=="offline":super.send_input(direction,aim,sprint);return
	if not connected or leaving:return
	if paused:direction=Vector2.ZERO;sprint=false
	if network_role=="host":sim.set_input(local_id,direction,aim,sprint)
	else:receive_input.rpc_id(1,direction,aim,sprint)

@rpc("any_peer","call_remote","unreliable_ordered",1)
func receive_input(direction:Vector2,aim:Vector2,sprint:bool):
	if network_role!="host" or not direction.is_finite() or not aim.is_finite():return
	var sender=multiplayer.get_remote_sender_id()
	if sim.players.has(sender) and not departures.has(sender):sim.set_input(sender,direction.limit_length(1),aim.normalized(),sprint)

func cancel_charge():
	if network_role=="offline":super.cancel_charge()
	elif connected:act("cancel_charge")

func act(kind:String,argument:String="")->bool:
	if network_role=="offline":return super.act(kind,argument)
	if not connected or leaving:return false
	if kind=="interact" and sim.map.zone=="town":
		var facility=preload("res://scripts/world_catalog.gd").nearest(state.players[local_id].pos)
		if facility!="":facility_requested.emit(facility);return true
	if network_role=="client":
		sequence+=1;receive_action.rpc_id(1,sequence,kind,argument);return true
	return host_action(local_id,kind,argument)

@rpc("any_peer","call_remote","reliable",2)
func receive_action(serial_number:int,kind:String,argument:String):
	if network_role!="host":return
	var sender=multiplayer.get_remote_sender_id()
	if not sim.players.has(sender) or serial_number<=int(last_sequence.get(sender,0)):return
	last_sequence[sender]=serial_number
	var budget=action_budget.get(sender,{"second":-1,"count":0})
	if budget.second!=int(sim.clock):budget={"second":int(sim.clock),"count":0}
	budget.count+=1;action_budget[sender]=budget
	if budget.count>40 or kind.length()>40 or argument.length()>8192:
		if kind.length()<=40 and kind not in COMBAT_ACTIONS:action_result.rpc_id(sender,serial_number,kind,false,PackedByteArray(),{})
		return
	var before=receipt_values(sim.players[sender]) if kind in ["facility","buy_appearance","wear_appearance"] else {}
	var result=host_action(sender,kind,argument) if not departures.has(sender) else false
	if not peer_ready(sender):return
	var receipt={"before":before,"after":receipt_values(sim.players[sender])} if not before.is_empty() else {}
	# Combat already uses the world stream. Do not resend the entire world for held attacks.
	action_result.rpc_id(sender,serial_number,kind,result,PackedByteArray() if kind in COMBAT_ACTIONS else snapshot_packet(sender),receipt)

func receipt_values(p:Dictionary)->Dictionary:
	return {"gold":p.gold,"potions":p.potions,"consumables":p.get("consumables",{}).duplicate(),"materials":p.materials.duplicate(),"hp":p.hp}

@rpc("authority","call_remote","reliable",2)
func action_result(serial_number:int,kind:String,success:bool,packet:PackedByteArray,receipt:Dictionary):
	if network_role!="client":return
	if not packet.is_empty():receive_snapshot(packet)
	transaction_receipt=receipt
	completed_sequence=serial_number
	if success:action_performed.emit(kind)
	elif kind not in COMBAT_ACTIONS:status_changed.emit("지금은 사용할 수 없습니다.")
	request_completed.emit(kind,success)

func host_action(id:int,kind:String,argument:String)->bool:
	if kind=="ready":ready_players[id]=argument=="true";publish_snapshot();return true
	if kind in ["return","enter_floor"]:
		if kind=="return" and (sim.map.zone=="town" or sim.players[id].return_cd>0):return false
		if id!=1:sim.notice(id,"층 이동은 모두 준비한 뒤 방장이 선택합니다.");flush_events();return false
		return travel("town") if kind=="return" else enter_floor(int(argument))
	if kind=="interact" and sim.map.floor_number>0 and sim.players[id].pos.distance_to(sim.map.exit_position)<2.8:
		if not sim.drops.values().any(func(d):return d.owner==id and d.pos.distance_to(sim.players[id].pos)<=1.8):return host_action(id,"enter_floor",str(sim.map.floor_number+1))
	var success=sim.action(id,kind,argument)
	if success and id==local_id:action_performed.emit(kind)
	flush_events();refresh();return success

func can_party_travel(floor_number:int)->bool:
	for id in sim.players:
		if sim.players[id].get("down_time",0)>0:status_changed.emit("쓰러진 동료를 먼저 구조하세요.");return false
		if sim.players.size()>1 and not ready_players.get(id,false):status_changed.emit("모든 모험가의 준비가 필요합니다.");return false
		if floor_number>0 and not preload("res://scripts/abyss_catalog.gd").locked_reason(sim.players[id],floor_number).is_empty():status_changed.emit("아직 이 층을 열지 못한 모험가가 있습니다.");return false
	return true

func enter_floor(floor_number:int)->bool:
	if network_role=="offline":return super.enter_floor(floor_number)
	if leaving:return false
	if network_role=="client":return act("enter_floor",str(floor_number))
	if not can_party_travel(floor_number):return false
	return super.enter_floor(floor_number)

func travel(zone:String)->bool:
	if network_role=="offline":return super.travel(zone)
	if leaving:return false
	if network_role=="client":return act("return") if zone=="town" else false
	if not can_party_travel(0):return false
	return super.travel(zone)

func change_map(zone:String,floor_number:int,arrival:Dictionary={})->bool:
	if network_role=="offline":return super.change_map(zone,floor_number,arrival)
	if network_role!="host":return false
	var guests={}
	for id in sim.players:
		if id!=local_id:guests[id]={"saved":sim.persistent(id),"hp":sim.players[id].hp,"stamina":sim.players[id].stamina}
	if not super.change_map(zone,floor_number,arrival):return false
	for id in guests:
		var data=guests[id];var p=sim.add_player(id,data.saved.name,data.saved);p.hp=mini(p.max_hp,data.hp);p.stamina=minf(p.max_stamina,data.stamina)
	preload("res://scripts/party_rules.gd").rescale(sim)
	for id in sim.players:ready_players[id]=false
	publish_snapshot();publish_checkpoints();refresh();return true

func publish_snapshot():
	if network_role!="host" or sim==null:return
	for id in sim.players:
		if id!=local_id and peer_ready(id):receive_snapshot.rpc_id(id,snapshot_packet(id))

func snapshot_packet(id:int)->PackedByteArray:
	snapshot_revision+=1
	return var_to_bytes({"revision":snapshot_revision,"seed":world_seed,"zone":sim.map.zone,"floor":sim.map.floor_number,"state":sim.snapshot(id),"ready":ready_players}).compress(FileAccess.COMPRESSION_DEFLATE)

@rpc("authority","call_remote","reliable",3)
func receive_snapshot(packet:PackedByteArray):
	if network_role!="client":return
	var envelope=bytes_to_var(packet.decompress_dynamic(4194304,FileAccess.COMPRESSION_DEFLATE))
	if not envelope is Dictionary or int(envelope.get("revision",-1))<=accepted_revision:return
	var data=envelope.state;var seed_value=int(envelope.seed);var zone=str(envelope.zone);var floor_number=int(envelope.floor)
	local_id=multiplayer.get_unique_id()
	if not data.get("players",{}).has(local_id):return
	accepted_revision=int(envelope.revision)
	var changed_map=sim==null or world_seed!=seed_value or sim.map.zone!=zone or sim.map.floor_number!=floor_number
	if changed_map:sim=Simulation.new(seed_value,zone,floor_number)
	world_seed=seed_value;state=data;ready_players=envelope.ready;sim.players=data.players.duplicate(true);sim.enemies=data.enemies.duplicate(true);sim.drops=data.drops.duplicate(true);sim.clock=data.clock
	sim.combat.projectiles=data.get("projectiles",[]);sim.monster_attacks.zones=data.get("enemy_attacks",[])
	preload("res://scripts/hidden_rooms.gd").synchronize(sim.map,data.get("opened_regions",[]),data.get("revealed_regions",[]))
	var first=not connected;connected=true;received_snapshots+=1;room_status="협동 방 · %d / 6"%state.players.size()
	if changed_map or first:entered.emit()
	changed.emit()

func publish_checkpoints():
	if network_role!="host":return
	for id in sim.players:
		if id==local_id or not peer_ready(id):continue
		if departures.has(id):continue
		var saved=sim.persistent(id);saved.world_seed=world_seed;checkpoint_revision+=1;receive_checkpoint.rpc_id(id,saved,checkpoint_revision)

@rpc("authority","call_remote","reliable",4)
func receive_checkpoint(data:Dictionary,revision:int):
	if network_role!="client" or revision<=accepted_checkpoint_revision or exit_saved:return
	var valid=validate_save(JSON.parse_string(JSON.stringify(data)))
	if valid!=null:latest_checkpoint=valid;accepted_checkpoint_revision=revision;save_game()

func save_game()->bool:
	if network_role!="client":return super.save_game()
	if latest_checkpoint.is_empty():return false
	if not write_save(latest_checkpoint,save_path()):mark_save_failure();return false
	save_failed=false;save_retry=0.;return true

func flush_events():
	if network_role!="host":
		if network_role=="offline":super.flush_events()
		return
	for event in sim.events:
		if event.get("type","")!="notice" or int(event.get("owner",local_id))==local_id:event_received.emit(event)
		for id in sim.players:
			if id!=local_id and peer_ready(id) and (event.get("type","")!="notice" or int(event.get("owner",-1))==id):receive_event.rpc_id(id,event)
	sim.events.clear()
	if not sim.dirty.is_empty() and save_retry<=0:save_game();publish_checkpoints()

@rpc("authority","call_remote","reliable",2)
func receive_event(event:Dictionary):
	if network_role=="client":event_received.emit(event)

func _physics_process(delta:float):
	if network_role=="offline":
		if not recovery_checkpoint.is_empty():
			save_retry-=delta
			if save_retry<=0:recover_save();save_retry=1.
		super._physics_process(delta);return
	if network_role=="client":
		if not connected:
			join_time+=delta
			if join_time>12:close_network("방 참가 시간이 초과됐습니다.")
		elif save_failed:
			save_retry=maxf(0,save_retry-delta)
			if save_retry<=0:save_game()
		return
	if not connected:return
	save_retry=maxf(0.,save_retry-delta)
	if paused:sim.set_input(local_id,Vector2.ZERO,sim.players[local_id].aim,false)
	sim.tick(delta);flush_events();refresh();snapshot_time+=delta;checkpoint_time+=delta
	if snapshot_time>=.1:publish_snapshot();snapshot_time=0.
	if checkpoint_time>=2.:save_game();publish_checkpoints();checkpoint_time=0.

func disconnect_game()->bool:
	if network_role=="offline":return super.disconnect_game()
	if not connected:close_network("방 참가를 취소했습니다.");return true
	if not leaving:leave_room()
	return not connected

func leave_room()->bool:
	if network_role=="offline":return super.disconnect_game()
	if leaving:return false
	leaving=true;exit_saved=false;exit_result=false
	exit_token=("host:" if network_role=="host" else "guest:")+str(Time.get_ticks_usec())
	room_status="최신 기록 저장 중…";status_changed.emit(room_status)
	var token=exit_token
	if network_role=="host":
		sim.players[local_id].network_leaving=true
		if not save_game():cancel_departure(token);return false
		for id in sim.players:
			if id!=local_id:start_departure(id,token)
	else:request_leave.rpc_id(1,token,sequence)
	var deadline=Time.get_ticks_msec()+15000
	while connected and leaving and Time.get_ticks_msec()<deadline:
		if network_role=="host" and departures.values().all(func(entry):return entry.get("ack",false)) and sim.players.keys().all(func(id):return id==local_id or departures.get(id,{}).get("ack",false)):
			exit_result=true;close_network("모두의 최신 기록을 저장하고 방을 닫았습니다.");return true
		await get_tree().process_frame
	if connected and leaving:
		if network_role=="client":cancel_leave.rpc_id(1,token)
		cancel_departure(token)
	return exit_result

func start_departure(id:int,token:String):
	sim.players[id].network_leaving=true
	departures[id]={"token":token,"ack":false}
	if not peer_ready(id):return
	var saved=sim.persistent(id);saved.world_seed=world_seed;checkpoint_revision+=1
	exit_checkpoint.rpc_id(id,token,saved,checkpoint_revision,int(last_sequence.get(id,0)))

@rpc("any_peer","call_remote","reliable",2)
func request_leave(token:String,last_serial:int):
	if network_role!="host" or leaving or token.length()>80:return
	var id=multiplayer.get_remote_sender_id()
	if not sim.players.has(id) or last_serial!=int(last_sequence.get(id,0)):return
	start_departure(id,token)

@rpc("authority","call_remote","reliable",2)
func exit_checkpoint(token:String,data:Dictionary,revision:int,last_serial:int):
	if network_role!="client" or (not token.begins_with("host:") and token!=exit_token):return
	leaving=true;exit_token=token;exit_saved=false
	var valid=validate_save(JSON.parse_string(JSON.stringify(data)))
	var success=valid!=null and revision>=accepted_checkpoint_revision and last_serial>=sequence
	if success:
		latest_checkpoint=valid;accepted_checkpoint_revision=revision;success=save_game()
	exit_saved=success;exit_ack.rpc_id(1,token,success)
	if not success:cancel_departure(token)

@rpc("any_peer","call_remote","reliable",2)
func exit_ack(token:String,success:bool):
	if network_role!="host":return
	var id=multiplayer.get_remote_sender_id()
	if departures.get(id,{}).get("token","")!=token:return
	if not success:
		if leaving:cancel_departure(token)
		else:sim.players[id].erase("network_leaving");departures.erase(id)
		return
	departures[id].ack=true
	if not leaving and peer_ready(id):commit_exit.rpc_id(id,token)

@rpc("authority","call_remote","reliable",2)
func commit_exit(token:String):
	if network_role=="client" and token==exit_token and exit_saved:
		exit_result=true;close_network("최신 기록을 저장하고 방을 나왔습니다.")

@rpc("any_peer","call_remote","reliable",2)
func cancel_leave(token:String):
	if network_role!="host":return
	var id=multiplayer.get_remote_sender_id()
	if departures.get(id,{}).get("token","")==token:
		if sim.players.has(id):sim.players[id].erase("network_leaving")
		departures.erase(id)

@rpc("authority","call_remote","reliable",2)
func cancel_exit(token:String):
	if network_role=="client" and token==exit_token:cancel_departure(token)

func cancel_departure(token:String):
	if token!=exit_token:return
	if network_role=="host":
		for id in sim.players:
			sim.players[id].erase("network_leaving")
			if id!=local_id and peer_ready(id):cancel_exit.rpc_id(id,token)
		departures.clear()
	leaving=false;exit_saved=false;exit_token="";exit_result=false
	room_status="저장을 확인하지 못해 방에 남았습니다. 다시 시도하세요.";status_changed.emit(room_status)
