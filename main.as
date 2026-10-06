// Fun-Balls: four clear balls, tinted like Clear-Tec-Balls' Clear (models/ball.txt), each with
// something drawn at the ball's middle every frame (Draw shapes don't roll with the ball):
//   * Checkpoint Arrow: an arrow on a stand, turned toward the next checkpoint, with Tesla-coil lightning.
//     The game doesn't say which checkpoint comes next (the host lists them by position, not in track order), so
//     "next" is the nearest one not yet touched this run: touched ones are seen through Race::CurrentCheckpoint, and
//     a new run (RunId) forgets them. With none left (or a track without checkpoints) the arrow hides.
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

[Setting name="Kettle: Steam" min=0 max=3 description="How much steam for the speed (1 is normal)"]
float SteamAmount = 1;

import bool AddBall(const string &in, const string &in, const string &in, const string &in, const string &in) from "cosmetic-kit";

const string ARROW_ID = "cryt4x.checkpoint-arrow";
const string SPEED_ID = "cryt4x.speed-ball";
const string KETTLE_ID = "cryt4x.kettle-ball";
const string TIMER_ID = "cryt4x.timer-ball";
const double SPEED_UNIT = 0.02;     // cm/s to the speedometer's number
const double JUMP = 400;            // further than this in one frame is a respawn or restart, not travel

int map = -1;
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
    if (onTrack && worn == ARROW_ID && Shown) ArrowFrame(x, y, z); else HideArrow();
    if (onTrack && worn == SPEED_ID) SpeedFrame(x, y, z); else HideSpeed();
    if (onTrack && worn == KETTLE_ID) KettleFrame(x, y, z); else HideKettle();
    RunClock(dt, onTrack);
    if (onTrack && worn == TIMER_ID) TimerFrame(x, y, z); else HideTimer();
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
    arrow = 0; stand = 0;
    bolts.resize(0);
    for (uint i = 0; i < segs.length(); i++) segs[i] = 0;
    for (uint i = 0; i < bars.length(); i++) { bars[i] = 0; barsOff[i] = 0; }
    kettle = 0;
    clock = 0;
    for (uint i = 0; i < timerSegs.length(); i++) timerSegs[i] = 0;
    for (uint i = 0; i < timerDots.length(); i++) timerDots[i] = 0;
    for (int i = 0; i < FLAMES; i++) flames[i] = 0;
    puffs.resize(0);
}

double Random()                     // 0..1
{
    seed = seed * 1664525 + 1013904223;
    return double(seed >> 8) / 16777216.0;
}

// --- Checkpoint Arrow ------------------------------------------------------------------------------------------------
int arrow = 0, stand = 0;
int run = -1;
array<bool> touched;                // per checkpoint index, this run

// Lightning: each bolt is a thin glowing tube along a jagged path from the ball's middle to its inside wall, made
// around the world's origin and moved to the ball each frame. It lives a moment, flickering, and a new one is made in
// another direction when it's gone.
const double BOLT_REACH = 45;       // cm from the middle: just inside the ball (radius 47.5)
class Bolt
{
    int id = 0;
    double age = 0, life = 0;
}
array<Bolt> bolts;

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

    int best = -1;
    double bestD = 0, tx = 0, ty = 0, tz = 0;
    for (int i = 0; i < count; i++)
    {
        double cx, cy, cz;
        if (touched[i] || !Race::CheckpointPosition(i, cx, cy, cz))
            continue;
        double d = (cx - x) * (cx - x) + (cy - y) * (cy - y) + (cz - z) * (cz - z);
        if (best < 0 || d < bestD)
        {
            best = i; bestD = d; tx = cx; ty = cy; tz = cz;
        }
    }
    if (best < 0)
    {
        HideArrow();
        return;
    }
    double dx = tx - x, dy = ty - y, dz = tz - z;
    double yaw = Math::atan2(dy, dx) * 57.2958;
    double pitch = Tilt ? Math::atan2(dz, Math::sqrt(dx * dx + dy * dy)) * 57.2958 : 0;

    if (arrow == 0)
        arrow = Draw::Model(Plugins::Folder() + "models/arrow.txt");
    if (stand == 0 && ShowStand)
        stand = Draw::Model(Plugins::Folder() + "models/stand.txt");
    if (arrow == 0)
        return;
    if (stand != 0)
    {
        if (!ShowStand)
            Draw::Show(stand, false);
        else if (Draw::Move(stand, x, y, z))
            Draw::Show(stand, true);
        else
            stand = 0;
    }
    if (!Draw::Move(arrow, x, y, z))
    {
        arrow = 0;                  // its actor is gone: make a new one next frame
        return;
    }
    Draw::Turn(arrow, pitch, yaw, 0);
    Draw::Show(arrow, true);
    Flicker(x, y, z);
}

