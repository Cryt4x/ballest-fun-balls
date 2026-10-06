// Fun-Balls: four clear balls, tinted like Clear-Tec-Balls' Clear (models/ball.txt), each with
// something drawn at the ball's middle every frame (Draw shapes don't roll with the ball):
//   * Checkpoint Arrow: an arrow on a stand, turned toward the next checkpoint, with Tesla-coil lightning.
//     The game doesn't say which checkpoint comes next (the host lists them by position, not in track order), so
//     "next" is the nearest one not yet touched this run: touched ones are seen through Race::CurrentCheckpoint, and
//     a new run (RunId) forgets them. With none left (or a track without any) it is red and spins.
//   * Speed Ball: the speed as two digits facing the camera, over a five-bar gauge.
//   * Timer Ball: the run's time in seven-segment digits facing the camera.
//   * Kettle-Ball: a kettle seen from the side; the faster the ball, the more steam out of its spout.
// Speeds are in the game's speedometer's units: cm/s / 50 (fits edd's reading: 50 km/h was ~27 there).

[Setting name="Arrow: Show the arrow" description="Draw the arrow inside the Checkpoint Arrow ball"]
bool Shown = true;

[Setting name="Arrow: Show stand" description="Draw the stand under the arrow"]
bool ShowStand = true;

[Setting name="Arrow: Tilt up and down" description="Point up and down at checkpoints above or below, not only left and right"]
bool Tilt = true;

[Setting name="Arrow: Lightning" description="Small Tesla-coil bolts flicker from the arrow's middle out to the ball"]
bool Lightning = true;

[Setting name="Arrow: Lightning only when moving" description="Lightning only while the ball is fast enough (the setting below)"]
bool OnlyMoving = true;

[Setting name="Arrow: Lightning from speed" min=0 max=150 description="With the setting above on: the speed from which the bolts show, as the game's speedometer shows it"]
float MinSpeed = 20;

[Setting name="Arrow: Bolts" min=1 max=6 description="How many bolts flicker at once"]
int BoltCount = 3;

[Setting name="Speedometer: Show gauge" description="Five bars, rising, under the number that light up, green to red, with the speed"]
bool ShowGauge = true;

[Setting name="Timer: Clock standing on ground" description="The clock stands on its feet at the bottom of the ball instead of floating in the middle"]
bool ClockOnGround = false;

[Setting name="Kettle: Steam" min=0 max=3 description="How much steam for the speed (0.3 is normal)"]
float SteamAmount = 0.3;

import bool AddBall(const string &in, const string &in, const string &in, const string &in, const string &in) from "cosmetic-kit";

const string ARROW_ID = "cryt4x.checkpoint-arrow";
const string SPEED_ID = "cryt4x.speed-ball";
const string KETTLE_ID = "cryt4x.kettle-ball";
const string TIMER_ID = "cryt4x.timer-ball";
const double SPEED_UNIT = 0.02;     // cm/s to the speedometer's number
const double JUMP = 400;            // further than this in one frame is a respawn or restart, not travel

int map = -1;
int frameNumber = 0;
bool arrowOn = false, speedOn = false, kettleOn = false, timerOn = false;     // drawn last frame
uint seed = 12345;
double frameDt = 0;
double lastX, lastY, lastZ;         // the ball last frame
bool haveLast = false;
double velX = 0, velY = 0, velZ = 0;    // smoothed, cm/s
double speed = 0;                   // smoothed, speedometer units

void Main()
{
    string f = Plugins::Folder(), ball = f + "models/ball.txt";
    AddBall(ARROW_ID, "Checkpoint Arrow", "", f + "preview.png", ball);
    AddBall(SPEED_ID, "Speed Ball", "", f + "preview_speed.png", ball);
    AddBall(KETTLE_ID, "Kettle-Ball", "", f + "preview_kettle.png", ball);
    AddBall(TIMER_ID, "Timer Ball", "", f + "preview_timer.png", ball);
}

