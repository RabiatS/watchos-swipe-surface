# Progress

A dated record of what the project looked like at each step, so the shape of
the interface can be seen changing. One folder per session under
`docs/progress/`. Newest first.

## 2026-09-18, later: four modes and a self-describing pad

The card deck is gone. The phone now has four things the Watch can drive,
and the pad labels its edges with what each direction does in the current
mode. The crown scrolls, Double Tap selects, a long press switches mode.
Around it: a welcome sheet, settings, keep-awake, imports that persist, a
privacy manifest, VoiceOver actions and 13 unit tests.

| | |
| --- | --- |
| <img src="docs/progress/2026-09-18-four-modes/hero-four-pads.png" width="420"> | The pad in Reader, Photos, Slides and Prompter. Same five gestures, different meanings, always written on the screen. |
| <img src="docs/progress/2026-09-18-four-modes/phone-reader.png" width="180"> | Reader, after two down flicks and a left: scrolled, then jumped to the next section of the sample recipe. |
| <img src="docs/progress/2026-09-18-four-modes/phone-photos.png" width="180"> | Photos, after a left and an up: second sample photo, starred. |
| <img src="docs/progress/2026-09-18-four-modes/phone-slides.png" width="180"> | Slides, after two lefts and an up: slide three of the sample deck, timer running. |
| <img src="docs/progress/2026-09-18-four-modes/phone-prompter.png" width="180"> | Prompter, after a tap: the script rolling past the reading line. |
| <img src="docs/progress/2026-09-18-four-modes/phone-welcome.png" width="180"> | The welcome sheet, with a live check that the Watch app is installed. |
| <img src="docs/progress/2026-09-18-four-modes/phone-settings.png" width="180"> | Settings. |

Learned today: `simctl launch` leaves the Watch simulator on its clock face
more and more often as a session goes on, and a reboot of the Watch
simulator resets that. Preferences cannot be cleared from outside the app
because the system caches them, hence the `-flickReset` launch argument.

## 2026-09-18: first link

The Watch pad and the phone deck exist and talk to each other on a paired
simulator pair. Six scripted flicks from the Watch (left, left, up, tap, right,
down) landed on the phone in order and left the deck in the expected state:
a starred second card of seven, with the dismissed card recoverable from the
menu.

What the interface is at this point: a bare pad on the Watch with the current
card's name, its position, a connection dot and a send counter; a single card
on the phone with a last-flick readout and a legend; and a log tab.

| | |
| --- | --- |
| <img src="docs/progress/2026-09-18/watch-pad-connected.png" width="180"> | Watch pad, connected, showing the phone's first card. |
| <img src="docs/progress/2026-09-18/watch-pad-flick-left.png" width="180"> | The flash that follows a left flick. Count at the bottom right. |
| <img src="docs/progress/2026-09-18/watch-pad-phone-context.png" width="180"> | After the phone answered: the current card is now starred. |
| <img src="docs/progress/2026-09-18/phone-deck-initial.png" width="180"> | Phone deck before any flick. |
| <img src="docs/progress/2026-09-18/phone-deck-after-six-flicks.png" width="180"> | Phone deck after the six-flick script. |
| <img src="docs/progress/2026-09-18/phone-log.png" width="180"> | The log, with per-flick latency. Simulator numbers, not hardware. |
| <img src="docs/progress/2026-09-18/icon.png" width="180"> | The icon, drawn by `scripts/make-icon.swift`. |

Measured on the simulator: one to two seconds one way, about three seconds
round trip. Hardware numbers are the next thing to record here.

Found and worked around today: `simctl launch` does not forward arguments to
watchOS apps, the system relaunches a terminated Watch app within a second,
and the Watch simulator returns to its clock face after 15 idle seconds.
