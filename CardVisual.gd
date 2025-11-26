class_name CardVisual
extends Button

var card_data: Card
var is_selected: bool = false

signal card_clicked(card_visual: CardVisual)

const NORMAL_COLOR = Color.WHITE
const SELECTED_COLOR = Color(0.7, 1.0, 0.7)
const HOVER_COLOR = Color(0.9, 0.9, 1.0)
const HEARTS_COLOR = Color(1.0, 0.2, 0.2)
const DIAMONDS_COLOR = Color(1.0, 0.4, 0.4)
const CLUBS_COLOR = Color(0.1, 0.1, 0.1)
const SPADES_COLOR = Color(0.2, 0.2, 0.2)

var rank_label: Label
var suit_label: Label
var animation_player: AnimationPlayer

func _ready() -> void:
	custom_minimum_size = Vector2(80, 120)
	toggle_mode = true

	create_card_ui()

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	toggled.connect(_on_toggled)

func create_card_ui() -> void:
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	rank_label = Label.new()
	rank_label.name = "RankLabel"
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(rank_label)

	suit_label = Label.new()
	suit_label.name = "SuitLabel"
	suit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	suit_label.add_theme_font_size_override("font_size", 36)
	vbox.add_child(suit_label)

	var anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	add_child(anim_player)
	animation_player = anim_player

	create_animations()

func set_card(card: Card) -> void:
	card_data = card

	if not rank_label:
		await ready

	rank_label.text = card.get_rank_name()
	suit_label.text = card.get_suit_symbol()

	match card.suit:
		Card.Suit.HEARTS, Card.Suit.DIAMONDS:
			suit_label.add_theme_color_override("font_color", HEARTS_COLOR)
		Card.Suit.CLUBS, Card.Suit.SPADES:
			suit_label.add_theme_color_override("font_color", CLUBS_COLOR)

func _on_mouse_entered() -> void:
	if not is_selected:
		modulate = HOVER_COLOR

func _on_mouse_exited() -> void:
	if not is_selected:
		modulate = NORMAL_COLOR

func _on_toggled(toggled_on: bool) -> void:
	is_selected = toggled_on
	if is_selected:
		modulate = SELECTED_COLOR
		play_animation("select")
	else:
		modulate = NORMAL_COLOR

	card_clicked.emit(self)

func play_animation(anim_name: String) -> void:
	if animation_player and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)

func create_animations() -> void:
	if not animation_player:
		return

	var select_anim = Animation.new()
	var track_index = select_anim.add_track(Animation.TYPE_VALUE)
	select_anim.track_set_path(track_index, ".:position:y")
	select_anim.track_insert_key(track_index, 0.0, 0.0)
	select_anim.track_insert_key(track_index, 0.15, -10.0)
	select_anim.length = 0.15

	var library = AnimationLibrary.new()
	library.add_animation("select", select_anim)
	animation_player.add_animation_library("", library)

func reset_selection() -> void:
	is_selected = false
	button_pressed = false
	modulate = NORMAL_COLOR
