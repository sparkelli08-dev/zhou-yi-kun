class_name UIController
extends Control

@onready var game_manager: GameManager = $"../GameManager"

@onready var current_rank_label: Label = $MarginContainer/VBoxContainer/TopBar/CurrentRankLabel
@onready var game_state_label: Label = $MarginContainer/VBoxContainer/TopBar/GameStateLabel
@onready var discard_pile_label: Label = $MarginContainer/VBoxContainer/CenterArea/DiscardPilePanel/VBoxContainer/PileCountLabel
@onready var last_play_label: Label = $MarginContainer/VBoxContainer/CenterArea/DiscardPilePanel/VBoxContainer/LastPlayLabel

@onready var challenge_button: Button = $MarginContainer/VBoxContainer/CenterArea/ChallengePanel/ChallengeButton
@onready var challenge_timer_label: Label = $MarginContainer/VBoxContainer/CenterArea/ChallengePanel/TimerLabel

@onready var player_hand_container: HBoxContainer = $MarginContainer/VBoxContainer/BottomArea/PlayerHandPanel/HandContainer
@onready var player_info_label: Label = $MarginContainer/VBoxContainer/BottomArea/PlayerInfoLabel
@onready var rank_selection_container: HBoxContainer = $MarginContainer/VBoxContainer/BottomArea/RankSelectionPanel/RankSelectionContainer
@onready var play_button: Button = $MarginContainer/VBoxContainer/BottomArea/PlayButton

@onready var ai_player1_label: Label = $MarginContainer/VBoxContainer/CenterArea/AIPlayers/AIPlayer1/NameLabel
@onready var ai_player1_cards: Label = $MarginContainer/VBoxContainer/CenterArea/AIPlayers/AIPlayer1/CardCountLabel
@onready var ai_player2_label: Label = $MarginContainer/VBoxContainer/CenterArea/AIPlayers/AIPlayer2/NameLabel
@onready var ai_player2_cards: Label = $MarginContainer/VBoxContainer/CenterArea/AIPlayers/AIPlayer2/CardCountLabel
@onready var ai_player3_label: Label = $MarginContainer/VBoxContainer/CenterArea/AIPlayers/AIPlayer3/NameLabel
@onready var ai_player3_cards: Label = $MarginContainer/VBoxContainer/CenterArea/AIPlayers/AIPlayer3/CardCountLabel

@onready var message_label: Label = $MarginContainer/VBoxContainer/MessageLabel
@onready var game_over_panel: Panel = $GameOverPanel
@onready var winner_label: Label = $GameOverPanel/VBoxContainer/WinnerLabel
@onready var restart_button: Button = $GameOverPanel/VBoxContainer/RestartButton

var selected_cards: Array[Card] = []
var card_visuals: Array[CardVisual] = []
var selected_rank: Card.Rank = Card.Rank.ACE
var rank_buttons: Array[Button] = []

func _ready() -> void:
	game_over_panel.hide()
	challenge_button.disabled = true
	play_button.disabled = true

	challenge_button.pressed.connect(_on_challenge_button_pressed)
	play_button.pressed.connect(_on_play_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)

	create_rank_selection_buttons()
	print_game_tutorial()

	await get_tree().process_frame
	connect_game_signals()
	update_hand_display()
	update_player_info()

func create_rank_selection_buttons() -> void:
	if not rank_selection_container:
		return

	# 创建13个牌面选择按钮（A到K）
	var rank_names = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

	for i in range(13):
		var button = Button.new()
		button.text = rank_names[i]
		button.custom_minimum_size = Vector2(50, 40)
		button.toggle_mode = true
		button.button_group = ButtonGroup.new() if i == 0 else rank_buttons[0].button_group

		var rank_value = i + 1
		button.pressed.connect(_on_rank_button_pressed.bind(rank_value))

		rank_selection_container.add_child(button)
		rank_buttons.append(button)

	# 默认选择A
	rank_buttons[0].button_pressed = true
	selected_rank = Card.Rank.ACE

func _on_rank_button_pressed(rank: Card.Rank) -> void:
	selected_rank = rank
	update_selection_info()

