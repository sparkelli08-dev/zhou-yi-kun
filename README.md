# 鬼牌

一个基于 Godot 4.6 引擎开发的多人在线卡牌游戏，支持 Steam P2P 联机。

## 项目介绍

"鬼牌"是一款经典的扑克牌游戏，玩家通过声明和出牌来消耗手牌，首个出光所有牌的玩家获胜。游戏的核心在于策略性撒谎和质疑机制，增加了游戏的趣味性和挑战性。

### 开发团队
- **工作室**: 明日之歌工作室
- **开发人员**:
  - 周義坤
  - 孙钰章

### 技术栈
- **游戏引擎**: Godot 4.6
- **渲染器**: Forward Plus
- **开发语言**: GDScript
- **网络方案**: Steam P2P
- **插件**: GodotSteam

## 游戏规则

### 核心玩法

1. **人数与牌数**
   - 2-3 人：使用 1 副扑克牌（54张）
   - 4-6 人：使用 2 副扑克牌（108张）

2. **游戏目标**
   - 首个出光所有手牌的玩家获胜

3. **出牌流程**
   - 首轮随机一位玩家开始，后续轮次由上一轮胜者开始
   - 出牌者声明出牌的点数和张数（可以撒谎）
   - 卡牌叩置到牌桌上（背面朝上）
   - 其他玩家可选择：质疑、跟牌或过牌

4. **质疑机制**
   - 质疑者可以在规定时间内（房主设置）翻开叩置的牌
   - 如果牌与声明一致：质疑失败，质疑者拿走所有桌面的牌
   - 如果牌与声明不一致：质疑成功，出牌者拿回自己的牌，质疑者可以出牌

5. **跟牌机制**
   - 玩家可以跟随上家继续出相同点数的牌
   - 跟牌后，只能质疑最新跟牌者的牌

6. **过牌机制**
   - 所有玩家都过牌后，桌面的牌进入弃牌堆
   - 下一位玩家开始新一轮

## 功能特性

### 已实现

- [x] Steam 集成与认证
- [x] **离线模式支持**（Steam 不可用时自动切换）
- [x] P2P 网络通信
- [x] 房间创建与加入（支持房间码）
- [x] 完整的游戏逻辑系统
  - [x] 发牌系统
  - [x] 回合管理
  - [x] 出牌与声明机制
  - [x] 质疑与验证系统
  - [x] 跟牌机制
  - [x] 胜利判定
- [x] 基础 UI 框架
  - [x] 主菜单界面
  - [x] 房间大厅界面
  - [x] 游戏主界面
- [x] 卡牌数据系统
- [x] 网络同步系统

### 待完善

- [ ] 场景文件创建（需在 Godot 编辑器中完成）
- [ ] 美术资源导入
  - [ ] 扑克牌图片
  - [ ] UI 界面美化
  - [ ] 背景音乐和音效
- [ ] 动画效果
  - [ ] 出牌动画
  - [ ] 翻牌动画
  - [ ] 胜利特效
- [ ] 聊天系统
- [ ] 战绩统计
- [ ] AI 玩家（单人模式）

## 项目结构

```
zhou-yi-kun/
├── 鬼牌/
│   ├── Scripts/
│   │   ├── Autoload/          # 自动加载单例
│   │   │   ├── SteamManager.gd      # Steam 管理器
│   │   │   ├── NetworkManager.gd    # 网络管理器
│   │   │   └── GameManager.gd       # 游戏状态管理器
│   │   ├── Cards/             # 卡牌系统
│   │   │   ├── Card.gd              # 卡牌类
│   │   │   └── Deck.gd              # 牌堆类
│   │   └── UI/                # UI 脚本
│   │       ├── MainMenu.gd          # 主菜单
│   │       ├── Lobby.gd             # 房间大厅
│   │       ├── Game.gd              # 游戏主界面
│   │       └── CardUI.gd            # 卡牌UI组件
│   ├── Scenes/               # 场景文件
│   │   ├── MainMenu.tscn     # （需创建）
│   │   ├── Lobby.tscn        # （需创建）
│   │   └── Game.tscn         # （需创建）
│   ├── Resources/            # 资源文件
│   │   ├── Cards/            # 卡牌图片
│   │   ├── Audio/            # 音效音乐
│   │   └── UI/               # UI资源
│   └── 项目设置指南.md       # 详细设置说明
├── project.godot             # Godot 项目配置
└── README.md                 # 本文件
```

## 技术实现

### 核心系统

1. **Steam 管理器 (SteamManager)**
   - Steam 初始化和用户认证
   - 大厅创建、加入、离开
   - 玩家列表管理
   - 好友邀请支持

2. **网络管理器 (NetworkManager)**
   - Steam P2P 连接管理
   - 消息序列化与传输
   - 主机-客户端架构
   - 网络同步机制

3. **游戏管理器 (GameManager)**
   - 游戏状态机管理
   - 回合流程控制
   - 卡牌逻辑处理
   - 质疑验证算法
   - 胜利条件判定

### 网络架构

