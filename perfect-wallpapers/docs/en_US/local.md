# Local Folders Provider Guide

The **Local** provider in Perfect Wallpapers allows you to browse, search, and set wallpapers from your personal offline media collection directly within the hub.

---

## 1. Features & Media Support

- **Subfolder Scanning**: Automatically scans your configured local folders recursively for supported formats.
- **Dual Media Tabs**:
  - **Images**: Fast browsing of `.jpg`, `.jpeg`, `.png`, `.webp`, `.bmp`, `.svg`, and `.avif`.
  - **Videos**: Fast browsing of `.mp4`, `.webm`, `.mkv`, and `.mov`.
- **Instant Search**: Type inside the search box to filter files immediately by filename, folder name, or relative path.
- **Pagination & Slicing**: Handles large collections (hundreds or thousands of files) smoothly with paginated chunking, preventing UI lag.
- **Direct Application**: Local media files are applied in place without copying or redundant downloads.

---

## 2. Configuring Local Folders

By default, the plugin scans `~/Pictures` and `~/Pictures/Wallpapers` if no specific folders are declared.

To configure your own directories:
1. Open the hub and click the **Manage folders** button (or open **Settings → Plugins → Perfect Wallpapers**).
2. Locate the **Local directories** setting (`local_directories`).
3. Add one absolute path per entry (e.g. `/home/user/Pictures/Wallpapers` or `/mnt/data/Photos`).
4. Re-opening or refreshing the local tab scans the configured locations immediately.

---

## 3. Playback Engines

- **Static Images**:
  Applied directly through Noctalia's built-in background renderer. Theme palettes and accent colors are recomputed on the fly.
- **Videos**:
  Played seamlessly as desktop wallpapers via `mpvpaper`. Supports audio muting (`mute_video`), hardware decoding acceleration (`hardware_decode`), and FPS rate limits (`video_fps`).