func print_game_tutorial() -> void:
	print("\n" + "=".repeat(80))
	print("欢迎来到《龟牌》游戏！")
	print("=".repeat(80))
	print("\n【游戏目标】")
	print("  • 成为第一个打出所有手牌的玩家获胜")
	print("\n【游戏规则】")
	print("  1. 轮到你时，先选择声称的牌面（A 到 K 任选）")
	print("  2. 再选择 1-4 张手牌打出")
	print("  3. 你可以说真话（实际打出声称的牌），也可以说谎（虚张声势）")
	print("  4. 其他玩家有 3 秒时间可以质疑你")
	print("\n【质疑规则】")
	print("  • 如果有玩家质疑你：")
	print("    - 你说真话 → 质疑者拿走所有弃牌堆的牌")
	print("    - 你说谎 → 你拿走所有弃牌堆的牌")
	print("  • 没人质疑 → 游戏继续，轮到下一个玩家")
	print("\n【操作指南】")
	print("  • 首先点击牌面按钮（A、2、3...K）选择你声称的牌面")
	print("  • 然后点击手牌选择要打出的牌（可选择 1-4 张）")
	print("  • 点击「打出选中的牌」按钮出牌")
	print("  • 当其他玩家出牌后，你可以点击「质疑！」按钮进行质疑")
	print("\n【策略提示】")
	print("  • 如果你手上有某张牌，声称并打出真牌更安全")
	print("  • 虚张声势时，打出低价值的牌更划算")
	print("  • 注意弃牌堆大小：牌堆越大，质疑的风险越高")
	print("  • 如果某个玩家声称打出的牌数量 + 你手上的同牌数量 > 4，那他一定在说谎！")
	print("\n" + "=".repeat(80))
	print("游戏开始！祝你好运！")
	print("=".repeat(80) + "\n")

func connect_game_signals() -> void:
	if not game_manager:
		return

	game_manager.game_state_changed.connect(_on_game_state_changed)
	game_manager.turn_changed.connect(_on_turn_changed)
	game_manager.cards_played_to_pile.connect(_on_cards_played_to_pile)
	game_manager.challenge_window_started.connect(_on_challenge_window_started)
	game_manager.challenge_window_ended.connect(_on_challenge_window_ended)
	game_manager.challenge_made.connect(_on_challenge_made)
	game_manager.challenge_resolved.connect(_on_challenge_resolved)
	game_manager.pile_updated.connect(_on_pile_updated)
	game_manager.game_won.connect(_on_game_won)

	for player in game_manager.players:
		player.hand_updated.connect(_on_player_hand_updated)

func _process(delta: float) -> void:
	if game_manager and game_manager.current_state == GameManager.GameState.CHALLENGE_WINDOW:
		var time_left = max(0, game_manager.challenge_timer)
		challenge_timer_label.text = "%.1fs" % time_left

func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	match new_state:
		GameManager.GameState.SETUP:
			game_state_label.text = "游戏准备中..."
			current_rank_label.text = "选择你要声称的牌面"
			animate_label_pulse(game_state_label)
		GameManager.GameState.PLAYER_TURN:
			game_state_label.text = "你的回合"
			current_rank_label.text = "选择你要声称的牌面"
			game_state_label.modulate = Color.GREEN
			play_button.disabled = false
			animate_label_pulse(game_state_label)
		GameManager.GameState.AI_TURN:
			game_state_label.text = "AI 回合"
			current_rank_label.text = "等待AI出牌..."
			game_state_label.modulate = Color.YELLOW
			play_button.disabled = true
		GameManager.GameState.CHALLENGE_WINDOW:
			game_state_label.text = "质疑时间！"
			game_state_label.modulate = Color.ORANGE
		GameManager.GameState.RESOLUTION:
			game_state_label.text = "结算中..."
			game_state_label.modulate = Color.WHITE
		GameManager.GameState.GAME_OVER:
			game_state_label.text = "游戏结束"
			game_state_label.modulate = Color.RED

func _on_turn_changed(player_index: int, player: Player) -> void:
	update_player_info()

	var turn_msg = "%s 的回合" % player.player_name
	show_message(turn_msg)

func _on_cards_played_to_pile(player: Player, card_count: int, claimed_rank: Card.Rank) -> void:
	var rank_name = game_manager.get_rank_name(claimed_rank)
	last_play_label.text = "%s 打出了 %d 张 %s" % [player.player_name, card_count, rank_name]

	var msg = "%s 声称打出 %d 张 %s" % [player.player_name, card_count, rank_name]
	show_message(msg, Color.YELLOW)

func _on_challenge_window_started(duration: float) -> void:
	var current_player = game_manager.players[game_manager.current_player_index]

	if current_player.player_type == Player.PlayerType.HUMAN:
		challenge_button.disabled = true
	else:
		challenge_button.disabled = false
		animate_button_flash(challenge_button)

	challenge_timer_label.show()
	animate_label_pulse(challenge_timer_label)

func _on_challenge_window_ended() -> void:
	challenge_button.disabled = true
	challenge_timer_label.hide()
	show_message("无人质疑，回合继续", Color.WHITE)

func _on_challenge_made(challenger: Player, target: Player) -> void:
	challenge_button.disabled = true
	var msg = "%s 质疑了 %s！" % [challenger.player_name, target.player_name]
	show_message(msg, Color.ORANGE)

