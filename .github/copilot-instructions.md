# Copilot instructions for Conduct

## Writing style (applies to all output: code comments, commit messages, changelogs, UI strings, docs)

- Never use long dashes (em dash or en dash). Use a comma, parentheses, or a plain hyphen `-` instead.
- Do not use AI buzzwords or filler. Avoid words like: seamless, leverage, robust, elevate, delve, unlock, empower, game-changer, "in today's fast-paced world". Write plainly and directly.
- Keep release notes, changelog entries, and commit messages concise and factual.

## Releasing (Sparkle appcast)

- NEVER sign a locally-built ZIP for the appcast. The CI release workflow builds its own binary; the bytes differ from any local build, so a locally-generated signature will be wrong and Sparkle will reject the update with "improperly signed".
- Always download the ZIP from the GitHub release after the workflow completes, sign that file with `./Frameworks/bin/sign_update <downloaded>.zip`, and put that signature in appcast.xml.
- NEVER use `codesign --deep` when signing the app. It re-signs Sparkle's internal XPC helpers (`Installer.xpc`, `Downloader.xpc`, `Autoupdate`) with the wrong entitlements, which breaks in-app updates. Use `codesign --force --sign <identity> --entitlements ...` on the outer app bundle only.
