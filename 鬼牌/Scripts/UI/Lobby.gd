extends Control

# 房间大厅UI - 玩家列表、准备、开始游戏

@onready var player_list_container: VBoxContainer = $VBoxContainer/PlayerListPanel/ScrollContainer/PlayerListContainer
@onready var ready_button: Button = $VBoxContainer/ReadyButton
@onready var start_game_button: Button = $VBoxContainer/StartGameButton
@onready var leave_button: Button = $VBoxContainer/LeaveButton
@onready var room_code_label: Label = $VBoxContainer/RoomCodeLabel
@onready var status_label: Label = $VBoxContainer/StatusLabel

var is_ready: bool = false
var player_list_items: Dictionary = {}  # steam_id -> Label

func _ready() -> void:
	# 检查 Steam 是否已初始化
	if not SteamManager.is_steam_initialized:
		status_label.text = "Steam 未初始化，返回主菜单..."
		push_error("Lobby: Steam 未初始化")
		await get_tree().create_timer(2.0).timeout
		if is_inside_tree():
			get_tree().change_scene_to_file("res://鬼牌/Scenes/MainMenu.tscn")
		return

	# 检查是否在有效的大厅中
	if SteamManager.current_lobby_id == 0:
		status_label.text = "无效的大厅，返回主菜单..."
		push_error("Lobby: 无效的大厅 ID")
		await get_tree().create_timer(2.0).timeout
		if is_inside_tree():
			get_tree().change_scene_to_file("res://鬼牌/Scenes/MainMenu.tscn")
		return

	# 连接按钮信号
	ready_button.pressed.connect(_on_ready_pressed)
	start_game_button.pressed.connect(_on_start_game_pressed)
	leave_button.pressed.connect(_on_leave_pressed)

	# 连接 Steam 信号
	SteamManager.player_joined.connect(_on_player_joined)
	SteamManager.player_left.connect(_on_player_left)

	# 连接游戏信号
	GameManager.game_started.connect(_on_game_started)

	# 显示房间码
	room_code_label.text = "房间码: " + str(SteamManager.current_lobby_id)

	# 如果是房主，显示开始游戏按钮
	if SteamManager.is_lobby_owner:
		start_game_button.visible = true
		status_label.text = "你是房主，等待玩家加入..."
	else:
		start_game_button.visible = false
		status_label.text = "等待房主开始游戏..."

	# 刷新玩家列表
	_refresh_player_list()

func _refresh_player_list() -> void:
	# 清空现有列表
	for child in player_list_container.get_children():
		child.queue_free()

	player_list_items.clear()

	# 检查 Steam 是否已初始化
	if not SteamManager.is_steam_initialized:
		return

	# 添加所有玩家
	for member in SteamManager.lobby_members:
		var player_label = Label.new()
		var player_name = member["name"]
		var steam_id = member["steam_id"]

		# 标记房主
		var lobby_owner_id = Steam.getLobbyOwner(SteamManager.current_lobby_id)
		if steam_id == lobby_owner_id:
			player_name += " [房主]"

		# 标记自己
		if steam_id == SteamManager.steam_id:
			player_name += " (你)"

		player_label.text = player_name
		player_list_container.add_child(player_label)
		player_list_items[steam_id] = player_label

	# 更新状态文本
	var player_count = SteamManager.lobby_members.size()
	var max_players = SteamManager.get_max_players()
	status_label.text = "玩家数量: " + str(player_count) + " / " + str(max_players)

func _on_player_joined(steam_id: int, player_name: String) -> void:
	print("玩家加入: ", player_name)
	_refresh_player_list()

func _on_player_left(steam_id: int) -> void:
	print("玩家离开: ", steam_id)
	_refresh_player_list()

func _on_ready_pressed() -> void:
	is_ready = !is_ready

	if is_ready:
		ready_button.text = "取消准备"
		status_label.text = "已准备！"

		# 发送准备消息给房主
		NetworkManager.send_player_ready()
	else:
		ready_button.text = "准备"
		status_label.text = "等待开始..."

func _on_start_game_pressed() -> void:
	# 仅房主可以开始游戏
	if not SteamManager.is_lobby_owner:
		return

	var player_count = SteamManager.lobby_members.size()

	# 检查人数
	if player_count < 2:
		status_label.text = "至少需要 2 名玩家！"
		return

	if player_count > 6:
		status_label.text = "最多支持 6 名玩家！"
		return

	status_label.text = "开始游戏..."

	# 发送游戏开始消息
	var game_config = {
		"max_players": player_count,
		"challenge_time": 10
	}

	# 初始化游戏
	GameManager.initialize_game(SteamManager.lobby_members, game_config)
	NetworkManager.send_game_start(game_config)
	GameManager.start_game()

func _on_leave_pressed() -> void:
	# 离开大厅
	SteamManager.leave_lobby()
	NetworkManager.close_all_p2p_sessions()

	# 使用延迟调用返回主菜单
	if is_inside_tree():
		call_deferred("_change_to_main_menu")

# 延迟切换到主菜单
func _change_to_main_menu() -> void:
	if is_inside_tree():
		get_tree().change_scene_to_file("res://鬼牌/Scenes/MainMenu.tscn")

func _on_game_started() -> void:
	# 检查节点是否还在场景树中
	if not is_inside_tree():
		return

	# 使用延迟调用切换场景
	call_deferred("_change_to_game_scene")

# 延迟切换到游戏场景
func _change_to_game_scene() -> void:
	if is_inside_tree():
		get_tree().change_scene_to_file("res://鬼牌/Scenes/Game.tscn")
