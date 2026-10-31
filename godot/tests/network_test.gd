extends SceneTree

var node: Node
var net: ChessNetwork
var game: ChessMatch
var host_mode = false
var received = 0

func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	host_mode = "--host" in OS.get_cmdline_user_args()
	node = Node.new()
	node.name = "NetworkTest"
	root.add_child(node)
	net = ChessNetwork.new()
	net.name = "Network"
	node.add_child(net)
	create_timer(15).timeout.connect(func() -> void:
		printerr("NETWORK_TEST_FAILED: timed out")
		net.close()
		quit(1)
	)
	if host_mode:
		game = ChessMatch.new(42)
		game.cards_unlocked = true
		game.draw_cards(0,2)
		game.draw_cards(1,2)
		game.apply({"op":"move","id":game.at(Vector2i(0,6)).id,"pos":Vector2i(0,5)})
		net.command_received.connect(_command)
		if net.host(game,18799)!=OK:
			printerr("NETWORK_TEST_FAILED: could not bind test port")
			quit(1)
		else: print("NETWORK_HOST_READY")
	else:
		net.state_received.connect(_state)
		if net.join("127.0.0.1",18799)!=OK:
			quit(1)

func _command(command: Dictionary, role: int) -> void:
	if role!=1 or not game.apply(command,role).ok:
		printerr("NETWORK_TEST_FAILED: host rejected legal client move")
		net.close()
		quit(1)
		return
	net.broadcast([])
	if game.turn==0 and game.ply==2 and not game.at(Vector2i(0,2)).is_empty():
		print("NETWORK_HOST_PASS: authoritative client move applied")
		await create_timer(0.6).timeout
		net.close()
		quit(0)

func _state(state: Dictionary, _events: Array) -> void:
	var current = ChessMatch.new(1,false)
	current.restore(state)
	if not current.valid():
		printerr("NETWORK_TEST_FAILED: invalid snapshot")
		quit(1)
		return
	if received==0:
		if current.players[0].hand[0].id!="hidden" or current.players[1].hand[0].id=="hidden":
			printerr("NETWORK_TEST_FAILED: private hand exposure")
			quit(1)
			return
		received+=1
		net.send({"op":"move","id":current.at(Vector2i(0,1)).id,"pos":Vector2i(0,2),"revision":current.revision})
	else:
		if current.ply==2 and current.turn==0 and not current.at(Vector2i(0,2)).is_empty():
			print("NETWORK_CLIENT_PASS: connected, private hands, submitted move and synchronized board")
			net.close()
			quit(0)
