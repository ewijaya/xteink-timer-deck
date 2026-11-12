# Timer Deck for XTEINK X4 Pro

Offline Lua 5.5/32 InkApp, API 2.18, 480×800. Functional baseline: Pebble Timer Deck 0.7.0 at 202dbc6. See PRD.md for the product contract.

Current work: M0 foundation shell and host tooling. Timer controls are not implemented yet. All results are HOST MOCK; no device validation has run.

Run `make test`, `make preview`, `make icons` (launcher icon), or `make package`. Python with Pillow and cryptography, make and a C compiler must already be installed. The Lua archive must exist at build/toolchain/lua-5.5.0.tar.gz; setup checks its pinned hash and builds locally. No build step downloads dependencies. After cleaning build/, restore the supplied archive from a local backup.

Previews and gate results are in build/; packages, source hashes, round-trip reports and SHA256SUMS are in dist/. See docs/INSTALL.md and docs/device-checklist.md. The packager is MIT, vendored at 4290dca; no cross-repository runtime imports.

This device has no sound or vibration. Timer Deck alerts you with a screen flash and a light pulse, so keep it where you can see it. Those effects arrive in M4. Timing will derive from wall-clock anchors; forward clock changes count as elapsed, detected rollback preserves values at the last trusted sample. Deadlines beyond January 2038 are refused. Stay awake cannot prevent manual lock or power-off; lock-screen support will be opt-in.
