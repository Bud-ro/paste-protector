# Paste Protector

A lightweight clipboard enhancement daemon that adds copy feedback and paste protection across platforms. Not a clipboard manager — it sits between you and your existing clipboard to add visual feedback and prevent accidental paste of stale or sensitive content.

## Features

- **Copy notifications** — Floating overlay that rises and fades on successful copy
- **Paste protection** — Clipboard is automatically cleared after a configurable delay, preventing accidental paste of stale content
- **Override key** — Press a configurable key (default: Right Ctrl) to restore blocked clipboard content
- **System tray** — Background daemon with right-click context menu for all settings
- **Zero dependencies** — No runtime dependencies beyond the OS on Windows and macOS

## Platform Support

| Feature                  | Linux (X11)          | Windows | macOS |
|--------------------------|:--------------------:|:-------:|:-----:|
| Clipboard Monitor        | ✅                   | ✅      | ✅    |
| Copy Notification        | ✅                   | ✅      | ✅    |
| Paste Protection         | ✅                   | ✅      | ✅    |
| Override Key Restore     | ✅                   | ✅      | ✅    |
| System Tray              | ✅ (if tray manager) | ✅      | ✅    |
| Context Menu             | ⚠️  (click-toggle)   | ✅      | ✅    |
| Zero libc                | ❌ (from X11 libs)   | ✅      | ✅    |

## Building

Requires [Zig 0.16+](https://ziglang.org/download/).

```bash
# Debug build
zig build

# Release build (ReleaseSmall, ~167KB Linux / ~460KB Windows)
zig build -Drelease

# Cross-compile for Windows
zig build -Dtarget=x86_64-windows -Drelease

# Cross-compile for macOS (requires SDK, see below)
zig build -Dtarget=aarch64-macos -Drelease

# Run tests (40 tests, <100ms, no sleeps)
zig build test
```

### Linux dependencies

```bash
sudo apt install libx11-dev libxfixes-dev libxrender-dev
```

### macOS cross-compilation

Cross-compiling to macOS from Linux requires a macOS SDK sysroot. See [mitchellh/zig-build-macos-sdk](https://github.com/mitchellh/zig-build-macos-sdk) for a Zig-compatible SDK package.

## Configuration

Config file location:
- Linux: `~/.config/paste-protector/config.toml`
- Windows: `%APPDATA%\paste-protector\config.toml`
- macOS: `~/.config/paste-protector/config.toml`

All settings are also configurable from the system tray context menu.

```toml
# Seconds after last copy before clipboard is cleared
block_duration_ms = 3000

# Key to press to restore blocked clipboard content
# Options: RightCtrl, RightAlt, RightShift, F12
override_key = "RightCtrl"

# Notification position on screen
# Options: top-right, top-left, bottom-right, bottom-left
notif_position = "bottom-right"

# How long the notification takes to fade (ms)
notif_duration_ms = 1200

# Notification size multiplier
# Options: 1, 1.5, 2, 3, 4
notif_scale = "2"

# Enable/disable features independently
notif_enabled = true
block_enabled = true

# Whether paste attempts reset the block timer
paste_resets_timer = true
```

## Usage

```bash
paste-protector                    # Run with default/saved config
paste-protector --config path.toml # Use specific config file
paste-protector --help
paste-protector --version
```

The program runs as a background daemon with a system tray icon. Right-click the tray icon to access settings or quit.

## How It Works

1. **Copy detected** — A "Copied!" notification floats up and fades in the configured corner
2. **Timer starts** — You can paste normally during the configured delay (default 3s)
3. **Clipboard cleared** — After the delay, clipboard content is cleared to prevent stale paste
4. **Override** — Press the override key (default: Right Ctrl) at any time to restore the original content

## Code Signing

See [SIGNING.md](SIGNING.md) for instructions on signing the Windows and macOS binaries.

## License

GPL-2.0
