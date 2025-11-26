class_name GameManager
extends Node

enum GameState {
	SETUP,
	PLAYER_TURN,
	AI_TURN,
	CHALLENGE_WINDOW,
	RESOLUTION,
	GAME_OVER
}

const NUM_PLAYERS: int = 4
const CHALLENGE_WINDOW_DURATION: float = 3.0

var current_state: GameState = GameState.SETUP
var deck: Deck
var players: Array[Player] = []
var discard_pile: Array[Card] = []

var current_player_index: int = 0

var last_played_cards: Array[Card] = []
var last_claimed_rank: Card.Rank
var last_player: Player

var challenge_timer: float = 0.0
var pending_challenger: Player = null

signal game_state_changed(new_state: GameState)
signal turn_changed(player_index: int, player: Player)
signal cards_played_to_pile(player: Player, card_count: int, claimed_rank: Card.Rank)
signal challenge_window_started(duration: float)
signal challenge_window_ended()
signal challenge_made(challenger: Player, target: Player)
signal challenge_resolved(success: bool, loser: Player, pile_size: int)
signal pile_updated(pile_size: int)
signal game_won(winner: Player)

func _ready() -> void:
	setup_game()

func setup_game() -> void:
	change_state(GameState.SETUP)

	deck = Deck.new()
	add_child(deck)
	deck.reset()

	create_players()

	var hands = deck.deal_to_players(NUM_PLAYERS)
	for i in range(NUM_PLAYERS):
		players[i].receive_cards(hands[i] as Array[Card])

	current_player_index = 0

	change_state(GameState.PLAYER_TURN)

func create_players() -> void:
	players.clear()

	var human_player = Player.new("你", Player.PlayerType.HUMAN, 0)
	add_child(human_player)
	players.append(human_player)

	for i in range(1, NUM_PLAYERS):
		var ai_player = Player.new("AI 玩家 %d" % i, Player.PlayerType.AI, i)
		add_child(ai_player)
		players.append(ai_player)

	for player in players:
		player.cards_played.connect(_on_player_cards_played)
		player.challenge_initiated.connect(_on_challenge_initiated)

func change_state(new_state: GameState) -> void:
	current_state = new_state
	game_state_changed.emit(new_state)

	match new_state:
		GameState.PLAYER_TURN:
			turn_changed.emit(current_player_index, players[current_player_index])
		GameState.AI_TURN:
			turn_changed.emit(current_player_index, players[current_player_index])
			await get_tree().create_timer(1.0).timeout
			process_ai_turn()
		GameState.CHALLENGE_WINDOW:
			start_challenge_window()
		GameState.RESOLUTION:
			resolve_challenge()
		GameState.GAME_OVER:
			pass

func _process(delta: float) -> void:
	if current_state == GameState.CHALLENGE_WINDOW:
		challenge_timer -= delta
		if challenge_timer <= 0.0:
			end_challenge_window()

func process_ai_turn() -> void:
	if current_state != GameState.AI_TURN:
		return

	var current_player = players[current_player_index]
	var decision = current_player.decide_play()

	if decision.is_empty():
		return

	var cards: Array[Card] = decision["cards"]
	var claimed_rank: Card.Rank = decision["claimed_rank"]
	current_player.play_cards(cards, claimed_rank)

func player_play_cards(cards: Array[Card], claimed_rank: Card.Rank) -> void:
	if current_state != GameState.PLAYER_TURN:
		return

	if cards.is_empty():
		return

	var current_player = players[current_player_index]
	current_player.play_cards(cards, claimed_rank)

func _on_player_cards_played(player: Player, cards: Array[Card], claimed_rank: Card.Rank) -> void:
	last_played_cards = cards
	last_claimed_rank = claimed_rank
	last_player = player

	for card in cards:
		discard_pile.append(card)

	cards_played_to_pile.emit(player, cards.size(), claimed_rank)
	pile_updated.emit(discard_pile.size())

	if not player.has_cards():
		change_state(GameState.GAME_OVER)
		game_won.emit(player)
		return

	change_state(GameState.CHALLENGE_WINDOW)

func start_challenge_window() -> void:
	challenge_timer = CHALLENGE_WINDOW_DURATION
	challenge_window_started.emit(CHALLENGE_WINDOW_DURATION)

	for i in range(NUM_PLAYERS):
		if i == current_player_index:
			continue

		var player = players[i]
		if player.player_type == Player.PlayerType.AI:
			if player.should_challenge(last_claimed_rank, last_played_cards.size(), discard_pile.size()):
				await get_tree().create_timer(randf_range(0.5, 2.0)).timeout
				initiate_challenge(player)
				return

func end_challenge_window() -> void:
	challenge_window_ended.emit()

	if pending_challenger == null:
		advance_turn()

func initiate_challenge(challenger: Player) -> void:
	if current_state != GameState.CHALLENGE_WINDOW:
		return

	pending_challenger = challenger
	challenge_made.emit(challenger, last_player)
	change_state(GameState.RESOLUTION)

func player_initiate_challenge() -> void:
	if current_state != GameState.CHALLENGE_WINDOW:
		return

	var human_player = players[0]
	if human_player.player_index == current_player_index:
		return

	initiate_challenge(human_player)

func resolve_challenge() -> void:
	if pending_challenger == null:
		advance_turn()
		return

	var all_cards_match: bool = true
	for card in last_played_cards:
		if card.rank != last_claimed_rank:
			all_cards_match = false
			break

	var loser: Player
	var challenge_success: bool

	if all_cards_match:
		challenge_success = false
		loser = pending_challenger
	else:
		challenge_success = true
		loser = last_player

	challenge_resolved.emit(challenge_success, loser, discard_pile.size())

	var pile_copy: Array[Card] = discard_pile.duplicate()
	loser.receive_cards(pile_copy)
	discard_pile.clear()
	pile_updated.emit(0)

	pending_challenger = null

	advance_turn()

func advance_turn() -> void:
	current_player_index = (current_player_index + 1) % NUM_PLAYERS

	var next_player = players[current_player_index]

	if next_player.player_type == Player.PlayerType.HUMAN:
		change_state(GameState.PLAYER_TURN)
	else:
		change_state(GameState.AI_TURN)

func _on_challenge_initiated(challenger: Player, target_player: Player) -> void:
	initiate_challenge(challenger)

func get_rank_name(rank: Card.Rank) -> String:
	match rank:
		Card.Rank.ACE: return "A"
		Card.Rank.TWO: return "2"
		Card.Rank.THREE: return "3"
		Card.Rank.FOUR: return "4"
		Card.Rank.FIVE: return "5"
		Card.Rank.SIX: return "6"
		Card.Rank.SEVEN: return "7"
		Card.Rank.EIGHT: return "8"
		Card.Rank.NINE: return "9"
		Card.Rank.TEN: return "10"
		Card.Rank.JACK: return "J"
		Card.Rank.QUEEN: return "Q"
		Card.Rank.KING: return "K"
		_: return "未知"
