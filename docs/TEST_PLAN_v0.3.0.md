# BRSCC Race Control v0.3.0 (M1, race meeting): in-game test (about 30 minutes)

New in this build:
- a full meeting: qualifying, then races 1, 2 and 3, with the app setting each grid and relaunching AC between sessions;
- race classification per NCR Ch.12 App.9 Art.1.11: at least 80% of the winner's laps, and across the line within 4 minutes of the winner;
- a results window (live order, then the provisional classification, with the meeting standings beside it);
- a default panel layout on first launch, and a "Reset panel layout" button.

The test driver can do all of it: Settings > Testing > "AI drives my car". Switch it on again after every relaunch, because it isn't saved.

## Setup
Standard test setup in CM (HANDOFF §3): Silverstone International, 9 AI, BRSCC MX-5. Start any **Race** session and get in the car.

## 1. Panels (2 min)
- [ ] Your panels stay where you put them. The first launch must not move a layout you've already arranged.
- [ ] Settings > Display > **Reset panel layout** places the panels: flags top centre, strip and messages under them, timing left, track limits right, pit board right of centre, results in the middle.
- [ ] **BRSCC Results** is in the app bar (podium icon) and shows the live running order.

## 2. Start a meeting (1 min)
- [ ] BRSCC Race Control window > **BRSCC meeting**: set qualifying to **5 min** and races to **3 laps**, then press **Start meeting: go to qualifying**.
- [ ] AC relaunches into a session called **Qualifying**, starting from the pits.

## 3. Qualifying (6 min)
- [ ] Turn on the test driver. The Results window shows the best valid laps; anyone under 3 laps is greyed out.
- [ ] When the session ends, the Race Control window offers **Continue to Race 1**.

## 4. Race 1 (6 min)
- [ ] Press Continue. AC relaunches into **Race 1** with the **same driver names** as qualifying, gridded in qualifying order. Anyone under 3 laps starts at the back.
- [ ] Turn the test driver on again. Let it run to the flag.
- [ ] The race report waits for the lapped cars: it's written once all running cars have finished, or 4 minutes after the winner.
- [ ] **No lapped finisher is NC** unless it's under 80% of the winner's laps.
- [ ] The Results window shows PROVISIONAL, gaps, points (100, 98, 96 …, +1 for the fastest valid lap) and the meeting standings.

## 5. Races 2 and 3 (12 min)
- [ ] Race 2's grid is race 1's finishing order, and race 3's is race 2's.
- [ ] Any grid drop from a penalty is applied, capped at 10 places, and a drop past the back means starting last.
- [ ] After race 3, the window says **Meeting complete**, and the standings add up all three races.

## Send back
- The reports folder: `Documents/Assetto Corsa/brscc-race-control/reports/`.
- The meeting file: `Documents/Assetto Corsa/brscc-race-control/meetings/active.json`.
- A screenshot of the Results window after race 3.