void Update(float dt)
{
    frameDt = dt;
    if (Host::MapNumber() != map)
    {
        Forget();                   // the map took the shapes with it
        map = Host::MapNumber();
    }
    double x, y, z;
    string worn = Cosmetics::Equipped(Cosmetics::Ball);
    bool onTrack = Race::OnTrack() && !Replay::IsActive() && Race::BallPosition(x, y, z);
    if (onTrack)
        Follow(x, y, z, dt);
    else
        haveLast = false;
    frameNumber++;
    // Each ball's shapes are hidden once when it stops being drawn, not again every frame.
    if (onTrack && worn == ARROW_ID && Shown) { ArrowFrame(x, y, z); arrowOn = true; } else if (arrowOn) { HideArrow(); arrowOn = false; }
    if (onTrack && worn == SPEED_ID) { SpeedFrame(x, y, z); speedOn = true; } else if (speedOn) { HideSpeed(); speedOn = false; }
    if (onTrack && worn == KETTLE_ID) { KettleFrame(x, y, z); kettleOn = true; } else if (kettleOn) { HideKettle(); kettleOn = false; }
    RunClock(dt);
    if (onTrack && worn == TIMER_ID) { TimerFrame(x, y, z); timerOn = true; } else if (timerOn) { HideTimer(); timerOn = false; }   // gone at the finish, as edd wants
}

void Follow(double x, double y, double z, float dt)
{
    if (haveLast && dt > 0)
    {
        double dx = x - lastX, dy = y - lastY, dz = z - lastZ;
        if (dx * dx + dy * dy + dz * dz < JUMP * JUMP)
        {
            double k = 1 - Math::pow(2.718, -12 * dt);
            velX += (dx / dt - velX) * k;
            velY += (dy / dt - velY) * k;
            velZ += (dz / dt - velZ) * k;
        }
        else
            velX = velY = velZ = 0;
    }
    lastX = x; lastY = y; lastZ = z;
    haveLast = true;
    speed = Math::sqrt(velX * velX + velY * velY + velZ * velZ) * SPEED_UNIT;
}

void Forget()
{
    ForgetMark(arrow); ForgetMark(arrowDone); ForgetMark(stand);
    for (int i = 0; i < MOST_BOLTS; i++) { bolts[i].id = 0; bolts[i].shown = false; }
    for (int d = 0; d < 2; d++) ForgetDigit(speedDigits[d]);
    for (int i = 0; i < 5; i++) { ForgetMark(bars[i]); ForgetMark(barsOff[i]); }
    kettle = 0;
    kettleShown = flamesShown = false;
    clock = 0;
    clockShown = false;
    for (int i = 0; i < 6; i++) ForgetDigit(timerDigits[i]);
    for (int i = 0; i < FLAMES; i++) flames[i] = 0;
    puffs.resize(0);
}

double Random()                     // 0..1
{
    seed = seed * 1664525 + 1013904223;
    return double(seed >> 8) / 16777216.0;
}

// --- Checkpoint Arrow ------------------------------------------------------------------------------------------------
Mark arrow, arrowDone, stand;      // arrow_done.txt: the red one, once every checkpoint is touched
double spinYaw = 0;
const double SPIN_SPEED = 120;      // degrees a second

// `mark` (made from `file` when needed) at x, y, z, turned to pitch and yaw (unless `turn` is false); shown only when
// that changes.
void PlaceLevel(Mark@ mark, const string &in file, double x, double y, double z, double pitch, double yaw, bool turn = true)
{
    if (mark.id == 0)
    {
        mark.id = Draw::Model(Plugins::Folder() + file);
        mark.shown = false;
        if (mark.id == 0) return;
    }
    if (!Draw::Move(mark.id, x, y, z))
    {
        ForgetMark(mark);           // its actor is gone: made again next frame
        return;
    }
    if (turn)
        Draw::Turn(mark.id, pitch, yaw, 0);
    if (!mark.shown)
    {
        Draw::Show(mark.id, true);
        mark.shown = true;
    }
}
int run = -1;
array<bool> touched;                // per checkpoint index, this run
array<double> cpX, cpY, cpZ;        // the checkpoints' positions, read once a map
array<bool> cpKnown;
int cpMap = -1;

