# OpenPlayer

A music and podcast player for Garmin smartwatch, syncing with Jellyfin media servers via username/password authentication.

[Garmin Connect IQ Store link](https://apps.garmin.com/apps/261eb561-66a9-448f-8ef0-9d3a5b22652a)

<img width="1440" height="720" alt="hero_garmin" src="https://github.com/user-attachments/assets/39d4c0a6-3b38-44c7-9c0b-b31be34e8b1c" />
(Audio player interface vary by model)



## Features
- Username/password authentication via Jellyfin's `/Users/AuthenticateByName`
- Credentials used once — only the access token is stored on device
- Select specific Jellyfin playlists to sync
- Local storage management with size warnings
- First-run setup wizard with QR code flow
- Garmin Connect Mobile settings for server URL, username, and password
- Audio content provider app for Garmin wearable integration

<img width="240" height="240" alt="ezgif-20d663f3e9bcf921" src="https://github.com/user-attachments/assets/f785cd54-17a9-432e-bed0-24223d7d60ae" />

## Requirements
- Garmin Fenix 5+ (or compatible Connect IQ device starting API level 3.1 with music and WiFi support)
- Jellyfin server accessible over **HTTPS** (e.g. `https://jellyfin.example.com`)
- Jellyfin user account credentials

**Note:** Garmin watches require TLS for all network connections. Plain HTTP addresses will not work on real hardware. If your Jellyfin server runs locally, set up a reverse proxy with a valid SSL certificate or use a service like Tailscale/Cloudflare Tunnel to expose it over HTTPS.

## Getting Started

### 1. Install

Install OpenPlayer from the [Garmin Connect IQ Store](https://apps.garmin.com/apps/261eb561-66a9-448f-8ef0-9d3a5b22652a) to your watch via Garmin Connect Mobile.

### 2. Connect to your Jellyfin server

Open OpenPlayer on your watch. On first launch you'll see a connect prompt. Press **ENTER** to proceed to the setup screen.

**Garmin Connect Mobile (recommended):** Enter your server URL (must start with `https://`), username, and password in the Garmin Connect Mobile app under **Device > Apps > OpenPlayer > Settings**. On the watch, press ENTER to connect once the fields are filled.

**QR code:** From the setup screen, press **UP** to switch to the QR code flow. A QR code is displayed on the watch. Scan it with your phone to open a secure form where you enter your Jellyfin server URL (must use HTTPS), username, and password. The credentials are transmitted to the watch and saved.

After entering credentials, the watch displays a review screen showing your server URL and username. Press ENTER to save.

### 3. Sync playlists

After setup you'll see a list of playlists from your Jellyfin server. Use UP/DOWN to scroll and ENTER to toggle a playlist for syncing. Press ENTER on the sync prompt to download the selected playlists to your watch. Tracks are stored locally for offline playback.

### 4. Play music

From the main playback screen:

1. **ENTER** to connect and load synced tracks.
2. Select a playlist, then select a track.
3. Use Garmin's native music controls (or the watch's media widget) to play, pause, skip, adjust volume, and toggle **shuffle** / **repeat** (available from the native player's playback menu). To switch back to on-watch (local) music or another provider, open the native Garmin Music app (not OpenPlayer) and use its **Music Source** / **Manage** menu (gear icon) → select your preferred source.

### 5. Manage playlists and storage

Press **Menu** (or the action menu on touch devices) from the playback or sync screens to access:

- **Settings** — Re-run the setup wizard to change server or credentials.
- **Sync playlists** — Select playlists, review number of tracks, and start syncing.
- **Clear All Downloads** — Remove all synced tracks from watch storage.
- **About** — App version and developer info.

### Button navigation

| Action | Button |
|--------|--------|
| Select / Confirm | ENTER |
| Scroll up | UP |
| Scroll down | DOWN |
| Back | ESC / LAP |
| Menu / Options | START (long-press on supported models) |

Touch-enabled watches (Venu X1, Venu 4, Vivoactive 5/6) support tap to select and swipe to scroll.

## Privacy

All data is stored locally, encrypted with your Garmin watch.

If QR authentication path is chosen, [Disposable Form](https://disposable.webgears.org/) ([GitHub](https://github.com/web-gears/disposable-form)) is used to gather the auth credentials.

## License
See [LICENSE.md](LICENSE.md) for full terms. All rights reserved.

## Developed by
Webgears  
https://webgears.org
