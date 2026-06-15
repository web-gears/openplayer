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
- Jellyfin server with public access
- Jellyfin user account credentials

## Privacy

All data is stored locally, encrypted with your Garmin watch.

If QR authentication path is chosen, [Disposable Form](https://disposable.webgears.org/) ([GitHub](https://github.com/web-gears/disposable-form)) is used to gather the auth credentials.

## License
See [LICENSE.md](LICENSE.md) for full terms. All rights reserved.

## Developed by
Webgears  
https://webgears.org
