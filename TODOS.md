# SoundBox Design TODOs

> From design review (2026-04-18). Ordered by priority.

## 1. 实现封面大气背景
- **What**: 用封面图提取主色调渲染为 60px 模糊背景 (0.6 dark / 0.4 light opacity)。字幕文本成为主内容区核心视觉元素，进度条作为导航焦点。缩小或移除独立的 200x200 封面方块。
- **Why**: DESIGN.md 核心设计意图：音声作品的视觉焦点是字幕+进度，不是封面。封面作为氛围背景更合适。
- **Pros**: 符合产品定位，视觉层次更清晰
- **Cons**: 需要主色调提取逻辑，SwiftUI 背景实现有一定复杂度
- **Context**: DESIGN.md lines 91-92, ContentView.swift:8-10, ContentView.swift:166-207
- **Depends on**: 无

## 2. 修复侧面板位置
- **What**: 侧面板从播放列表和主内容之间移到最右边。HStack 顺序改为: Playlist | Main Content | Side Panel。
- **Why**: macOS 应用约定：辅助面板在右侧。当前位置在 Playlist 和 Player 之间违反惯例。
- **Pros**: 符合 macOS 规范，用户心智模型一致
- **Cons**: 零风险改动，只需调 HStack 顺序
- **Context**: ContentView.swift:24-28
- **Depends on**: 无

## 3. 添加加载状态指示
- **What**: (1) 播放按钮在 `playbackState == .loading` 时显示 spinner 而非播放图标。(2) 文件夹扫描时侧边栏显示扫描进度指示器。
- **Why**: Hi-Res 文件平均 400MB，加载需要 3-8 秒。用户点击播放后看不到任何反馈。文件夹扫描 15 个文件可能需要 10+ 秒无反馈。
- **Pros**: 消除"卡住了？"的焦虑，提升感知性能
- **Cons**: 需要在 AudioEngine 中正确触发 .loading 状态
- **Context**: PlayerControlBar.swift:110, SoundBoxApp.swift:312-322, Models.swift:183 (.loading enum case)
- **Depends on**: AudioEngine loading 状态触发机制

## 4. 控制栏缩略图显示封面
- **What**: 将 PlayerControlBar 的静态波形占位符替换为 AsyncArtworkView (36x36, cornerRadius: 8)。
- **Why**: DESIGN.md spec: "Thumbnail: 36x36 in control bar"。当前是彩色方块+波形图标，不显示真实封面。
- **Pros**: 一致性，用户能在控制栏看到正在播放的曲目封面
- **Cons**: 无
- **Context**: PlayerControlBar.swift:63-73
- **Depends on**: AsyncArtworkView 已实现

## 5. 统一 formatTime 函数
- **What**: 提取到共享工具函数 (如 `FormatUtils.formatTime`)，统一小时格式处理。当前 5 处重复实现，BookmarkListView 支持小时但 PlayerControlBar 不支持。
- **Why**: 5 次重复 = 5 次不一致风险。小时格式已出现分歧。
- **Pros**: 消除 DRY 违规，统一时间显示
- **Cons**: 5 个文件小改动
- **Context**: ContentView.swift:316, PlayerControlBar.swift:230, PlayerControlBar.swift:367, SubtitlePreviewPanel.swift:188, BookmarkOverlay.swift:49
- **Depends on**: 无

## 6. 侧面板标签用图标替换文字
- **What**: 用 SF Symbol 图标 (text.bubble | doc.text | bookmark) 替换文字标签 "字幕 | 台本 | 书签"。激活状态用 accent color + 底部边框。
- **Why**: DESIGN.md 提议的改进。图标更紧凑，跨语言一致。
- **Pros**: 更美观，更紧凑，视觉一致性更好
- **Cons**: 低优先级改进
- **Context**: ContentView.swift:90-111
- **Depends on**: 无

## 7. AudioEngine 单例重构为协议注入
- **What**: 定义 AudioEngineProtocol，AppState 持有协议而非具体类型。解耦测试和未来多实例支持。
- **Why**: 当前单例 + delegate 一对一绑定，无法 mock 测试 AppState，无法支持 Phase 3 双屏播放器实例。
- **Pros**: 可测试 + 可扩展
- **Cons**: 触及核心架构，需全量回归
- **Context**: AudioEngine.swift:13 (`static let shared`), SoundBoxApp.swift:267 (`AudioEngine.shared.delegate = self`)
- **Depends on**: Phase 3 (F7 双屏体验) 前必须完成

## 8. 统一 formatTime 并加测试
- **What**: 提取 FormatUtils.formatTime()，统一小时格式处理（>60min 显示 H:MM:SS）。替换 5 处重复实现。
- **Why**: 5 处重复 + 小时格式不一致。PlayerControlBar 显示 72:30，BookmarkListView 显示 1:12:30。用户可见 bug。
- **Pros**: 消除 DRY 违规，统一时间显示，纯函数易测试
- **Cons**: 5 个文件小改动
- **Context**: ContentView.swift:316, PlayerControlBar.swift:230,367, SubtitlePreviewPanel.swift:188, BookmarkOverlay.swift:49
- **Depends on**: 无

## 9. 补核心逻辑单元测试
- **What**: 补充 FileScanner.extractTrackNumber、PlaybackPositionManager 存取恢复、formatTime 的单元测试。AppState 测试被 AudioEngine 单例卡住（TODO #7），先补能测的。
- **Why**: 核心逻辑零测试。Track number 排序错会打乱播放列表。播放位置恢复是 one-shot 逻辑，易出回归。测试覆盖率从 43% 提升到 ~60%。
- **Pros**: 回归保护，文档化行为
- **Cons**: extractTrackNumber 需改可见性 (private → internal)
- **Context**: SoundBoxTests/ 目录下新增测试文件
- **Depends on**: TODO #8 (formatTime) 先完成

## 10. 修复 .finished 状态无下一曲时 UI 卡住
- **What**: repeat mode .none 时最后一曲播完，goToNextTrack() 直接 return，UI 停在 .finished 无反馈。应显示"播放完成"提示或回到 .stopped 状态。
- **Why**: 用户不知道播放结束了。播放器看起来像是卡住了。
- **Pros**: 明确的播放结束反馈
- **Cons**: 小改动，需确认 UI 显示方式
- **Context**: SoundBoxApp.swift:446-458 (playNextTrack early return)
- **Depends on**: 无
