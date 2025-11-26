class_name Deck
extends Node

var cards: Array[Card] = []

signal deck_shuffled()
signal cards_dealt(player_index: int, cards_received: Array[Card])

func _init() -> void:
	initialize_deck()

func initialize_deck() -> void:
	cards.clear()

	for suit in Card.Suit.values():
		for rank in range(Card.Rank.ACE, Card.Rank.KING + 1):
			var card = Card.new(suit, rank)
			cards.append(card)

func shuffle() -> void:
	cards.shuffle()
	deck_shuffled.emit()

func deal(num_cards: int) -> Array[Card]:
	var dealt_cards: Array[Card] = []

	for i in range(num_cards):
		if cards.is_empty():
			break
		dealt_cards.append(cards.pop_front())

	return dealt_cards

func deal_to_players(num_players: int) -> Array:
	var hands: Array = []

	for i in range(num_players):
		var hand: Array[Card] = []
		hands.append(hand)

	var player_index: int = 0
	while not cards.is_empty():
		var card = cards.pop_front()
		hands[player_index].append(card)
		player_index = (player_index + 1) % num_players

	for i in range(num_players):
		cards_dealt.emit(i, hands[i] as Array[Card])

	return hands

func get_remaining_cards() -> int:
	return cards.size()

func is_empty() -> bool:
	return cards.is_empty()

func reset() -> void:
	initialize_deck()
	shuffle()
