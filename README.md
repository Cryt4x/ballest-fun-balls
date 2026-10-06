# Fun-Balls

A Ballest plugin by CryT4x that adds four clear balls (tinted light blue like Clear-Tec-Balls' Clear, opacity 0.2) with something inside.
Needs [Cosmetic Kit](https://github.com/AnythingGoes-ballest/ballest-plugin-manager) and host 0.20.0 or newer.
Pick the balls on the Customize page.

## Balls

- **Checkpoint Arrow**: a yellow cartoon arrow (black outline) on a stand that always points to the next checkpoint,
  with small Tesla-coil lightning flickering from its middle out to the ball.
  The game doesn't tell which checkpoint comes next, so the arrow points at the nearest one not yet touched this run;
  a restart starts over. When all are touched (or the track has none) the arrow hides.
- **Speed Ball**: the speed as a two-digit number (seven-segment style, up to 99) that always faces the camera, in the
  same units as the game's speedometer. Under it a gauge of five bars side by side, each higher than the last: grey at 0, each lit in its own colour
  (green to red) from 1, 15, 30, 45 and 59.
- **Timer Ball**: the run's time as "MM:SS.hh" in a 3D digital clock facing the camera: a grey
  case half as deep as it is high, black behind the digits, a red rim at the front, small red feet and an ON/OFF rocker switch on top, half as wide as the clock.
  Plugins can't read the game's own timer, so the plugin times the run itself (from each new run, while the race
  is on and not paused, stopping at the finish); it can differ a little from the game's.
- **Kettle-Ball**: a kettle seen from the side, its spout to the left, with 14 small flickering flames coming out around its foot; the faster the ball goes, the more steam comes out of its spout. The steam is shut in: it rises and slides along the ball's wall up to the top.

## Settings

Each setting's name starts with the ball it belongs to (Arrow, Speedometer, Timer, Kettle).

| Setting | Default | What it does |
|---|---|---|
| Arrow: Show the arrow | on | Draw the arrow in the Checkpoint Arrow ball |
| Arrow: Show stand | on | Draw the stand under the arrow |
| Arrow: Tilt up and down | on | The arrow also points up and down at checkpoints above or below |
| Arrow: Lightning | on | Tesla-coil bolts in the Checkpoint Arrow ball |
| Arrow: Lightning only when moving | on | Bolts only from the speed below |
| Arrow: Lightning from speed | 20 | That speed, as the speedometer shows it (0-150) |
| Arrow: Bolts | 3 | How many bolts at once (1-6) |
| Speedometer: Show gauge | on | The five-bar gauge under the number |
| Timer: Clock standing on ground | off | The clock stands on its feet at the bottom of the ball (a little smaller) instead of floating in the middle |
| Kettle: Steam | 1 | How much steam for the speed (0-3) |

## Files

- `main.as`: the plugin
- `models/ball.txt`: the tinted ball
- `models/arrow.txt`, `models/stand.txt`: arrow and stand
- `models/seg_h.txt`, `models/seg_v.txt`: segments of the speed digits
- `models/bar_1.txt` .. `bar_5.txt`, `bar_1_off.txt` .. `bar_5_off.txt`: the speed gauge's bars, lit and grey
- `models/clock.txt`, `models/dot.txt`: the timer's clock and its dots (for . and :)
- `models/kettle.txt`, `models/flame.txt`: the kettle and one of its flames
- `preview*.png`: the balls' pictures on the Customize page (screenshots from the game)
- `icon.png`: the plugin's icon (the Speed Ball's picture)

## Notes

- Everything inside is drawn around the ball's middle each frame and doesn't roll with the ball.
- Replays and ghosts don't show it, only your own ball.
