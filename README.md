# SoundBox - 高保真音频播放器

一款专为音声作品设计的 macOS 高保真音频播放器，支持 Bit-Perfect 输出。

## 功能特性

- **Bit-Perfect 输出** - 绕过系统混音器，直接输出原始音频数据
- **Integer Mode** - 支持 DAC 原生整数格式，避免浮点转换
- **Hi-Res 支持** - 支持 24-bit/96kHz 及以上高解析度音频
- **多格式支持** - WAV, FLAC, AIFF, ALAC, MP3, AAC, OGG
- **VTT 字幕** - 自动加载并同步显示 VTT 格式字幕
- **播放列表** - 支持文件夹导入、拖放排序
- **内存播放** - 音频预加载到内存，减少磁盘干扰

## 系统要求

- macOS 14.0+
- Xcode 15.0+
- Swift 5.9+

## 构建方法

### 方法一：使用 Xcode（推荐）

1. 打开 Xcode
2. 选择 File → New → Project
3. 选择 macOS → App
4. 产品名称输入 `SoundBox`
5. 界面选择 `SwiftUI`，语言选择 `Swift`
6. 选择保存位置（覆盖此目录）
7. 将 SoundBox 目录下的源文件添加到项目中
8. 构建运行 (⌘R)

### 方法二：使用命令行

```bash
cd /Users/leecode/ai-workspaces/SoundBox
swift build
swift run SoundBox
```

## 项目结构

```
SoundBox/
├── App/
│   └── SoundBoxApp.swift          # 应用入口
├── Models/
│   └── Models.swift               # 数据模型
├── Views/
│   ├── ContentView.swift          # 主视图
│   ├── PlaylistView.swift         # 播放列表
│   ├── PlayerControlBar.swift     # 播放控制
│   └── SubtitleView.swift         # 字幕显示
├── AudioEngine/
│   └── AudioEngine.swift          # 核心音频引擎
├── Decoder/
│   └── LosslessDecoder.swift      # 音频解码器
├── Subtitle/
│   └── VTTParser.swift            # VTT字幕解析
├── Utils/
│   └── FileScanner.swift          # 文件扫描
└── Resources/
    └── Info.plist                 # 应用配置
```

## 音频引擎架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Bit-Perfect 播放链路                      │
│                                                             │
│  [音频文件] → [AVAudioFile] → [原始PCM] → [AUHAL] → [DAC]    │
│                  ↓              ↓              ↓            │
│              保持原始格式     环形缓冲区     独占访问          │
└─────────────────────────────────────────────────────────────┘
```

## 使用的外部 DAC 推荐

为了获得最佳音质体验，建议使用外部 USB DAC：

- AudioQuest DragonFly
- iFi audio hip-dac
- FiiO K3
- Chord Mojo

## 开发路线

- [x] 基础播放功能
- [x] VTT 字幕同步
- [ ] Integer Mode 完整实现
- [ ] 自动采样率切换
- [ ] 无缝播放
- [ ] 睡眠定时器
- [ ] 均衡器
- [ ] 媒体键支持

## 许可证

MIT License
