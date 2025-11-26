class_name Player
extends Node

enum PlayerType {
	HUMAN,
	AI
}

@export var player_name: String = "Player"
@export var player_type: PlayerType = PlayerType.HUMAN
var player_index: int = 0

var hand: Array[Card] = []

signal cards_played(player: Player, cards: Array[Card], claimed_rank: Card.Rank)
signal challenge_initiated(challenger: Player, target_player: Player)
signal hand_updated(player: Player)

func _init(p_name: String = "Player", p_type: PlayerType = PlayerType.HUMAN, p_index: int = 0) -> void:
	player_name = p_name
	player_type = p_type
	player_index = p_index

func receive_cards(cards: Array[Card]) -> void:
	hand.append_array(cards)
	sort_hand()
	hand_updated.emit(self)

func sort_hand() -> void:
	hand.sort_custom(func(a: Card, b: Card) -> bool:
		if a.rank != b.rank:
			return a.rank < b.rank
		return a.suit < b.suit
	)

func play_cards(cards: Array[Card], claimed_rank: Card.Rank) -> void:
	for card in cards:
		hand.erase(card)

	hand_updated.emit(self)
	cards_played.emit(self, cards, claimed_rank)

func get_hand_size() -> int:
	return hand.size()

func has_cards() -> bool:
	return not hand.is_empty()

func has_rank(rank: Card.Rank) -> bool:
	for card in hand:
		if card.rank == rank:
			return true
	return false

func count_rank(rank: Card.Rank) -> int:
	var count: int = 0
	for card in hand:
		if card.rank == rank:
			count += 1
	return count

func get_cards_of_rank(rank: Card.Rank) -> Array[Card]:
	var matching_cards: Array[Card] = []
	for card in hand:
		if card.rank == rank:
			matching_cards.append(card)
	return matching_cards

func get_lowest_value_cards(count: int) -> Array[Card]:
	var sorted_hand = hand.duplicate()
	sorted_hand.sort_custom(func(a: Card, b: Card) -> bool:
		return a.rank < b.rank
	)

	var selected: Array[Card] = []
	for i in range(min(count, sorted_hand.size())):
		selected.append(sorted_hand[i])

	return selected

func initiate_challenge(target_player: Player) -> void:
	challenge_initiated.emit(self, target_player)

func decide_play() -> Dictionary:
	if player_type == PlayerType.HUMAN:
		return {}

	var cards_to_play: Array[Card] = []
	var claimed_rank: Card.Rank
	var will_bluff: bool = false

	# AI随机选择一个手中有的牌面，或者虚张声势选择一个牌面
	var hand_ranks: Array[Card.Rank] = []
	for card in hand:
		if card.rank not in hand_ranks:
			hand_ranks.append(card.rank)

	# 70%的概率说真话
	if hand_ranks.size() > 0 and randf() < 0.7:
		# 选择手中的一个牌面
		claimed_rank = hand_ranks[randi() % hand_ranks.size()]
		var matching_cards = get_cards_of_rank(claimed_rank)
		var num_to_play = min(matching_cards.size(), randi_range(1, min(4, matching_cards.size())))
		for i in range(num_to_play):
			cards_to_play.append(matching_cards[i])
		will_bluff = false
	else:
		# 虚张声势：随机选择一个牌面，打出最小的牌
		claimed_rank = (randi() % Card.Rank.KING) + 1
		var num_to_play = randi_range(1, min(4, hand.size()))
		cards_to_play = get_lowest_value_cards(num_to_play)
		will_bluff = true

	return {
		"cards": cards_to_play,
		"claimed_rank": claimed_rank,
		"is_bluff": will_bluff
	}

func should_challenge(claimed_rank: Card.Rank, claimed_count: int, total_discard_pile: int) -> bool:
	if player_type == PlayerType.HUMAN:
		return false

	var cards_i_have = count_rank(claimed_rank)

	if cards_i_have + claimed_count > 4:
		return true

	var challenge_probability = 0.0

	if claimed_count >= 3:
		challenge_probability = 0.3
	elif claimed_count == 2:
		challenge_probability = 0.15
	else:
		challenge_probability = 0.05

	if total_discard_pile > 20:
		challenge_probability *= 0.5

	return randf() < challenge_probability
