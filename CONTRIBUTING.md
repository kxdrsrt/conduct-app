# Contributing to Conduct

Conduct is open source and welcomes contributions of all kinds - bug reports, feature requests, code, documentation, and translations.

## Reporting bugs

Open an issue and include:

- macOS version and which music app(s) you use
- Steps to reproduce the problem
- What you expected vs. what happened

## Suggesting features

Open an issue describing the use case. Keep in mind Conduct is a lightweight menu bar controller, so proposals that add significant complexity or dependencies are less likely to land.

## Contributing code

1. Fork the repo and create a branch.
2. Build with `make build` (requires Xcode command-line tools).
3. Make your changes. Run the app with `make dev` to test locally.
4. Open a pull request with a clear description of what changed and why.

There is no formal style guide, but match the conventions of the surrounding code. Keep pull requests focused - one logical change per PR.

## Adding or improving a translation

Conduct uses standard `.strings` files under `Resources/`. Each language is a folder named `<language-code>.lproj`.

### Languages currently included

| Folder     | Language       |
| ---------- | -------------- |
| `en.lproj` | English (base) |
| `de.lproj` | German         |
| `es.lproj` | Spanish        |
| `tr.lproj` | Turkish        |

### Adding a new language

1. Find the [IETF language tag](https://www.iana.org/assignments/language-subtag-registry) for the language (e.g. `fr` for French, `ja` for Japanese).
2. Copy the English strings file as a starting point:
   ```
   cp Resources/en.lproj/Localizable.strings Resources/<code>.lproj/Localizable.strings
   ```
3. Translate every value on the right-hand side of `=`. Do not change the keys (left side).
4. Keep special characters as-is: `\u2026` (ellipsis), `\u2192` (arrow), modifier key symbols (`\u2303\u2325`).
5. Keep app and platform names untranslated: `Conduct`, `Apple Music`, `Spotify`, `Ko-fi`, `GitHub`, etc.
6. Open a pull request with the new folder.

### Updating an existing translation

If a string is missing from your language file, copy the English entry and translate it. Missing keys fall back to English automatically, so the app won't break - but a complete translation is preferred.

### Testing your translation

Build the app and change your Mac's language to the target locale under System Settings > Language & Region. Relaunch Conduct and verify the UI looks correct. Pay attention to long strings that might truncate in menus or settings rows.
