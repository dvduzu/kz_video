# KzVideo

克制的 B 站第三方客户端：无广告、无无限推荐流、每日固定一批。

- 平台：Android（Flutter）
- 当前版本：`0.3.1+9`（见 `pubspec.yaml`）
- 远端：`gitea`（自建）与 `origin`（GitHub）

## 功能

- **推荐流**：每日固定一批，可按分区（全部 / 热门 / 科技 / 知识 / 美食 / 游戏 / 娱乐 / 音乐）配置长视频时长与推荐数量
- **热门**：瀑布流浏览；可设置“不限”或固定条数
- **订阅**：时间线 + 分桶轮询（多样性）+ 换一批分页，可按已关注 UP 主筛选
- **UP 主主页**：头像、粉丝数、投稿分页（app cursor 分页）
- **播放器**：AndroidX Media3 ExoPlayer，Texture 渲染，后台播放 + 通知栏媒体控制
- **弹幕**：`canvas_danmaku` 渲染，支持透明度 / 字号 / 速度 / 显示区域 / 描边
- **字幕**：B 站 CC 字幕，可调字号 / 位置 / 背景
- **本地**：历史、稍后看、黑名单、播放进度续播
- **外观**：Material You 动态取色、色环选色、主题（音调/清冽/果色/鲜艳/单色）、动画细粒度配置
- **数据**：登录信息、订阅、黑名单、设置的导入 / 导出（系统文件选择器）

## 架构

```
UI (lib/ui)
  ↓
VideoRepository (lib/data/video_repository.dart)   # Facade：委托 + 基础本地 CRUD
  ↓
FeedService / VideoApi / AuthRepository / LocalStore
  ↓
BilibiliClient (WBI 签名、buvid、bili_ticket、请求头)
  ↓
Dio
```

播放器：

```
PlayerScreen (Flutter)
  ↓ NativePlayer (MethodChannel kz/exoplayer + EventChannel kz/exoplayer/events)
ExoPlayerPlugin (Kotlin)
  ↓
PlaybackService (MediaSessionService，持有 ExoPlayer + MediaSession)
  ↓
Media3 ExoPlayer（Texture 输出）
```

## 目录结构

```
lib/
├── core/                 # 日志等基础设施
├── data/
│   ├── video_api.dart          # B 站接口（WBI / app AppSign / protobuf 弹幕解析）
│   ├── video_repository.dart   # Facade
│   ├── feed_service.dart       # 推荐编排 / 过滤 / 缓存
│   ├── local_store.dart        # SharedPreferences 封装
│   ├── models.dart             # VideoInfo / DanmakuItem / SubtitleCue 等
│   ├── bilibili_client.dart    # Dio + WBI + 设备指纹
│   ├── app_sign.dart           # app 接口签名
│   ├── native_player.dart      # ExoPlayer 的 Dart 封装
│   └── ...
└── ui/
    ├── video_list_screen.dart  # 主页列表
    ├── player_screen.dart      # 播放器
    ├── up_channel_screen.dart  # UP 主主页
    └── ...                     # 设置 / 外观 / 订阅等
android/app/src/main/kotlin/com/kzv/kz_video/
├── MainActivity.kt
├── ExoPlayerPlugin.kt
├── PlayerHolder.kt
└── PlaybackService.kt
```

## 开发环境

使用 Nix flake + direnv 提供 Flutter / Android SDK，**所有 Flutter 命令都要用 `direnv exec .` 包裹**：

```bash
direnv exec . bash -c 'flutter pub get'
direnv exec . bash -c 'flutter analyze'
direnv exec . bash -c 'flutter test'
direnv exec . bash -c 'flutter build apk --debug'
direnv exec . bash -c 'flutter build apk --release'
```

注意：`flake.nix` / `flake.lock` 被 `.gitignore` 忽略，但 nix 评估要求在 git 中；如 direnv 环境失效：

```bash
git add -f flake.nix flake.lock && direnv reload
```

## 构建与安装

```bash
direnv exec . bash -c 'flutter build apk --debug'
adb connect <设备IP>:5555
adb -s <设备IP>:5555 install -r build/app/outputs/flutter-apk/app-debug.apk
```

## 登录

- 扫码登录（Web 二维码流程）
- 支持导入 Cookie
- 登录凭据使用 `flutter_secure_storage` 保存

## 数据存储

- `SharedPreferences`：设置、历史、稍后看、黑名单、订阅、播放进度、每日推荐缓存
- `flutter_secure_storage`：登录 Cookie

## 已知问题

- UP 主页头图（banner）：公开 `card` 接口已不返回头图，`acc/info` 的 `top_photo` 受 `-403` 风控影响，暂不稳定
- 尚未覆盖自动化测试（正在补核心 parser / 签名 / 存储的单测）
- `VideoListScreen` / `PlayerScreen` / `VideoApi` / `LocalStore` 偏大，计划逐步拆分

## 免责声明

本项目为个人学习用途的非官方客户端，与哔哩哔哩无关联。请合理使用，遵守相关服务条款。
