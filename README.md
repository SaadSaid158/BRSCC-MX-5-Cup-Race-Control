# BRSCC MX-5 Cup Race Control

An Assetto Corsa app that runs offline races like a real **BRSCC Mazda MX-5 Championship** round:
- marshal flags;
- stewards and penalties;
- AI that obeys race control.

Every rule comes from the **2026 BRSCC MX-5 Championship regulations** and the **Motorsport UK National Competition Rules**, and the code says which article it implements.

I'm using it to train for a real MX-5 Cup season, so the aim is realism over convenience.

> **Status: v0.2.1, early development.** Expect rough edges. See the [roadmap](docs/ROADMAP.md).

## Features
- **Marshal posts and flags:** posts are placed automatically from the track layout. A stopped car brings out yellow and double yellow; the track goes green after the incident; overtaking under yellow is penalised unless the place is given back.
- **AI that follows the rules:** the AI slows for yellows, doesn't overtake under them, serves its penalties, and doesn't pit unless race control sends it in.
- **Track limits:** checked per wheel against the surface underneath (kerbs are legal, grass isn't). The NCR penalty ladder applies: warning → +5 s → +10 s → drive-through → black flag.
- **Stewards:** drive-through and stop-go penalties, time penalties, penalty points and championship points. The **same consequences apply to every driver**, you included.
- **HUD:** a full-information *Practice* mode and a realistic *Race* mode (flags only at the post, plus a pit board).
- **Reports:** after each session you get provisional results, the race-control log, and evidence files.

## Install
1. You need Assetto Corsa, Content Manager and **Custom Shaders Patch** 0.2.11 or newer.
2. Download the latest install zip from [Actions](../../actions) (open the newest run and download *install-zip*) or from [Releases](../../releases).
3. Unzip it into your Assetto Corsa folder, the one containing `acs.exe`.
4. **Disable any other race-control or AI apps**, such as FIA-style race control apps. They fight over the AI and the flags.
5. Start any **offline** session. The app runs automatically. Two windows are in the apps bar: **Settings** and **Race Control**.

## How this was made
This project was **vibe coded**. I directed it and tested it in-game, and the code, research and tests were written by Claude Opus 5.5 (Anthropic's AI) in Claude Code. My part was the idea, the decisions and the testing; almost none of the code is hand-written.

The rule details all come from the official regulations: every value in [`rules.lua`](src/brscc_race_control/rules.lua) cites its source.

## Development
```bash
luajit tests/run.lua
```
```bash
luajit tests/sim.lua
```
```bash
OLD_CSP=1 luajit tests/sim.lua
```
```bash
scripts/package.sh
```
- `tests/run.lua`: unit tests for the rules.
- `tests/sim.lua`: an end-to-end simulated race against a fake CSP API.
- `OLD_CSP=1`: runs the same simulated race as if on an older CSP.
- `scripts/package.sh`: builds the install zip.

CI runs all of these on every push. The research notes and API notes are in [`docs/`](docs/).

## Disclaimer
This is an unofficial fan project, not affiliated with the BRSCC, Mazda or Motorsport UK.
