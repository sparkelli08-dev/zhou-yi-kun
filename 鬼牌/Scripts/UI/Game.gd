extends Control

# 游戏主界面UI - 手牌、出牌、质疑

# UI节点引用
@onready var hand_container: HBoxContainer = $HandContainer
@onready var table_area: Panel = $TableArea
@onready var table_cards_label: Label = $TableArea/VBoxContainer/TableCardsLabel
@onready var current_claim_label: Label = $TableArea/VBoxContainer/CurrentClaimLabel

@onready var play_panel: Panel = $PlayPanel
@onready var rank_option_button: OptionButton = $PlayPanel/VBoxContainer/RankOptionButton
@onready var card_count_spinbox: SpinBox = $PlayPanel/VBoxContainer/CardCountSpinBox
@onready var is_lying_checkbox: CheckBox = $PlayPanel/VBoxContainer/IsLyingCheckBox
@onready var play_button: Button = $PlayPanel/VBoxContainer/PlayButton

@onready var response_panel: Panel = $ResponsePanel
@onready var challenge_button: Button = $ResponsePanel/VBoxContainer/ChallengeButton
@onready var follow_button: Button = $ResponsePanel/VBoxContainer/FollowButton
@onready var pass_button: Button = $ResponsePanel/VBoxContainer/PassButton
@onready var timer_label: Label = $ResponsePanel/VBoxContainer/TimerLabel

@onready var player_info_container: VBoxContainer = $PlayerInfoContainer
@onready var status_label: Label = $StatusLabel
@onready var my_card_count_label: Label = $MyCardCountLabel

# 游戏数据
var my_hand: Array[Card] = []
var selected_cards: Array[Card] = []
var card_ui_nodes: Array = []  # 手牌的UI节点

func _ready() -> void:
	# 连接游戏管理器信号
	GameManager.game_started.connect(_on_game_started)
	GameManager.cards_dealt.connect(_on_cards_dealt)
	GameManager.turn_changed.connect(_on_turn_changed)
	GameManager.cards_claimed.connect(_on_cards_claimed)
	GameManager.cards_played.connect(_on_cards_played)
	GameManager.cards_followed.connect(_on_cards_followed)
	GameManager.player_challenged.connect(_on_player_challenged)
	GameManager.challenge_result.connect(_on_challenge_result)
	GameManager.player_passed.connect(_on_player_passed)
	GameManager.player_won.connect(_on_player_won)

	# 连接按钮信号
	play_button.pressed.connect(_on_play_button_pressed)
	challenge_button.pressed.connect(_on_challenge_button_pressed)
	follow_button.pressed.connect(_on_follow_button_pressed)
	pass_button.pressed.connect(_on_pass_button_pressed)

	# 初始化UI
	play_panel.visible = false
	response_panel.visible = false

	# 初始化点数选择
	_init_rank_options()

	status_label.text = "等待发牌..."

func _process(_delta: float) -> void:
	# 更新倒计时显示
	if GameManager.waiting_for_responses and GameManager.challenge_timer > 0:
		timer_label.text = "剩余时间: " + str(int(GameManager.challenge_timer)) + "秒"

# 初始化点数选择选项
func _init_rank_options() -> void:
	rank_option_button.clear()
	var ranks = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "小王", "大王"]
	for rank in ranks:
		rank_option_button.add_item(rank)

# ========== 游戏事件处理 ==========

func _on_game_started() -> void:
	status_label.text = "游戏开始！"
	_refresh_player_info()

func _on_cards_dealt(player_id: int, cards: Array) -> void:
	if player_id == SteamManager.steam_id:
		# 转换类型
		my_hand.clear()
		for card in cards:
			if card is Card:
				my_hand.append(card)
		_display_hand()
		my_card_count_label.text = "你的手牌: " + str(my_hand.size()) + " 张"

func _on_turn_changed(player_id: int) -> void:
	var player = GameManager.get_player_by_id(player_id)

	if player_id == SteamManager.steam_id:
		status_label.text = "轮到你出牌！"
		play_panel.visible = true
		response_panel.visible = false
	else:
		status_label.text = player["name"] + " 正在出牌..."
		play_panel.visible = false
		response_panel.visible = false

	_refresh_player_info()

func _on_cards_claimed(player_id: int, rank: String, count: int) -> void:
	var player = GameManager.get_player_by_id(player_id)
	current_claim_label.text = player["name"] + " 声称出了 " + str(count) + " 张 " + rank
	status_label.text = player["name"] + " 声称出了 " + str(count) + " 张 " + rank

	# 如果不是自己出的牌，显示响应面板
	if player_id != SteamManager.steam_id:
		response_panel.visible = true
		play_panel.visible = false

	_refresh_player_info()

func _on_cards_played(player_id: int, card_count: int) -> void:
	table_cards_label.text = "桌上有 " + str(GameManager.table_cards.size()) + " 张牌"

	# 更新手牌显示
	if player_id == SteamManager.steam_id:
		var player_hand = GameManager.get_player_by_id(SteamManager.steam_id)["hand"]
		my_hand.clear()
		for card in player_hand:
			if card is Card:
				my_hand.append(card)
		_display_hand()
		my_card_count_label.text = "你的手牌: " + str(my_hand.size()) + " 张"

func _on_cards_followed(player_id: int, rank: String, count: int) -> void:
	var player = GameManager.get_player_by_id(player_id)
	current_claim_label.text = player["name"] + " 跟牌: " + str(count) + " 张 " + rank
	status_label.text = player["name"] + " 跟了 " + str(count) + " 张 " + rank

	# 重新显示响应面板
	if player_id != SteamManager.steam_id:
		response_panel.visible = true

	_refresh_player_info()