- **主机模式**：房主负责游戏逻辑计算和状态同步
- **客户端模式**：其他玩家接收状态更新，发送操作指令
- **P2P 通信**：使用 Steam 网络进行点对点数据传输
- **消息类型**：
  - 玩家准备
  - 游戏开始
  - 发牌
  - 出牌声明
  - 质疑
  - 跟牌
  - 过牌
  - 状态同步

## 快速开始

### 前置要求

1. **Godot Engine 4.6+**
   - 下载地址：https://godotengine.org/download

2. **GodotSteam 插件**（可选）
   - 文档：https://godotsteam.com/
   - 在线模式需要安装并配置
   - 离线模式可跳过

3. **Steam 客户端**（可选）
   - 在线模式需要 Steam 客户端在线
   - **离线模式**：Steam 不可用时自动启用单人游戏

### 安装步骤

1. **克隆项目**
   ```bash
   git clone https://github.com/yourusername/zhou-yi-kun.git
   cd zhou-yi-kun
   ```

2. **使用 Godot 打开项目**
   - 打开 Godot Engine
   - 导入 `project.godot` 文件

3. **创建场景文件**
   - 参考 `鬼牌/项目设置指南.md` 创建 UI 场景
   - 或者先运行测试核心逻辑

4. **配置 Steam App ID**
   - 在项目根目录创建 `steam_appid.txt`
   - 测试时使用：`480`（Spacewar）
   - 正式发布替换为你的 Steam App ID

5. **运行游戏**
   - 点击 Godot 编辑器的运行按钮
   - Steam 可用：显示在线模式
   - Steam 不可用：自动切换到离线模式

### 离线模式

**什么时候启用**：
- Steam 客户端未运行
- GodotSteam 插件未安装
- Steam API 初始化失败

**离线模式功能**：
- ✅ 单人游戏
- ✅ 完整游戏逻辑
- ❌ 多人联机
- ❌ 好友邀请

**使用方法**：
1. 不启动 Steam 客户端
2. 运行游戏，看到"离线模式"提示
3. 点击"创建房间"
4. 开始单人游戏

详细说明：`鬼牌/离线模式说明.md`

### 多人测试

**方法一：本地多开**
1. 导出项目为可执行文件
2. 使用不同 Steam 账号运行多个实例

**方法二：好友联机**
1. 玩家A 创建房间，获取房间码
2. 玩家B 输入房间码加入
3. 或通过 Steam 好友列表直接加入

## 开发文档

### 详细配置指南
请查看：`鬼牌/项目设置指南.md`

### API 文档

**SteamManager**
```gdscript
# 创建大厅
SteamManager.create_lobby(max_players: int, challenge_time: int)

# 加入大厅
SteamManager.join_lobby(lobby_id: int)

# 离开大厅
SteamManager.leave_lobby()
```

**NetworkManager**
```gdscript
# 发送消息给所有人
NetworkManager.send_message_to_all(message: Dictionary)

# 发送消息给特定玩家
NetworkManager.send_message_to(peer_id: int, message: Dictionary)
```

**GameManager**
```gdscript
# 初始化游戏
GameManager.initialize_game(player_list: Array, config: Dictionary)

# 玩家出牌
GameManager.player_claim_cards(player_id: int, rank: String, count: int, cards: Array)

# 质疑
GameManager.player_challenge(challenger_id: int)
```

## 更新日志

### [v0.1.0] - 2025-11-26

#### 新增
- 完整的 Steam P2P 联机系统
- 房间创建与加入功能（支持房间码）
- 完整的游戏核心逻辑
  - 自动发牌系统
  - 回合管理
  - 出牌声明机制
  - 质疑验证系统
  - 跟牌系统
  - 胜利判定
- 三个核心管理器（Steam、Network、Game）
- 卡牌数据系统（Card、Deck）
- UI 脚本框架
  - 主菜单
  - 房间大厅
  - 游戏主界面
  - 卡牌UI组件
- 项目设置指南文档

#### 待完成
- 场景文件创建
- 美术资源导入
- 音效系统
- 动画效果

---

## 常见问题

**Q: Steam 初始化失败怎么办？**
A: 确保 Steam 客户端正在运行，检查 `steam_appid.txt` 文件是否存在。

**Q: 如何测试多人联机？**
A: 导出游戏后，使用不同的 Steam 账号运行多个实例，或邀请 Steam 好友加入。

**Q: 卡牌图片不显示？**
A: 确认图片文件命名正确（小写），格式为 PNG，路径为 `res://鬼牌/Resources/Cards/`。

**Q: P2P 连接失败？**
A: 确认双方都在 Steam 好友列表中，检查防火墙设置。

## 贡献指南

欢迎参与项目开发！

1. Fork 本项目
2. 创建你的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交你的更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开 Pull Request

## 许可证

待定

## 联系方式

- 项目地址：https://github.com/yourusername/zhou-yi-kun
- 问题反馈：https://github.com/yourusername/zhou-yi-kun/issues

---

**明日之歌工作室**
开发人员：周義坤、孙钰章
© 2025
