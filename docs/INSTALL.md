# Local installation

The current foundation package is a HOST MOCK development build, not a usable timer release. Device installation has not been tested (V02 / DV01).

1. Copy dist/timerdeck-0.1.0.xtapp to the SD-card root over USB and eject safely.
2. On the reader open All Files, tap the package, then install.
3. If Ink App is absent: Settings → About → tap Model ten times (community guidance).
4. Open Ink App → Timer Deck; open Device information and photograph it for DV01.

Later, when M5 implements the opt-in control: Menu → Settings → Lock screen → On. Keep Settings → Display → Off wallpaper on Default (community guidance). M0 contains only a name/time lock page and does not select it automatically.

Reinstalling the same app_id upgrades and preserves data by contract. Uninstalling deletes private data, but preserves /AppFiles/timerdeck/.

If the firmware rejects the pinned package, record the exact firmware and error. The community packager supports --image for deriving a key from the owner's flash dump. Do not upload sources or use Studio without explicit owner approval.
