# Wallpaper Engine (Steam Workshop) Provider Guide

[Wallpaper Engine](https://store.steampowered.com/app/431960/Wallpaper_Engine/) on Steam is the leading platform for animated, interactive, and 3D live wallpapers.

Perfect Wallpapers brings native Wallpaper Engine support to Noctalia and Wayland compositors (such as Umbriel), allowing you to browse, search, and apply your subscribed Steam Workshop wallpapers with automatic color palette extraction and power-saving controls.

---

## 1. Supported Wallpaper Types

Perfect Wallpapers parses your Steam Workshop items and categorizes them automatically:

1. **Scene**: Interactive 2D and 3D real-time rendered scenes powered by OpenGL/Vulkan shaders.
2. **Video**: Pre-rendered high-definition animated loops.
3. **Web**: Interactive HTML5, WebGL, and JavaScript desktop experiences.

The plugin provides a type selector in the hub (**All**, **Scene**, **Video**, **Web**) and an instant search filter by title, workshop ID, or tags.

---

## 2. Resolving Dependencies

To render live Wallpaper Engine assets under Linux Wayland compositors, you need the following components installed on your system:

### A. The Engine: `linux-wallpaperengine`

`linux-wallpaperengine` is an open-source reimplementation of the Wallpaper Engine runtime for Linux:

- **Arch Linux / AUR**:
  ```sh
  paru -S linux-wallpaperengine
  ```
  *(or using `yay -S linux-wallpaperengine`)*

- **Pandora Linux Distribution / Hybrid GPU Setup**:
  On systems with dual GPUs (Intel/AMD iGPU + NVIDIA dGPU), Pandora installs a dedicated wrapper (`~/.local/bin/linux-wallpaperengine`) targeting the power-efficient integrated GPU via Mesa drivers to ensure maximum battery longevity and smooth Wayland rendering.

- **Check installation**:
  ```sh
  which linux-wallpaperengine
  linux-wallpaperengine --help
  ```

### B. Helper Utilities: `setsid` and `pkill`

These standard system utilities manage the background process lifecycle cleanly:
- On Arch Linux, they are included in `util-linux` and `procps-ng` (installed by default).

### C. Steam & Workshop Wallpapers

To use Wallpaper Engine wallpapers:
1. Ensure the Steam client is installed.
2. Subscribe to wallpapers in the Steam Workshop for Wallpaper Engine (AppID `431960`).
3. Ensure the wallpapers are downloaded by Steam.

---

## 3. Library Location & Detection

Perfect Wallpapers automatically locates your downloaded Workshop items by scanning standard Steam directories:

- `~/.local/share/Steam/steamapps/workshop/content/431960/`
- `~/.steam/steam/steamapps/workshop/content/431960/`
- Multi-drive Steam libraries defined inside `libraryfolders.vdf`.

### Custom Directory Override:
If your Steam library is placed in a non-standard mount or partition, specify the folder path in **Settings → Plugins → Perfect Wallpapers → Custom Wallpaper Engine workshop directory** (`wallpaperengine_dir`).

---

## 4. Wayland Desktop Integration & Performance

Running animated wallpapers on Wayland requires careful handling to avoid visual artifacts or excessive battery drain:

- **True Wayland Layer Shell Anchoring**:
  The plugin inspects your active monitors via `noctalia.outputs()` and launches the engine with `--screen-root <output> --bg <id>`, anchoring the wallpaper to the Wayland `wlr-layer-shell` background layer. It **never** creates an unwanted floating window.
- **Palette Synchronization**:
  Before switching to the live scene, Perfect Wallpapers feeds the wallpaper's static preview image to Noctalia's native engine (`noctalia.setWallpaper()`). This triggers Noctalia and Umbriel to calculate desktop color schemes, bar colors, and accent highlights that match the wallpaper seamlessly.
- **Native Wallpaper Suspension**:
  While the live scene is active, Noctalia's native static wallpaper layer is disabled (`mutex.enableNoctaliaWallpaper(false)`), freeing GPU cycles and avoiding double compositing.
- **Process Cleanup & Escrow**:
  When stopping or switching back to an image, any active `linux-wallpaperengine` processes are cleanly terminated with escalating signals (`SIGTERM` followed by `SIGKILL`), restoring the native static background.
- **Audio & FPS Settings**:
  - `mute_video`: passes `--silent` to prevent unexpected sound from scenes.
  - `video_fps`: passes `--fps <target>` to throttle rendering rates and keep hardware cool.
