# Wallhaven Provider Guide

[Wallhaven](https://wallhaven.cc/) is one of the internet's largest community-driven wallpaper databases, featuring an extensive selection of anime, digital art, high-resolution photography, and desktop artwork.

Perfect Wallpapers integrates directly with the Wallhaven API to search, browse, filter, cache, and apply wallpapers without opening a browser.

---

## 1. Features & Search Filters

Wallhaven in Perfect Wallpapers provides full control over the Wallhaven search catalog:

- **Categories**: Toggle **General**, **Anime**, and **People** to scope down searches.
- **Purity**:
  - **SFW** (Safe for Work): enabled by default.
  - **Sketchy**: mildly suggestive or artistic wallpapers.
  - **NSFW**: adult-oriented content (strictly requires a free Wallhaven API key).
- **Sorting Modes**: Sort results by **Date added**, **Relevance**, **Random**, **Views**, **Favorites**, or **Toplist**.
- **Aspect Ratio Filtering**: Filter wallpapers by **Any**, **16:9**, **16:10**, **21:9**, or **Portrait**.
- **Resolution Filtering**:
  - **At least**: Find wallpapers with minimum pixel dimensions (e.g. at least 2560×1440 or 3840×2160).
  - **Exact**: Match exact display resolutions (e.g. 1920×1080).

---

## 2. Obtaining a Free Wallhaven API Key

While Wallhaven allows anonymous searches for standard SFW wallpapers, generating a free API key unlocks:
1. **NSFW content filtering** (requires being logged into an adult-enabled account).
2. **Significantly higher API rate limits** (reducing the chance of encountering HTTP 429 status codes during rapid queries).
3. **Access to personal favorites and curated collections**.

### Steps to generate your key:

1. Create a free account or log in at [wallhaven.cc](https://wallhaven.cc/).
2. Navigate to your account settings: [wallhaven.cc/settings/account](https://wallhaven.cc/settings/account).
3. Scroll down to the **API Key** section.
4. If an API key is not yet generated, click **Generate Key**.
5. Copy the 32-character alphanumeric key.
6. In Noctalia:
   - Open **Settings → Plugins → Perfect Wallpapers** (or click the gear icon inside the Perfect Wallpapers hub).
   - Paste the token into the **Wallhaven API key** field.
   - The key is instantly available to the plugin.

---

## 3. Intelligent Caching & Rate Limit Protection

Wallhaven enforces a public rate limit of approximately 45 requests per minute:

- **In-RAM Query Caching**: Every search payload is hashed based on its exact parameter tuple (`category`, `purity`, `sorting`, `order`, `ratio`, `minWidth`, `minHeight`, `query`, `page`). When you revisit previous tabs or pagination pages, results are returned instantly from RAM without firing network requests.
- **Deduplication of In-Flight Requests**: If you switch tabs rapidly while a request is in flight, the pending query is tracked and shared so redundant network requests are never sent.
- **Session Expiry**: Temporary query envelopes in RAM (`tmpfs`) automatically expire after 24 hours and are wiped when the hub closes or the service restarts, leaving zero persistent disk clutter.

---

## 4. Applying Wallpapers

When you click any Wallhaven thumbnail in the grid:
1. The full-resolution image is downloaded directly into your configured wallpaper download folder (by default `~/Pictures/Wallpapers/perfect-wallpapers`).
2. Any active dynamic wallpaper background processes (such as `linux-wallpaperengine` from Wallpaper Engine or `mpvpaper`) are automatically and immediately stopped, releasing all GPU and CPU resources for maximum efficiency.
3. Noctalia's native wallpaper layer is re-enabled and receives the image via `noctalia.setWallpaper()`.
4. Noctalia and Umbriel immediately synchronize the desktop color palette, system accent colors, and bar themes to match the new image.
