extends Node

# 游戏状态管理器 - 管理游戏核心逻辑

signal game_started()
signal cards_dealt(player_id: int, cards: Array)
signal turn_changed(player_id: int)
signal cards_claimed(player_id: int, rank: String, count: int)
signal cards_played(player_id: int, card_count: int)
signal cards_followed(player_id: int, rank: String, count: int)
signal player_challenged(challenger_id: int, target_id: int)
signal challenge_result(success: bool, cards: Array, penalty_player: int)
signal player_passed(player_id: int)
signal round_ended()
signal player_won(player_id: int)
signal game_ended(winner_id: int)

enum GameState {
	WAITING,        # 等待玩家
	DEALING,        # 发牌中
	PLAYING,        # 游戏中
	CHALLENGING,    # 质疑阶段
	ROUND_END,      # 回合结束
	GAME_END        # 游戏结束
}

enum TurnPhase {
	CLAIM,          # 声明阶段
	WAIT_RESPONSE,  # 等待其他玩家响应（质疑/跟牌/过牌）
	REVEAL          # 翻牌阶段（质疑后）
}

# 游戏配置
var max_players: int = 6
var min_players: int = 2
var challenge_time: int = 10  # 质疑时间（秒）

# 游戏状态
var current_state: GameState = GameState.WAITING
var current_phase: TurnPhase = TurnPhase.CLAIM

# 玩家管理
var players: Array = []  # 玩家列表 {steam_id, name, hand, card_count, is_ready}
var current_player_index: int = 0
var first_player_index: int = 0  # 首个出牌玩家（每轮胜者）

# 牌堆
var deck: Deck = Deck.new()

# 当前回合数据
var table_cards: Array = []  # 桌上的牌（叩置状态）
var table_claims: Array = []  # 桌上的声明列表 [{player_id, rank, count, actual_cards}]
var current_claim: Dictionary = {}  # 当前声明
var players_passed: Array = []  # 已经过牌的玩家
var challenge_timer: float = 0.0
var waiting_for_responses: bool = false

# 质疑相关
var challenger_id: int = 0
var challenge_target_index: int = -1  # 被质疑的玩家索引（table_claims 中的索引）

func _ready() -> void:
	add_child(deck)
	NetworkManager.message_received.connect(_on_network_message_received)

func _process(delta: float) -> void:
	# 质疑倒计时
	if waiting_for_responses and challenge_timer > 0:
		challenge_timer -= delta
		if challenge_timer <= 0:
			_on_challenge_timeout()

# ========== 游戏初始化 ==========

# 初始化游戏
func initialize_game(player_list: Array, config: Dictionary) -> void:
	players.clear()
	table_cards.clear()
	table_claims.clear()
	players_passed.clear()

	max_players = config.get("max_players", 6)
	challenge_time = config.get("challenge_time", 10)

	# 创建玩家数据
	for player_data in player_list:
		players.append({
			"steam_id": player_data["steam_id"],
			"name": player_data["name"],
			"hand": [],
			"card_count": 0,
			"is_ready": false
		})

	# 根据玩家数量决定使用几副牌
	var deck_count = 1 if players.size() <= 3 else 2
	deck.create_multiple_decks(deck_count)
	deck.shuffle()

	current_state = GameState.DEALING
	print("游戏初始化完成，玩家数: ", players.size(), "，使用 ", deck_count, " 副牌")

# 开始游戏
func start_game() -> void:
	if players.size() < min_players:
		push_error("玩家数量不足")
		return

	# 发牌
	deal_cards()

	# 随机选择首个出牌玩家
	first_player_index = randi() % players.size()
	current_player_index = first_player_index

	current_state = GameState.PLAYING
	current_phase = TurnPhase.CLAIM

	print("游戏开始！首个出牌玩家: ", players[first_player_index]["name"])
	game_started.emit()
	turn_changed.emit(players[current_player_index]["steam_id"])

# 发牌
func deal_cards() -> void:
	var hands = deck.deal_cards(players.size())

	for i in range(players.size()):
		players[i]["hand"] = hands[i]
		players[i]["card_count"] = hands[i].size()

		# 排序手牌
		players[i]["hand"].sort_custom(func(a, b): return a.get_sort_value() < b.get_sort_value())

		# 如果是房主，发送牌给每个玩家
		if NetworkManager.is_host:
			var cards_data = []
			for card in hands[i]:
				cards_data.append(card.to_dict())

			NetworkManager.send_deal_cards(players[i]["steam_id"], cards_data)

		print("玩家 ", players[i]["name"], " 获得 ", players[i]["card_count"], " 张牌")

# ========== 游戏流程控制 ==========

