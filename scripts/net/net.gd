extends Node
## Autoload singleton (registered as `Net` in project.godot): the online
## (direct-IP) connection, and the messages sent over it. An autoload so
## the connection survives the menu -> court scene change.
##
## Host-authoritative, two players, no server: the host plays team A and
## runs all the physics; the client plays team B and only displays what
## the host sends. A throw crosses the network as its aim (yaw, pitch,
## place on the line) plus the swing gauge angle — never as physics — and
## the host sends each throw's ThrowResult back. Both sides feed the same
## results through the same rules engine, so score and turn order can't
## drift apart. While a throw is moving, the host streams body transforms
## so the client sees it happen; see OnlineLink for the court side.
##
## Connecting: the host listens on PORT and tries to open it on the router
## with UPnP; the client types the host's address. When UPnP can't (CGNAT,
## office networks), a VPN like Tailscale/ZeroTier works with no changes —
## the client just joins the host's VPN address.

signal lobby_status(text: String)  ## progress for the menu to show
signal lobby_failed(text: String)  ## the connection attempt ended
signal peer_left                   ## the other player disconnected
signal opponent_ready              ## the other side's court scene is up
signal aim_received(yaw: float, elevation: float, offset: float)
signal throw_requested_by_client(yaw: float, elevation: float, offset: float, gauge: float)
signal throw_started(number: int)
signal snapshot_received(number: int, data: PackedFloat32Array)
signal result_received(result: Dictionary, snapshot: PackedFloat32Array)
signal impact_received(kind: int, strength: float, at: Vector3)

enum Role { OFFLINE, HOST, CLIENT }

const PORT := 24480
const PROTOCOL_VERSION := 3  ## bump when any message changes (2: tower mode, 3: own-pesä results); mismatched peers are turned away
const COURT_SCENE := "res://scenes/court.tscn"
const SETTINGS_PATH := "user://online.cfg"

var role: Role = Role.OFFLINE
var local_team: int = 0  ## 0 = team A (the host), 1 = team B (the client)
var opponent_court_ready: bool = false  ## set by the other side's court_ready, reset each match
var last_address: String = ""  ## remembered for the Join field
var last_team_name: String = ""

var _local_team_name: String = ""
var _opponent_id: int = 0
var _upnp: UPNP
var _upnp_status: String = ""
var _upnp_task: int = -1


func _ready() -> void:
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		last_address = settings.get_value("online", "address", "")
		last_team_name = settings.get_value("online", "team_name", "")
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## Quitting mid-UPnP would free this node under the worker thread, so wait
## for it (discovery times out after ~2 s).
func _exit_tree() -> void:
	if _upnp_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_upnp_task)
		_upnp_task = -1


func is_online() -> bool:
	return role != Role.OFFLINE


func is_host() -> bool:
	return role == Role.HOST


func is_client() -> bool:
	return role == Role.CLIENT


# Lobby -----------------------------------------------------------------------

## Starts listening for the other player. The season is whatever
## GameMode.current is when they connect.
func host(team_name: String) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	role = Role.HOST
	local_team = 0
	_local_team_name = team_name
	_remember("", team_name)
	_upnp_status = "Trying to open the port on your router…"
	_emit_host_status()
	if DisplayServer.get_name() != "headless":
		_upnp_task = WorkerThreadPool.add_task(_open_port)
	return OK


## Connects to a host at "address" or "address:port".
func join(address: String, team_name: String) -> Error:
	leave()
	var host_part := address.strip_edges()
	var port := PORT
	if host_part.count(":") == 1:  # not an IPv6 address
		port = int(host_part.get_slice(":", 1))
		host_part = host_part.get_slice(":", 0)
	if host_part == "":
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host_part, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	role = Role.CLIENT
	local_team = 1
	_local_team_name = team_name
	_remember(address.strip_edges(), team_name)
	lobby_status.emit("Connecting to %s…" % address)
	return OK


## Closes the connection (and the router port, if UPnP opened one).
func leave() -> void:
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	role = Role.OFFLINE
	_opponent_id = 0
	opponent_court_ready = false
	if _upnp != null:
		var upnp := _upnp
		_upnp = null
		WorkerThreadPool.add_task(func() -> void: upnp.delete_port_mapping(PORT, "UDP"))


## Host: start (or restart, for a Rematch) the match on both machines.
func start_match() -> void:
	if not is_host() or _opponent_id == 0:
		return
	_start_match.rpc(GameMode.current, GameMode.team_names)
	_start_match(GameMode.current, GameMode.team_names)


func _on_peer_connected(id: int) -> void:
	if not is_host():
		return
	if _opponent_id != 0:
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id)  # two players only
		return
	_opponent_id = id
	lobby_status.emit("Someone's connecting…")


func _on_peer_disconnected(id: int) -> void:
	if id != _opponent_id:
		return
	_opponent_id = 0
	opponent_court_ready = false
	peer_left.emit()
	if is_host():
		_emit_host_status()


func _on_connected_to_server() -> void:
	_opponent_id = 1
	lobby_status.emit("Connected — waiting for the host…")
	_hello.rpc_id(1, PROTOCOL_VERSION, _local_team_name)


func _on_connection_failed() -> void:
	leave()
	lobby_failed.emit("Couldn't connect. Check the address, and that the host is waiting.")


