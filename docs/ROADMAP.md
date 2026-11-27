# Roadmap

Each milestone is a complete feature release.
- It's built, tested end to end in the simulator, and then tested in-game before the next one starts.
- Bug fixes go into the milestone they belong to.
- The goal for v1.0 is a full 2026 BRSCC MX-5 season you can race offline.

## Done
- **v0.1:**
  - marshal sectors and yellow flags;
  - AI that obeys yellows;
  - overtaking under yellow;
  - the track-limits ladder;
  - drive-through and black flag;
  - reports.
- **v0.2:**
  - the Practice HUD;
  - the settings window;
  - automatic marshal posts;
  - gap timing;
  - the AI pit guard;
  - compatibility with older CSP versions.

## M1 · v0.3: Race meeting (in progress: built and sim-tested, in-game meeting run outstanding)
*A BRSCC meeting is qualifying followed by 3 races (REGS 2.3.3). This makes it one connected event instead of separate CM sessions.*
- A meeting file that remembers the event across sessions: the track, the session order, results, penalties and points.
- **Qualifying rules:**
  - at least 3 laps to qualify (REGS 2.3.2);
  - laps deleted for track limits or a double yellow;
  - grid penalties carried to the race.
- **Grids:**
  - race 1 from qualifying;
  - race 2 from race 1's result;
  - race 3 from race 2's result.

  The app records the grid slots and puts each car in its correct slot (`physics.setCarPosition`). Option: relaunch AC between sessions with a generated race.ini (`ac.restartAssettoCorsa`).
- **Classification:** the official order with time penalties applied, classified vs not classified, PROVISIONAL → FINAL, and points per race.
- An in-game **results window** for each session and for the meeting.

## M2 · v0.4: Race procedures
- **Standing start (REGS 2.5):**
  - the 1-minute and 30-second boards;
  - the green flag lap, with the AI holding grid order;
  - forming up on the grid;
  - the 5-second board;
  - red lights out 2–7 s later.
- **Jump starts:** +10 s (NCR App.6 Art.7). **Pit-lane starts:** REGS 2.5.3.
- **Blue flags:** stationary and waved. Lapped AI yield, and ignoring blue flags is reported.
- **Chequered flag:** the cool-down lap with no overtaking, then into the pit lane and parc fermé (REGS 2.8).
- **Pit lane:** speeding detection at 60 km/h.

## M3 · v0.5: Neutralisations
- **Safety Car (NCR App.8 Art.2):**
  - deployment and SC boards;
  - the AI queue at 5 car lengths or less;
  - no overtaking;
  - lapped cars waved past when ordered;
  - the pit lane open;
  - lights out, then the restart at the line;
  - a race run entirely behind the SC is null and void.
- **Red flag (REGS 2.6):**
  - the field stops on the grid;
  - **Case A**: no contest, restart from the original grid;
  - **Case B**: the race resumes from the order one lap before the stoppage;
  - **Case C**: results declared one lap before the stoppage.
- **Code 60** as a per-event option (NCR App.8 Art.3).

## M4 · v0.6: Stewarding
- **Contact judgements:** the evidence (positions, speeds, line, who was ahead) goes to a verdict of NFA, Noted or a penalty, and the reasons are logged.
- Penalty points and the 12-point ban (NCR Ch.2 App.12).
- **The BRSCC Driving Standards Policy:** Yellow and Red Warnings, review outcomes, and exclusion from the next round, the same for every driver.

## M5 · v0.7: Championship
- The season file and the 2026 calendar.
- Standings with the 3 worst scores dropped, and the ×3 deduction for penalty points (REGS 1.6, 4.2.4).
- The Masters and Rookie trophies.
- A championship window with standings, history and each driver's record.
- Settings and marshal-post maps for each calendar track (as the track mods become available).

## M6 · v0.8: Race mode and polish
- The full realistic Race HUD:
  - light panels;
  - the start-line board sequence;
  - pit-board styles;
  - real race numbers from the car skins.
- A final pass on the UI design, plus an option for briefing sheets and Final Instructions for each event.

## v1.0
A full 2026 season, playable from start to finish.
