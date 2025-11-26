extends Node

# Steam 管理器 - 处理 Steam 初始化、大厅和好友邀请

signal steam_initialized(success: bool)
signal lobby_created(lobby_id: int)
signal lobby_joined(lobby_id: int)
signal lobby_join_failed(reason: String)
signal player_joined(steam_id: int, player_name: String)
signal player_left(steam_id: int)
signal lobby_data_updated()

var is_steam_initialized: bool = false
var steam_id: int = 0
var player_name: String = ""
var current_lobby_id: int = 0
var lobby_members: Array = []
var is_lobby_owner: bool = false

# 初始化 Steam
func _ready() -> void:
	initialize_steam()

func initialize_steam() -> void:
	# 检查 Steam 是否存在
	if not Steam:
		print("=== Steam API 不存在！GodotSteam 插件可能未安装 ===")
		push_error("GodotSteam 插件未找到")
		steam_initialized.emit(false)
		return

	print("开始初始化 Steam...")
	print("确保 Steam 客户端正在运行中...")

	var init_result: Dictionary = Steam.steamInitEx()

	print("Steam 初始化结果: ", init_result)

	if init_result['status'] == 0:
		# 初始化成功（status=0 表示 STEAM_API_INIT_RESULT_OK）
		_setup_steam_online_mode()
		return

	# 初始化失败（status > 0 表示各种错误）
	var error_msg = "未知错误"
	match init_result['status']:
		1: error_msg = "一般性失败（status=1）"
		2: error_msg = "无法连接到Steam（status=2）"
		3: error_msg = "Steam客户端需要更新（status=3）"
		_: error_msg = "错误代码: " + str(init_result['status'])

	print("=== Steam 初始化失败: ", error_msg, " ===")
	print("完整错误信息: ", init_result)
	print("解决方案:")
	print("1. 确保 Steam 客户端已启动（不只是游戏本身）")
	print("2. 如果 Steam 已启动，尝试重启 Steam 客户端")
	print("3. 检查 GodotSteam DLL 文件是否存在")
	push_error("Steam 初始化失败: " + error_msg)
	steam_initialized.emit(false)

# Steam 成功初始化后的处理
func _setup_steam_online_mode() -> void:
	is_steam_initialized = true
	steam_id = Steam.getSteamID()
	player_name = Steam.getPersonaName()

	# 连接 Steam 回调信号
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	Steam.lobby_data_update.connect(_on_lobby_data_update)
	Steam.lobby_invite.connect(_on_lobby_invite)
	Steam.join_requested.connect(_on_join_requested)

	print("========================================")
	print("Steam 初始化成功！")
	print("用户: ", player_name)
	print("Steam ID: ", steam_id)
	print("========================================")
	steam_initialized.emit(true)

func _process(_delta: float) -> void:
	if is_steam_initialized:
		Steam.run_callbacks()

# 创建大厅
func create_lobby(max_players: int, _challenge_time: int) -> void:
	if not is_steam_initialized:
		push_error("Steam 未初始化")
		return

	# 创建仅好友可见的大厅
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, max_players)

# Steam 回调：大厅创建成功
func _on_lobby_created(result: int, lobby_id: int) -> void:
	if result != 1:
		push_error("创建大厅失败: " + str(result))
		return

	current_lobby_id = lobby_id
	is_lobby_owner = true

	# 设置大厅数据
	Steam.setLobbyData(lobby_id, "name", player_name + " 的房间")
	Steam.setLobbyData(lobby_id, "game_version", "1.0")

	print("大厅创建成功！ID: ", lobby_id)
	lobby_created.emit(lobby_id)

# 搜索大厅
func search_lobbies() -> void:
	if not is_steam_initialized:
		return

	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.addRequestLobbyListStringFilter("game_version", "1.0", Steam.LOBBY_COMPARISON_EQUAL)
	Steam.requestLobbyList()

func _on_lobby_match_list(lobbies: Array) -> void:
	print("找到 ", lobbies.size(), " 个大厅")

# 通过 ID 加入大厅
func join_lobby(lobby_id: int) -> void:
	if not is_steam_initialized:
		return

	Steam.joinLobby(lobby_id)

