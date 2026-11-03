# OpenPlayer

A music and podcast player for Garmin smartwatches, syncing with Jellyfin media servers via username/password authentication.

[Garmin Connect IQ Store link](https://apps.garmin.com/apps/261eb561-66a9-448f-8ef0-9d3a5b22652a)

> **Updating the app?** After an update is installed, fully restart your watch before opening OpenPlayer. The first launch after an update can still run the cached previous version (older menus/options may be shown). A quick restart ensures you're on the new version.

<img width="1440" height="720" alt="hero_garmin" src="https://github.com/user-attachments/assets/39d4c0a6-3b38-44c7-9c0b-b31be34e8b1c" />
(Audio player interface varies by model)

## Features
- Username/password authentication via Jellyfin's `/Users/AuthenticateByName` (supports Jellyfin 10.8+ through 12)
- Credentials used once: only the access token is stored on device, and passwords in phone settings are masked
- Select specific Jellyfin playlists to sync
- Audio bitrate settings in Garmin Connect Mobile (Auto 128k/256k, 128k, 192k, 256k, 320k)
- Two playback modes: Music mode (shuffle, repeat) and Podcast mode (30-second skip buttons and headphone skip triggers)
- Bluetooth headphone controls (play/pause, volume, track change, 30s skips)
- Physical 5-button navigation and touchscreen gestures (tap, swipe, action menus)
- English and Ukrainian interface support
- First-run setup wizard with QR code flow
- Garmin Connect Mobile settings for server URL, username, password, and bitrate
- Audio content provider app for Garmin wearable integration

<img width="240" height="240" alt="ezgif-20d663f3e9bcf921" src="https://github.com/user-attachments/assets/f785cd54-17a9-432e-bed0-24223d7d60ae" />

## Requirements
- Compatible Garmin smartwatch with music support (Connect IQ API 3.1+)
- Jellyfin media server accessible over HTTPS with a valid SSL certificate (see [Server URL and HTTPS](#server-url-and-https))
- Jellyfin user account credentials

## Supported Devices

Over 60 Garmin smartwatch models are supported:

- **Fenix:** Fenix 5 Plus / 5S Plus / 5X Plus, Fenix 6 Pro / 6S Pro / 6X Pro, Fenix 7 / 7S / 7X (and Pro models), Fenix 8 (43mm, 47mm, Pro, Solar), Fenix 9 (43mm, 47mm, Pro, Pro Solar), Fenix E
- **Forerunner:** FR165 Music, FR170 Music, FR245 Music, FR255 Music / 255S Music, FR265 / 265S, FR570, FR745, FR945 / LTE, FR955, FR965, FR970
- **Venu:** Venu 2 / 2 Plus / 2S, Venu 3 / 3S, Venu 4 (41mm, 45mm), Venu Sq 2 Music, Venu X1
- **Vivoactive:** Vivoactive 3 Music / LTE, Vivoactive 4 / 4S, Vivoactive 5, Vivoactive 6
- **Enduro:** Enduro 3, Enduro 4
- **Epix:** Epix (Gen 2), Epix Pro (42mm, 47mm, 51mm)
- **MARQ & D2:** MARQ (Gen 2), MARQ (Gen 2) Aviator, D2 Mach 2 Pro

## Server URL and HTTPS

OpenPlayer needs to reach your Jellyfin server to authenticate, list playlists, and download tracks. Your Jellyfin server should be exposed via HTTPS with a valid SSL certificate.

### Why HTTPS is needed

The app accepts both `http://` and `https://` URLs, but plain HTTP is unreliable on real watch hardware:

1. **Garmin Connect Mobile blocks cleartext HTTP:**
   When the watch is paired to your phone via Bluetooth, web requests route through Garmin Connect Mobile. On Android 9+, cleartext (HTTP) requests to LAN or external IPs are blocked by default OS policies (only `127.0.0.1` is allowed). On iOS, App Transport Security (ATS) enforces HTTPS. Any plain HTTP URL will fail when relayed through your phone.

2. **Garmin watches put Wi-Fi to sleep:**
   Watches aggressively turn off Wi-Fi to save battery. Connect IQ apps have no way to wake the Wi-Fi chip themselves. When Wi-Fi is sleeping, network requests fall back to phone Bluetooth relay, where plain HTTP fails.

3. **Valid SSL certificates are required:**
   The connection must use a certificate from a standard trusted Certificate Authority (like Let's Encrypt). Self-signed certificates fail handshake verification on both watch and phone.

If your Jellyfin instance runs on a home network, expose it via a reverse proxy (Caddy, Nginx Proxy Manager, Traefik), Cloudflare Tunnel, or Tailscale with HTTPS enabled.

### Working URL examples

| Type | Example | Notes |
|---|---|---|
| Standard HTTPS domain | `https://jellyfin.example.com` | Recommended. Default port 443 with valid SSL certificate. |
| HTTPS with custom port | `https://jellyfin.example.com:8920` | Jellyfin native HTTPS port or custom port. |
| HTTPS with subpath | `https://example.com/jellyfin` | When Jellyfin runs behind a reverse proxy subpath. |
| Dynamic DNS with HTTPS | `https://yourname.duckdns.org` | DDNS domain with a Let's Encrypt certificate. |
| Tailscale / Mesh VPN | `https://jellyfin.your-tailnet.ts.net` | Tailscale with MagicDNS and HTTPS certificates enabled. |

### URLs that do not work

| Example URL | Reason |
|---|---|
| `http://192.168.1.50:8096` | Plain HTTP. Blocked by Android/iOS cleartext policies when relayed through the phone; only works if watch Wi-Fi is already actively awake. |
| `http://jellyfin.local:8096` | Plain HTTP, and `.local` mDNS names are not resolved by Garmin Connect Mobile. |
| `https://192.168.1.50:8920` (self-signed) | Untrusted certificate fails TLS handshake verification. |

## Getting Started

### 1. Install

Install OpenPlayer from the [Garmin Connect IQ Store](https://apps.garmin.com/apps/261eb561-66a9-448f-8ef0-9d3a5b22652a) to your watch via Garmin Connect Mobile.

### 2. Connect to your Jellyfin server

Open OpenPlayer on your watch. On first launch you'll see a connect prompt. Press **ENTER** to proceed to the setup screen.

**Garmin Connect Mobile (recommended):** In the Garmin Connect Mobile app on your phone, open **Device > Apps > OpenPlayer > Settings**. Fill in:
- **Server URL:** e.g. `https://jellyfin.example.com`
- **Username:** your Jellyfin account username
- **Password:** your Jellyfin account password (masked)
- **Audio Bitrate:** default is *Auto*, or pick a fixed bitrate

On the watch, press ENTER to connect once the fields are filled.

**QR code:** From the setup screen, press **UP** to switch to the QR code flow. A QR code is displayed on the watch. Scan it with your phone to open a form where you enter your Jellyfin server URL, username, and password. The credentials are transmitted to the watch and saved.

After entering credentials, the watch displays a review screen showing your server URL and username. Press ENTER to save.

### 3. Audio Bitrate settings

You can change the audio bitrate in Garmin Connect Mobile settings under **Audio Bitrate**:

- **Auto (128k / 256k)** (default): Tracks longer than 20 minutes (podcasts, audiobooks) download at 128 kbps to save watch storage; music tracks download at 256 kbps.
- **128 kbps (Low):** Smallest file size, best for audiobooks or watches with less free storage.
- **192 kbps (Standard):** Good balance between size and quality.
- **256 kbps (High):** Standard high quality music.
- **320 kbps (Maximum):** Maximum MP3 bitrate.

### 4. Sync playlists

After setup you'll see a list of playlists from your Jellyfin server. Use UP/DOWN to scroll and ENTER to toggle a playlist for syncing. Press ENTER on the sync prompt to download the selected playlists to your watch. Tracks are stored locally for offline playback.

If the sync preview shows **0 new tracks** (everything is already up to date), pressing ENTER finishes the sync locally without connecting over Wi-Fi or starting a background download.

**Network requirement for syncing:** Fetching and downloading tracks requires a network connection on the watch (either Wi-Fi or a paired phone). If the watch has no Wi-Fi and no phone connection, syncing stops immediately with the message **"WiFi isn't connected. Open Settings -> WiFi"** instead of hanging. When using an HTTPS server with a domain name, sync requests can route through your paired phone over Bluetooth. If your server is reachable only on your local network, wake the watch's Wi-Fi first (for example via **Settings > Wi-Fi**) before starting a sync.

Syncing works in two modes:
- **Selected playlists** are fully synced to mirror the server: new tracks are downloaded, and tracks removed from the playlist on the server are dropped from the synced list.
- **Deselected playlists** are not touched: tracks you downloaded previously stay on the watch until you remove them explicitly.

To free up storage space:
- **Remove this Playlist:** From the music screen (playback list), open the menu and choose **Remove this Playlist**; confirm the prompt. This deselects the playlist and deletes its tracks from the watch.
- **Remove Track:** From the music screen menu, choose **Remove Track** to delete the currently selected song.
- **Clear All Downloads:** From the **Menu > Options** screen, choose **Clear All Downloads** to wipe all synced playlists and tracks from watch storage.

### 5. Play music

From the main playback screen:

1. Press **ENTER** to connect and load synced tracks.
2. Select a playlist, then select a track.
3. Use Garmin's native music controls (or the watch media widget) to play, pause, skip tracks, adjust volume, and toggle **shuffle** / **repeat** (available from the native player's playback menu in Music mode).
4. Headphone controls: Bluetooth headphone play, pause, volume, and next/previous track buttons work directly.

To switch back to on-watch (local) music or another provider, open the native Garmin Music app (not OpenPlayer) and use its **Music Source** / **Manage** menu (gear icon) to select your preferred source.

### 6. Music vs Podcast mode

The app runs in **Music mode** by default. Use **Menu > Switch to podcast mode** (in the main Options menu or the touch action menu) to toggle. The item is labeled **"Switch to music mode"** while in podcast mode.

- **Music mode:** Native playback controls: next, previous, volume, shuffle, repeat. Headphone next/previous commands change tracks like standard music players.
- **Podcast mode:** Native playback controls: skip forward 30s, skip back 30s, previous, next, volume (shuffle/repeat hidden). Headphone next/previous commands perform 30-second skips.

The mode applies when playback next starts.

### 7. Button navigation

| Action | Button | Touch Gesture |
|---|---|---|
| Select / Confirm | ENTER | Tap |
| Scroll up | UP | Swipe down (or tap top hint) |
| Scroll down | DOWN | Swipe up (or tap bottom hint) |
| Back | ESC / LAP | Swipe right |
| Menu / Options | START (long-press on supported models) | Action menu |

Touch-enabled watches (Venu, Vivoactive) support tap to select and swipe to scroll.

## Troubleshooting and FAQ

#### "WiFi isn't connected. Open Settings -> WiFi"
Garmin watches put their Wi-Fi chip to sleep to save battery, and third-party apps cannot wake it automatically.
- If your Jellyfin server is configured with an HTTPS domain, keep your phone connected via Bluetooth; requests will route through Garmin Connect Mobile.
- If your server is reachable only over local Wi-Fi, wake the watch Wi-Fi first in **Settings > Wi-Fi** or via a built-in sync widget before starting the sync in OpenPlayer.

#### How to switch back to native music or Spotify
Garmin manages active music providers through the native system player. To switch providers:
1. Open the native Garmin Music app.
2. Hold **MENU** (or open the **Manage** / gear icon menu).
3. Select **Music Providers** and pick your source.

#### Playlists fail to load or show auth error
- Check that your Jellyfin URL uses HTTPS and has a valid SSL certificate.
- If your password changed, open **Menu > Settings** on the watch to update credentials.
- Stored tokens that expire are automatically refreshed on the next sync attempt.

#### "Multimedia error" during playback or download
Very large audio files (over 60-80 MB, like long single-file audiobooks) can exceed hardware decoder memory on older models like Fenix 6S Pro. Set **Audio Bitrate** to **Auto** or **128 kbps** in Garmin Connect Mobile settings so Jellyfin transcodes the audio to a smaller size.

## Localization

OpenPlayer is available in:
- English
- Ukrainian

Language follows the watch system language setting.

## Privacy

All data is stored locally, encrypted with your Garmin watch.

If the QR authentication path is chosen, [Disposable Form](https://disposable.webgears.org/) ([GitHub](https://github.com/web-gears/disposable-form)) is used to gather the auth credentials.

## License
See [LICENSE.md](LICENSE.md) for full terms. All rights reserved.

## Developed by
Webgears  
https://webgears.org
