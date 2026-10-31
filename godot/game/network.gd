class_name ChessNetwork
extends Node
## Native two-player ENet transport. The host alone executes commands.

signal state_received(snapshot: Dictionary, messages: Array)
signal command_received(command: Dictionary, role: int)
signal status_changed(message: String)

var guest_id = 0
var role = -1
var server_game: ChessMatch
var active = false
var timer_seconds = 0
var time_remaining = 0.0

func _ready() -> void:
	multiplayer.peer_connected.connect(_connected)
	multiplayer.peer_disconnected.connect(_disconnected)
	multiplayer.connected_to_server.connect(func() -> void:
		status_changed.emit("Connected. Waiting for the host's board...")
	)
	multiplayer.connection_failed.connect(func() -> void:
		status_changed.emit("Could not connect. Check the address, port and host firewall.")
		close()
	)
	multiplayer.server_disconnected.connect(func() -> void:
		status_changed.emit("The host disconnected. Your local copy is paused.")
		close()
	)

func host(game: ChessMatch, port: int = 8799) -> Error:
	close()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port,1)
	if error != OK:
		return error
	server_game = game
	multiplayer.multiplayer_peer = peer
	role = 0
	active = true
	status_changed.emit("Hosting on port %d. Share your LAN or Tailscale address." % port)
	return OK

func join(address: String, port: int = 8799) -> Error:
	close()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address.strip_edges(),port)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	role = 1
	active = true
	return OK

func close() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	guest_id = 0
	active = false
	role = -1
	server_game = null

func _connected(id: int) -> void:
	if multiplayer.is_server() and server_game != null:
		guest_id = id
		_sync.rpc_id(id,server_game.public_snapshot(1),[],timer_seconds,time_remaining)
		status_changed.emit("Onyx has joined. The match is ready.")

func _disconnected(id: int) -> void:
	if id == guest_id:
		guest_id = 0
		status_changed.emit("Onyx disconnected. Keep hosting to allow a rejoin.")

func broadcast(messages: Array = []) -> void:
	if active and role == 0 and guest_id > 0 and server_game != null:
		_sync.rpc_id(guest_id,server_game.public_snapshot(1),ChessMatch.encode(messages),timer_seconds,time_remaining)

func send(command: Dictionary) -> void:
	if active and role == 1:
		_submit.rpc_id(1,ChessMatch.encode(command))

@rpc("any_peer","call_remote","reliable")
func _submit(command: Dictionary) -> void:
	if not active or not multiplayer.is_server() or multiplayer.get_remote_sender_id() != guest_id:
		return
	command_received.emit(ChessMatch.decode(command),1)

@rpc("authority","call_remote","reliable")
func _sync(state: Dictionary, messages: Array, seconds: int, remaining: float) -> void:
	if active and role == 1:
		timer_seconds=seconds
		time_remaining=remaining
		state_received.emit(state,ChessMatch.decode(messages))
