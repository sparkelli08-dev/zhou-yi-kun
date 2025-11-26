extends Resource
class_name Card

# 卡牌类 - 表示单张扑克牌

enum Suit {
	HEARTS,    # 红桃
	DIAMONDS,  # 方块
	CLUBS,     # 梅花
	SPADES,    # 黑桃
	JOKER      # 鬼牌
}

enum Rank {
	ACE = 1,
	TWO = 2,
	THREE = 3,
	FOUR = 4,
	FIVE = 5,
	SIX = 6,
	SEVEN = 7,
	EIGHT = 8,
	NINE = 9,
	TEN = 10,
	JACK = 11,
	QUEEN = 12,
	KING = 13,
	JOKER_SMALL = 14,  # 小王
	JOKER_BIG = 15     # 大王
}

var suit: Suit
var rank: Rank
var is_joker: bool = false
var card_id: String = ""  # 唯一标识符

func _init(p_suit: Suit = Suit.HEARTS, p_rank: Rank = Rank.ACE) -> void:
	suit = p_suit
	rank = p_rank
	is_joker = (suit == Suit.JOKER)
	card_id = generate_card_id()

# 生成卡牌唯一标识符
func generate_card_id() -> String:
	if is_joker:
		return "JOKER_" + str(rank)
	else:
		return get_suit_name() + "_" + get_rank_name()

# 获取花色名称
func get_suit_name() -> String:
	match suit:
		Suit.HEARTS: return "HEARTS"
		Suit.DIAMONDS: return "DIAMONDS"
		Suit.CLUBS: return "CLUBS"
		Suit.SPADES: return "SPADES"
		Suit.JOKER: return "JOKER"
		_: return "UNKNOWN"

# 获取点数名称
func get_rank_name() -> String:
	match rank:
		Rank.ACE: return "A"
		Rank.TWO: return "2"
		Rank.THREE: return "3"
		Rank.FOUR: return "4"
		Rank.FIVE: return "5"
		Rank.SIX: return "6"
		Rank.SEVEN: return "7"
		Rank.EIGHT: return "8"
		Rank.NINE: return "9"
		Rank.TEN: return "10"
		Rank.JACK: return "J"
		Rank.QUEEN: return "Q"
		Rank.KING: return "K"
		Rank.JOKER_SMALL: return "小王"
		Rank.JOKER_BIG: return "大王"
		_: return "UNKNOWN"

# 获取卡牌显示名称（中文）
func get_display_name() -> String:
	if is_joker:
		return get_rank_name()

	var suit_symbol = ""
	match suit:
		Suit.HEARTS: suit_symbol = "♥"
		Suit.DIAMONDS: suit_symbol = "♦"
		Suit.CLUBS: suit_symbol = "♣"
		Suit.SPADES: suit_symbol = "♠"

	return suit_symbol + get_rank_name()

# 获取卡牌图片路径（预设路径，资源需自行添加）
func get_card_image_path() -> String:
	if is_joker:
		if rank == Rank.JOKER_SMALL:
			return "res://鬼牌/Resources/Cards/joker_small.png"
		else:
			return "res://鬼牌/Resources/Cards/joker_big.png"
	else:
		return "res://鬼牌/Resources/Cards/" + get_suit_name().to_lower() + "_" + get_rank_name().to_lower() + ".png"

# 转换为字典（用于网络传输）
func to_dict() -> Dictionary:
	return {
		"suit": suit,
		"rank": rank,
		"card_id": card_id
	}

# 从字典创建卡牌
static func from_dict(data: Dictionary) -> Card:
	var card = Card.new(data["suit"], data["rank"])
	return card

# 比较两张牌是否相同
func equals(other: Card) -> bool:
	return card_id == other.card_id

# 获取卡牌的排序值（用于排序手牌）
func get_sort_value() -> int:
	if is_joker:
		return rank * 100  # 鬼牌排在最后
	else:
		return suit * 13 + rank
