# Changelog

## 0.5.0

### Fixed
- `flipH`/`flipV` no longer break uniform scale: an omitted `sy` follows `sx`, as in `love.graphics.draw`.
- Grid column and row counts now account for `left`, `top` and `border`; frames outside the sheet are rejected.
- `onLoop` set to an unknown method name raises a clear error instead of `attempt to call a string value`.
- `update` ignores `dt <= 0`, `NaN` and infinity (a bad `dt` used to rewind the animation or freeze it for good).
- `desAnim8.new(frames, durations)` (anim8 style, no image) and incomplete legacy calls raise a usage error that points to `newAnimation`.
- Duplicate range keys in a durations table are rejected instead of depending on `pairs` order.
- Non-integer frame and range numbers are rejected by `Grid` and `gotoFrame`.
- `resume` on a finished `once`/`bounceOnce` animation no longer fires `onLoop` again.
- The frame list is copied at construction.
- Instances no longer inherit the module table (`anim.new`, `anim._VERSION`, ...).
- Errors are reported at the caller's line instead of inside the library.
- The embedded license notice names the copyright holder.

### Added
- `setFlipH(bool)`, `setFlipV(bool)`, `getFrameCount()`, `getDuration()`, `getPlayMode()`.
- `draw` raises a clear error when called with the wrong argument shape for bound or image-less animations.
- Unknown play mode errors list the valid modes and hint at `onLoop`.
- Test suite: `tests/run.lua` (unit, mocked LÖVE) and `tests/smoke` (real LÖVE).

### Docs
- README: heading hierarchy, play mode table, fields table, notes on `pauseAtEnd` per mode, updated anim8 migration table, pixel-art filter in Quick start.
