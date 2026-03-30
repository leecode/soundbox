# 媒体键支持 & 封面显示 — 设计规格

## 概述

为 SoundBox 添加两个功能：
1. **媒体键支持** — 响应键盘媒体键（播放/暂停/上一曲/下一曲）
2. **封面显示** — 从文件夹中读取封面图片，在主界面中央显示

## 功能 1：媒体键支持

### 需求
- 响应键盘上的播放/暂停、上一曲、下一曲按键
- 不涉及锁屏控制、Touch Bar、系统菜单栏控件

### 方案
使用 `MediaPlayer` 框架的 `MPRemoteCommandCenter` 监听媒体键事件。

### 改动范围

**AppState (`App/SoundBoxApp.swift`)**
- 在 `init()` 中配置 `MPRemoteCommandCenter`：
  - `playCommand` → 调用已有的播放方法
  - `pauseCommand` → 调用已有的暂停方法
  - `nextTrackCommand` → 调用 `playNextTrack()`
  - `previousTrackCommand` → 调用 `playPreviousTrack()`
- 在 `deinit` 中移除命令监听
- 每次曲目切换或播放状态变化时，更新 `MPNowPlayingInfoCenter.default().nowPlayingInfo`（至少包含 `MPMediaItemPropertyTitle`）
  - 这是 `MPRemoteCommandCenter` 正常工作的前提

**Info.plist**
- 已有 `NSAppleEventsUsageDescription`，无需额外添加
- 不需要启用 Background Mode，仅在前台响应媒体键

**AudioEngine (`AudioEngine/AudioEngine.swift`)**
- 无改动，媒体键逻辑完全在 AppState 层处理

### 不涉及
- 锁屏控制
- Touch Bar 集成
- 系统菜单栏播放控件
- Now Playing 中显示封面

---

## 功能 2：封面显示

### 需求
- 从音频文件所在文件夹中查找封面图片
- 在主界面中央显示（替换当前波形图标占位符）
- 无封面时保持当前波形图标

### 方案
在现有 `FileScanner` 异步扫描流程中同时查找封面图片，将封面 URL 附加到 `AudioFile` 模型上。

### 改动范围

**FileScanner (`Utils/FileScanner.swift`)**
- 扫描文件夹时，额外查找封面图片文件
- 匹配规则：
  - 文件名（不区分大小写）：`cover`、`folder`、`album`
  - 扩展名：`.jpg`、`.jpeg`、`.png`、`.webp`
  - 查找顺序：按文件名优先级 `cover > folder > album`，找到第一个即停止
- 将找到的封面 URL 附加到 `AudioFile` 上

**AudioFile (`Models/Models.swift`)**
- 新增属性：`let artworkURL: URL?`
- 无封面时为 `nil`
- `Hashable` 实现不变（仍按 URL 判等）

**ContentView / 主界面 (`Views/ContentView.swift`)**
- 当前波形图标位置改为条件渲染：
  - `artworkURL != nil` → 加载并显示图片（`NSImage(contentsOf:)`），圆角 12pt
  - `artworkURL == nil` → 保持当前波形图标
- 图片尺寸与当前波形图标一致（200x200）
- 使用 `aspectRatio(contentMode: .fit)` 防止变形

### 不涉及
- 封面缓存机制（文件为本地读取，无需缓存）
- 拖放设置封面
- 控制栏小封面
- 播放列表中的缩略图
- 音频文件内嵌元数据封面

---

## 实现顺序

1. 先实现封面显示（改动独立，可即时验证视觉效果）
2. 再实现媒体键支持（需要在后台测试键盘响应）