// Lightning: a few bolt shapes, each a thin glowing tube along a jagged path out along +x from the world's origin,
// are made once (Draw::Tube builds a mesh actor, so making and removing one for every bolt was costly). A bolt is one
// of them shown for a moment, turned to a random direction about the ball's middle and given a random brightness;
// then the same shape is turned somewhere else. Per frame each shown bolt is only moved with the ball.
const double BOLT_REACH = 45;       // cm from the middle: just inside the ball (radius 47.5)
const int MOST_BOLTS = 6;           // the "Arrow: Bolts" setting's top
class Bolt
{
    int id = 0;                     // its shape, made once (0: not yet, or its map is gone)
    bool shown = false;
    double age = 0, life = 0;
}
array<Bolt> bolts(MOST_BOLTS);

void ArrowFrame(double x, double y, double z)
{
    int count = Race::CheckpointCount();
    if (Race::RunId() != run || int(touched.length()) != count)
    {
        run = Race::RunId();
        touched.resize(0);
        touched.resize(count);
    }
    int current = Race::CurrentCheckpoint();
    if (current >= 0 && current < count)
        touched[current] = true;

    // The checkpoints don't move: their positions are read once a map (and again if the count changes).
    if (cpMap != Host::MapNumber() || int(cpX.length()) != count)
    {
        cpMap = Host::MapNumber();
        cpX.resize(count); cpY.resize(count); cpZ.resize(count); cpKnown.resize(count);
        for (int i = 0; i < count; i++)
            cpKnown[i] = Race::CheckpointPosition(i, cpX[i], cpY[i], cpZ[i]);
    }
    int best = -1;
    double bestD = 0, tx = 0, ty = 0, tz = 0;
    for (int i = 0; i < count; i++)
    {
        if (touched[i] || !cpKnown[i])
            continue;                   // touched ones aren't pointed at again
        double cx = cpX[i], cy = cpY[i], cz = cpZ[i];
        double d = (cx - x) * (cx - x) + (cy - y) * (cy - y) + (cz - z) * (cz - z);
        if (best < 0 || d < bestD)
        {
            best = i; bestD = d; tx = cx; ty = cy; tz = cz;
        }
    }
    // Every checkpoint touched, or a track without any: the arrow is red and spins, level.
    bool done = best < 0;
    double yaw, pitch;
    if (done)
    {
        spinYaw = (spinYaw + frameDt * SPIN_SPEED) % 360;
        yaw = spinYaw;
        pitch = 0;
    }
    else
    {
        double dx = tx - x, dy = ty - y, dz = tz - z;
        yaw = Math::atan2(dy, dx) * 57.2958;
        pitch = Tilt ? Math::atan2(dz, Math::sqrt(dx * dx + dy * dy)) * 57.2958 : 0;
    }
    if (ShowStand)
        PlaceLevel(stand, "models/stand.txt", x, y, z, 0, 0, false);    // round and upright: never turned
    else
        HideMark(stand);
    if (done)
    {
        PlaceLevel(arrowDone, "models/arrow_done.txt", x, y, z, pitch, yaw);
        HideMark(arrow);
    }
    else
    {
        PlaceLevel(arrow, "models/arrow.txt", x, y, z, pitch, yaw);
        HideMark(arrowDone);
    }
    Flicker(x, y, z);
}

void HideArrow()
{
    HideMark(arrow);
    HideMark(arrowDone);
    HideMark(stand);
    HideBolts();
}