void HideArrow()
{
    if (arrow != 0) Draw::Show(arrow, false);
    if (stand != 0) Draw::Show(stand, false);
    RemoveBolts();
}

// The bolts at the ball's middle x, y, z: older ones go, new ones come.
void Flicker(double x, double y, double z)
{
    int want = Lightning && (speed >= MinSpeed || !OnlyMoving) ? BoltCount : 0;
    while (int(bolts.length()) > want)
    {
        if (bolts[bolts.length() - 1].id != 0) Draw::Remove(bolts[bolts.length() - 1].id);
        bolts.removeLast();
    }
    while (int(bolts.length()) < want)
        bolts.insertLast(Bolt());
    for (uint i = 0; i < bolts.length(); i++)
    {
        Bolt@ b = bolts[i];
        b.age += frameDt;
        if (b.id == 0 || b.age >= b.life)
        {
            if (b.id != 0) Draw::Remove(b.id);
            b.id = MakeBolt();
            b.age = 0;
            b.life = 0.05 + Random() * 0.12;
        }
        if (b.id == 0) continue;
        Draw::Move(b.id, x, y, z);
        Draw::Glow(b.id, 0.55f, 0.7f, 1.0f, float(4 + Random() * 8));
        Draw::Show(b.id, true);
    }
}

// A jagged path from the origin out to BOLT_REACH in a random direction.
int MakeBolt()
{
    double dz = Random() * 2 - 1, a = Random() * 6.28318;
    double s = Math::sqrt(1 - dz * dz), dx = s * Math::cos(a), dy = s * Math::sin(a);
    // two directions across the bolt, for its zigzag
    double ux = -dy, uy = dx, uz = 0;
    double ul = Math::sqrt(ux * ux + uy * uy);
    if (ul < 0.01) { ux = 1; uy = 0; ul = 1; }
    ux /= ul; uy /= ul;
    double vx = dy * uz - dz * uy, vy = dz * ux - dx * uz, vz = dx * uy - dy * ux;
    array<double> path;
    const int STEPS = 7;
    for (int k = 0; k <= STEPS; k++)
    {
        double t = double(k) / STEPS, d = 6 + t * (BOLT_REACH - 6);     // from just outside the arrow's joint
        double j = (k == 0 || k == STEPS) ? 0 : 5 * t + 1.5;
        double p = (Random() * 2 - 1) * j, q = (Random() * 2 - 1) * j;
        path.insertLast(dx * d + ux * p + vx * q);
        path.insertLast(dy * d + uy * p + vy * q);
        path.insertLast(dz * d + uz * p + vz * q);
    }
    return Draw::Tube(path, 0.6, 0.55f, 0.7f, 1.0f, true);
}

void RemoveBolts()
{
    for (uint i = 0; i < bolts.length(); i++)
        if (bolts[i].id != 0) Draw::Remove(bolts[i].id);
    bolts.resize(0);
}

// --- Speed Ball ------------------------------------------------------------------------------------------------------
// Two seven-segment digits facing the camera. Each digit's seven segments are shapes of their own (models/seg_h.txt
// lying, models/seg_v.txt standing), shown or hidden for the number. There's no reading of the camera, so which way
// it looks comes from Camera::Project: a point east of the ball and one north of it, and how far right each lands on
// screen, give the camera's right-hand direction.
const double DIGIT_W = 14, DIGIT_H = 26, DIGIT_GAP = 20;    // cm; DIGIT_GAP is between the two digits' middles
// segments a b c d e f g: a top, b top right, c bottom right, d bottom, e bottom left, f top left, g middle
const array<int> DIGITS = {0x3f, 0x06, 0x5b, 0x4f, 0x66, 0x6d, 0x7d, 0x07, 0x7f, 0x6f};
const array<double> SEG_U = {0, 0.5, 0.5, 0, -0.5, -0.5, 0};            // across, in digit widths
const array<double> SEG_V = {0.5, 0.25, -0.25, -0.5, -0.25, 0.25, 0};   // up, in digit heights
array<int> segs(14);
double camYaw = 0;
// The gauge: five bars side by side under the number, the same width, each higher than the last, their middles on one
// line (models/bar_1..5.txt lit, bar_1..5_off.txt grey; Draw::Glow doesn't recolour a model's glow). Grey until the
// speed reaches theirs, then lit in their own colour (green to red).
const array<double> BAR_FROM = {1, 15, 30, 45, 59};             // speedometer units
const array<double> BAR_U = {-18, -9, 0, 9, 18};                 // across, cm from the middle (7 wide, 2 apart)
const double BAR_V = -22;                                        // the line through their middles
const double NUM_U = 0, NUM_V = 8;      // where the number goes with the gauge on
array<int> bars(5), barsOff(5);