func _on_player_challenged(challenger_id: int, target_id: int) -> void:
	var challenger = GameManager.get_player_by_id(challenger_id)
	status_label.text = challenger["name"] + " 发起质疑！"
	response_panel.visible = false

func _on_challenge_result(success: bool, cards: Array, penalty_player: int) -> void:
	var penalty_player_obj = GameManager.get_player_by_id(penalty_player)

	if success:
		status_label.text = "质疑成功！" + penalty_player_obj["name"] + " 拿回了牌"
	else:
		status_label.text = "质疑失败！" + penalty_player_obj["name"] + " 拿走了所有牌"

	# 显示翻开的牌
	var revealed_text = "翻开的牌: "
	for card in cards:
		if card is Card:
			revealed_text += card.get_display_name() + " "

	current_claim_label.text = revealed_text

	# 更新手牌 - 转换类型
	var player_hand = GameManager.get_player_by_id(SteamManager.steam_id)["hand"]
	my_hand.clear()
	for card in player_hand:
		if card is Card:
			my_hand.append(card)
	_display_hand()
	my_card_count_label.text = "你的手牌: " + str(my_hand.size()) + " 张"

	_refresh_player_info()

func _on_player_passed(player_id: int) -> void:
	var player = GameManager.get_player_by_id(player_id)
	status_label.text = player["name"] + " 选择过牌"

func _on_player_won(player_id: int) -> void:
	var player = GameManager.get_player_by_id(player_id)
	status_label.text = player["name"] + " 获胜！"

	play_panel.visible = false
	response_panel.visible = false

# ========== UI交互 ==========

func _on_play_button_pressed() -> void:
	var selected_rank_index = rank_option_button.selected
	var selected_rank = rank_option_button.get_item_text(selected_rank_index)
	var card_count = int(card_count_spinbox.value)
	var is_lying = is_lying_checkbox.button_pressed

	# 验证选择的牌数
	if selected_cards.size() != card_count:
		status_label.text = "请选择 " + str(card_count) + " 张牌！"
		return

	# 如果撒谎，使用声称的点数，否则使用实际牌的点数
	var claimed_rank = selected_rank if is_lying else selected_cards[0].get_rank_name()

	# 发送出牌消息
	var cards_data = []
	for card in selected_cards:
		cards_data.append(card.to_dict())

	# 调用游戏管理器
	GameManager.player_claim_cards(SteamManager.steam_id, claimed_rank, card_count, selected_cards)

	# 广播出牌
	NetworkManager.send_claim_cards(claimed_rank, card_count)
	NetworkManager.send_play_cards(cards_data)

	# 清空选择
	selected_cards.clear()
	play_panel.visible = false

func _on_challenge_button_pressed() -> void:
	# 发起质疑
	GameManager.player_challenge(SteamManager.steam_id)
	NetworkManager.send_challenge()

	response_panel.visible = false

func _on_follow_button_pressed() -> void:
	# 跟牌（简化版：使用当前的声明点数）
	var selected_rank_index = rank_option_button.selected
	var selected_rank = rank_option_button.get_item_text(selected_rank_index)
	var card_count = int(card_count_spinbox.value)

	if selected_cards.size() != card_count:
		status_label.text = "请选择 " + str(card_count) + " 张牌！"
		return

	# 发送跟牌消息
	var cards_data = []
	for card in selected_cards:
		cards_data.append(card.to_dict())

	GameManager.player_follow_cards(SteamManager.steam_id, selected_rank, card_count, selected_cards)
	NetworkManager.send_follow_cards(selected_rank, card_count, cards_data)

	selected_cards.clear()
	response_panel.visible = false

func _on_pass_button_pressed() -> void:
	# 过牌
	GameManager.player_pass(SteamManager.steam_id)
	NetworkManager.send_pass()

	response_panel.visible = false

# ========== UI更新 ==========

# 显示手牌
func _display_hand() -> void:
	# 清空现有手牌UI
	for node in card_ui_nodes:
		node.queue_free()
	card_ui_nodes.clear()

	# 创建手牌按钮
	for card in my_hand:
		var card_button = Button.new()
		card_button.text = card.get_display_name()
		card_button.custom_minimum_size = Vector2(60, 80)

		# TODO: 加载卡牌图片
		# card_button.icon = load(card.get_card_image_path())

		card_button.pressed.connect(_on_card_selected.bind(card, card_button))

		hand_container.add_child(card_button)
		card_ui_nodes.append(card_button)

# 选择/取消选择卡牌
func _on_card_selected(card: Card, button: Button) -> void:
	if card in selected_cards:
		# 取消选择
		selected_cards.erase(card)
		button.modulate = Color(1, 1, 1)  # 恢复原色
	else:
		# 选择
		selected_cards.append(card)
		button.modulate = Color(0.5, 0.5, 1)  # 高亮显示

	status_label.text = "已选择 " + str(selected_cards.size()) + " 张牌"

# 刷新玩家信息显示
func _refresh_player_info() -> void:
	# 清空现有信息
	for child in player_info_container.get_children():
		child.queue_free()

	# 添加所有玩家信息
	for player in GameManager.players:
		var info_label = Label.new()
		var text = player["name"] + ": " + str(player["card_count"]) + " 张牌"

		# 标记当前出牌玩家
		if GameManager.players[GameManager.current_player_index]["steam_id"] == player["steam_id"]:
			text += " [出牌中]"

		info_label.text = text
		player_info_container.add_child(info_label)