// The bolts at the ball's middle x, y, z: each lives a moment, then is turned to a new direction.
void Flicker(double x, double y, double z)
{
    int want = Lightning && (speed >= MinSpeed || !OnlyMoving) ? BoltCount : 0;
    for (int i = 0; i < MOST_BOLTS; i++)
    {
        Bolt@ b = bolts[i];
        if (i >= want)
        {
            HideBolt(b);
            continue;
        }
        if (b.id == 0)
        {
            b.id = MakeBolt();
            if (b.id == 0) continue;
            b.age = b.life = 0;     // aim it below
        }
        b.age += frameDt;
        if (b.age >= b.life)        // a new bolt: the same shape in another direction, at another brightness
        {
            b.age = 0;
            b.life = 0.05 + Random() * 0.12;
            Draw::Turn(b.id, Math::asin(Random() * 2 - 1) * 57.2958, Random() * 360, Random() * 360);
            Draw::Glow(b.id, 0.55f, 0.7f, 1.0f, float(4 + Random() * 8));
        }
        if (!Draw::Move(b.id, x, y, z))
        {
            b.id = 0;               // its actor is gone: make it again next frame
            b.shown = false;
            continue;
        }
        if (!b.shown)
        {
            Draw::Show(b.id, true);
            b.shown = true;
        }
    }
}

void HideBolt(Bolt@ b)
{
    if (b.id != 0 && b.shown) Draw::Show(b.id, false);
    b.shown = false;
}

// A bolt shape: a jagged path from near the origin out to BOLT_REACH along +x, zigzagging across it.
int MakeBolt()
{
    array<double> path;
    const int STEPS = 7;
    for (int k = 0; k <= STEPS; k++)
    {
        double t = double(k) / STEPS, d = 6 + t * (BOLT_REACH - 6);     // from just outside the arrow's joint
        double j = (k == 0 || k == STEPS) ? 0 : 5 * t + 1.5;
        path.insertLast(d);
        path.insertLast((Random() * 2 - 1) * j);
        path.insertLast((Random() * 2 - 1) * j);
    }
    return Draw::Tube(path, 0.6, 0.55f, 0.7f, 1.0f, true);
}

void HideBolts()
{
    for (int i = 0; i < MOST_BOLTS; i++)
        HideBolt(bolts[i]);
}

// --- Speed Ball ------------------------------------------------------------------------------------------------------
// Two seven-segment digits facing the camera: each place shows one of ten ready-made digit models (models/digit_0..9.txt,
// made once each when first needed), so a new number only swaps which one is shown. There's no reading of the camera, so which way
// it looks comes from Camera::Project: a point east of the ball and one north of it, and how far right each lands on
// screen, give the camera's right-hand direction.
const double DIGIT_W = 14, DIGIT_H = 26, DIGIT_GAP = 20;    // cm; DIGIT_GAP is between the two digits' middles
// segments a b c d e f g: a top, b top right, c bottom right, d bottom, e bottom left, f top left, g middle
const array<int> DIGITS = {0x3f, 0x06, 0x5b, 0x4f, 0x66, 0x6d, 0x7d, 0x07, 0x7f, 0x6f};
const array<double> SEG_U = {0, 0.5, 0.5, 0, -0.5, -0.5, 0};            // across, in digit widths
const array<double> SEG_V = {0.5, 0.25, -0.25, -0.5, -0.25, 0.25, 0};   // up, in digit heights
double camYaw = 0;

// A shape made once from a model file, moved and turned with the ball, shown and hidden only when that changes.
class Mark
{
    int id = 0;
    bool shown = false;
    double scale = 1;
}