void SpeedFrame(double x, double y, double z)
{
    LookCamera(x, y, z);
    double yr = camYaw / 57.2958;
    double rightX = -Math::sin(yr), rightY = Math::cos(yr);    // to the camera's right
    int n = int(speed + 0.5);
    if (n > 99) n = 99;
    for (int d = 0; d < 2; d++)
    {
        int digit = d == 0 ? n / 10 : n % 10;
        int bits = (d == 0 && digit == 0) ? 0 : DIGITS[digit];    // no leading zero
        double offset = n < 10 ? 0 : (d == 0 ? -0.5 : 0.5) * DIGIT_GAP;     // one digit sits in the middle
        double up = 0;
        if (ShowGauge) { offset += NUM_U; up = NUM_V; }
        for (int s = 0; s < 7; s++)
        {
            int k = d * 7 + s;
            bool on = (bits & (1 << s)) != 0;
            if (segs[k] == 0)
            {
                if (!on) continue;
                bool lying = s == 0 || s == 3 || s == 6;
                segs[k] = Draw::Model(Plugins::Folder() + (lying ? "models/seg_h.txt" : "models/seg_v.txt"));
                if (segs[k] == 0) continue;
            }
            if (!on)
            {
                Draw::Show(segs[k], false);
                continue;
            }
            double u = offset + SEG_U[s] * DIGIT_W, v = up + SEG_V[s] * DIGIT_H;
            if (!Draw::Move(segs[k], x + rightX * u, y + rightY * u, z + v))
            {
                segs[k] = 0;
                continue;
            }
            Draw::Turn(segs[k], 0, camYaw, 0);
            Draw::Show(segs[k], true);
        }
    }
    Gauge(x, y, z, rightX, rightY);
}

void Gauge(double x, double y, double z, double rightX, double rightY)
{
    for (int i = 0; i < 5; i++)
    {
        bool lit = speed >= BAR_FROM[i];
        if (!ShowGauge)
            lit = false;
        bars[i] = PlaceBar(bars[i], "models/bar_" + (i + 1) + ".txt", ShowGauge && lit, i, x, y, z, rightX, rightY);
        barsOff[i] = PlaceBar(barsOff[i], "models/bar_" + (i + 1) + "_off.txt", ShowGauge && !lit, i, x, y, z, rightX, rightY);
    }
}

// Bar i's shape `id` (made from `file` when needed) shown in its place, or hidden. Returns its id (0: gone).
int PlaceBar(int id, const string &in file, bool shown, int i, double x, double y, double z, double rightX, double rightY)
{
    if (!shown)
    {
        if (id != 0) Draw::Show(id, false);
        return id;
    }
    if (id == 0)
        id = Draw::Model(Plugins::Folder() + file);
    if (id == 0) return 0;
    if (!Draw::Move(id, x + rightX * BAR_U[i], y + rightY * BAR_U[i], z + BAR_V))
    {
        return 0;
    }
    Draw::Turn(id, 0, camYaw, 0);
    Draw::Show(id, true);
    return id;
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
    for (uint i = 0; i < segs.length(); i++)
        if (segs[i] != 0) Draw::Show(segs[i], false);
    for (uint i = 0; i < bars.length(); i++)
    {
        if (bars[i] != 0) Draw::Show(bars[i], false);
        if (barsOff[i] != 0) Draw::Show(barsOff[i], false);
    }
}

