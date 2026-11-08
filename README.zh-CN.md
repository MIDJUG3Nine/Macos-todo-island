# Todo Island

[![CI](https://github.com/MIDJUG3Nine/Macos-todo-island/actions/workflows/ci.yml/badge.svg)](https://github.com/MIDJUG3Nine/Macos-todo-island/actions/workflows/ci.yml)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black)
[![MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

[English](README.md) | 简体中文

把待办清单放进 MacBook 的刘海里。指针移到刘海上，清单就从刘海里展开；移开，它就收回去。

- **悬停就能看。** 指针在刘海上停一下，Island 就会展开。
- **点进去就不收。** 点进面板（打字或打勾）后会一直展开，直到你点别处或按 <kbd>Esc</kbd>。也可以用图钉按钮固定。
- **默认待办，也能加别的面板。** 默认打开待办，内置一个便签面板；显示哪些面板、默认打开哪个都可以在设置里改。
- **也可以用 Apple 提醒事项。** 待办可以存在本机（默认），也可以选一个提醒事项列表：在 Island 里添加、打勾、修改、删除都会同步到提醒事项和 iPhone。「清除已完成」只是隐藏，不会删除提醒事项。
- **没有刘海也能用。** 没有刘海的 Mac 或外接显示器上，菜单栏中间会显示一个小胶囊（可关闭）。
- **数据只在本地。** 存在 `~/Library/Application Support/TodoIsland` 下的 JSON 文件里。不用账号，不联网，不收集数据。只有你打开提醒事项来源时才会请求提醒事项权限。
- 界面支持英文和简体中文，跟随系统语言。

## 安装

需要 macOS 13 Ventura 或更新版本，Apple 芯片和 Intel 都能用。

### 下载

在 [Releases](https://github.com/MIDJUG3Nine/Macos-todo-island/releases) 下载 `TodoIsland-<版本>.dmg`，打开后把 **Todo Island** 拖进「应用程序」。发布版用 Developer ID 签名并经过 Apple 公证，可以直接打开。

### 从源码构建

```bash
git clone https://github.com/MIDJUG3Nine/Macos-todo-island.git
cd Macos-todo-island
scripts/bundle.sh          # 生成 build/Todo Island.app
open "build/Todo Island.app"
```

想长期使用就把 `Todo Island.app` 拖进「应用程序」。本地构建只做了 ad-hoc 签名，在构建它的那台 Mac 上可以直接用；拷到别的 Mac 上第一次打开会被拦，这时打开「系统设置 > 隐私与安全性」点「仍要打开」（或者运行
`xattr -dr com.apple.quarantine "/Applications/Todo Island.app"`）。

想自己做签名和公证的发布版，看 `scripts/release.sh` 开头的说明。

开发时也可以直接 `swift run TodoIsland`（开机自启需要打包后的 App）。

## 使用

| 操作 | 方法 |
| --- | --- |
| 展开 | 指针放到刘海上，或点菜单栏的清单图标 → 展开 Island |
| 添加待办 | 在顶部输入框输入，按 <kbd>回车</kbd> |
| 完成 / 取消完成 | 点前面的圆圈 |
| 编辑 | 双击文字，或右键 → 编辑 |
| 删除 | 指针移到某一行点 ×，或右键 → 删除 |
| 切换面板 | 左上角的图标 |
| 保持展开 | 点进面板，或点图钉 |
| 收起 | 指针移开（未固定时）、点别处，或按 <kbd>Esc</kbd> |
| 设置 | 齿轮按钮，或菜单栏图标 → 设置… |

设置项：待办来源（本机或某个提醒事项列表）、默认面板、显示哪些面板、是否回到上次的面板、大小、悬停多久展开 / 离开多久收起、无刘海屏幕的小胶囊、开机自动启动。提醒事项需要用打包好的 App，因为系统通过 Info.plist 来请求权限。

## 原理

一个无边框、不抢焦点的 `NSPanel` 放在菜单栏之上一层，正好盖住摄像头区域（通过 `NSScreen.safeAreaInsets` 和 `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` 算出刘海位置）。鼠标移动事件交给一个小状态机（`HoverState`）决定何时展开、何时收起，不需要辅助功能权限。展开时窗口变成面板大小，SwiftUI 让黑色形状从刘海里"长"出来。

代码分两部分：

- `Sources/TodoIslandCore`：纯 Swift，不依赖 AppKit。待办规则、JSON 存储（文件损坏时会先备份，绝不覆盖）、设置、刘海几何和悬停计时，都有单元测试。
- `Sources/TodoIsland`：App 本身。窗口、菜单栏图标、SwiftUI 面板和设置。

### 新增一个面板

1. 在 `Sources/TodoIslandCore/Settings.swift` 的 `PanelID` 里加一个 case，写上标题和 SF Symbol。
2. 在 `Sources/TodoIsland/Views/` 里写它的 SwiftUI 视图。
3. 在 `IslandRootView.swift` 的 `PanelContentView` 里返回这个视图。

之后它会自动出现在标签栏和设置里。

## 开发

```bash
swift build
swift test
```

以后可能会做：全局快捷键、拖动排序、截止日期、更多面板（日历、剪贴板）。欢迎提 Issue 和 PR。

## 许可证

[MIT](LICENSE) © 2026 MID JUG 3 Nine