func _on_server_disconnected() -> void:
	_opponent_id = 0
	peer_left.emit()


@rpc("any_peer", "reliable")
func _hello(version: int, team_name: String) -> void:
	if not is_host() or multiplayer.get_remote_sender_id() != _opponent_id:
		return
	if version != PROTOCOL_VERSION:
		_rejected.rpc_id(_opponent_id, "The host is running a different version of the game.")
		return
	GameMode.set_team_names(_local_team_name, team_name)
	start_match()


@rpc("authority", "reliable")
func _rejected(reason: String) -> void:
	leave()
	lobby_failed.emit(reason)


@rpc("authority", "reliable")
func _start_match(season: int, names: Array) -> void:
	GameMode.current = season as GameMode.Mode
	var typed: Array[String] = []
	typed.assign(names)
	GameMode.team_names = typed
	opponent_court_ready = false
	get_tree().paused = false
	get_tree().change_scene_to_file(COURT_SCENE)


func _open_port() -> void:
	var upnp := UPNP.new()
	var status := "Couldn't open the port automatically: they'll need to be on your network, or you both on a VPN like Tailscale (or forward UDP %d on your router)." % PORT
	if upnp.discover(2000, 2) == UPNP.UPNP_RESULT_SUCCESS and upnp.get_gateway() != null and upnp.get_gateway().is_valid_gateway():
		if upnp.add_port_mapping(PORT, PORT, "Kyykka", "UDP") == UPNP.UPNP_RESULT_SUCCESS:
			status = "Over the internet: %s (port opened automatically)." % upnp.query_external_address()
			_finish_port.call_deferred(upnp, status)
			return
	_finish_port.call_deferred(null, status)


func _finish_port(upnp: UPNP, status: String) -> void:
	if _upnp_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_upnp_task)
		_upnp_task = -1
	if not is_host():  # left while UPnP was working
		if upnp != null:
			WorkerThreadPool.add_task(func() -> void: upnp.delete_port_mapping(PORT, "UDP"))
		return
	_upnp = upnp
	_upnp_status = status
	if _opponent_id == 0:
		_emit_host_status()


func _emit_host_status() -> void:
	var lan: Array[String] = []
	for address in IP.get_local_addresses():
		if address.count(".") == 3 and not address.begins_with("127.") and not address.begins_with("169.254."):
			lan.append(address)
	lobby_status.emit("Waiting for the other player to join…\nOn the same network: %s\n%s" % [", ".join(lan) if not lan.is_empty() else "(no network found)", _upnp_status])


func _remember(address: String, team_name: String) -> void:
	if address != "":
		last_address = address
	last_team_name = team_name
	var settings := ConfigFile.new()
	settings.set_value("online", "address", last_address)
	settings.set_value("online", "team_name", last_team_name)
	settings.save(SETTINGS_PATH)


# Match messages (see OnlineLink) ---------------------------------------------

func send_court_ready() -> void:
	if _opponent_id != 0:
		_court_ready.rpc_id(_opponent_id)


@rpc("any_peer", "reliable")
func _court_ready() -> void:
	opponent_court_ready = true
	opponent_ready.emit()


func send_aim(yaw: float, elevation: float, offset: float) -> void:
	if _opponent_id != 0:
		_aim.rpc_id(_opponent_id, yaw, elevation, offset)


@rpc("any_peer", "unreliable_ordered")
func _aim(yaw: float, elevation: float, offset: float) -> void:
	aim_received.emit(yaw, elevation, offset)


func send_throw_request(yaw: float, elevation: float, offset: float, gauge: float) -> void:
	if is_client():
		_request_throw.rpc_id(1, yaw, elevation, offset, gauge)


@rpc("any_peer", "reliable")
func _request_throw(yaw: float, elevation: float, offset: float, gauge: float) -> void:
	if is_host() and multiplayer.get_remote_sender_id() == _opponent_id:
		throw_requested_by_client.emit(yaw, elevation, offset, gauge)


func send_throw_started(number: int) -> void:
	if is_host() and _opponent_id != 0:
		_throw_started.rpc_id(_opponent_id, number)


@rpc("authority", "reliable")
func _throw_started(number: int) -> void:
	throw_started.emit(number)


func send_snapshot(number: int, data: PackedFloat32Array) -> void:
	if is_host() and _opponent_id != 0:
		_snapshot.rpc_id(_opponent_id, number, data)


@rpc("authority", "unreliable_ordered")
func _snapshot(number: int, data: PackedFloat32Array) -> void:
	snapshot_received.emit(number, data)


func send_result(result: Dictionary, snapshot: PackedFloat32Array) -> void:
	if is_host() and _opponent_id != 0:
		_result.rpc_id(_opponent_id, result, snapshot)


@rpc("authority", "reliable")
func _result(result: Dictionary, snapshot: PackedFloat32Array) -> void:
	result_received.emit(result, snapshot)


func send_impact(kind: int, strength: float, at: Vector3) -> void:
	if is_host() and _opponent_id != 0:
		_impact.rpc_id(_opponent_id, kind, strength, at)


@rpc("authority", "unreliable")
func _impact(kind: int, strength: float, at: Vector3) -> void:
	impact_received.emit(kind, strength, at)