# Steam 回调：加入大厅
func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != 1:
		var error_msg = "未知错误"
		match response:
			2: error_msg = "大厅不存在"
			3: error_msg = "无权限加入"
			4: error_msg = "大厅已满"
			5: error_msg = "连接失败"
			6: error_msg = "社区封禁"
			7: error_msg = "玩家被限制"

		lobby_join_failed.emit(error_msg)
		return

	current_lobby_id = lobby_id
	is_lobby_owner = (Steam.getLobbyOwner(lobby_id) == steam_id)

	# 获取所有大厅成员
	update_lobby_members()

	print("成功加入大厅: ", lobby_id)
	lobby_joined.emit(lobby_id)

# 离开大厅
func leave_lobby() -> void:
	if current_lobby_id != 0:
		Steam.leaveLobby(current_lobby_id)
		current_lobby_id = 0
		is_lobby_owner = false
		lobby_members.clear()

# 更新大厅成员列表
func update_lobby_members() -> void:
	if current_lobby_id == 0:
		return

	lobby_members.clear()
	var num_members = Steam.getNumLobbyMembers(current_lobby_id)

	for i in range(num_members):
		var member_id = Steam.getLobbyMemberByIndex(current_lobby_id, i)
		var member_name = Steam.getFriendPersonaName(member_id)
		lobby_members.append({
			"steam_id": member_id,
			"name": member_name
		})

	print("大厅成员数: ", lobby_members.size())

# Steam 回调：大厅聊天更新（玩家加入/离开）
func _on_lobby_chat_update(lobby_id: int, changed_id: int, _making_change_id: int, chat_state: int) -> void:
	if lobby_id != current_lobby_id:
		return

	var member_name = Steam.getFriendPersonaName(changed_id)

	match chat_state:
		Steam.CHAT_MEMBER_STATE_CHANGE_ENTERED:
			print("玩家加入: ", member_name)
			update_lobby_members()
			player_joined.emit(changed_id, member_name)

		Steam.CHAT_MEMBER_STATE_CHANGE_LEFT, Steam.CHAT_MEMBER_STATE_CHANGE_DISCONNECTED:
			print("玩家离开: ", member_name)
			update_lobby_members()
			player_left.emit(changed_id)

		Steam.CHAT_MEMBER_STATE_CHANGE_KICKED, Steam.CHAT_MEMBER_STATE_CHANGE_BANNED:
			print("玩家被踢出: ", member_name)
			update_lobby_members()
			player_left.emit(changed_id)

# Steam 回调：大厅数据更新
# 注意：在 Godot 4 的 GodotSteam 中，lobby_data_update 只传递 3 个参数
func _on_lobby_data_update(success: int, lobby_id: int, _member_id: int) -> void:
	if success == 1 and lobby_id == current_lobby_id:
		lobby_data_updated.emit()

# Steam 回调：收到好友邀请
func _on_lobby_invite(inviter: int, lobby_id: int, _game_id: int) -> void:
	var inviter_name = Steam.getFriendPersonaName(inviter)
	print("收到来自 ", inviter_name, " 的邀请，大厅 ID: ", lobby_id)

# Steam 回调：通过 Steam 界面加入游戏
func _on_join_requested(lobby_id: int) -> void:
	print("通过 Steam 加入大厅: ", lobby_id)
	join_lobby(lobby_id)

# 设置大厅数据
func set_lobby_data(key: String, value: String) -> void:
	if current_lobby_id != 0 and is_lobby_owner and is_steam_initialized:
		Steam.setLobbyData(current_lobby_id, key, value)

# 获取大厅数据
func get_lobby_data(key: String) -> String:
	if current_lobby_id != 0 and is_steam_initialized:
		return Steam.getLobbyData(current_lobby_id, key)
	return ""

# 获取大厅最大玩家数
func get_max_players() -> int:
	if current_lobby_id == 0 or not is_steam_initialized:
		return 0

	return Steam.getLobbyMemberLimit(current_lobby_id)

# 设置大厅最大玩家数
func set_max_players(max_players: int) -> void:
	if current_lobby_id != 0 and is_lobby_owner and is_steam_initialized:
		Steam.setLobbyMemberLimit(current_lobby_id, max_players)