// `mark` (made from `file` when needed, at `scale`) at u across and v up from x, y, z, facing the camera; or hidden.
void PlaceMark(Mark@ mark, const string &in file, bool shown, double x, double y, double z, double rightX,
               double rightY, double u, double v, double scale)
{
    if (!shown)
    {
        HideMark(mark);
        return;
    }
    if (mark.id == 0)
    {
        mark.id = Draw::Model(Plugins::Folder() + file);
        if (mark.id == 0) return;
        mark.shown = false;
        mark.scale = 1;
    }
    if (!Draw::Move(mark.id, x + rightX * u, y + rightY * u, z + v))
    {
        mark.id = 0;                // its actor is gone: made again next frame
        return;
    }
    Draw::Turn(mark.id, 0, camYaw, 0);
    if (mark.scale != scale)
    {
        Draw::Scale(mark.id, scale);
        mark.scale = scale;
    }
    if (!mark.shown)
    {
        Draw::Show(mark.id, true);
        mark.shown = true;
    }
}

void HideMark(Mark@ mark)
{
    if (mark.id != 0 && mark.shown) Draw::Show(mark.id, false);
    mark.shown = false;
}

void ForgetMark(Mark@ mark)
{
    mark.id = 0;
    mark.shown = false;
}

// One place of a number: the ten digit models, at most one shown.
class DigitPlace
{
    array<Mark> forms(10);
    int digit = -1;                 // shown (-1: none)
}

// Place `p` showing `digit` (-1: nothing) at u, v.
void PlaceDigit(DigitPlace@ p, int digit, double x, double y, double z, double rightX, double rightY, double u, double v,
                double scale)
{
    if (digit != p.digit && p.digit >= 0)
        HideMark(p.forms[p.digit]);
    p.digit = digit;
    if (digit >= 0)
        PlaceMark(p.forms[digit], "models/digit_" + digit + ".txt", true, x, y, z, rightX, rightY, u, v, scale);
}

void HideDigit(DigitPlace@ p)
{
    if (p.digit >= 0) HideMark(p.forms[p.digit]);
    p.digit = -1;
}

void ForgetDigit(DigitPlace@ p)
{
    for (int i = 0; i < 10; i++) ForgetMark(p.forms[i]);
    p.digit = -1;
}

array<DigitPlace> speedDigits(2);
// The gauge: five bars side by side under the number, the same width, each higher than the last, their middles on one
// line (models/bar_1..5.txt lit, bar_1..5_off.txt grey; Draw::Glow doesn't recolour a model's glow). Grey until the
// speed reaches theirs, then lit in their own colour (green to red).
const array<double> BAR_FROM = {1, 15, 30, 45, 59};             // speedometer units
const array<double> BAR_U = {-18, -9, 0, 9, 18};                 // across, cm from the middle (7 wide, 2 apart)
const double BAR_V = -22;                                        // the line through their middles
const double NUM_U = 0, NUM_V = 8;      // where the number goes with the gauge on
array<Mark> bars(5), barsOff(5);

void SpeedFrame(double x, double y, double z)
{
    LookCamera(x, y, z);
    double yr = camYaw / 57.2958;
    double rightX = -Math::sin(yr), rightY = Math::cos(yr);    // to the camera's right
    int n = int(speed + 0.5);
    if (n > 99) n = 99;
    for (int d = 0; d < 2; d++)
    {
        int digit = d == 0 ? (n < 10 ? -1 : n / 10) : n % 10;      // no leading zero
        double offset = n < 10 ? 0 : (d == 0 ? -0.5 : 0.5) * DIGIT_GAP;     // one digit sits in the middle
        double up = 0;
        if (ShowGauge) { offset += NUM_U; up = NUM_V; }
        PlaceDigit(speedDigits[d], digit, x, y, z, rightX, rightY, offset, up, 1);
    }
    Gauge(x, y, z, rightX, rightY);
}

void Gauge(double x, double y, double z, double rightX, double rightY)
{
    for (int i = 0; i < 5; i++)
    {
        bool lit = speed >= BAR_FROM[i];
        PlaceMark(bars[i], "models/bar_" + (i + 1) + ".txt", ShowGauge && lit, x, y, z, rightX, rightY, BAR_U[i], BAR_V, 1);
        PlaceMark(barsOff[i], "models/bar_" + (i + 1) + "_off.txt", ShowGauge && !lit, x, y, z, rightX, rightY, BAR_U[i], BAR_V, 1);
    }
}

