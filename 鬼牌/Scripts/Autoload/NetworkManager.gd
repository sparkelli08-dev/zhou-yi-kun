extends Node

# 网络管理器 - 处理 Steam P2P 网络通信

signal message_received(sender_id: int, message: Dictionary)
signal connection_established(peer_id: int)
signal connection_failed(peer_id: int)

enum MessageType {
	PLAYER_READY,
	GAME_START,
	DEAL_CARDS,
	CLAIM_CARDS,       # 声明出牌
	PLAY_CARDS,        # 实际出牌
	FOLLOW_CARDS,      # 跟牌
	CHALLENGE,         # 质疑
	CHALLENGE_RESULT,  # 质疑结果
	PASS,              # 过牌
	ROUND_END,         # 回合结束
	GAME_END,          # 游戏结束
	SYNC_STATE,        # 同步游戏状态
	CHAT_MESSAGE       # 聊天消息
}

const CHANNEL_GAME = 0
var is_host: bool = false
var connected_peers: Array = []

func _ready() -> void:
	# 等待 Steam 初始化后再连接信号
	SteamManager.steam_initialized.connect(_on_steam_initialized)

	# 如果 Steam 已经初始化，直接连接信号
	if SteamManager.is_steam_initialized:
		_setup_steam_signals()

func _on_steam_initialized(success: bool) -> void:
	if success:
		_setup_steam_signals()

func _setup_steam_signals() -> void:
	# 连接 Steam P2P 信号
	Steam.p2p_session_request.connect(_on_p2p_session_request)
	Steam.p2p_session_connect_fail.connect(_on_p2p_session_connect_fail)

func _process(_delta: float) -> void:
	if SteamManager.is_steam_initialized:
		_read_p2p_packets()

# 读取 P2P 数据包
func _read_p2p_packets() -> void:
	while Steam.getAvailableP2PPacketSize(CHANNEL_GAME) > 0:
		var packet_size = Steam.getAvailableP2PPacketSize(CHANNEL_GAME)
		var packet = Steam.readP2PPacket(packet_size, CHANNEL_GAME)

		# 检查数据包是否有效
		if packet.is_empty() or not packet.has("data") or not packet.has("remote_steam_id"):
			print("警告: 收到无效的 P2P 数据包")
			continue

		var sender_id: int = packet["remote_steam_id"]
		var data: PackedByteArray = packet["data"]

		# 解析消息
		var message = bytes_to_var(data)
		if message is Dictionary:
			message_received.emit(sender_id, message)

# 发送消息给特定玩家
func send_message_to(peer_id: int, message: Dictionary) -> void:
	if not SteamManager.is_steam_initialized:
		return

	var data = var_to_bytes(message)
	Steam.sendP2PPacket(peer_id, data, Steam.P2P_SEND_RELIABLE, CHANNEL_GAME)

# 发送消息给所有玩家（广播）
func send_message_to_all(message: Dictionary, exclude_self: bool = true) -> void:
	for member in SteamManager.lobby_members:
		var peer_id = member["steam_id"]
		if exclude_self and peer_id == SteamManager.steam_id:
			continue
		send_message_to(peer_id, message)

# 发送消息给房主
func send_message_to_host(message: Dictionary) -> void:
	if not SteamManager.is_steam_initialized or is_host:
		return

	var owner_id = Steam.getLobbyOwner(SteamManager.current_lobby_id)
	send_message_to(owner_id, message)

# Steam 回调：收到 P2P 会话请求
func _on_p2p_session_request(remote_id: int) -> void:
	var requester_name = Steam.getFriendPersonaName(remote_id)
	print("收到来自 ", requester_name, " 的 P2P 连接请求")

	# 接受连接请求
	Steam.acceptP2PSessionWithUser(remote_id)

	if remote_id not in connected_peers:
		connected_peers.append(remote_id)

	connection_established.emit(remote_id)

# Steam 回调：P2P 连接失败
func _on_p2p_session_connect_fail(steam_id: int, session_error: int) -> void:
	var error_msg = "未知错误"
	match session_error:
		0: error_msg = "无错误"
		1: error_msg = "目标用户未运行相同游戏"
		2: error_msg = "本地用户无 Steam 会话"
		3: error_msg = "无连接"
		4: error_msg = "超时"
		5: error_msg = "目标用户未连接"

	push_error("与玩家 " + str(steam_id) + " 的 P2P 连接失败: " + error_msg)
	connection_failed.emit(steam_id)

# 关闭与指定玩家的连接
func close_p2p_session(peer_id: int) -> void:
	if SteamManager.is_steam_initialized:
		Steam.closeP2PSessionWithUser(peer_id)
	connected_peers.erase(peer_id)

# 关闭所有 P2P 连接
func close_all_p2p_sessions() -> void:
	if SteamManager.is_steam_initialized:
		for peer_id in connected_peers:
			Steam.closeP2PSessionWithUser(peer_id)
	connected_peers.clear()

# 设置为房主
func set_as_host() -> void:
	is_host = true

# 设置为客户端
func set_as_client() -> void:
	is_host = false

# 便捷方法：发送玩家准备消息
func send_player_ready() -> void:
	send_message_to_host({
		"type": MessageType.PLAYER_READY,
		"player_id": SteamManager.steam_id
	})

# 便捷方法：发送游戏开始消息（仅房主）
func send_game_start(game_config: Dictionary) -> void:
	if is_host:
		send_message_to_all({
			"type": MessageType.GAME_START,
			"config": game_config
		}, false)

# 便捷方法：发送发牌消息
func send_deal_cards(player_id: int, cards: Array) -> void:
	send_message_to(player_id, {
		"type": MessageType.DEAL_CARDS,
		"cards": cards
	})

# 便捷方法：发送声明出牌消息
func send_claim_cards(claimed_rank: String, claimed_count: int) -> void:
	send_message_to_all({
		"type": MessageType.CLAIM_CARDS,
		"player_id": SteamManager.steam_id,
		"rank": claimed_rank,
		"count": claimed_count
	})

# 便捷方法：发送实际出牌消息（仅发给房主用于验证）
func send_play_cards(cards: Array) -> void:
	send_message_to_all({
		"type": MessageType.PLAY_CARDS,
		"player_id": SteamManager.steam_id,
		"cards": cards
	})

# 便捷方法：发送质疑消息
func send_challenge() -> void:
	send_message_to_all({
		"type": MessageType.CHALLENGE,
		"challenger_id": SteamManager.steam_id
	})

# 便捷方法：发送质疑结果
func send_challenge_result(success: bool, cards: Array, penalty_player: int) -> void:
	send_message_to_all({
		"type": MessageType.CHALLENGE_RESULT,
		"success": success,
		"revealed_cards": cards,
		"penalty_player": penalty_player
	}, false)

# 便捷方法：发送过牌消息
func send_pass() -> void:
	send_message_to_all({
		"type": MessageType.PASS,
		"player_id": SteamManager.steam_id
	})

# 便捷方法：发送跟牌消息
func send_follow_cards(claimed_rank: String, claimed_count: int, cards: Array) -> void:
	send_message_to_all({
		"type": MessageType.FOLLOW_CARDS,
		"player_id": SteamManager.steam_id,
		"rank": claimed_rank,
		"count": claimed_count,
		"cards": cards
	})

# 便捷方法：发送游戏状态同步
func send_sync_state(state: Dictionary) -> void:
	if is_host:
		send_message_to_all({
			"type": MessageType.SYNC_STATE,
			"state": state
		}, false)
