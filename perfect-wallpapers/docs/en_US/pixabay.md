# Pixabay Provider Guide

[Pixabay](https://pixabay.com/) is a world-renowned creative community sharing copyright-free images, illustrations, vectors, and cinematic video footage under the Pixabay Content License.

Perfect Wallpapers integrates directly with the official Pixabay REST API to provide seamless browsing and applying of both still photographs and animated video loops.

---

## 1. Features & Media Types

- **Dual Media Tabs**:
  - **Images**: Browse millions of curated photos, digital illustrations, and vector art.
  - **Videos**: Browse high-definition (HD/4K) looped videos and background motions.
- **Search & Exploration Filters**:
  - **Category**: Filter by 20+ specialized topics including *Nature*, *Backgrounds*, *Science*, *Computer*, *Architecture*, *Feelings*, and *Travel*.
  - **Order**: Toggle between **Popular** and **Latest**.
  - **Editor's Choice**: Restrict results exclusively to media hand-selected and awarded by the Pixabay editorial team.
  - **Orientation**: Filter by **Horizontal**, **Vertical**, or **All**.
  - **SafeSearch**: Enforce age-appropriate content across all queries.
  - **Video Quality Preference**: Configure preferred video stream sizes (**Large**, **Medium**, **Small**, or **Tiny**).

---

## 2. Obtaining a Free Pixabay API Key

Pixabay strictly requires an API key to access its search endpoints. Accounts and API keys are 100% free for personal use.

### Steps to get your API key:

1. Register or sign in to your free account at [pixabay.com](https://pixabay.com/).
2. Open the official API Documentation page: [pixabay.com/api/docs](https://pixabay.com/api/docs/).
3. Scroll down to the **Search Images** or **Parameters** section.
4. Locate the green box showing your unique API key:
   ```text
   key (str): Your API key: XXXXXXX-XXXXXXXXXXXXXXXXXXXXXXXXX
   ```
5. Copy the entire key.
6. In Noctalia:
   - Open **Settings → Plugins → Perfect Wallpapers** (or click the gear icon in the hub).
   - Paste the token into the **Pixabay API key** field.
   - The plugin will now immediately authenticate and load Pixabay results.

---

## 3. Video Wallpaper Engine (`mpvpaper`)

When choosing a video from Pixabay, Perfect Wallpapers coordinates with `mpvpaper` to render the video smoothly as a Wayland desktop wallpaper:

- **Hardware Acceleration**: Video decoding can utilize GPU hardware acceleration by enabling the `hardware_decode` setting (`--hwdec=auto`).
- **FPS Capping**: To conserve battery on laptops and minimize GPU resource usage, you can set a target frame rate (e.g. 30 FPS or 60 FPS) in the plugin settings via `video_fps`.
- **Audio Control**: Mute background audio automatically with the `mute_video` setting.
- **Mutual Exclusion**: Applying a video automatically halts any existing video processes, foreign daemons, or Wallpaper Engine processes to avoid resource conflicts.

---

## 4. Local Download Policy

Pixabay's API Terms of Service strictly forbid permanent hotlinking of media URLs from their CDN. 

To comply with upstream policies and guarantee offline availability:
1. When you select a wallpaper or video, Perfect Wallpapers downloads the full file to your local download directory (`~/Pictures/Wallpapers/perfect-wallpapers`).
2. The local file is then applied to the desktop.
3. Previews and intermediate search pages are kept in temporary RAM (`tmpfs`), avoiding redundant disk writes.
