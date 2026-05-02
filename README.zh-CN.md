# SoundBox

[English](README.md) | 简体中文

专为 DLsite 同人音声设计的 macOS 音频播放器，支持字幕显示和便捷的播放列表管理。

## 功能特性

- **多格式支持** - WAV, FLAC, AIFF, ALAC, MP3, AAC, OGG 等常见音频格式
- **VTT 字幕** - 自动加载并同步显示 VTT 格式字幕，支持字幕预览面板
- **播放列表管理** - 支持文件夹导入、拖放排序
- **文件夹历史** - 记录最近打开的文件夹，快速访问收藏内容
- **播放控制** - 上一曲/下一曲、播放/暂停、循环模式（关闭/单曲/列表）
- **音量控制** - 精确的音量调节和静音切换
- **进度控制** - 可视化进度条，支持拖拽跳转和时间预览
- **媒体键支持** - 键盘媒体键控制播放/暂停/上下曲
- **封面显示** - 自动加载文件夹中的封面图片

## 系统要求

- macOS 14.0+
- Xcode 15.0+

## 构建方法

1. 克隆仓库

```bash
git clone https://github.com/leecode/soundbox.git
cd soundbox
```

2. 使用 Xcode 打开项目

```bash
open SoundBox.xcodeproj
```

3. 构建并运行 (⌘R)

或者使用命令行构建：

```bash
xcodebuild -project SoundBox.xcodeproj -scheme SoundBox build
```

## 项目结构

```text
SoundBox/
├── App/
│   └── SoundBoxApp.swift          # 应用入口和菜单
├── Models/
│   └── Models.swift               # 数据模型（播放列表、历史记录等）
├── Views/
│   ├── ContentView.swift          # 主视图
│   ├── PlaylistView.swift         # 播放列表侧边栏
│   ├── PlayerControlBar.swift     # 播放控制栏
│   ├── SubtitleView.swift         # 字幕显示视图
│   └── SubtitlePreviewPanel.swift # 字幕预览面板
├── AudioEngine/
│   └── AudioEngine.swift          # 核心音频引擎
├── Decoder/
│   └── LosslessDecoder.swift      # 无损音频解码器
├── Subtitle/
│   └── VTTParser.swift            # VTT 字幕解析器
└── Utils/
    └── FileScanner.swift          # 文件夹扫描工具
```

## 快捷键

- ⌘O - 打开文件夹
- ⌘S - 切换字幕预览面板
- ␣ (空格) - 播放/暂停
- ← → - 快退/快进 5 秒

## 使用方法

1. 点击菜单栏 "文件" → "打开文件夹..." (⌘O) 选择包含音频文件的文件夹
2. 从播放列表中选择要播放的音声文件
3. 使用底部控制栏进行播放控制：
   - ⏮ ⏸ ▶️ ⏭ - 播放控制
   - 🔁 - 循环模式切换（关闭/单曲/列表）
   - 📊 - 进度条拖拽跳转
   - 🔊 - 音量调节
4. 点击字幕按钮 (⌘S) 打开字幕预览面板

## 开发路线

- [x] 基础播放功能
- [x] VTT 字幕同步显示
- [x] 播放列表管理
- [x] 文件夹历史记录
- [x] 循环模式（关闭/单曲/列表）
- [x] 进度条时间预览
- [x] 媒体键支持（播放/暂停/上下曲）
- [x] 封面显示

## 许可证

MIT License
