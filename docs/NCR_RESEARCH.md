# NCR 2026 research: Safety Car, Code 60, FCY, penalties

Covers handoff §10 items 1, 2, 3 and part of 5.
**Source:** the Motorsport UK NCR 2026 ebook at
`https://ebooks.motorsportuk.org/motorsport-uk-ncr-2026-edition-4/0952123001742394230/p<N>`. Pages read: p110–111 and p422–427.
**Caveats:**
- The page headers say "Edition 5" but the URL says edition-4. Check which edition is current.
- Text extraction dropped some lettered sub-items: App.10 Art.2.1 a–h and App.8 Art.2.16 b–f.
- p421 (App.8 Art.2.1–2.4) has **not** been read yet.
- Everything below is paraphrased. Check the ebook for exact wording before quoting it.

---

## 1. Safety Car: Ch.12 App.8 Art.2 (p422–423)

| Art | Rule | Implementation note |
|---|---|---|
| 2.4–2.5 | Deployed on the CoC's order. Waved yellow and an "SC" board at the S/F line, then shown at every post. Flashing yellow lights are optional | `flags`: SC state at all sectors |
| 2.6 | Cars line up behind the SC at **≤ 5 car lengths**. **No overtaking or overlapping** of any car. Passing the SC only if its observer signals it. An overtake is a breach of signals (Ch.2 App.12 1.2b, so penalty points apply) | AI gap control; steward check for overtakes |
| 2.7 | **Lapped cars are waved past only if the CoC orders it.** Cars between the SC and the leader go by at reduced speed, without overtaking, to the back of the queue | Make this a config option, default on |
| 2.8 | **Pit lane open.** Cars rejoin only when signalled, not while the SC or the queue is passing pit exit. They then go to the back of the queue | Hold the pit-exit release while the queue passes |
| 2.9 | The SC stays out at least until most cars are lined up behind it | |
| 2.10 | Coming in: the SC turns its lights off. Normally that is ≥ 25% of a lap before it pits on circuits over 2 miles, or **≥ 50% on circuits under 2 miles (so Brands Indy)** | |
| 2.11 | With the lights off, **the leader sets the pace** and may drop back > 5 lengths. Nobody may pass the SC before it is in the pit road, and nobody may move erratically | |
| 2.12 | As the SC enters the pit road: **green at the S/F line**, SC board withdrawn, waved green for 1 lap. **No overtaking until each car passes the green at the control line.** Passing earlier counts as gaining an advantage (Ch.2 Annexe A 1.3) | Restart line = S/F line |
| 2.13 | **SC laps count** as race laps (unless the championship regs say otherwise; the BRSCC regs don't) | |
| 2.14 | The CoC may lead the whole field into the pit lane behind the SC | Optional |
| 2.15 | Red flag under the SC: everyone stops behind the SC wherever its observer indicates (usually the grid or parc fermé) | Ties into `redflag.lua` |
| 2.16 | Exceptional start behind the SC: the SC leads the field away from the grid in single file, and the race counts as started at that moment | Low priority |
| 2.17 | Slow, erratic or dangerous driving under the SC is reported to the CoC | |

**Ch.12 App.9 (p426), end of race:**
- **1.13: a race run entirely under the SC is null and void.**
- 1.12: if the chequered flag is shown early or late, the race ends when the flag was actually shown. Results are taken from the leader's last completed lap.
- 1.6–1.7: a set-distance race ends when the leader completes the distance. A timed race ends at the time limit.

**Not found yet:** the last-lap / "SC lights out" signal beyond Art.2.10. It may be on p421.

## 2. Code 60: Ch.12 App.8 Art.3 (p423–424). **This is valid in circuit racing.**
- The CoC alone decides. It is allowed only if every post has direct comms with Race Control (3.1).
- A countdown of ≥ 15 s, then "5-4-3-2-1 Code 60" (3.2).
- The purple **Code 60 board** is waved at the line and at every post for ≥ 1 lap, then held stationary (3.3).
- Yellows are waved at the incident. **No green flags are shown** (3.4).
- **60 km/h**, stay behind the car in front, avoid harsh braking (3.5).
- The pit lane is open; cars rejoin only when signalled (3.6).
- Ending it: "prepare to go green in less than 30 s", a countdown, then **green everywhere at once**, and racing resumes (3.7–3.8).
- **Overtaking before the green can earn a time penalty of ≥ 1 min** (3.9).
- Code 60 laps count (3.10).

## 3. Full Course Yellow: Ch.12 App.8 Art.4 (p424–425). A possible third neutralisation mode
- It needs comms to the drivers and GPS tracking. In the sim those conditions are always met.
- **80 km/h**, single file, no overtaking from the moment it is declared (4.5–4.6).
- The pit entry and exit limit is 80 km/h. Entering cars may overtake on-track cars only after SC Line 1; exiting cars may be passed only until SC Line 2 (4.7).
- Ending it uses the same countdown as Code 60, and racing resumes at the green (4.9–4.11).
- An FCY can be escalated to a full SC: the SC joins with its lights off, gets ahead of the leader, then switches its lights on (4.12, 5.1).
- FCY laps count (4.14).
- **Decision for the user:** do we offer FCY, or just SC and Code 60?

## 4. Stop-go / drive-through: Ch.12 App.10 Art.2 (p427)
- This applies only where the championship regs provide for it. BRSCC 4.2.1 does.
- **Notification:** a black flag with the car number plus a "Stop-Go Penalty" / "Drive Through Penalty" board. The team is told in writing.
- **The driver must enter the pit lane within 3 complete laps** of first passing the board.
- **Stop-go:** go straight to the penalty area, wait out the time, leave without stopping anywhere else, and no work on the car.
- **Drive-through:** drive through the pit lane without stopping, at the speed limit.
- **Under the SC:** if the driver isn't already in the pit lane when the SC board appears, the penalty can't be served until the green after the SC period. **SC laps count toward the 3-lap limit.**
- **Late penalty:** if it is given in the **last 5 laps**, after the race, or in the **last 10 min of a timed race**, or it can't be served, it becomes a **time penalty of 30–60 s** added to elapsed time.
- **Not served:** further penalties, up to DSQ. **Our choice:** DSQ (a black flag) after 3 laps unserved, to be documented.
- **Drive-through and stop-go carry 0 penalty points and can't be appealed** (Ch.2 App.12 1.4).

## 5. Time / place penalties: Ch.2 Annexe A (p111)
- **There is no offence table.** It is a general power instead.
- 1.3a: for an unfair advantage, a time penalty **of up to 1 min** or **up to 10 places**.
- 1.7: a grid penalty of up to 10 places at a future race in the same event or championship. If the driver can't serve it all, they start last and it counts as served.
- **So the specific values are ours to set.** Our choices:
  - track limits: **5 s**;
  - causing a collision: **5 s / 10 s**, by severity;
  - a passing offence: a place give-back, then 5 s.

  All of these sit inside the 1-min cap.

## 6. Penalty points: Ch.2 App.12 (p110)
| Penalty | Points |
|---|---|
| Verbal warning | 0 |
| Written reprimand | 2 |
| Fine / time / grid / position / lap penalty | 3 |
| DSQ from practice, heat or race | 4 |
| DSQ from the event | 6 |
| Stop-go / drive-through | **0** |

- **12 points in 12 months** → referral to the National Court (1.6). For us, that means a ban from the next round.
- **BRSCC 4.2.4:** −3 championship points per penalty point. So a **5 s penalty costs 9 championship points**, but a drive-through costs nothing.
- Points apply to driving offences (Ch.2 App.1 1.13; Ch.12 App.7 1.2, 1.5, 1.7–1.9, 1.12), to ignoring signals (1.2b), to conduct, and to disobeying officials.

---

## Changes to the approved design (§5.2 of the handoff)
1. **Escalation ladder:** warning → 5 s → drive-through → DSQ. A drive-through carries 0 points while 5 s carries 3, so the "harsher" step is cheaper in championship points. That is faithful to the NCR, but the user should know.
2. **Late drive-through:** one given in the last 5 laps becomes 30 s.
3. **SC/Code 60 rules to add:**
   - a race run entirely under the SC is void;
   - the restart line is the S/F line;
   - an overtake under Code 60 is ≥ 1 min.

## Still open
- p421: SC Art.2.1–2.4.
- App.7 Arts 1.x: what each driving offence covers (§10 item 4).
- The flag-signals section (§10 item 5).
- Red flag Case C (§10 item 6).

---

# Part 2: flags, driving standards, start, red flag, calendar (2026-11-26)
Pages read: p411–422. The same edition caveats apply. Sub-article letters were inferred from the order of the flattened text.

## 7. Calendar and format: REGS 1.5–1.6 (read from the public PDF of the same regs)
| Rounds | Date | Venue | In install? |
|---|---|---|---|
| 1–3 | 18–19 Apr | Snetterton 300 | no |
| 4–5 | 9 May | Oulton Park International | no |
| 6–8 | 6–7 Jun | Donington Park National | no |
| 9–11 | 11–12 Jul | Croft | no |
| 12–14 | 8–9 Aug | Cadwell Park | no |
| 15–17 | 12–13 Sep | Anglesey International | no |
| 18–20 | 10–11 Oct | **Silverstone International** | **yes (`ks_silverstone`)** |

- **Brands Hatch is not on the 2026 calendar, and nor are Thruxton or Silverstone GP/National.** → Recommend making **Silverstone International** the testbed.
- **Format:** qualifying plus 3 races per meeting (Oulton: 2). Grids: R1 from qualifying, R2 from the R1 result, R3 from the R2 result (2.3.3).
- **Points (1.6.1):** 100, 98, 96 … (−2 per place). **+1 for fastest lap, but not if the lap breached App.7 Art.1.6 (track limits).**
- **Season total (1.6.2):** best scores less the 3 lowest. DSQ rounds can't be dropped. Rounds from the final event can't be dropped unless you took part in it.
- **Shortened race (1.6.4):** still full points.

## 8. Track limits and driving standards: Ch.12 App.7 (p416–418)
- **1.6:** the white lines are part of the track. **You've left the track if any part of any tyre's contact patch goes beyond the outer edge of the kerb** (or the white line where there's no kerb). This is stricter than "four wheels off".
  - **AC approximation:** any wheel counted outside the track surface = a breach. Verify against the actual field once the SDK is checked.
- **1.11 track-limits ladder (races). This replaces our design:**
  1. no action;
  2. warning (black/white flag);
  3. **5 s**;
  4. **a further 10 s**;
  5. **drive-through**;
  6. **black flag**.

  Each signal must have been shown before the next step applies. **Qualifying: the lap is deleted** (1.11a). Races of 40 min or more may vary the ladder; ours don't.
- **1.5:** a car about to be lapped must let the faster car by at the first opportunity; blue flags if it doesn't use its mirrors. **One change of direction per overtake attempt.** When moving back to the racing line, leave **a car's width**. No forcing a car off the track.
- **1.7:** rejoin only when it's safe and without gaining an advantage.
- **1.8:** causing a collision, repeated mistakes or a lack of control → penalty, up to DSQ.
- **1.9:** driving slowly, erratically or dangerously.
- **1.12:** no reversing on track.

## 9. Flags: Ch.12 App.8 Art.1 (p419–421)
- **Single waved yellow:** slow down, **no overtaking**.
- **Double waved yellow:** slow considerably, be ready to stop, **no overtaking**.
- **No overtaking from the yellow until the green is passed** (1.10).
- **Incident signalling (1.8):** waved yellow at the post before → double yellow immediately before the incident → **waved green immediately after it**. If the incident is well off track: single yellow, then green.
- **Yellow/red stripes:** stationary = slippery surface ahead; waved = slippery surface imminent.
- **White:** a slow or service vehicle. Waved in the sector it's in; stationary in the sector after.
- **Blue:** stationary = a car close behind; waved = a car trying to pass.
- **Black/orange disc + car number:** pit **next lap** for repairs.
- **Black/white diagonal + car number:** warning about conduct.
- **Black + car number:** pit next lap and report to the CoC. DSQ.
- **Chequered:** the session is over and can't be restarted. It is never shown at the same time as a red.
- **Purple = Code 60.** It must be named in the official documents and the briefing (so ours goes in the pre-race briefing message).
- **Other boards:** a hazard-area board; an "SC" board; an "FCY" panel.
- **1.15:** if no car crosses the line for 5 min, the race ends and results are taken from the last crossing.
- **Not in the NCR:** an "SC in this lap" board. The SC only switches its lights off (Art.2.10).

## 10. Start: Ch.12 App.6 (p411–414)
- **6.12:** on the formation lap the **pole car sets the pace**; cars stay in grid order; no practice starts.
- **6.13:** the 5 s board shows the grid is complete. The red lights come on about 5 s after the board is withdrawn, then **go out 2–7 s later**. This replaces our 2–3 s.
- **6.11:** a car that can't start: the driver raises an arm, marshals show a yellow, and the car starts after the rest of the grid has gone.
- **6.4:** cars still in the pit lane or the assembly area once the countdown starts go to the back. The pit exit closes 30 s after the last car leaves.
- **Art.7–8, false start:** wrong position, or moving before the lights go out → **+10 s**, **no penalty points**. This replaces our drive-through.
- **Not found:** the text for the 5-min and 3-min boards (lost at the page break). The BRSCC regs only require boards from 1 min.

## 11. Red flag: Ch.12 App.6 Art.9 (p414–415)
- **9.1 b, c, e:** the "one lap fewer than the leader" roll-back is **confirmed**. It applies to Case B (the restart grid), to Case B races that can't be restarted, and to Case C.
- **9.1d:** the result is the finishing order of the restarted race. It lists **everyone who took the original start**. The first part is used only for lap records (and for points where the regs say so; BRSCC 2.6.3 says the restart's order counts).
- **9.1f:** **track-limit breaches on the laps removed by the roll-back don't count.** Other incidents on those laps are still reviewed.
- **9.2:** cars may go to the pits for repairs, but they then start from the pit lane behind everyone else. No work on the grid except for safety.
- **9.3:** the restart may be shortened. The 75% test then uses the new duration.
- **Gap:** "fewer than 2 laps" (A) versus "more than 2 laps" (B). Exactly 2 laps → **we treat it as Case B**.

## 12. Changes to the design already applied in `script/rules.lua`
- The track-limits ladder now follows App.7 1.11.
- Jump start: +10 s, 0 penalty points.
- Lights out 2–7 s after the red lights come on.
- Late or unserved drive-through/stop-go: becomes 30 s (0 penalty points); unserved after 3 laps → DSQ.
- Qualifying track limits: the lap is deleted.