// camYaw: the way the camera looks (degrees), from where a point east and one north of x, y, z land on screen.
void LookCamera(double x, double y, double z)
{
    float sx, sy, ex, ey, nx, ny;
    if (Camera::Project(x, y, z, sx, sy) && Camera::Project(x + 100, y, z, ex, ey) && Camera::Project(x, y + 100, z, nx, ny))
    {
        double rx = ex - sx, ry = nx - sx;     // the camera's right, in world x and y
        if (rx * rx + ry * ry > 0.0001)
            camYaw = Math::atan2(ry, rx) * 57.2958 - 90;
    }
}

void HideSpeed()
{
    for (int d = 0; d < 2; d++) HideDigit(speedDigits[d]);
    for (int i = 0; i < 5; i++) { HideMark(bars[i]); HideMark(barsOff[i]); }
}

// --- Kettle-Ball ------------------------------------------------------------------------------------------------------
// A kettle (models/kettle.txt, spout along +x) seen from the side: its spout to the camera's left, whichever way the
// ball goes. Steam: small white puffs out of the spout's tip, more the faster the ball. They rise, and at the ball's
// wall they can't get out: they slide along it up to the top, as if shut in, gather there and fade.
const double SPOUT_X = 27, SPOUT_Z = -18;   // the spout's tip in the kettle's coordinates (cm)
const int MOST_PUFFS = 40;
const double PUFF_RADIUS = 3.6;
const double WALL = 45;            // the inside of the ball's wall (cm from the middle)
class Puff
{
    int id = 0;
    bool alive = false, shown = false;
    double x = 0, y = 0, z = 0;     // from the ball's middle
    double vx = 0, vy = 0, vz = 0;
    double age = 0, life = 0;
}
array<Puff> puffs;
int kettle = 0;
bool kettleShown = false, flamesShown = false;
double kettleYaw = 0;
// Flames: a ring of small flames (models/flame.txt) around the kettle's foot, leaning out of its sides, each
// flickering on its own.
const int FLAMES = 14;
const double FLAME_RING = 16, FLAME_Z = -42, FLAME_LEAN = 25;   // cm from the middle, their foot, degrees outward
array<int> flames(FLAMES);
array<double> flameSize(FLAMES, 1);
double steamDue = 0;                // puffs owed (fractions carry over)

void KettleFrame(double x, double y, double z)
{
    LookCamera(x, y, z);
    kettleYaw = camYaw - 90;        // seen from the side, its spout to the left
    if (kettle == 0)
        kettle = Draw::Model(Plugins::Folder() + "models/kettle.txt");
    if (kettle != 0)
    {
        if (Draw::Move(kettle, x, y, z))
        {
            Draw::Turn(kettle, 0, kettleYaw, 0);
            if (!kettleShown) { Draw::Show(kettle, true); kettleShown = true; }
        }
        else
        {
            kettle = 0;             // its actor is gone
            kettleShown = false;
        }
    }
    Flames(x, y, z);
    Steam(x, y, z);
}