func _on_challenge_resolved(success: bool, loser: Player, pile_size: int) -> void:
	challenge_timer_label.hide()

	if success:
		var msg = "虚张声势被识破！%s 拿走 %d 张牌！" % [loser.player_name, pile_size]
		show_message(msg, Color.RED)
	else:
		var msg = "错误的指控！%s 拿走 %d 张牌！" % [loser.player_name, pile_size]
		show_message(msg, Color.GREEN)

	await get_tree().create_timer(2.0).timeout
	clear_message()

func _on_pile_updated(pile_size: int) -> void:
	discard_pile_label.text = "弃牌堆：%d 张牌" % pile_size
	if pile_size > 0:
		animate_label_scale_bounce(discard_pile_label)

func _on_game_won(winner: Player) -> void:
	winner_label.text = "%s 获胜！" % winner.player_name
	game_over_panel.modulate = Color(1, 1, 1, 0)
	game_over_panel.show()
	animate_panel_fade_in(game_over_panel)

func _on_player_hand_updated(player: Player) -> void:
	if player.player_index == 0:
		update_hand_display()
	update_player_info()

func update_hand_display() -> void:
	for card_visual in card_visuals:
		card_visual.queue_free()
	card_visuals.clear()
	selected_cards.clear()

	if not game_manager or game_manager.players.size() == 0:
		return

	var human_player = game_manager.players[0]

	for card in human_player.hand:
		var card_visual = CardVisual.new()
		card_visual.set_card(card)
		card_visual.card_clicked.connect(_on_card_visual_clicked.bind(card))
		player_hand_container.add_child(card_visual)
		card_visuals.append(card_visual)

func _on_card_visual_clicked(card_visual: CardVisual, card: Card) -> void:
	if card_visual.is_selected:
		if selected_cards.size() < 4:
			selected_cards.append(card)
		else:
			card_visual.reset_selection()
	else:
		selected_cards.erase(card)

	update_selection_info()

func update_selection_info() -> void:
	var rank_name = game_manager.get_rank_name(selected_rank) if game_manager else "A"
	if selected_cards.size() > 0:
		player_info_label.text = "已选择：%d 张牌 | 声称：%s" % [selected_cards.size(), rank_name]
		play_button.disabled = false
	else:
		player_info_label.text = "选择 1-4 张牌出牌 | 当前声称：%s" % rank_name
		play_button.disabled = true

func _on_play_button_pressed() -> void:
	if selected_cards.is_empty():
		return

	if game_manager.current_state != GameManager.GameState.PLAYER_TURN:
		return

	game_manager.player_play_cards(selected_cards.duplicate(), selected_rank)
	play_button.disabled = true

func _on_challenge_button_pressed() -> void:
	game_manager.player_initiate_challenge()
	challenge_button.disabled = true

func _on_restart_button_pressed() -> void:
	get_tree().reload_current_scene()

func update_player_info() -> void:
	if not game_manager or game_manager.players.size() < 4:
		return

	ai_player1_label.text = game_manager.players[1].player_name
	ai_player1_cards.text = "%d 张牌" % game_manager.players[1].get_hand_size()

	ai_player2_label.text = game_manager.players[2].player_name
	ai_player2_cards.text = "%d 张牌" % game_manager.players[2].get_hand_size()

	ai_player3_label.text = game_manager.players[3].player_name
	ai_player3_cards.text = "%d 张牌" % game_manager.players[3].get_hand_size()

	var human_player = game_manager.players[0]
	if selected_cards.is_empty():
		player_info_label.text = "手牌：%d 张 - 选择 1-4 张出牌" % human_player.get_hand_size()

func show_message(msg: String, color: Color = Color.WHITE) -> void:
	message_label.text = msg
	message_label.modulate = color
	message_label.show()

func clear_message() -> void:
	message_label.text = ""
	message_label.hide()

func animate_label_pulse(label: Label) -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "scale", Vector2(1.1, 1.1), 0.3)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.3)

func animate_label_shake(node: Control) -> void:
	# 使用scale而不是position来避免布局问题
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "scale", Vector2(1.05, 1.05), 0.05)
	tween.tween_property(node, "scale", Vector2(0.95, 0.95), 0.05)
	tween.tween_property(node, "scale", Vector2(1.05, 1.05), 0.05)
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.05)

func animate_button_flash(button: Button) -> void:
	var tween = create_tween()
	tween.set_loops()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(button, "modulate", Color(1.5, 1.5, 1.0), 0.5)
	tween.tween_property(button, "modulate", Color.WHITE, 0.5)

func animate_label_scale_bounce(label: Label) -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.2)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.3)

func animate_panel_fade_in(panel: Panel) -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate", Color.WHITE, 0.5)
