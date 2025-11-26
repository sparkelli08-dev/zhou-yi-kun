extends Control

# 主菜单UI - 创建/加入房间

@onready var create_room_button: Button = $VBoxContainer/CreateRoomButton
@onready var join_room_button: Button = $VBoxContainer/JoinRoomButton
@onready var room_code_input: LineEdit = $VBoxContainer/RoomCodeContainer/RoomCodeInput
@onready var player_count_spinbox: SpinBox = $VBoxContainer/SettingsContainer/PlayerCountContainer/PlayerCountSpinBox
@onready var challenge_time_spinbox: SpinBox = $VBoxContainer/SettingsContainer/ChallengeTimeContainer/ChallengeTimeSpinBox
@onready var status_label: Label = $VBoxContainer/StatusLabel

# 房间设置
var max_players: int = 4
var challenge_time: int = 10

func _ready() -> void:
	# 连接信号
	create_room_button.pressed.connect(_on_create_room_pressed)
	join_room_button.pressed.connect(_on_join_room_pressed)

	# 连接 Steam 信号
	SteamManager.steam_initialized.connect(_on_steam_initialized)
	SteamManager.lobby_created.connect(_on_lobby_created)
	SteamManager.lobby_joined.connect(_on_lobby_joined)
	SteamManager.lobby_join_failed.connect(_on_lobby_join_failed)

	# 初始化UI
	player_count_spinbox.min_value = 2
	player_count_spinbox.max_value = 6
	player_count_spinbox.value = max_players
	player_count_spinbox.value_changed.connect(_on_player_count_changed)

	challenge_time_spinbox.min_value = 5
	challenge_time_spinbox.max_value = 30
	challenge_time_spinbox.value = challenge_time
	challenge_time_spinbox.value_changed.connect(_on_challenge_time_changed)

	# 检查 Steam 是否已初始化
	if SteamManager.is_offline_mode:
		status_label.text = "离线模式 - " + SteamManager.player_name
		create_room_button.disabled = false
		join_room_button.disabled = true  # 离线模式不能加入房间
		room_code_input.editable = false
	elif not SteamManager.is_steam_initialized:
		status_label.text = "正在初始化 Steam..."
		create_room_button.disabled = true
		join_room_button.disabled = true
	else:
		status_label.text = "欢迎，" + SteamManager.player_name + "！"

func _on_steam_initialized(success: bool) -> void:
	if success:
		status_label.text = "欢迎，" + SteamManager.player_name + "！"
		create_room_button.disabled = false
		join_room_button.disabled = false
	elif SteamManager.is_offline_mode:
		# 离线模式
		status_label.text = "离线模式 - " + SteamManager.player_name
		create_room_button.disabled = false
		join_room_button.disabled = true  # 离线模式不能加入房间
		room_code_input.editable = false
	else:
		status_label.text = "Steam 初始化失败！请重启游戏"
		create_room_button.disabled = true
		join_room_button.disabled = true

func _on_create_room_pressed() -> void:
	status_label.text = "正在创建房间..."
	create_room_button.disabled = true

	# 创建大厅
	SteamManager.create_lobby(max_players, challenge_time)

func _on_join_room_pressed() -> void:
	var room_code = room_code_input.text.strip_edges()

	if room_code.is_empty():
		status_label.text = "请输入房间码！"
		return

	# 将房间码转换为 lobby_id（整数）
	var lobby_id = int(room_code)
	if lobby_id <= 0:
		status_label.text = "无效的房间码！"
		return

	status_label.text = "正在加入房间..."
	join_room_button.disabled = true

	# 加入大厅
	SteamManager.join_lobby(lobby_id)

func _on_lobby_created(lobby_id: int) -> void:
	print("房间创建成功！房间码: ", lobby_id)
	status_label.text = "房间创建成功！房间码: " + str(lobby_id)

	# 设置为房主
	NetworkManager.set_as_host()

	# 切换到大厅场景
	get_tree().change_scene_to_file("res://鬼牌/Scenes/Lobby.tscn")

func _on_lobby_joined(lobby_id: int) -> void:
	print("成功加入房间: ", lobby_id)
	status_label.text = "成功加入房间！"

	# 设置为客户端
	NetworkManager.set_as_client()

	# 切换到大厅场景
	get_tree().change_scene_to_file("res://鬼牌/Scenes/Lobby.tscn")

func _on_lobby_join_failed(reason: String) -> void:
	status_label.text = "加入失败: " + reason
	join_room_button.disabled = false

func _on_player_count_changed(value: float) -> void:
	max_players = int(value)

func _on_challenge_time_changed(value: float) -> void:
	challenge_time = int(value)
