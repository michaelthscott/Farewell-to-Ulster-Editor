# Changelog

All notable changes to the Farewell to Ulster editor app are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow [Semantic Versioning](https://semver.org): MAJOR.MINOR.PATCH. Each release is tagged `editor-vMAJOR.MINOR.PATCH`.

## [Unreleased]

### Changed

- The app passes its SwiftData container to SwiftUI, so views can use `@Query`. The Eras, Events, Subjects and Poems tabs, the poem editor's pickers and the subject ordering sheet now do so. Their lists no longer fetch everything on each redraw, and they update as soon as an item is added or deleted.
- On first launch, poems are linked to their era, events and subjects by looking each one up by UUID, in place of a database fetch per link.
- "Failed to create storage" now says what went wrong, such as a missing asset or the JSON decoding error, in place of a generic "invalid asset".

### Added

- If the book's JSON links a poem to an era, event or subject that isn't in the book, first launch still loads the book without that link, and an alert now lists each link that was left out. Before, these links were dropped silently.

### Fixed

- Edits are saved as soon as you tap Save in an editor, delete an item, or save a new subject order. Before, these changes were only written when SwiftData's autosave next ran. A failed save now shows a "Save failed" alert.
- A new subject's sort position is saved along with the subject. Before, it was set after the save and left to autosave.
- The book loaded on first launch is saved straight away. Before, it was only written when autosave next ran.
- Commit update stops and reports an error if the book, eras, events, subjects or poems can't be fetched. Before, a failed fetch was treated as an empty list, so the update could commit a book with parts missing to the site repo.
- PDF export shows a "PDF export failed" alert if the book can't be fetched, in place of doing nothing, and the Book tab shows the error in place of a blank page.

## [1.1.2]

### Changed

- The Poems tab's search tokens are filtered by `PoemSearchToken.filter(_:)` in place of a private function in `PoemsTab`, and each token now has a unit test.
- The duplicate title token counts titles once, in place of fetching every poem again for each poem in the list.

## [1.1.1]

### Changed

- Moved the editor from the `Editor/` folder of [Farewell-to-Ulster](https://github.com/michaelthscott/Farewell-to-Ulster) into this repo, with its history. Scripts now run from the repo root as `scripts/release.sh` and `scripts/refresh-seed.sh`. Build numbers continue from 1.1.0's build 523.
- `Document` is now a `FileDocument` struct holding the exported bytes, in place of a `ReferenceFileDocument` class. This drops the app's use of Combine.
- The JSON export uses the standard `public.json` type. The custom `org.michaelthscott.json` type never took effect, because the system always resolved it to `public.json`.

### Fixed

- Removed the warning about opening documents in place. `Info.plist` no longer declares a document type, because the app never opens files.

## [1.1.0]

### Changed

- Commit update writes the book's JSON to `_data/Farewell-to-Ulster.json` in the site repo instead of into the editor's asset catalog. The bundled copy is now only the first-launch seed.

### Added

- `Editor/scripts/refresh-seed.sh` downloads the latest book from the site repo into the asset catalog. `release.sh` runs it and commits any change before building.

## [1.0.0]

### Added

- Versioned release pipeline: `Editor/scripts/release.sh` tests, archives, and installs a release on the iPhone, and tags it.
- The Book tab menu shows the app version and build number.

### Fixed

- Release builds failed to compile because previews referenced `SampleData`, which is a development asset left out of archives. Previews that use it are now wrapped in `#if DEBUG`.

### Changed

- Renamed the `PreviewContent` folder to `Previews` and updated the Development Assets build setting to match.
- Replaced the `Previewer` helper with a `SampleData` preview modifier. The in-memory sample storage is now created once and shared across previews, which use the `.sampleData` preview trait.
- Renamed the `Model` folder to `Models`.
- Replaced the `AppIcon` asset catalog icon set with an Icon Composer `AppIcon.icon` file. The map image now has a transparent background in place of solid white.
