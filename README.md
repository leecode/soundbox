# SoundBox

专为 DLsite 同人音声设计的 macOS 音频播放器，支持字幕显示和便捷的播放列表管理。

## 功能特性

- **多格式支持** - WAV, FLAC, AIFF, ALAC, MP3, AAC, OGG 等常见音频格式
- **VTT 字幕** - 自动加载并同步显示 VTT 格式字幕，支持按曲目折叠的字幕预览面板和跟随播放定位
- **浮动字幕** - 独立浮动窗口显示当前字幕，支持拖动位置并记忆窗口位置
- **播放列表管理** - 支持文件夹导入、拖放排序
- **文件夹历史** - 记录最近打开的文件夹，快速访问收藏内容
- **播放控制** - 上一曲/下一曲、播放/暂停、循环模式（关闭/单曲/列表）、倍速播放
- **A-B 循环** - 支持手动设置 A/B 点，也可以一键循环当前字幕句
- **书签** - 在播放位置添加书签，并在侧栏中快速跳转
- **睡眠定时器** - 支持多档定时暂停，结束前平滑淡出
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
git clone https://github.com/yourusername/SoundBox.git
cd SoundBox
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

```
SoundBox/
├── App/
│   └── SoundBoxApp.swift          # 应用入口和菜单
├── AudioEngine/
│   └── AudioEngine.swift          # 核心音频引擎
├── Decoder/
│   └── LosslessDecoder.swift      # 无损音频解码器
├── Floating/
│   ├── FloatingSubtitlePanel.swift # 浮动字幕窗口
│   └── FloatingSubtitleView.swift  # 浮动字幕视图
├── Managers/
│   └── BookmarkManager.swift      # 书签管理
├── Models/
│   └── Models.swift               # 数据模型（播放列表、历史记录等）
├── Subtitle/
│   └── VTTParser.swift            # VTT 字幕解析器
├── Update/
│   └── UpdateManager.swift        # 应用更新检查
├── Utils/
│   └── FileScanner.swift          # 文件夹扫描工具
├── Views/
│   ├── ContentView.swift          # 主视图
│   ├── PlaylistView.swift         # 播放列表侧边栏
│   ├── PlayerControlBar.swift     # 播放控制栏
│   ├── SubtitleView.swift         # 字幕显示视图
│   └── SubtitlePreviewPanel.swift # 字幕预览面板
└── Resources/
    └── Info.plist                 # 应用配置
```

## 快捷键

- ⌘O - 打开文件夹
- ⌘S - 切换字幕预览面板
- ⌘⇧F - 切换浮动字幕
- ⌘B - 添加书签
- ⌘R - 切换循环模式
- ␣ (空格) - 播放/暂停
- ← → - 快退/快进 5 秒
- ⌘← / ⌘→ - 上一曲/下一曲

## 使用方法

1. 点击菜单栏 "文件" → "打开文件夹..." (⌘O) 选择包含音频文件的文件夹
2. 从播放列表中选择要播放的音声文件
3. 使用底部控制栏进行播放控制：
   - ⏮ ⏸ ▶️ ⏭ - 播放控制
   - 🔁 - 循环模式切换（关闭/单曲/列表）
   - 📊 - 进度条拖拽跳转
   - 🔊 - 音量调节
   - 倍速按钮 - 在常用倍速之间切换
4. 点击字幕按钮 (⌘S) 打开字幕预览面板，可按 track 展开/收起字幕并跟随当前播放位置
5. 在 "播放" 菜单中设置 A-B 循环，或直接循环当前字幕句
6. 在 "显示" 菜单中打开浮动字幕 (⌘⇧F)

## 开发路线

- [x] 基础播放功能
- [x] VTT 字幕同步显示
- [x] 按 track 分组的字幕预览和跟随定位
- [x] 浮动字幕窗口
- [x] 播放列表管理
- [x] 文件夹历史记录
- [x] 循环模式（关闭/单曲/列表）
- [x] A-B 循环和当前字幕句循环
- [x] 倍速播放
- [x] 书签
- [x] 睡眠定时器
- [x] 进度条时间预览
- [x] 媒体键支持（播放/暂停/上下曲）
- [x] 封面显示

## 许可证

MIT License