# 玩家声明出牌
func player_claim_cards(player_id: int, claimed_rank: String, claimed_count: int, actual_cards: Array) -> void:
	if current_state != GameState.PLAYING:
		return

	var player = get_player_by_id(player_id)
	if player == null or players[current_player_index]["steam_id"] != player_id:
		push_error("不是该玩家的回合")
		return

	# 验证玩家是否有这些牌
	if not validate_player_has_cards(player, actual_cards):
		push_error("玩家没有这些牌")
		return

	# 移除玩家手牌
	for card in actual_cards:
		for i in range(player["hand"].size()):
			if player["hand"][i].equals(card):
				player["hand"].remove_at(i)
				break

	player["card_count"] = player["hand"].size()

	# 记录声明
	current_claim = {
		"player_id": player_id,
		"rank": claimed_rank,
		"count": claimed_count,
		"actual_cards": actual_cards
	}

	# 添加到桌面
	table_claims.append(current_claim)
	table_cards.append_array(actual_cards)

	# 广播声明
	cards_claimed.emit(player_id, claimed_rank, claimed_count)
	cards_played.emit(player_id, actual_cards.size())

	# 检查玩家是否获胜
	if player["card_count"] == 0:
		_player_wins(player_id)
		return

	# 进入等待响应阶段
	current_phase = TurnPhase.WAIT_RESPONSE
	waiting_for_responses = true
	challenge_timer = challenge_time
	players_passed.clear()

	print("玩家 ", player["name"], " 声称出了 ", claimed_count, " 张 ", claimed_rank)

# 玩家跟牌
func player_follow_cards(player_id: int, claimed_rank: String, claimed_count: int, actual_cards: Array) -> void:
	if current_state != GameState.PLAYING or current_phase != TurnPhase.WAIT_RESPONSE:
		return

	var player = get_player_by_id(player_id)
	if player == null:
		return

	# 验证玩家是否有这些牌
	if not validate_player_has_cards(player, actual_cards):
		push_error("玩家没有这些牌")
		return

	# 移除玩家手牌
	for card in actual_cards:
		for i in range(player["hand"].size()):
			if player["hand"][i].equals(card):
				player["hand"].remove_at(i)
				break

	player["card_count"] = player["hand"].size()

	# 重置之前的声明和质疑状态
	table_claims.clear()
	players_passed.clear()

	# 记录新的声明
	current_claim = {
		"player_id": player_id,
		"rank": claimed_rank,
		"count": claimed_count,
		"actual_cards": actual_cards
	}

	table_claims.append(current_claim)
	table_cards.append_array(actual_cards)

	# 广播跟牌
	cards_followed.emit(player_id, claimed_rank, claimed_count)

	# 检查玩家是否获胜
	if player["card_count"] == 0:
		_player_wins(player_id)
		return

	# 重新开始倒计时
	challenge_timer = challenge_time
	waiting_for_responses = true

	print("玩家 ", player["name"], " 跟牌：声称出了 ", claimed_count, " 张 ", claimed_rank)

# 玩家质疑
func player_challenge(challenger_id_param: int) -> void:
	if current_state != GameState.PLAYING or current_phase != TurnPhase.WAIT_RESPONSE:
		return

	if table_claims.is_empty():
		return

	challenger_id = challenger_id_param
	challenge_target_index = table_claims.size() - 1  # 质疑最新的声明
	var target_claim = table_claims[challenge_target_index]

	waiting_for_responses = false
	current_phase = TurnPhase.REVEAL

	# 翻开牌检查
	var claimed_rank = target_claim["rank"]
	var claimed_count = target_claim["count"]
	var actual_cards: Array = target_claim["actual_cards"]

	# 验证声明是否正确
	var is_claim_correct = validate_claim(claimed_rank, claimed_count, actual_cards)

	var penalty_player_id: int
	var next_player_id: int

	if is_claim_correct:
		# 声明正确，质疑者拿走所有桌面的牌
		penalty_player_id = challenger_id
		var challenger = get_player_by_id(challenger_id)
		challenger["hand"].append_array(table_cards)
		challenger["card_count"] = challenger["hand"].size()

		# 下一个出牌者是被质疑者的下家
		var target_player_id = target_claim["player_id"]
		var target_index = get_player_index(target_player_id)
		current_player_index = (target_index + 1) % players.size()
		next_player_id = players[current_player_index]["steam_id"]

		print("质疑失败！质疑者 ", challenger["name"], " 拿走了 ", table_cards.size(), " 张牌")
	else:
		# 声明错误，出牌者拿回自己的牌
		penalty_player_id = target_claim["player_id"]
		var target_player = get_player_by_id(penalty_player_id)
		target_player["hand"].append_array(target_claim["actual_cards"])
		target_player["card_count"] = target_player["hand"].size()

		# 下一个出牌者是质疑者
		current_player_index = get_player_index(challenger_id)
		next_player_id = challenger_id

		print("质疑成功！出牌者 ", target_player["name"], " 拿回了自己的牌")

	# 广播质疑结果
	challenge_result.emit(not is_claim_correct, actual_cards, penalty_player_id)

	# 清空桌面
	table_cards.clear()
	table_claims.clear()
	players_passed.clear()

	# 进入下一回合
	current_phase = TurnPhase.CLAIM
	turn_changed.emit(next_player_id)

