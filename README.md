# Fun-Balls

A Ballest plugin by CryT4x that adds four clear balls (tinted light blue like Clear-Tec-Balls' Clear, opacity 0.2) with something inside.
Needs Cosmetic Kit and host 0.23.4 or newer.
Pick the balls on the Customize page.

## Balls

- **Checkpoint Arrow**: An arrow on a stand that always points to the next checkpoint,
  with small Tesla-coil lightning flickering from its middle out to the ball.
  The arrow points at the nearest one not yet touched this run.
  When all are touched, or the track has none, the arrow is red and spins.
- **Speed Ball**: The speed as a two-digit number (seven-segment style) that always faces the camera, in the
  same units as the game's speedometer. Under it a gauge of five bars side by side. Each lit in its own colour
  (green to red) from 1, 15, 30, 45 and 59.
- **Timer Ball**: The run's time as "MM:SS.hh" in a 3D digital clock.
  The plugin times the run itself; it can differ a little from the game's.
- **Kettle-Ball**: A kettle seen from the side with small flickering flames coming out around its foot; The faster the ball goes, the more steam comes out of its spout.

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
| Kettle: Steam | 0.3 | How much steam for the speed (0-3) |

## Notes

- Everything inside is drawn around the ball's middle each frame and doesn't roll with the ball.
- Only visible while playing on maps
- The checkpoints' positions are read once a map.
- The lightning reuses a few bolt shapes made once, only turning them to new directions, so it costs little. The kettle's
  steam (40 puffs) and flames are made once too, and change size and fading only every few frames. The numbers are ready-made digit models, one
  shown per place.