void Steam(double x, double y, double z)
{
    if (puffs.length() == 0)
        puffs.resize(MOST_PUFFS);
    double yr = kettleYaw / 57.2958, fx = Math::cos(yr), fy = Math::sin(yr);
    steamDue += frameDt * speed * 1.2 * SteamAmount;      // puffs a second: 1.2 per speedometer unit
    if (steamDue > 5) steamDue = 5;
    for (uint i = 0; i < puffs.length() && steamDue >= 1; i++)
    {
        Puff@ p = puffs[i];
        if (p.alive) continue;
        steamDue -= 1;
        p.alive = true;
        p.age = 0;
        p.life = 2.2 + Random() * 1.3;
        p.x = fx * SPOUT_X; p.y = fy * SPOUT_X; p.z = SPOUT_Z;
        double push = 40 + speed * 1.5, side = (Random() * 2 - 1) * 12;
        p.vx = fx * push - fy * side;
        p.vy = fy * push + fx * side;
        p.vz = 25 + Random() * 20;
    }
    for (uint i = 0; i < puffs.length(); i++)
    {
        Puff@ p = puffs[i];
        if (!p.alive)
            continue;
        p.age += frameDt;
        double t = p.age / p.life, grow = 1 + t * 1.4;
        double drag = Math::pow(0.4, frameDt);     // the push out of the spout dies down
        p.vx *= drag; p.vy *= drag;
        p.vz += 70 * frameDt;                      // steam rises
        if (p.vz > 60) p.vz = 60;
        p.x += p.vx * frameDt; p.y += p.vy * frameDt; p.z += p.vz * frameDt;
        // At the wall: back onto it, and only the part of the motion along it is kept, so it slides up the wall.
        double r = Math::sqrt(p.x * p.x + p.y * p.y + p.z * p.z), most = WALL - PUFF_RADIUS * grow;
        if (r > most && r > 0.001)
        {
            double nx = p.x / r, ny = p.y / r, nz = p.z / r;
            p.x = nx * most; p.y = ny * most; p.z = nz * most;
            double away = p.vx * nx + p.vy * ny + p.vz * nz;
            if (away > 0) { p.vx -= away * nx; p.vy -= away * ny; p.vz -= away * nz; }
        }
        if (t >= 1)                                // faded
        {
            p.alive = false;
            HidePuff(p);
            continue;
        }
        if (p.id == 0)
        {
            p.id = Draw::Ball(PUFF_RADIUS, 0.95f, 0.95f, 1.0f);
            p.shown = false;
        }
        if (p.id == 0) continue;
        if (!Draw::Move(p.id, x + p.x, y + p.y, z + p.z))
        {
            p.id = 0;
            continue;
        }
        // size and fading change slowly: every third frame is enough (the puffs take turns), and on its first
        if (!p.shown || (frameNumber + int(i)) % 3 == 0)
        {
            Draw::Scale(p.id, grow);
            Draw::Fade(p.id, float(t < 0.6 ? 0.8 : 0.8 * (1 - t) / 0.4));
        }
        if (!p.shown)
        {
            Draw::Show(p.id, true);
            p.shown = true;
        }
    }
}

void Flames(double x, double y, double z)
{
    for (int i = 0; i < FLAMES; i++)
    {
        double a = 6.28318 * i / FLAMES;
        if (flames[i] == 0)
        {
            flames[i] = Draw::Model(Plugins::Folder() + "models/flame.txt");
            if (flames[i] == 0) continue;
            Draw::Turn(flames[i], -FLAME_LEAN, a * 57.2958, 0);   // leaning out, away from the kettle: once
            if (flamesShown) Draw::Show(flames[i], true);
        }
        if (!Draw::Move(flames[i], x + Math::cos(a) * FLAME_RING, y + Math::sin(a) * FLAME_RING, z + FLAME_Z))
        {
            flames[i] = 0;
            continue;
        }
        // flicker: toward a new random size, quickly; every second frame (the flames take turns)
        if ((frameNumber + i) % 2 == 0)
        {
            double goal = 0.6 + Random() * 0.8, k = 1 - Math::pow(2.718, -36 * frameDt);
            flameSize[i] += (goal - flameSize[i]) * k;
            Draw::Scale(flames[i], flameSize[i]);
        }
    }
    if (!flamesShown)
    {
        for (int i = 0; i < FLAMES; i++)
            if (flames[i] != 0) Draw::Show(flames[i], true);
        flamesShown = true;
    }
}

void HidePuff(Puff@ p)
{
    if (p.id != 0 && p.shown) Draw::Show(p.id, false);
    p.shown = false;
}

