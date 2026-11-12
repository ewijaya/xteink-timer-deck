# Local installation

Candidate **0.3.0 is host-validated only**. Installation and every device check are Not run. The encrypted package is built with the pinned community packager; its decrypted content is compared byte-for-byte with the sources.

1. Copy `dist/timerdeck-0.3.0.xtapp` to the SD-card root over USB and eject safely.
2. On the reader open All Files, tap the package, then install.
3. If Ink App is absent: Settings → About → tap Model ten times (community guidance).
4. Open Ink App → Timer Deck. Menu → Help / About, then tap the title seven times to open Device information. Photograph its pages for DV01.

New timer opens the keypad. Start timer starts immediately; Save adds a Ready timer; More options sets name, icon and alert. Tap a deck row for detail, or its right-hand toggle to start/pause/resume. Swipe left to reveal Delete/Keep. Down highlights the next row; Up acts. Chain run: Down opens steps, Up pauses/resumes. Lists page by swiping vertically or moving the key highlight.

The Chains button opens saved sequences. New chain offers an empty draft, Deck copies and three templates. Copies take configured durations, never remaining time. Start snapshots the sequence. Skip and Restart step act immediately; Stop asks for confirmation. Only one chain runs at once.

Menu → Settings → Lock screen asks the system to select Timer Deck. Keep Settings → Display → Off wallpaper on **Default** (community guidance). Turning the setting off gives back the previous lockscreen. The page is read-only, silent, and requests 30–3600 second intervals; actual firmware behavior remains V05/V06. The power key ends the foreground session regardless of Stay awake.

File sync: open Menu → Settings → Import and export to create `/AppFiles/timerdeck/`. Put `timerdeck-import.txt` there over USB. Import file adds Ready definitions atomically; `timerdeck-import-result.txt` contains the outcome. Export deck writes `timerdeck-export.txt`, which can be renamed and imported into an empty deck. The app never edits or removes the input file.

```text
# kind | name | duration | icon | alert | count
timer | Tea | 4:00 | Coffee | Short + short | 3
stopwatch | Run | Run
chain | Practice | 1 | Music
step | Scales | 5:00 | Music | Short
step | Piece | 20:00
```

Durations accept seconds, MM:SS, H:MM:SS, or ordered units such as `1d 2h 3m 4s`. Names use at most 16 printable ASCII characters, excluding backslash and pipe. Keywords and icon/pattern names ignore case. Icons accept 0–30; patterns 0–3; counts 1–5; rounds 1–9. Blank/comment lines are ignored. Limits are 16,384 bytes and 80 lines (documented D17 correction). One invalid line or insufficient capacity rejects the entire file. The last four digest/length receipts prevent duplicate imports. No clock is needed because imports never start anything.

Reinstalling the same app_id preserves data by contract; DV14 verifies this on the owner's firmware. Uninstalling deletes private state/backup but preserves `/AppFiles/timerdeck/`. Reset saved data asks for confirmation, removes timers/chains/settings/receipts and the private backup, and releases keep-awake. It leaves user-visible files intact.

If installation fails, record firmware and the exact error in the device checklist. The manifest's community `lockscreen.enabled` field is the first documented compatibility candidate. The packager supports `--image` for an owner's local flash dump if keys change. No Studio upload or network action is authorized by these instructions.

Host previews use substitute fonts and Pillow geometry. They prove layout and draw-command behavior, not refresh latency, touch feel, light visibility, ghosting or battery life. Use DV01–DV15 to record those results before calling this device-validated.
