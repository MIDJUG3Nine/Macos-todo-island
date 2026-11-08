# Todo Island

[![CI](https://github.com/MIDJUG3Nine/Macos-todo-island/actions/workflows/ci.yml/badge.svg)](https://github.com/MIDJUG3Nine/Macos-todo-island/actions/workflows/ci.yml)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black)
[![MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

English | [简体中文](README.zh-CN.md)

Your todo list lives in the MacBook notch. Move the pointer onto the notch and the list
drops down; move away and it tucks back in.

- **Hover to peek.** Rest the pointer on the notch for a moment and the island opens.
- **Click to stay.** Click inside (to type or tick things off) and it stays open until you
  click somewhere else or press <kbd>Esc</kbd>. There is also a pin button.
- **Todo first, more panels if you want.** Todo is the default. A Notes scratchpad is built
  in, and you can choose which panels appear and which one opens first.
- **Use Apple Reminders if you like.** Keep todos on this Mac (default), or pick a
  Reminders list: what you add, tick, edit or delete in the island syncs to Reminders and
  your iPhone. "Clear completed" only hides finished reminders, it never deletes them.
- **No notch? Still works.** On Macs without a notch, or external displays, a small pill
  sits in the middle of the menu bar (can be turned off).
- **Local and private.** Plain JSON files in `~/Library/Application Support/TodoIsland`.
  No account, no network, no analytics. Reminders access is asked for only if you turn it on.
- English and Simplified Chinese UI, following your system language.

## Install

Requires macOS 13 Ventura or later. Works on Apple silicon and Intel.

### Download

Get `TodoIsland-<version>.dmg` from [Releases](https://github.com/MIDJUG3Nine/Macos-todo-island/releases),
open it and drag **Todo Island** into **Applications**. Release builds are signed with a
Developer ID and notarized by Apple, so they open normally.

### Build from source

```bash
git clone https://github.com/MIDJUG3Nine/Macos-todo-island.git
cd Macos-todo-island
scripts/bundle.sh          # builds build/Todo Island.app
open "build/Todo Island.app"
```

Drag `Todo Island.app` into `/Applications` to keep it. A local build is ad-hoc signed,
which is fine on the Mac that built it. If you copy it to another Mac, macOS will block the
first launch: open **System Settings > Privacy & Security** and click **Open Anyway** (or run
`xattr -dr com.apple.quarantine "/Applications/Todo Island.app"`).

To make a signed, notarized release yourself, see the setup notes at the top of
`scripts/release.sh`.

For quick development runs, `swift run TodoIsland` works too (open at login needs the
bundled app).

## Using it

| Action | How |
| --- | --- |
| Open | Hover the notch, or click the checklist icon in the menu bar → Open Island |
| Add a todo | Type in the field at the top and press <kbd>Return</kbd> |
| Finish / reopen | Click the circle |
| Edit | Double-click the text, or right-click → Edit |
| Delete | Hover a row and click ×, or right-click → Delete |
| Switch panel | Icons at the top left |
| Keep open | Click inside, or use the pin button |
| Close | Move away (if not pinned), click elsewhere, or press <kbd>Esc</kbd> |
| Settings | Gear button, or menu bar icon → Settings… |

Settings: todo source (this Mac or an Apple Reminders list), default panel, which panels
are shown, reopen last panel, size, hover and close delays, the pill on screens without a
notch, and open at login. Apple Reminders needs the bundled app, because macOS asks for
permission through its Info.plist.

## How it works

A borderless, non-activating `NSPanel` sits just above the menu bar level, exactly over the
camera housing (found with `NSScreen.safeAreaInsets` and `auxiliaryTopLeftArea` /
`auxiliaryTopRightArea`). Mouse-move monitors feed a small state machine (`HoverState`)
that decides when to open and close; no Accessibility permission is needed. When it opens,
the window grows to the panel size and SwiftUI animates the black shape out of the notch.

The code is split in two:

- `Sources/TodoIslandCore`: plain Swift with no AppKit. Todo list rules, JSON storage
  (a broken file is moved aside, never overwritten), settings, notch geometry and hover
  timing. Covered by unit tests.
- `Sources/TodoIsland`: the app. Window, menu bar item, SwiftUI panels and settings.

### Adding a panel

1. Add a case to `PanelID` in `Sources/TodoIslandCore/Settings.swift` with a title and an
   SF Symbol.
2. Write its SwiftUI view in `Sources/TodoIsland/Views/`.
3. Return it from `PanelContentView` in `IslandRootView.swift`.

It then shows up as a tab and in Settings automatically.

## Development

```bash
swift build
swift test
```

Ideas for later: a global keyboard shortcut, drag to reorder, due dates, more panels
(calendar, clipboard). Issues and pull requests are welcome.

## License

[MIT](LICENSE) © 2026 MID JUG 3 Nine
