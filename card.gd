class_name Card
extends Resource

enum Suit {
	HEARTS,
	DIAMONDS,
	CLUBS,
	SPADES
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
	KING = 13
}

@export var suit: Suit
@export var rank: Rank

func _init(p_suit: Suit = Suit.HEARTS, p_rank: Rank = Rank.ACE) -> void:
	suit = p_suit
	rank = p_rank

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
		_: return "未知"

func get_suit_name() -> String:
	match suit:
		Suit.HEARTS: return "红桃"
		Suit.DIAMONDS: return "方块"
		Suit.CLUBS: return "梅花"
		Suit.SPADES: return "黑桃"
		_: return "未知"

func get_suit_symbol() -> String:
	match suit:
		Suit.HEARTS: return "♥"
		Suit.DIAMONDS: return "♦"
		Suit.CLUBS: return "♣"
		Suit.SPADES: return "♠"
		_: return "?"

func _to_string() -> String:
	return "%s of %s" % [get_rank_name(), get_suit_name()]

func get_short_name() -> String:
	return "%s%s" % [get_rank_name(), get_suit_symbol()]
