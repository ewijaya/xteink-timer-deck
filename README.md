# Timer Deck for XTEINK X4 Pro

Countdowns, stopwatches, and repeatable timer sequences for your XTEINK X4 Pro. Keep a deck of timers for tea, cooking, study sessions, exercise, or anything else you want to time.

**Current version: 0.3.2.** Local automated checks pass; this version still awaits device testing. An earlier version, 0.3.0, has been used on the reader. See the [device checklist](docs/device-checklist.md) for what remains to be checked.

## What you can do

- Save up to **10 countdowns and stopwatches** in one deck.
- Create up to **5 timer chains**, each with up to 10 steps and 9 rounds. One chain can run at a time.
- Start, pause, resume, and reset timers using touch or the side buttons.
- Give timers names and icons so they are easy to find.
- Choose screen flashes and light pulses for completion alerts while the app is open.
- Use an optional timer lockscreen page, subject to the limits below.
- Import and export timer and chain definitions as text files.

The interface follows the reader's system dark mode. Timers and settings save automatically, with a private backup for recovery. The app uses no network connection and requests no permissions.

## Will it notify me while I read?

**Timer Deck cannot notify you while you read a book or use another app.** The countdown still stays correct: the app saves the finish time and checks it when you return. It does not keep running in the background.

For example, start a 10-minute timer, leave for 3 minutes, and reopen it: about 7 minutes remain. Return after the deadline and it shows completion.

| What you are doing | What happens |
| --- | --- |
| Keeping Timer Deck open and visible | It can flash the screen and pulse the light when time is up, if those options are enabled. |
| Reading a book or using another app | No Timer Deck notification. Reopen the app to check the timer. |
| Using Timer Deck as the lockscreen, after leaving the book reader | The optional page can show progress and completion on periodic refreshes. Actual wake timing still needs device testing. |
| Locking while a book is open | The system does not run Timer Deck's lockscreen script or its timed refreshes. Selecting it as the lockscreen does not change this. |

This device has no sound or vibration. Timer Deck alerts you with a screen flash and a light pulse, so keep it where you can see it.

**Stay awake** helps keep Timer Deck visible for countdowns or chains ending within four hours. It uses more battery and cannot prevent manual lock, power-off, or low-battery shutdown. It does not enable background alerts.

## Install

Timer Deck targets the **XTEINK X4 Pro**, InkApp API **2.18**, with a 480 × 800 portrait display. Other devices are not verified.

Download `timerdeck-0.3.2.xtapp` from the [latest release](https://github.com/ewijaya/xteink-timer-deck/releases/latest). No account is needed. You can check the file against the release's `SHA256SUMS`. To build the package yourself, see [Build from source](#build-from-source) below.

1. Copy `timerdeck-0.3.2.xtapp` to the root of the reader's SD card over USB, then eject safely.
2. On the reader, open **All Files**, select the package, and install it.
3. Open **Ink App → Timer Deck**.

If **Ink App** is missing, community guidance is to open **Settings → About** and tap **Model** ten times. See the [installation guide](docs/INSTALL.md) for more details and troubleshooting.

## Start your first timer

1. Tap **New timer** and enter a duration.
2. Tap **Start timer** to begin, or **Save** to keep it ready for later. **More options** lets you choose a name, icon, and alert.
3. Tap a timer row to open its details. Use the toggle on the right to start, pause, or resume it.

For a stopwatch, open **Menu → New stopwatch**. For a sequence such as work followed by rest, open **Chains** and create a chain or choose a template.

The **Down** button highlights the next deck row; **Up** acts on it. In a chain run, **Down** opens the steps and **Up** pauses or resumes. To edit or delete a timer, open its details and choose **Edit**.

## Settings and saved data

Open **Menu → Settings** to adjust alerts, the seconds display, Stay awake, and the optional lockscreen page. **Test alert** tries the enabled alert channels. For dark mode, use the reader's display settings or double-press Home.

To try the lockscreen page, select **Menu → Settings → Lock screen** and accept the system prompt. Community guidance is to keep the reader's **Settings → Display → Off wallpaper** on **Default**. Leave the book reader before locking; the page cannot update while reading. Lockscreen wake timing remains unverified on the device.

Use **Menu → Settings → Data** for import, export, and resetting saved data. Files live in `/AppFiles/timerdeck/`:

- `timerdeck-export.txt`: exported timer and chain definitions.
- `timerdeck-import.txt`: definitions you want to add to the deck.
- `timerdeck-import-result.txt`: the import result.

Imports add saved definitions; they do not restore or start running timers. The [installation guide](docs/INSTALL.md) includes an example file and format limits.

Timers use the device clock, so changing the clock can affect them. A forward change counts as elapsed time; a detected backward change restores values from the last trusted time. Durations can be up to 999 days, 23:59:59, but a countdown cannot end beyond the device clock's January 2038 limit.

## Build from source

The local build uses **Lua 5.5 with 32-bit integers and numbers**, matching the device runtime. A standard Lua installation with 64-bit integers is not a substitute.

Prerequisites:

- Python 3 with Pillow and cryptography.
- `make`, a C compiler, and the development libraries needed for Lua's Linux build.
- DejaVu Sans regular and bold fonts at `/usr/share/fonts/truetype/dejavu/` for previews.
- The Lua 5.5.0 source archive placed at `build/toolchain/lua-5.5.0.tar.gz`.

The setup script verifies the archive's pinned checksum and builds the interpreter with `LUA_32BITS`. Build commands work locally and do not download dependencies.

```sh
make test      # Run lint, Lua suites, resource checks, and preview generation
make preview   # Regenerate local preview images
make icons     # Regenerate the icon assets
make package   # Run checks and build the installable .xtapp package
```

Build outputs:

| Path | Contents |
| --- | --- |
| `dist/timerdeck-0.3.2.xtapp` | Installable package, with an adjacent verification report and `SHA256SUMS`. |
| `build/gate-results.json` | Automated check results. |
| `build/validation-results.json` | Host memory and instruction-count measurements. |
| `build/previews/` | Preview PNGs, drawing records, and contact sheets. |

**All generated previews and simulated results are HOST MOCK, not device evidence.** They use substitute fonts and rendering. Screen refresh behavior, light visibility, touch response, lockscreen wakes, and battery use need checks on the reader.

## Project references

Timer Deck adapts the behavior of Pebble Timer Deck 0.7.0 for the X4 Pro's screen and controls.

- [Installation and file format](docs/INSTALL.md)
- [Device testing checklist](docs/device-checklist.md)
- [Test report](docs/test-report.md)
- [Product requirements](PRD.md) and [0.3.2 changes](docs/prd-0.3.2.md)
- [Design decisions and platform limits](docs/decisions.md)
- [Saved-data format](docs/storage-format.md)

Third-party components retain their license notices: Lucide icons (ISC), the vendored packager and lint tool (MIT), and Lua (MIT). Packager notices are in [tools/vendor/xtpack/NOTICE.md](tools/vendor/xtpack/NOTICE.md).

## License

Timer Deck is released under the [MIT License](LICENSE).