# 玩家过牌
func player_pass(player_id: int) -> void:
	if current_state != GameState.PLAYING or current_phase != TurnPhase.WAIT_RESPONSE:
		return

	if player_id in players_passed:
		return

	players_passed.append(player_id)
	player_passed.emit(player_id)

	print("玩家 ", get_player_by_id(player_id)["name"], " 选择过牌")

	# 检查是否所有其他玩家都过牌了
	var all_passed = true
	for player in players:
		if player["steam_id"] == current_claim["player_id"]:
			continue  # 跳过出牌者
		if player["steam_id"] not in players_passed:
			all_passed = false
			break

	if all_passed:
		_all_players_passed()

# 所有玩家都过牌
func _all_players_passed() -> void:
	print("所有玩家都过牌，牌进入弃牌堆")

	# 牌进入弃牌堆
	deck.add_to_discard(table_cards)
	table_cards.clear()
	table_claims.clear()
	players_passed.clear()

	waiting_for_responses = false

	# 下一个玩家出牌
	current_player_index = (current_player_index + 1) % players.size()
	current_phase = TurnPhase.CLAIM

	round_ended.emit()
	turn_changed.emit(players[current_player_index]["steam_id"])

# 质疑超时
func _on_challenge_timeout() -> void:
	# 如果没有人质疑，视为所有人过牌
	_all_players_passed()

# ========== 辅助方法 ==========

# 验证声明是否正确
func validate_claim(claimed_rank: String, claimed_count: int, actual_cards: Array) -> bool:
	if actual_cards.size() != claimed_count:
		return false

	for card in actual_cards:
		if not (card is Card):
			return false

		# 检查牌的点数是否匹配
		var card_rank_name = card.get_rank_name()
		if card_rank_name != claimed_rank:
			return false

	return true

# 验证玩家是否拥有这些牌
func validate_player_has_cards(player: Dictionary, cards: Array) -> bool:
	for card in cards:
		var has_card = false
		for hand_card in player["hand"]:
			if hand_card.equals(card):
				has_card = true
				break
		if not has_card:
			return false
	return true

# 根据 Steam ID 获取玩家
func get_player_by_id(steam_id: int) -> Dictionary:
	for player in players:
		if player["steam_id"] == steam_id:
			return player
	return {}

# 获取玩家索引
func get_player_index(steam_id: int) -> int:
	for i in range(players.size()):
		if players[i]["steam_id"] == steam_id:
			return i
	return -1

# 玩家获胜
func _player_wins(player_id: int) -> void:
	var player = get_player_by_id(player_id)
	print("玩家 ", player["name"], " 获胜！")

	player_won.emit(player_id)

	# 下一轮由获胜者先出牌
	first_player_index = get_player_index(player_id)
	current_player_index = first_player_index

	# 游戏结束（可以选择开始下一轮）
	current_state = GameState.GAME_END
	game_ended.emit(player_id)

# ========== 网络消息处理 ==========

func _on_network_message_received(sender_id: int, message: Dictionary) -> void:
	var msg_type = message.get("type", -1)

	match msg_type:
		NetworkManager.MessageType.PLAYER_READY:
			_handle_player_ready(sender_id)

		NetworkManager.MessageType.GAME_START:
			_handle_game_start(message["config"])

		NetworkManager.MessageType.DEAL_CARDS:
			_handle_deal_cards(message["cards"])

		NetworkManager.MessageType.CLAIM_CARDS:
			player_claim_cards(message["player_id"], message["rank"], message["count"], _cards_from_dict_array(message.get("cards", [])))

		NetworkManager.MessageType.FOLLOW_CARDS:
			player_follow_cards(message["player_id"], message["rank"], message["count"], _cards_from_dict_array(message["cards"]))

		NetworkManager.MessageType.CHALLENGE:
			player_challenge(message["challenger_id"])

		NetworkManager.MessageType.PASS:
			player_pass(message["player_id"])

func _handle_player_ready(player_id: int) -> void:
	var player = get_player_by_id(player_id)
	if player:
		player["is_ready"] = true
		print("玩家 ", player["name"], " 已准备")

func _handle_game_start(config: Dictionary) -> void:
	initialize_game(SteamManager.lobby_members, config)
	start_game()

func _handle_deal_cards(cards_data: Array) -> void:
	# 客户端接收发牌
	var my_hand: Array[Card] = []
	for card_data in cards_data:
		my_hand.append(Card.from_dict(card_data))

	var my_player = get_player_by_id(SteamManager.steam_id)
	if my_player:
		my_player["hand"] = my_hand
		my_player["card_count"] = my_hand.size()

	cards_dealt.emit(SteamManager.steam_id, my_hand)

func _cards_from_dict_array(cards_data: Array) -> Array:
	var cards: Array = []
	for card_data in cards_data:
		cards.append(Card.from_dict(card_data))
	return cards
