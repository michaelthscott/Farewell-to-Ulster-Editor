This is the Xcode project for the app that I use on my iPhone to work on _Farewell to Ulster_. The book itself, and the website built from it, live in [Farewell-to-Ulster](https://github.com/michaelthscott/Farewell-to-Ulster).

## Requirements

- iOS 27
- Xcode 27

## Development

Open `FarewellToUlster/FarewellToUlster.xcodeproj` in Xcode and run the `FarewellToUlster` scheme. Run the unit tests with ⌘U.

Debug builds always show version **1.0 (1)**. The real version number is only applied by the release script, so if the Book tab menu shows 1.0 (1), you're running a debug build.

## Versioning

| Part | Where it comes from | Example |
|---|---|---|
| Version | Argument to `release.sh`, following [Semantic Versioning](https://semver.org) | `1.1.0` |
| Build number | Number of commits on `main` plus 359 for the commits left in the site repo (always increases) | `523` |
| Git tag | Created by `release.sh` after a successful install | `editor-v1.1.0` |

Tags start with `editor-` because the editor used to share a repo with the book. The prefix is kept so all releases are tagged the same way.

How to choose the version number:

| Bump | When | Example |
|---|---|---|
| **Patch** | Bug fixes only | `1.0.0` → `1.0.1` |
| **Minor** | New features, nothing breaks | `1.0.1` → `1.1.0` |
| **Major** | Breaking changes, e.g. a new JSON or Markdown output format | `1.1.0` → `2.0.0` |

## Release Checklist

Run these from the repo root (`Farewell-to-Ulster-Editor`).

Before you start:

- [ ] All work is committed on `main`.
- [ ] `git pull`, in case anything was pushed from another machine.
- [ ] Tests pass in Xcode (⌘U).
- [ ] Pick the new version number using the table above. Check the last one with `git describe --tags --abbrev=0 --match 'editor-v*'`.

Update the changelog:

- [ ] In `CHANGELOG.md`, rename `## [Unreleased]` to `## [x.y.z]` and make sure it lists everything in this release.
- [ ] Add a new empty `## [Unreleased]` section above it.
- [ ] Commit: `git commit -am "Prepare x.y.z"`

Release:

- [ ] In the app on the iPhone, commit any updates you want to keep safe on GitHub. They go to the site repo, [Farewell-to-Ulster](https://github.com/michaelthscott/Farewell-to-Ulster). Installing keeps the app's data, but it's good to have a copy.
- [ ] Unlock the iPhone and keep it connected by cable or on the same Wi-Fi as the Mac.
- [ ] Run `scripts/release.sh x.y.z`. It refreshes the bundled seed data from the site repo (committing it if it changed), then tests, archives, signs, installs on the iPhone, and tags `editor-vx.y.z`.
  - To install on another device, run `DEVICE=<identifier> scripts/release.sh x.y.z`. Find identifiers with `xcrun devicectl list devices`.

Afterwards:

- [ ] Open the app on the iPhone and check the Book tab menu (⋯) shows the new version.
- [ ] Check your poems are all there.
- [ ] Push the commit and tag: `git push origin main editor-vx.y.z`

### If something goes wrong

- **Script stops before "Tagging"**: nothing was tagged. Fix the problem, commit, and run the script again with the same version.
- **"main is behind origin/main"**: run `git pull`, then run the script again. The build number will be higher.
- **Roll back to an earlier version**: open Xcode → **Window → Organizer**, select the archive you want, click **Distribute App → Custom → Debugging**, export it, and install with `xcrun devicectl device install app --device <identifier> <path to .app>`. The `.app` is inside `Payload/` once the exported `.ipa` is unzipped.
- **Undo a tag that hasn't been pushed**: `git tag -d editor-vx.y.z`

## Signing

Releases are signed with an Apple Development certificate (`scripts/ExportOptions.plist`, method `debugging`). They run on devices registered to the team, and the provisioning profile expires after a year, so make a new release before then.

`ExportOptions.plist` is ignored by git, so copy it into `scripts/` when you clone this repo on a new Mac.
