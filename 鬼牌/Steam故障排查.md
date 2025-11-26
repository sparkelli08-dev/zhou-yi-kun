# Steam 故障排查指南

## 问题：游戏显示"离线模式"，但 Steam 已运行

如果你已经启动了 Steam 客户端，但游戏仍然显示为离线模式，请按照以下步骤排查。

---

## 步骤1：查看 Godot 输出日志

运行游戏后，查看 Godot 编辑器底部的"输出"面板，寻找以下信息：

### 情况A：看到 "Steam API 不存在"
```
=== Steam API 不存在！GodotSteam 插件可能未安装 ===
```

**原因**：GodotSteam 插件未正确安装

**解决方法**：
1. 下载 GodotSteam 插件：https://godotsteam.com/
2. 确保下载的是 **Godot 4.x** 版本（不是 Godot 3.x）
3. 将插件文件解压到项目的 `addons/godotsteam/` 目录
4. 重启 Godot 编辑器

### 情况B：看到 "Steam 初始化失败"
```
=== Steam 初始化失败: XXXXX ===
```

根据错误代码：

#### 错误：Steam 未运行
**解决方法**：
- 确认 Steam 客户端正在运行
- 确认你已登录 Steam 账号

#### 错误：Steam 客户端未运行
**解决方法**：
- 启动 Steam 客户端
- 等待 Steam 完全加载后再运行游戏

#### 错误：Steam API 未加载
**解决方法**：
- 检查 GodotSteam 插件文件是否完整
- 确认使用的是正确的 Godot 版本（4.6+）
- 重新安装 GodotSteam 插件

---

## 步骤2：检查 GodotSteam 插件安装

### 验证插件文件
确认以下文件存在：

```
zhou-yi-kun/
├── addons/
│   └── godotsteam/
│       ├── godotsteam.gdextension
│       ├── win64/
│       │   ├── libgodotsteam.windows.template_debug.x86_64.dll
│       │   └── steam_api64.dll
│       ├── linux64/
│       └── osx/
```

### 启用插件
1. 在 Godot 编辑器中，点击 **项目 → 项目设置**
2. 切换到 **插件** 标签
3. 确认 **GodotSteam** 已勾选启用

---

## 步骤3：检查 steam_appid.txt

确认项目根目录下有 `steam_appid.txt` 文件：

```
zhou-yi-kun/
└── steam_appid.txt  ← 必须存在
```

文件内容应该是：
```
480
```

**注意**：
- 文件名必须是 `steam_appid.txt`，不能有其他扩展名
- 内容只有一行：`480`（测试用 App ID）

---

## 步骤4：检查 Godot 版本兼容性

### 确认版本
- **Godot**: 必须是 4.6 或更高版本
- **GodotSteam**: 必须是 Godot 4.x 版本

### 检查方法
1. 打开 Godot 编辑器
2. 点击 **帮助 → 关于 Godot**
3. 确认版本号是 4.6.x

---

## 步骤5：手动测试 Steam API

创建一个简单的测试脚本：

```gdscript
# test_steam.gd
extends Node

func _ready():
	print("测试 Steam API...")

	if not Steam:
		print("❌ Steam API 不存在")
		return

	print("✅ Steam API 存在")

	var result = Steam.steamInitEx()
	print("初始化结果: ", result)

	if result['status'] == 1:
		print("✅ Steam 初始化成功")
		print("Steam ID: ", Steam.getSteamID())
		print("用户名: ", Steam.getPersonaName())
	else:
		print("❌ Steam 初始化失败")
		print("错误代码: ", result['status'])
```

运行这个脚本，查看输出信息。

---

## 常见问题

### Q1: GodotSteam 插件在哪里下载？
**A**: 访问 https://godotsteam.com/ 下载对应版本。

### Q2: 我用的是 Godot 4.6，应该下载哪个版本？
**A**: 下载标有 "Godot 4.x" 或 "GDExtension" 的版本。

### Q3: 插件解压后放在哪里？
**A**: 解压到项目根目录的 `addons/godotsteam/` 文件夹中。

### Q4: 我需要重新编译 Godot 吗？
**A**: 不需要！GodotSteam 是 GDExtension 插件，直接使用即可。

### Q5: Steam 客户端必须在线吗？
**A**: 是的，Steam 客户端必须运行并登录。

### Q6: 可以在没有 Steam 的电脑上测试吗？
**A**: 可以，游戏会自动切换到离线模式。

---

## 正确的启动流程

### ✅ 正确流程
```
1. 启动 Steam 客户端
2. 等待 Steam 完全加载
3. 打开 Godot 编辑器
4. 运行游戏（F5）
5. 看到"Steam 初始化成功"
6. 显示你的 Steam 用户名
```

### ❌ 错误流程
```
1. Steam 未运行
2. 直接运行游戏
3. 显示"离线模式"
```

---

## 详细日志示例

### 成功的日志
```
开始初始化 Steam...
Steam 初始化结果: { "status": 1, "verbal": "成功" }
========================================
Steam 初始化成功！
用户: YourSteamName
Steam ID: 76561198XXXXXXXX
========================================
```

### 失败的日志（Steam 未运行）
```
开始初始化 Steam...
Steam 初始化结果: { "status": 0 }
=== Steam 初始化失败: Steam 未运行 ===
========================================
切换到离线模式
原因: Steam 未运行
========================================
```

### 失败的日志（插件未安装）
```
=== Steam API 不存在！GodotSteam 插件可能未安装 ===
========================================
切换到离线模式
原因: GodotSteam 插件未找到
========================================
```

---

## 仍然无法解决？

如果按照以上步骤仍然无法解决问题：

1. **截图 Godot 输出日志**（完整日志）
2. **检查项目文件结构**
   ```bash
   ls -la addons/godotsteam/
   cat steam_appid.txt
   ```
3. **提供 Godot 版本信息**
4. **提供 GodotSteam 版本信息**

带着这些信息寻求帮助。

---

**明日之歌工作室**
开发人员：周義坤、孙钰章
