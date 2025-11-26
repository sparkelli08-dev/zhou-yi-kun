extends Control

# 房间大厅UI - 玩家列表、准备、开始游戏

@onready var player_list_container: VBoxContainer = $VBoxContainer/PlayerListPanel/ScrollContainer/PlayerListContainer
@onready var ready_button: Button = $VBoxContainer/ReadyButton
@onready var start_game_button: Button = $VBoxContainer/StartGameButton
@onready var leave_button: Button = $VBoxContainer/LeaveButton
@onready var room_code_label: Label = $VBoxContainer/RoomCodeLabel
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var time_spinbox: SpinBox = $VBoxContainer/TimeSettingContainer/TimeSpinBox
@onready var time_setting_container: HBoxContainer = $VBoxContainer/TimeSettingContainer

var is_ready: bool = false
var player_list_items: Dictionary = {}  # steam_id -> HBoxContainer
var avatar_cache: Dictionary = {}  # steam_id -> ImageTexture

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

	# 如果是房主，显示开始游戏按钮和时间设置
	if SteamManager.is_lobby_owner:
		start_game_button.visible = true
		time_spinbox.editable = true
		status_label.text = "你是房主，等待玩家加入..."
	else:
		start_game_button.visible = false
		time_spinbox.editable = false
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
		var player_name = member["name"]
		var steam_id = member["steam_id"]

		# 创建水平容器用于显示头像和名字
		var player_item = HBoxContainer.new()
		player_item.custom_minimum_size = Vector2(0, 40)

		# 添加头像
		var avatar_texture_rect = TextureRect.new()
		avatar_texture_rect.custom_minimum_size = Vector2(32, 32)
		avatar_texture_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		avatar_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		avatar_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		# 尝试加载Steam头像
		var avatar_texture = get_steam_avatar(steam_id)
		if avatar_texture:
			avatar_texture_rect.texture = avatar_texture
		else:
			# 使用灰色占位符
			var placeholder = ColorRect.new()
			placeholder.custom_minimum_size = Vector2(32, 32)
			placeholder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			placeholder.color = Color(0.5, 0.5, 0.5, 1.0)
			player_item.add_child(placeholder)
			# 跳过添加TextureRect
			avatar_texture_rect.queue_free()
			avatar_texture_rect = null

		if avatar_texture_rect:
			player_item.add_child(avatar_texture_rect)

		# 添加间距
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(10, 0)
		player_item.add_child(spacer)

		# 创建富文本标签以支持颜色
		var player_label = RichTextLabel.new()
		player_label.bbcode_enabled = true
		player_label.fit_content = true
		player_label.scroll_active = false
		player_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		player_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		# 构建显示文本
		var display_text = ""

		# 检查是否是房主
		var lobby_owner_id = Steam.getLobbyOwner(SteamManager.current_lobby_id)
		var is_owner = (steam_id == lobby_owner_id)

		# 检查是否是自己
		var is_self = (steam_id == SteamManager.steam_id)

		# 标记房主（前缀，红色）
		if is_owner:
			display_text += "[color=red][房主][/color] "

		# 标记自己（前缀，绿色）
		if is_self:
			display_text += "[color=green](你)[/color] "

		# 添加玩家名字
		display_text += player_name

		player_label.text = display_text
		player_item.add_child(player_label)

		player_list_container.add_child(player_item)
		player_list_items[steam_id] = player_item

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

	# 检查人数上限
	if player_count > 6:
		status_label.text = "最多支持 6 名玩家！"
		return

	status_label.text = "开始游戏..."

	# 准备玩家列表
	var player_list = []
	for member in SteamManager.lobby_members:
		player_list.append(member)

	# 如果只有1个玩家，自动添加2个AI玩家
	if player_count == 1:
		player_list.append({
			"steam_id": -1,  # AI玩家使用负数ID
			"name": "AI玩家1",
			"is_ai": true
		})
		player_list.append({
			"steam_id": -2,
			"name": "AI玩家2",
			"is_ai": true
		})
		status_label.text = "开始游戏（添加了2个AI玩家）..."

	# 获取设置的响应时间
	var challenge_time = int(time_spinbox.value)

	# 发送游戏开始消息
	var game_config = {
		"max_players": player_list.size(),
		"challenge_time": challenge_time
	}

	# 初始化游戏
	GameManager.initialize_game(player_list, game_config)
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

# 从Steam获取玩家头像
func get_steam_avatar(steam_id: int) -> ImageTexture:
	# 检查缓存
	if avatar_cache.has(steam_id):
		return avatar_cache[steam_id]

	# 获取小头像（32x32）
	var avatar_handle = Steam.getSmallFriendAvatar(steam_id)

	# 如果头像未准备好，返回null
	if avatar_handle <= 0:
		return null

	# 获取头像尺寸
	var avatar_size = Steam.getImageSize(avatar_handle)
	if not avatar_size.has("width") or avatar_size["width"] == 0:
		return null

	var width = avatar_size["width"]
	var height = avatar_size["height"]

	# 获取头像的RGBA数据
	var avatar_data_dict = Steam.getImageRGBA(avatar_handle)

	# 检查返回的数据类型
	if typeof(avatar_data_dict) != TYPE_DICTIONARY:
		return null

	if not avatar_data_dict.has("buffer"):
		return null

	var avatar_data = avatar_data_dict["buffer"]

	# 确保数据是PackedByteArray类型
	if typeof(avatar_data) != TYPE_PACKED_BYTE_ARRAY:
		return null

	# 检查数据大小
	var expected_size = width * height * 4  # RGBA = 4 bytes per pixel
	if avatar_data.size() != expected_size:
		push_warning("头像数据大小不匹配: 期望 " + str(expected_size) + " 字节，实际 " + str(avatar_data.size()) + " 字节")
		return null

	# 创建Image对象
	var avatar_image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, avatar_data)

	# 创建ImageTexture
	var avatar_texture = ImageTexture.create_from_image(avatar_image)

	# 缓存头像
	avatar_cache[steam_id] = avatar_texture

	return avatar_texture
