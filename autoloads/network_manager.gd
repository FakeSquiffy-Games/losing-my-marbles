extends Node

const UDP_PORT: int = 8912
const DEFAULT_GAME_PORT: int = 8913
const BROADCAST_INTERVAL: float = 2.0
const DISCOVERY_POLL_INTERVAL: float = 0.5
const SESSION_KEY_LENGTH: int = 6

var session_key: String = ""
var is_host: bool = false
var connected_peers: Array[int] = []
var local_player_id: int = 1

var _broadcast_socket: PacketPeerUDP
var _discovery_server: UDPServer
var _broadcast_timer: Timer
var _discovery_timer: Timer
var _target_session_key: String = ""

func _ready() -> void:
	_broadcast_timer = Timer.new()
	_broadcast_timer.timeout.connect(_broadcast_session)
	add_child(_broadcast_timer)

	_discovery_timer = Timer.new()
	_discovery_timer.timeout.connect(_poll_discovery)
	add_child(_discovery_timer)

func host_game(port: int = DEFAULT_GAME_PORT) -> void:
	_teardown_peer()
	session_key = _generate_session_key()
	is_host = true
	local_player_id = 1

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		SignalBus.connection_failed.emit("Failed to create server: %d" % err)
		return

	multiplayer.multiplayer_peer = peer
	_safe_connect(multiplayer.peer_connected, _on_peer_connected)
	_safe_connect(multiplayer.peer_disconnected, _on_peer_disconnected)

	_start_udp_broadcast()
	SignalBus.server_started.emit()
	SignalBus.session_key_updated.emit(session_key)

func join_game_by_key(key: String) -> void:
	_target_session_key = key.to_upper().strip_edges()
	_start_udp_discovery()

func reset_network() -> void:
	_stop_broadcast()
	_stop_discovery()
	_teardown_peer()
	is_host = false
	session_key = ""
	connected_peers.clear()

func _teardown_peer() -> void:
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

func _safe_connect(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)

func create_offline_game() -> void:
	_teardown_peer()
	is_host = true
	local_player_id = 1
	session_key = "OFFLINE"

	var peer := OfflineMultiplayerPeer.new()
	multiplayer.multiplayer_peer = peer
	SignalBus.server_started.emit()
	SignalBus.session_key_updated.emit(session_key)

func get_opponent_id() -> int:
	for id in connected_peers:
		if id != local_player_id:
			return id
	return -1

func _on_peer_connected(peer_id: int) -> void:
	connected_peers.append(peer_id)
	SignalBus.player_connected.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	connected_peers.erase(peer_id)
	SignalBus.player_disconnected.emit(peer_id)

func _generate_session_key() -> String:
	const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var key := ""
	for _i in SESSION_KEY_LENGTH:
		key += CHARS[randi() % CHARS.length()]
	return key

func _start_udp_broadcast() -> void:
	_broadcast_socket = PacketPeerUDP.new()
	_broadcast_socket.set_broadcast_enabled(true)
	_broadcast_socket.set_dest_address("255.255.255.255", UDP_PORT)
	_broadcast_timer.start(BROADCAST_INTERVAL)

func _broadcast_session() -> void:
	if not is_host or not _broadcast_socket:
		return
	var packet := ("LMM:%s:%d" % [session_key, DEFAULT_GAME_PORT]).to_utf8_buffer()

	# Broadcast to LAN
	_broadcast_socket.set_dest_address("255.255.255.255", UDP_PORT)
	_broadcast_socket.put_packet(packet)

	# Also unicast to localhost for same-machine discovery
	_broadcast_socket.set_dest_address("127.0.0.1", UDP_PORT)
	_broadcast_socket.put_packet(packet)

func _start_udp_discovery() -> void:
	_discovery_server = UDPServer.new()
	_discovery_server.listen(UDP_PORT)
	_discovery_timer.start(DISCOVERY_POLL_INTERVAL)

func _poll_discovery() -> void:
	if not _discovery_server or not _discovery_server.is_listening():
		return
	_discovery_server.poll()
	if _discovery_server.is_connection_available():
		var peer := _discovery_server.take_connection()
		if peer and peer.get_available_packet_count() > 0:
			var packet := peer.get_packet().get_string_from_utf8()
			if packet.begins_with("LMM:"):
				var parts := packet.split(":")
				if parts.size() >= 3 and parts[1] == _target_session_key:
					var address := peer.get_packet_ip()
					var host_port := int(parts[2])
					_connect_to_host(address, host_port)

func _connect_to_host(address: String, port: int) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		SignalBus.connection_failed.emit("Failed to connect: %d" % err)
		return

	multiplayer.multiplayer_peer = peer
	_safe_connect(multiplayer.connection_failed, _on_connection_failed)
	_safe_connect(multiplayer.connected_to_server, _on_connected_to_server)

func _on_connected_to_server() -> void:
	multiplayer.connection_failed.disconnect(_on_connection_failed)
	multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	local_player_id = multiplayer.get_unique_id()
	_stop_discovery()
	SignalBus.connected_to_server.emit()

func _on_connection_failed() -> void:
	multiplayer.connection_failed.disconnect(_on_connection_failed)
	multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	_stop_discovery()
	SignalBus.connection_failed.emit("Connection failed")

func _stop_discovery() -> void:
	_discovery_timer.stop()
	if _discovery_server:
		_discovery_server.stop()
		_discovery_server = null

func _stop_broadcast() -> void:
	_broadcast_timer.stop()
	if _broadcast_socket:
		_broadcast_socket.close()
		_broadcast_socket = null

func _exit_tree() -> void:
	_stop_broadcast()
	_stop_discovery()
	_teardown_peer()
