# BRSCC Race Control v0.1.2: retest (about 25 min)

## Install
Unzip `BRSCC-Race-Control-v0.1.2-install.zip` into your AC root folder and **overwrite** the old files. If you've saved a marshal map, it's kept: the zip doesn't include one.

## Settings
Same as before: BRSCC MX-5 NA for everyone, Silverstone International, Clear, 20 °C, 14:00, Optimum track, 9 AI at 95 % strength and 50 % aggression, damage 0 %, Penalties ON, jump start off.

**Changes:**
- **Race of 15 laps.**
- **You start on POLE (P1).** This time the AI need to come up *behind* your stopped car.

## Race, lap by lap
| Lap | Do this | Expect |
|---|---|---|
| 1 | Race cleanly | maybe a few AI track-limit calls, but **far fewer** than last time (was 9 cars in 40 s) |
| 2 | Pick a straight with good sight lines. **Stop on the track** (all 4 wheels on tarmac). **Stay until all 9 AI have passed.** Watch them in your mirrors or on the replay camera | double yellow on your HUD. The AI slow **before** they reach you, crawl past, don't overtake each other near you, and **speed up again straight after passing you** (that's the fix) |
| 3 | Ride the kerbs **hard** at 2–3 corners, but don't go past them onto grass or gravel | **nothing**: kerbs are legal now |
| 4 | Excursion #1: two wheels **clearly onto the grass** beyond a kerb, for about half a second | "track limits #1 - noted" |
| 5 | Excursion #2 | **warning** and black/white flag |
| 5 again | A second excursion **in the same lap** | **nothing on the HUD**. The app window LOG says "not escalated, previous signal not yet shown" |
| 6 | Excursion #3 | +5 s |
| 7 | Excursion #4 | +10 s |
| 8 | Excursion #5 | DRIVE-THROUGH, plus AC's own penalty notice |
| 9 | **Serve it:** through the pit lane on the limiter, no stop | "drive-through served". Does AC's notice clear as well? |
| 10 | Excursion #6 | BLACK FLAG. Pit, press **"Write report now"**, then quit |

You only get one escalation per lap now. The NCR says the previous signal has to be shown, at the line, before the next step.

## Watch for: AI pitting (new in v0.1.2)
- In races, the app now cancels any AI pit stop that race control didn't order, and logs why the car wanted to come in: fuel, engine life, gearbox, damage or tyre wear. You'll see these lines in the window LOG and in the report.
- **The field should stay out for all 15 laps.** If AI cars still pit or vanish, count how many and roughly which laps.
- **Our app no longer touches AC's own flag display.** Your flags come only from our panel at the top of the screen.

## Send back
1. **Both** sessions' files from `Documents/Assetto Corsa/brscc-race-control/reports/`. That's **all four types**: `.txt`, `.json`, `_trace.csv` and the new **`_excursions.csv`**.
2. **From last time:** the `2026-11-26_183116_…_trace.csv`, which covers your stops at 06:40 and 08:18.
3. **Quick answers:**
   1. On lap 2, did the AI slow down too much, about right, or not enough? Did any hit you or each other?
   2. Did they pick up speed straight after passing you?
   3. Lap 3: were any kerbs flagged?
   4. Lap 4: did any of your grass excursions get **missed**?
   5. Is the HUD readable, and is it in a good place?
   6. Any FPS drop?
   7. Your CSP version.
