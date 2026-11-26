# BRSCC Race Control v0.2.0: in-game test (about 35 min)

New in this build:
- the Practice HUD (from the mock-ups) and a basic Race HUD;
- a Settings window;
- automatic marshal posts from the track geometry;
- interval timing.

v0.1.2 fixes carried over: the AI pit guard, per-wheel track limits, one ladder step per lap, and green after the incident.

## Install
1. Download the install zip from the latest **tests** run on GitHub (Actions → the newest run on `main` → *install-zip*), or from the release once it's tagged.
2. Unzip it into the AC root folder and **overwrite** the existing files.
3. If you recorded a marshal map in an older version, it's in `apps/lua/brscc_race_control/data/tracks/`. It still overrides the automatic posts. Delete it if you want to see the automatic ones.

## Settings (same as before)
- Car: BRSCC MX-5 NA for every car.
- Track: Silverstone International.
- Conditions: Clear, 20 °C, 14:00, Optimum track.
- AI: 9 cars, 95 % strength, 50 % aggression.
- Damage 0 %, Penalties ON, jump start off.
- CSP 0.2.11.

## Part 1: Practice, 10 min, no AI (checking the posts and the HUD)
1. The briefing message should say **"Marshal posts: N automatic from track geometry"**.
2. Open **BRSCC Race Control - Settings** → **Marshal posts** tab. Take a **screenshot of the post list**: names and distances.
   - Drive a lap and check that the posts sit **just before each corner**, with nothing silly like three posts in one corner or a 600 m gap.
   - Corner names appear only if the track has a `sections.ini`; otherwise they're "Turn 1", "Turn 2" and so on.
3. HUD check:
   - the track strip shows your ▼ moving round;
   - the left panel shows the lap and the session time left;
   - the right panel says "clean".
4. **Display** tab: try the HUD scale slider (0.6–1.5). Then switch to **Race** mode, drive past the line, and check the pit board appears for about 8 s. Switch back to **Practice**.

## Part 2: Race, 15 laps, you start on POLE
| Lap | Do this | Expect |
|---|---|---|
| 1 | Race cleanly | left panel shows P, LAP 1 / 15, 14 laps to go; "Behind" gap counts up or down |
| 2 | **Stop on the track** on a straight and stay until all 9 AI have passed | HUD shows **YELLOW** at the post before, then **DOUBLE YELLOW** ("incident … m ahead") for the cars approaching; your strip shows yellow, double yellow, then green. The AI slow before you, crawl past without overtaking, and speed up straight after |
| 3 | Ride kerbs hard, but don't go beyond them | nothing |
| 4–8 | One clear excursion onto the grass per lap | pips fill: noted → black/white → +5 s → +10 s → DRIVE-THROUGH. The right panel shows "next: …"; at #5 the big panel shows the drive-through board with a countdown |
| 9 | Serve the drive-through (pit lane, limiter, no stop) | "drive-through served", chip disappears |
| 10–15 | Race to the finish | **AI should all still be out** (pit guard) |

After the flag, wait 60 s or press **Write report now** in the Race Control window.

## Send back
1. Everything in `Documents/Assetto Corsa/brscc-race-control/reports/` from this test.
2. The **screenshot of the marshal-post list**, plus screenshots of the HUD under the double yellow and with the drive-through.
3. **Quick answers:**
   1. Are the automatic posts in sensible places?
   2. Is the HUD readable at a glance? What would you move, resize or remove?
   3. How did the AI behave around your stopped car?
   4. Did any AI pit or retire?
   5. Any FPS drop?
   6. Is there a **HUD error** (red text) at the top of the Settings window?
4. The folder names inside `apps/lua/` and `extension/lua/`.
