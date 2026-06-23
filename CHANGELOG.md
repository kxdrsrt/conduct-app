# Changelog

All notable changes to Conduct are documented here.

## [1.0.0] - 2026-06-22

The first public release of Conduct - a lightweight menu bar conductor for your media keys.

### Media Key Routing

- Route media keys (play/pause, next, previous) to your preferred music app
- **Auto mode** - smart detection of the currently active/playing player, with a configurable priority order
- **9 supported players**: Apple Music, Spotify, Doppler, Vox, Swinsian, Cider, DaftCloud, and YouTube
- **YouTube browser control** - JavaScript injection with a keystroke fallback across 13 browsers
- Volume key redirection to in-app volume
- Double-tap next/previous for skip-two or restart
- Global hotkey to cycle the target app
- Pause other players on play, and resume playback on wake

### Settings Window

- **Sizes to fit each tab** - every section sizes to its own content, so the full Auto Priority list is always visible without scrolling
- **Rock-solid tab bar** - the navigation row never jumps or drifts when switching sections, even on the largest size changes
- **Sliding selection indicator** - the highlight glides smoothly between tabs at a constant size, with no stretching or jank
- **Live animated drag-reordering** - Auto Priority entries shuffle dynamically with a spring animation as you drag
- **Auto Priority and Detection** - sorted by popularity (Spotify, Apple Music, YouTube, DaftCloud, Doppler, Cider, Vox, Swinsian), with larger app icons
- **Global shortcut row** stays visible (greyed out) when disabled, instead of disappearing
- CMD+W closes the frontmost window
- Donation links (Ko-fi, GitHub Sponsors, Open Collective, Patreon, Liberapay) in the About tab

### System

- Launch at login (SMAppService on macOS 13+, LaunchAgent on 11-12)
- First-launch onboarding wizard with an **"Everything It Does"** feature tour
- Hiding the menu bar icon runs the app silently in the background with no Dock icon; re-open from Spotlight or Finder to access settings
- Localized in English, German, Spanish, and Turkish

### Project

- `FUNDING.yml` enables the Sponsor button on the repository
- Support section on the project website with donation buttons
- `CONTRIBUTING.md` with localization contributor guide