// --- Kettle-Ball ------------------------------------------------------------------------------------------------------
// A kettle (models/kettle.txt, spout along +x) seen from the side: its spout to the camera's left, whichever way the
// ball goes. Steam: small white puffs out of the spout's tip, more the faster the ball. They rise, and at the ball's
// wall they can't get out: they slide along it up to the top, as if shut in, gather there and fade.
const double SPOUT_X = 27, SPOUT_Z = -18;   // the spout's tip in the kettle's coordinates (cm)
const int MOST_PUFFS = 60;
const double WALL = 45;            // the inside of the ball's wall (cm from the middle)
class Puff
{
    int id = 0;
    bool alive = false;
    double x = 0, y = 0, z = 0;     // from the ball's middle
    double vx = 0, vy = 0, vz = 0;
    double age = 0, life = 0;
}
array<Puff> puffs;
int kettle = 0;
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
            Draw::Show(kettle, true);
        }
        else
            kettle = 0;
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
        {
            if (p.id != 0) Draw::Show(p.id, false);
            continue;
        }
        p.age += frameDt;
        double t = p.age / p.life, grow = 1 + t * 1.6;
        double drag = Math::pow(0.4, frameDt);     // the push out of the spout dies down
        p.vx *= drag; p.vy *= drag;
        p.vz += 70 * frameDt;                      // steam rises
        if (p.vz > 60) p.vz = 60;
        p.x += p.vx * frameDt; p.y += p.vy * frameDt; p.z += p.vz * frameDt;
        // At the wall: back onto it, and only the part of the motion along it is kept, so it slides up the wall.
        double r = Math::sqrt(p.x * p.x + p.y * p.y + p.z * p.z), most = WALL - 3 * grow;
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
            if (p.id != 0) Draw::Show(p.id, false);
            continue;
        }
        if (p.id == 0)
            p.id = Draw::Ball(3, 0.95f, 0.95f, 1.0f);
        if (p.id == 0) continue;
        if (!Draw::Move(p.id, x + p.x, y + p.y, z + p.z))
        {
            p.id = 0;
            continue;
        }
        Draw::Scale(p.id, grow);
        Draw::Fade(p.id, float(t < 0.6 ? 0.8 : 0.8 * (1 - t) / 0.4));
        Draw::Show(p.id, true);
    }
}

void Flames(double x, double y, double z)
{
    for (int i = 0; i < FLAMES; i++)
    {
        if (flames[i] == 0)
            flames[i] = Draw::Model(Plugins::Folder() + "models/flame.txt");
        if (flames[i] == 0) continue;
        double a = 6.28318 * i / FLAMES;
        if (!Draw::Move(flames[i], x + Math::cos(a) * FLAME_RING, y + Math::sin(a) * FLAME_RING, z + FLAME_Z))
        {
            flames[i] = 0;
            continue;
        }
        // flicker: toward a new random size, quickly
        double goal = 0.6 + Random() * 0.8, k = 1 - Math::pow(2.718, -18 * frameDt);
        flameSize[i] += (goal - flameSize[i]) * k;
        Draw::Scale(flames[i], flameSize[i]);
        Draw::Turn(flames[i], -FLAME_LEAN, a * 57.2958, 0);   // leaning out, away from the kettle
        Draw::Show(flames[i], true);
    }
}

void HideKettle()
{
    if (kettle != 0) Draw::Show(kettle, false);
    for (int i = 0; i < FLAMES; i++)
        if (flames[i] != 0) Draw::Show(flames[i], false);
    for (uint i = 0; i < puffs.length(); i++)
    {
        puffs[i].alive = false;
        if (puffs[i].id != 0) Draw::Show(puffs[i].id, false);
    }
    steamDue = 0;
}

// --- Timer Ball ------------------------------------------------------------------------------------------------------
// The run's time as "MM:SS.hh" in the Speed Ball's digits (smaller), in a 3D digital clock
// (models/clock.txt: a grey case as deep as it is high, black behind the digits, a red rim at the front), all facing
// the camera. Plugins can't read the game's own timer, so the plugin keeps one: from 0 at each new run (RunId),
// counting while the race is on (IsActive) and not paused, and standing still at the finish. It can differ a little
// from the game's.
const int TIMER_SLOTS = 8;                  // "MM:SS.hh"
const double T_SCALE = 0.48;               // of the Speed Ball's digits
const double T_ADVANCE = 9, T_DOT_ADVANCE = 5;    // cm from one character's middle to the next
const double CLOCK_GROUND = -30.6;         // cm down from the middle when standing: its feet on the ball's bottom
const double CLOCK_GROUND_SIZE = 0.8;      // and smaller there, where the ball is narrower
const double CLOCK_FRONT = 9.5;             // cm toward the camera from the ball's middle: the digits, on the face
array<int> timerSegs(TIMER_SLOTS * 7);
array<int> timerDots(TIMER_SLOTS * 2);
int clock = 0;
double runClock = 0;
int clockRun = -1;

