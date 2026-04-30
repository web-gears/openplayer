# OpenPlayer

A music and podcast player for Garmin Fenix 6S Pro, syncing with Jellyfin media servers via API key authentication.

## Features
- Secure API key authentication (no username/password)
- Select specific Jellyfin playlists to sync
- Local storage management with size warnings
- Encrypted API key storage (XOR obfuscation)
- First-run setup wizard
- In-app configuration screen
- Audio content provider app for Garmin wearable integration

## Requirements
- Garmin Fenix 6S Pro (or compatible Connect IQ device)
- Jellyfin server with public access
- API key generated from Jellyfin

## Project Structure
```
OpenPlayer/
├── source/
│    ├── JellyfinClient.mc
│    ├── StorageManager.mc
│    ├── OpenPlayerApp.mc
│    ├── OpenPlayerContentIterator.mc
│    ├── OpenPlayerConfigureSyncDelegate.mc
│    ├── OpenPlayerConfigureSyncView.mc
│    ├── SettingsWizardDelegate.mc
│    ├── SettingsWizardView.mc
│    ├── OpenPlayerConfigurePlaybackDelegate.mc
│    ├── OpenPlayerConfigurePlaybackView.mc
│    ├── OpenPlayerOptionsView.mc
│    ├── ConfirmActionMenu.mc
│    └── JellyfinModels.mc
├── resources/strings/strings.xml
├── manifest.xml
└── monkey.jungle
```

## License
See [LICENSE.md](LICENSE.md) for full terms. All rights reserved.

## Developed by
Webgears  
https://webgears.org
