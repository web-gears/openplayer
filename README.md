# OpenPlayer

A music and podcast player for Garmin smartwatch, syncing with Jellyfin media servers via username/password authentication.

[Garmin Connect IQ Store link](https://apps.garmin.com/apps/261eb561-66a9-448f-8ef0-9d3a5b22652a)

> **Updating the app?** After an update is installed, fully restart your watch before opening OpenPlayer. The first launch after an update can still run the cached previous version (older menus/options may be shown). A quick restart ensures you're on the new version.

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
- Jellyfin server accessible from the watch. Both `https://` and `http://` URLs are accepted.
- Jellyfin user account credentials

**Note about HTTP vs HTTPS:** Garmin watches cannot be forced to allow plain HTTP when the request is relayed through the phone (Garmin Connect Mobile): on Android, cleartext connections to LAN/private addresses are blocked (only `127.0.0.1` is exempt), while iOS typically allows HTTP to raw IP addresses. Plain HTTP to a LAN server generally works when the watch connects directly over WiFi. You can enter `http://` in the server URL; HTTPS remains the reliable option on real hardware.

## Getting Started

### 1. Install

Install OpenPlayer from the [Garmin Connect IQ Store](https://apps.garmin.com/apps/261eb561-66a9-448f-8ef0-9d3a5b22652a) to your watch via Garmin Connect Mobile.

### 2. Connect to your Jellyfin server

Open OpenPlayer on your watch. On first launch you'll see a connect prompt. Press **ENTER** to proceed to the setup screen.

**Garmin Connect Mobile (recommended):** Enter your server URL (e.g. `https://jellyfin.example.com` or `http://192.168.1.50:8096`), username, and password in the Garmin Connect Mobile app under **Device > Apps > OpenPlayer > Settings**. On the watch, press ENTER to connect once the fields are filled.

**QR code:** From the setup screen, press **UP** to switch to the QR code flow. A QR code is displayed on the watch. Scan it with your phone to open a secure form where you enter your Jellyfin server URL (scheme is preserved, e.g. `http://192.168.1.50:8096`), username, and password. The credentials are transmitted to the watch and saved.

After entering credentials, the watch displays a review screen showing your server URL and username. Press ENTER to save.

### 3. Sync playlists

After setup you'll see a list of playlists from your Jellyfin server. Use UP/DOWN to scroll and ENTER to toggle a playlist for syncing. Press ENTER on the sync prompt to download the selected playlists to your watch. Tracks are stored locally for offline playback.

If the sync preview shows **0 new tracks** (everything is already up to date), pressing ENTER finishes the sync locally without connecting over Wi-Fi or starting a background download.

Syncing works in two modes:
- **Selected playlists** are fully synced to **mirror the server**: new tracks are downloaded and tracks that were removed from the playlist on the server are dropped from your synced track list.
- **Deselected playlists** (playlists you downloaded before but aren't selecting now) are **never touched** — their tracks stay on the watch exactly as they are, even after you run another sync.

The synced track list is updated during sync, but cached audio files are only physically removed from the watch by the explicit options below. If you need to regain storage space, use **Remove this Playlist** or **Clear All Downloads**.

In other words, keep a playlist **selected** only if you want it to stay in sync with your Jellyfin server. Deselecting a playlist does **not** delete anything from your watch — it just stops that playlist from being updated. Previously downloaded playlists remain playable offline until you remove them explicitly:

- **Remove this Playlist** — from the music screen (playback list), open the menu and choose **Remove this Playlist**; confirm the prompt. This deselects the playlist and deletes its tracks from the watch.
- **Remove Track** — from the music screen menu, choose **Remove Track** to delete the currently selected song.
- **Clear All Downloads** — from the **Menu → Options** screen, choose **Clear All Downloads** to wipe every synced playlist and track from watch storage.

### 4. Play music

From the main playback screen:

1. **ENTER** to connect and load synced tracks.
2. Select a playlist, then select a track.
3. Use Garmin's native music controls (or the watch's media widget) to play, pause, skip tracks, adjust volume, and toggle **shuffle** / **repeat** (available from the native player's playback menu; shuffle/repeat only appear in Music mode). To switch back to on-watch (local) music or another provider, open the native Garmin Music app (not OpenPlayer) and use its **Music Source** / **Manage** menu (gear icon) → select your preferred source.

### 4.5 Music vs Podcast mode

The app runs in **Music mode** by default. Use **Menu → Switch to podcast mode** (in the main Options menu or the touch action menu) to toggle. The item is labeled **"Switch to music mode"** while in podcast mode.

- **Music mode** — native playback controls: next, previous, volume, shuffle, repeat. (No 30-second skip buttons, so headphone next/previous commands advance/rewind tracks like standard music players.)
- **Podcast mode** — native playback controls: skip forward, skip back, previous, next, volume (shuffle/repeat hidden). Podcast mode enables the 30-second skip buttons; headphone next/previous commands perform 30-second skips here.

The mode applies when playback next starts.

### 5. Manage playlists and storage

Press **Menu** (or the action menu on touch devices) from the playback or sync screens to access:

- **Settings** — Re-run the setup wizard to change server or credentials.
- **Switch to podcast mode / Switch to music mode** — Toggle between Music and Podcast playback modes.
- **Sync playlists** — Select playlists, review number of tracks, and start syncing.
- **Remove this Playlist** — Deselect the highlighted playlist and delete its tracks from the watch (confirmation required).
- **Remove Track** — Delete the currently selected track (confirmation required).
- **Clear All Downloads** — Remove all synced tracks from watch storage (confirmation required).
- **About** — App version and developer info.

### Button navigation

| Action | Button |
|--------|--------|
| Select / Confirm | ENTER |
| Scroll up | UP |
| Scroll down | DOWN |
| Back | ESC / LAP |
| Menu / Options | START (long-press on supported models) |

Touch-enabled watches (Venu X1, Venu 4, Vivoactive 5/6) support tap to select and swipe to scroll: swipe **down** for the next page / item below, swipe **up** for the previous page / item above (matches the on-screen "UP/DOWN" hints).

## Privacy

All data is stored locally, encrypted with your Garmin watch.

If QR authentication path is chosen, [Disposable Form](https://disposable.webgears.org/) ([GitHub](https://github.com/web-gears/disposable-form)) is used to gather the auth credentials.

## License
See [LICENSE.md](LICENSE.md) for full terms. All rights reserved.

## Developed by
Webgears  
https://webgears.org
