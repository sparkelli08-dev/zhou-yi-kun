extends Node
class_name Deck

# 牌堆类 - 管理扑克牌的生成、洗牌、发牌

var cards: Array[Card] = []
var discard_pile: Array[Card] = []  # 弃牌堆

# 创建标准 54 张扑克牌（包含大小王）
func create_standard_deck() -> void:
	cards.clear()

	# 创建 4 种花色，每种 13 张牌
	for suit in [Card.Suit.HEARTS, Card.Suit.DIAMONDS, Card.Suit.CLUBS, Card.Suit.SPADES]:
		for rank in range(Card.Rank.ACE, Card.Rank.KING + 1):
			cards.append(Card.new(suit, rank))

	# 添加两张鬼牌
	cards.append(Card.new(Card.Suit.JOKER, Card.Rank.JOKER_SMALL))
	cards.append(Card.new(Card.Suit.JOKER, Card.Rank.JOKER_BIG))

	print("创建了 ", cards.size(), " 张牌")

# 创建指定数量的牌堆（用于多人游戏）
func create_multiple_decks(deck_count: int) -> void:
	cards.clear()

	for i in range(deck_count):
		# 创建 4 种花色，每种 13 张牌
		for suit in [Card.Suit.HEARTS, Card.Suit.DIAMONDS, Card.Suit.CLUBS, Card.Suit.SPADES]:
			for rank in range(Card.Rank.ACE, Card.Rank.KING + 1):
				cards.append(Card.new(suit, rank))

		# 添加两张鬼牌
		cards.append(Card.new(Card.Suit.JOKER, Card.Rank.JOKER_SMALL))
		cards.append(Card.new(Card.Suit.JOKER, Card.Rank.JOKER_BIG))

	print("创建了 ", deck_count, " 副牌，共 ", cards.size(), " 张")

# 洗牌
func shuffle() -> void:
	cards.shuffle()
	print("牌堆已洗牌")

# 发牌给玩家（平均分配）
func deal_cards(player_count: int) -> Array:
	if cards.is_empty():
		push_error("牌堆为空，无法发牌")
		return []

	var hands: Array = []
	var cards_per_player = cards.size() / player_count

	# 为每个玩家创建手牌数组
	for i in range(player_count):
		hands.append([])

	# 依次发牌
	var current_player = 0
	for card in cards:
		hands[current_player].append(card)
		current_player = (current_player + 1) % player_count

	print("已为 ", player_count, " 名玩家发牌，每人约 ", cards_per_player, " 张")

	# 清空牌堆（所有牌已发出）
	cards.clear()

	return hands

# 发指定数量的牌
func draw_cards(count: int) -> Array[Card]:
	var drawn_cards: Array[Card] = []

	for i in range(min(count, cards.size())):
		drawn_cards.append(cards.pop_front())

	return drawn_cards

# 添加牌到弃牌堆
func add_to_discard(discarded_cards: Array) -> void:
	for card in discarded_cards:
		if card is Card:
			discard_pile.append(card)

# 清空弃牌堆
func clear_discard_pile() -> void:
	discard_pile.clear()

# 获取剩余牌数
func get_remaining_count() -> int:
	return cards.size()

# 将弃牌堆重新洗入牌堆
func reshuffle_discard_into_deck() -> void:
	cards.append_array(discard_pile)
	discard_pile.clear()
	shuffle()

# 转换为字典（用于网络同步）
func to_dict() -> Dictionary:
	var cards_data = []
	for card in cards:
		cards_data.append(card.to_dict())

	var discard_data = []
	for card in discard_pile:
		discard_data.append(card.to_dict())

	return {
		"cards": cards_data,
		"discard_pile": discard_data
	}

# 从字典恢复牌堆
func from_dict(data: Dictionary) -> void:
	cards.clear()
	discard_pile.clear()

	for card_data in data["cards"]:
		cards.append(Card.from_dict(card_data))

	for card_data in data["discard_pile"]:
		discard_pile.append(Card.from_dict(card_data))