void HideKettle()
{
    if (kettle != 0) Draw::Show(kettle, false);
    kettleShown = false;
    for (int i = 0; i < FLAMES; i++)
        if (flames[i] != 0) Draw::Show(flames[i], false);
    flamesShown = false;
    for (uint i = 0; i < puffs.length(); i++)
    {
        puffs[i].alive = false;
        HidePuff(puffs[i]);
    }
    steamDue = 0;
}

// --- Timer Ball ------------------------------------------------------------------------------------------------------
// The run's time as "MM:SS.hh" in the Speed Ball's digit models (smaller), in a 3D digital clock (models/clock.txt: a
// grey case, black behind the digits, a red rim at the front; its ':' and '.' are part of it), all facing the camera. Plugins can't read the game's own timer, so the plugin keeps one: from 0 at each new run (RunId),
// counting while the race is on (IsActive) and not paused, so it stands still at the finish. It can differ a little
// from the game's.
const double T_SCALE = 0.48;               // of the Speed Ball's digits
const double CLOCK_GROUND = -30.6;         // cm down from the middle when standing: its feet on the ball's bottom
const double CLOCK_GROUND_SIZE = 0.8;      // and smaller there, where the ball is narrower
const double CLOCK_FRONT = 9.5;             // cm toward the camera from the ball's middle: the digits, on the face
array<DigitPlace> timerDigits(6);
// the six digits' places across the face, cm from its middle: MM, then SS after the ':', then hh after the '.'
const array<double> TIMER_U = {-27.5, -18.5, -4.5, 4.5, 18.5, 27.5};
int clock = 0;
bool clockShown = false;
double clockScale = 1;
double runClock = 0;
int clockRun = -1;

// Counts while the race runs: the game turns IsActive off at the finish, so the time stands still there. IsComplete
// isn't asked: it can stay on into the next run, which then never counted (edd, 2026-10-06).
void RunClock(float dt)
{
    if (!Race::OnTrack()) return;
    if (Race::RunId() != clockRun)
    {
        clockRun = Race::RunId();
        runClock = 0;
    }
    if (Race::IsActive() && !Race::IsPaused())
        runClock += dt;
}

void TimerFrame(double x, double y, double z)
{
    LookCamera(x, y, z);
    double yr = camYaw / 57.2958;
    double rightX = -Math::sin(yr), rightY = Math::cos(yr);
    double size = ClockOnGround ? CLOCK_GROUND_SIZE : 1;
    double towardX = -Math::cos(yr) * CLOCK_FRONT * size, towardY = -Math::sin(yr) * CLOCK_FRONT * size;   // to the camera
    if (ClockOnGround)
        z += CLOCK_GROUND;
    if (clock == 0)
    {
        clock = Draw::Model(Plugins::Folder() + "models/clock.txt");
        clockShown = false;
        clockScale = 1;
    }
    if (clock != 0)
    {
        if (Draw::Move(clock, x, y, z))
        {
            Draw::Turn(clock, 0, camYaw, 0);
            if (clockScale != size) { Draw::Scale(clock, size); clockScale = size; }
            if (!clockShown) { Draw::Show(clock, true); clockShown = true; }
        }
        else
        {
            clock = 0;
            clockShown = false;
        }
    }
    double fx = x + towardX, fy = y + towardY;      // the face
    double t = runClock > 5999.99 ? 5999.99 : runClock;
    int hundredths = int(t * 100);
    array<int> digits = {hundredths / 60000, (hundredths / 6000) % 10, (hundredths / 1000) % 6, (hundredths / 100) % 10,
                         (hundredths / 10) % 10, hundredths % 10};
    for (int i = 0; i < 6; i++)
        PlaceDigit(timerDigits[i], digits[i], fx, fy, z, rightX, rightY, TIMER_U[i] * size, 0, T_SCALE * size);
}

void HideTimer()
{
    if (clock != 0 && clockShown) Draw::Show(clock, false);
    clockShown = false;
    for (int i = 0; i < 6; i++) HideDigit(timerDigits[i]);
}
