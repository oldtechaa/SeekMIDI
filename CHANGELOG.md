# Change Log
Notable changes will be documented here. This project strives for [Semantic Versioning](http://semver.org/) adherence.

## [Unreleased] - 2016-03-26
### Added
- Measure markings are provided at the top and throughout the note grid.
- README now links to the wiki.
- Allow changing volume of notes.
- Extend CONTRIBUTING.md to be more meaningful.
### Fixed
- Bug fix for issue #18, now you can run SeekMIDI outside of the directory containing the script.
- Bug fix for issue #11, which spews out a bunch of unnecessary warnings.
- Fix for issue #15: higher notes are now at the top of the plotting area.
- Fix #13: An empty filename now does nothing.
### Changed
- Left-click and drag now adds notes, right-click removes.
- No longer rely on installation of MIDI-Perl. It is now included in the source directory under lib/.
- SeekMIDI.pl can now be found in the bin/ directory.

## 0.01 - 2016-03-25
### Added
- First release. Added the last bit of code for getting the MIDI output from the GUI.

[Unreleased]: https://github.com/oldtechaa/SeekMIDI/compare/v0.1.0...HEAD
