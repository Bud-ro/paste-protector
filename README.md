# Paste Protector

A <128KB clipboard daemon that adds copy feedback and clears stale clipboard content automatically.

Copy something, get a checkmark. Wait a few seconds, clipboard is cleared. Press Right Ctrl to get it back.

## Platform Support

| Feature                  | Windows          | Linux (X11)          | macOS                |
|--------------------------|:----------------:|:--------------------:|:--------------------:|
| Clipboard Monitor        | ✅               | ✅                   | ✅                   |
| Copy Notification        | ✅               | ✅                   | ✅                   |
| Paste Protection         | ✅               | ✅                   | ✅                   |
| Override Key Restore     | ✅               | ✅                   | ✅                   |
| System Tray              | ✅               | ✅ (if tray manager) | ✅                   |
| Multi-Monitor            | ✅               | —                    | —                    |
| Image Clipboard          | ✅               | —                    | —                    |

## Install

Download `paste-protector.exe` from the [latest release](https://github.com/Bud-ro/paste-protector/releases). Run it. Auto-start: `Win+R` → `shell:startup` → drop the exe there.

## Build

Requires [Zig 0.16+](https://ziglang.org/download/).

```bash
zig build -Doptimize=ReleaseSmall -Dtarget=x86_64-windows   # 77KB
zig build -Doptimize=ReleaseSmall                             # Linux
zig build test                                                # Run tests
```

Linux needs `libx11-dev libxfixes-dev libxrender-dev`.

## Configuration

Right-click the tray icon. All settings are there and persist automatically.

Config file: `%APPDATA%\paste-protector\config.toml` (Windows) or `~/.config/paste-protector/config.toml` (Linux/macOS).

## License

[GPL-2.0](LICENSE) — Copyright (C) 2026 Budro
