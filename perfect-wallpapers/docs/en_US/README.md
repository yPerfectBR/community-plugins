# Perfect Wallpapers

**Perfect Wallpapers** is your unified control center for image, video, and live scene wallpapers in Noctalia. It features seamless integration with the **Wallhaven API** for high-resolution static wallpapers, the **Pixabay API** for stunning photos and video loops, local directories for personal offline media, and **Wallpaper Engine (Steam Workshop)** for interactive and animated scenes.

This plugin was conceived and engineered to unify all wallpaper workflows into a single cohesive interface, eliminating the need to install, configure, and juggle multiple separate plugins from fragmented sources. Built with high performance and resource mindfulness from the ground up, it stays extremely lightweight:
- **Automatic backend termination & maximum efficiency:** When switching providers — such as switching from Wallpaper Engine (which uses `linux-wallpaperengine`) to a static wallpaper (like Wallhaven, Pixabay photos, or local images) — the `linux-wallpaperengine` process is immediately terminated. Dynamic engines are never left idling in the background, freeing 100% of GPU shaders and CPU cycles for your applications.
- **In-RAM session cache:** Search pages, queries, and preview thumbnails live in RAM (`tmpfs`) strictly while the hub panel is open, discarding in-memory structures and unlinking temporary cache upon closing.
- **Intelligent parameter & search cache:** Search queries, pagination states, and preview thumbnails are indexed by their exact parameters (tags, aspect ratios, purity, resolution, sorting). This protects your API rate limits from being exhausted just because you navigated between tabs or repeated previous searches.
- **Automatic session expiry:** Session caches auto-expire after 24 hours and are cleaned up on service restart, preventing long-term disk clutter even across extended desktop uptime.

---

## Plugin

| Field | Value |
| --- | --- |
| ID | `perfect/perfect-wallpapers` |
| Entries | Bar widget: `widget`; panel: `hub`; shortcut: `shortcut`; service: `service` |

---

## Supported Providers (Overview)

For in-depth setup, dependency resolution, API keys, and advanced options, refer to the dedicated guides:

| Provider | Media Types | API Key / Requirements | Documentation |
| :--- | :--- | :--- | :--- |
| **Wallhaven** | High-resolution static images & anime art | Optional (free key for NSFW & higher limits) | [Wallhaven Guide](wallhaven.md) |
| **Pixabay** | Curated photos, illustrations & video loops | Required (free personal API key) | [Pixabay Guide](pixabay.md) |
| **Wallpaper Engine** | 2D/3D interactive scenes, video loops & web | `linux-wallpaperengine` + Steam Workshop | [Wallpaper Engine Guide](wallpaper-engine.md) |
| **Local Folders** | Offline images & videos from personal folders | None | [Local Guide](local.md) |

---

## Requirements

The plugin requires Noctalia with plugin API level ≥ 28. External tools and API tokens depend on the providers you use:

- `mpvpaper` and `mpv`: required for video playback.
- `linux-wallpaperengine`: required for Steam Workshop interactive scenes.
- `setsid` and `pkill`: standard system utilities for background process management.
- Pixabay: free personal API token (see [Pixabay Guide](pixabay.md)).
- Wallhaven: optional free personal API token (see [Wallhaven Guide](wallhaven.md)).

---

## Usage

### 1. Bar Widget
Add the `widget` entry to your bar in Noctalia (**Settings → Bar → Widgets**). Clicking the widget toggles the `hub` panel. The widget dynamically reflects status (glyph changes to `movie` during animated video or Wallpaper Engine playback).

### 2. Control Center Shortcut
Add the `shortcut` entry to your Control Center (**Settings → Control Center → Shortcuts**). The tile indicates whether a wallpaper is actively running and toggles the `hub` with a single click.

### 3. CLI & IPC
Toggle the panel or control the background service via IPC:

```sh
# Toggle the wallpaper hub panel
noctalia msg panel-toggle perfect/perfect-wallpapers:hub

# Switch tabs directly via IPC
noctalia msg plugin perfect/perfect-wallpapers:hub all wallhaven
noctalia msg plugin perfect/perfect-wallpapers:hub all pixabay
noctalia msg plugin perfect/perfect-wallpapers:hub all wallpaperengine
noctalia msg plugin perfect/perfect-wallpapers:hub all local

# Query backend status
noctalia msg plugin perfect/perfect-wallpapers:service all status

# Stop active video/scene wallpaper engines
noctalia msg plugin perfect/perfect-wallpapers:service all stop

# Manually purge session caches
noctalia msg plugin perfect/perfect-wallpapers:service all clear-cache
```

---

## Settings

Configure settings under **Settings → Plugins → Perfect Wallpapers** or inside `config.toml`:

| Setting | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `default_provider` | `select` | `pixabay` | Default provider loaded when opening the hub (`local`, `pixabay`, `wallhaven`, `wallpaperengine`). |
| `download_dir` | `folder` | `""` | Shared fallback directory for downloaded media (empty = `~/Pictures/Wallpapers/perfect-wallpapers`). |
| `local_directories` | `string_list` | `[]` | List of local directories scanned for wallpapers and videos. |
| `wallpaperengine_dir` | `folder` | `""` | Custom path to the Steam `431960` workshop directory if outside standard locations. |
| `pixabay_api_key` | `string` | `""` | Free Pixabay API token. |
| `pixabay_safesearch` | `bool` | `true` | Restrict Pixabay results to all-ages safe content. |
| `pixabay_video_quality` | `select` | `large` | Preferred video stream resolution (`large`, `medium`, `small`, `tiny`). |
| `wallhaven_api_key` | `string` | `""` | Optional Wallhaven API token for higher limits and NSFW content. |
| `wallhaven_purity_sfw` | `bool` | `true` | Include Safe for Work wallpapers from Wallhaven. |
| `wallhaven_purity_sketchy` | `bool` | `false` | Include artistic/sketchy wallpapers from Wallhaven. |
| `wallhaven_purity_nsfw` | `bool` | `false` | Include adult wallpapers (requires Wallhaven API key). |
| `video_fps` | `int` | `30` | Maximum FPS limit for video & Wallpaper Engine rendering (0 = uncapped). |
| `hardware_decode` | `bool` | `true` | Enable GPU hardware acceleration for video playback. |
| `mute_video` | `bool` | `true` | Automatically mute audio on live wallpapers and video loops. |
| `stop_foreign_backends` | `bool` | `true` | Halt competing daemons (`mpvpaper`, `swww-daemon`, `awww-daemon`) when applying. |

---

## Portuguese Documentation

For the complete documentation translated into Brazilian Portuguese, visit [docs/pt_BR/README.md](../pt_BR/README.md).
