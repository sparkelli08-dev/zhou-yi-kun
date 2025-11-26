extends TextureButton
class_name CardUI

# 卡牌UI组件 - 可视化单张卡牌

signal card_clicked(card: Card)

var card_data: Card
var is_selected: bool = false

@onready var card_label: Label = $CardLabel
@onready var suit_label: Label = $SuitLabel

func _ready() -> void:
	pressed.connect(_on_pressed)
	custom_minimum_size = Vector2(80, 120)

# 设置卡牌数据
func set_card(card: Card) -> void:
	card_data = card

	# 尝试加载卡牌图片
	var image_path = card.get_card_image_path()
	if ResourceLoader.exists(image_path):
		texture_normal = load(image_path)
	else:
		# 如果没有图片，使用文本显示
		if card_label:
			card_label.text = card.get_rank_name()

		if suit_label:
			suit_label.text = _get_suit_symbol(card.suit)

			# 设置花色颜色
			if card.suit == Card.Suit.HEARTS or card.suit == Card.Suit.DIAMONDS:
				suit_label.modulate = Color.RED
			else:
				suit_label.modulate = Color.BLACK

# 获取花色符号
func _get_suit_symbol(suit: Card.Suit) -> String:
	match suit:
		Card.Suit.HEARTS: return "♥"
		Card.Suit.DIAMONDS: return "♦"
		Card.Suit.CLUBS: return "♣"
		Card.Suit.SPADES: return "♠"
		Card.Suit.JOKER: return "★"
		_: return ""

# 切换选中状态
func toggle_selection() -> void:
	is_selected = !is_selected

	if is_selected:
		modulate = Color(0.7, 0.7, 1.0)  # 蓝色高亮
		position.y -= 10  # 向上移动
	else:
		modulate = Color.WHITE
		position.y += 10  # 恢复位置

# 设置选中状态
func set_selected(selected: bool) -> void:
	if is_selected != selected:
		toggle_selection()

func _on_pressed() -> void:
	toggle_selection()
	card_clicked.emit(card_data)