void RunClock(float dt, bool onTrack)
{
    if (!onTrack) return;
    if (Race::RunId() != clockRun)
    {
        clockRun = Race::RunId();
        runClock = 0;
    }
    if (Race::IsActive() && !Race::IsPaused() && !Race::IsComplete())
        runClock += dt;
}

string Two(int n) { return (n < 10 ? "0" : "") + n; }

string ClockText(double t)
{
    if (t > 5999.99) t = 5999.99;
    int hundredths = int(t * 100);
    return Two(hundredths / 6000) + ":" + Two((hundredths / 100) % 60) + "." + Two(hundredths % 100);
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
        clock = Draw::Model(Plugins::Folder() + "models/clock.txt");
    if (clock != 0)
    {
        if (Draw::Move(clock, x, y, z))
        {
            Draw::Turn(clock, 0, camYaw, 0);
            Draw::Scale(clock, size);
            Draw::Show(clock, true);
        }
        else
            clock = 0;
    }
    double fx = x + towardX, fy = y + towardY;      // the face
    string text = ClockText(runClock);
    double width = 0;
    for (int c = 0; c < TIMER_SLOTS; c++)
        width += Advance(text[c], c) * size;
    double u = -width / 2;
    for (int slot = 0; slot < TIMER_SLOTS; slot++)
    {
        uint ch = text[slot];
        bool isDot = ch == 46, isColon = ch == 58;
        double advance = Advance(ch, slot) * size, mid = u + advance / 2;
        double w = DIGIT_W * T_SCALE * size, h = DIGIT_H * T_SCALE * size, scale = T_SCALE * size;
        int bits = (ch >= 48 && ch <= 57) ? DIGITS[ch - 48] : 0;
        for (int s = 0; s < 7; s++)
        {
            int k = slot * 7 + s;
            bool lying = s == 0 || s == 3 || s == 6;
            timerSegs[k] = PlaceMark(timerSegs[k], lying ? "models/seg_h.txt" : "models/seg_v.txt", (bits & (1 << s)) != 0,
                                     fx, fy, z, rightX, rightY, mid + SEG_U[s] * w, SEG_V[s] * h, scale);
        }
        // a '.' is one dot at the bottom, a ':' two in the middle
        timerDots[slot * 2] = PlaceMark(timerDots[slot * 2], "models/dot.txt", isDot || isColon,
                                        fx, fy, z, rightX, rightY, mid, isDot ? -h / 2 : h / 4, scale);
        timerDots[slot * 2 + 1] = PlaceMark(timerDots[slot * 2 + 1], "models/dot.txt", isColon,
                                            fx, fy, z, rightX, rightY, mid, -h / 4, scale);
        u += advance;
    }
}

double Advance(uint ch, int slot)
{
    if (ch == 46 || ch == 58) return T_DOT_ADVANCE;     // '.' and ':'
    return T_ADVANCE;
}

// A shape (made from `file` when needed) at u across and v up from the ball's middle, facing the camera; or hidden.
// Returns its id (0: gone).
int PlaceMark(int id, const string &in file, bool shown, double x, double y, double z, double rightX, double rightY,
              double u, double v, double scale)
{
    if (!shown)
    {
        if (id != 0) Draw::Show(id, false);
        return id;
    }
    if (id == 0)
        id = Draw::Model(Plugins::Folder() + file);
    if (id == 0) return 0;
    if (!Draw::Move(id, x + rightX * u, y + rightY * u, z + v))
        return 0;
    Draw::Turn(id, 0, camYaw, 0);
    Draw::Scale(id, scale);
    Draw::Show(id, true);
    return id;
}

void HideTimer()
{
    if (clock != 0) Draw::Show(clock, false);
    for (uint i = 0; i < timerSegs.length(); i++)
        if (timerSegs[i] != 0) Draw::Show(timerSegs[i], false);
    for (uint i = 0; i < timerDots.length(); i++)
        if (timerDots[i] != 0) Draw::Show(timerDots[i], false);
}
