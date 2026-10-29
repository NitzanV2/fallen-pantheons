# Board sprites

Frameless battle-board sprites (idle + attack) for unit tokens.

**Preview (recommended):** open [`board_sprites_preview.html`](board_sprites_preview.html) in a browser (Cursor markdown often shows stale local images). Rebuild anytime with:

```powershell
powershell -File tools/rebuild_sprite_preview.ps1
```

Then use **Hard refresh images** in the page, or reload.

Files in `game/art/sprites/`:

- `{id}.png` - idle pose
- `{id}_attack.png` - strike / release pose during the melee lunge or ranged shot
- `amalgam.png` / `amalgam_attack.png` - shared by every `amalgam_*` unit id
- `wolf.png`, `scarab.png` (+ `_attack`) - unique token summons
- `{id}_airborne.png` / `{id}_airborne_attack.png` - optional flying pose when the unit is Airborne (Erinyes Fury)

## Batch order

1. **Greek** units (done)
2. **Norse** units (done; incl. unique **wolf**)
3. Regular **enemies** (done � act 1 & 2 `kind: enemy`)
4. **Egyptian** units (done; incl. unique **scarab**)
5. **Elites** (done)
6. **Bosses** (done; wide 16:9 for width>1)
7. Shared **amalgam** (done - ``amalgam.png`` / ``amalgam_attack.png``)

Spells and armaments have no board sprite.

## Presentation rules

- **Not** the card portraits. Idle and attack board sprites are separate combat poses. Hand and codex still use `art/cards` and `art/enemies`.
- Allies face **up the board** (rear / three-quarter rear, toward enemies). Enemies face **the player** (front / three-quarter front).
- Smooth painted game art (not chunky pixel art).
- Humanoid framing ends around **waist to knee** (no full legs/feet). Lower third fades to transparent so keyword / status icons can sit under the figure.
- Board tokens are larger (`210x230`); sprite host runs to the HP bar with bottom-fade bleed over icons.
- Multi-tile units (`width` > 1) use **16:9** landscape board art that width-fits the token. Serpentine bosses span edge-to-edge; humanoids may fill spare width with peripheral props (pillars, banners, scales, gate).

## Attack timing

| Kind | When the attack sprite shows |
| --- | --- |
| Melee | Whole lunge (0.12s out + 0.20s back), then idle |
| Ranged | Recoil while the bolt flies, then idle |

## Greek

### Hoplite (`hoplite`)

Idle | Attack
--- | ---
![idle](game/art/sprites/hoplite.png?v=greek3) | ![attack](game/art/sprites/hoplite_attack.png?v=greek3)

### Myrmidon (`myrmidon`)

Idle | Attack
--- | ---
![idle](game/art/sprites/myrmidon.png?v=greek3) | ![attack](game/art/sprites/myrmidon_attack.png?v=greek3)

### Athena (`athena`)

Idle | Attack
--- | ---
![idle](game/art/sprites/athena.png?v=greek3) | ![attack](game/art/sprites/athena_attack.png?v=greek3)

### Zeus (`zeus`)

Idle | Attack
--- | ---
![idle](game/art/sprites/zeus.png?v=greek3) | ![attack](game/art/sprites/zeus_attack.png?v=greek3)

### Peltast (`peltast`)

Idle | Attack
--- | ---
![idle](game/art/sprites/peltast.png?v=greek3) | ![attack](game/art/sprites/peltast_attack.png?v=greek3)

### Apollo (`apollo`)

Idle | Attack
--- | ---
![idle](game/art/sprites/apollo.png?v=greek3) | ![attack](game/art/sprites/apollo_attack.png?v=greek3)

### Achilles (`achilles`)

Idle | Attack
--- | ---
![idle](game/art/sprites/achilles.png?v=greek3) | ![attack](game/art/sprites/achilles_attack.png?v=greek3)

### Pythia (`pythia`)

Idle | Attack
--- | ---
![idle](game/art/sprites/pythia.png?v=greek3) | ![attack](game/art/sprites/pythia_attack.png?v=greek3)

### Forge Apprentice (`forge_apprentice`)

Idle | Attack
--- | ---
![idle](game/art/sprites/forge_apprentice.png?v=greek3) | ![attack](game/art/sprites/forge_apprentice_attack.png?v=greek3)

### Cyclops Smith (`cyclops_smith`)

Idle | Attack
--- | ---
![idle](game/art/sprites/cyclops_smith.png?v=greek3) | ![attack](game/art/sprites/cyclops_smith_attack.png?v=greek3)

### Talos (`talos`)

Idle | Attack
--- | ---
![idle](game/art/sprites/talos.png?v=greek3) | ![attack](game/art/sprites/talos_attack.png?v=greek3)

### Hermes (`hermes`)

Idle | Attack
--- | ---
![idle](game/art/sprites/hermes.png?v=greek3) | ![attack](game/art/sprites/hermes_attack.png?v=greek3)

### Line Captain (`line_captain`)

Idle | Attack
--- | ---
![idle](game/art/sprites/line_captain.png?v=greek3) | ![attack](game/art/sprites/line_captain_attack.png?v=greek3)

### Sybil (`sybil`)

Idle | Attack
--- | ---
![idle](game/art/sprites/sybil.png?v=greek3) | ![attack](game/art/sprites/sybil_attack.png?v=greek3)

### Line Chanter (`chorus_of_delphi`)

Idle | Attack
--- | ---
![idle](game/art/sprites/chorus_of_delphi.png?v=greek3) | ![attack](game/art/sprites/chorus_of_delphi_attack.png?v=greek3)

### Daedalus (`daedalus`)

Idle | Attack
--- | ---
![idle](game/art/sprites/daedalus.png?v=greek3) | ![attack](game/art/sprites/daedalus_attack.png?v=greek3)

## Neutral (starter)

### Ark Sentinel (`ark_sentinel`)

Idle | Attack
--- | ---
![idle](game/art/sprites/ark_sentinel.png?v=greek3) | ![attack](game/art/sprites/ark_sentinel_attack.png?v=greek3)

### Echo Archer (`echo_archer`)

Idle | Attack
--- | ---
![idle](game/art/sprites/echo_archer.png?v=greek3) | ![attack](game/art/sprites/echo_archer_attack.png?v=greek3)

## Demo enemies (Hollow Procession)

### Hollowed Zealot (`hollowed_zealot`)

Idle | Attack
--- | ---
![idle](game/art/sprites/hollowed_zealot.png?v=greek3) | ![attack](game/art/sprites/hollowed_zealot_attack.png?v=greek3)

### Hollowed Bulwark (`hollowed_bulwark`)

Idle | Attack
--- | ---
![idle](game/art/sprites/hollowed_bulwark.png?v=greek3) | ![attack](game/art/sprites/hollowed_bulwark_attack.png?v=greek3)

### Hollow Archer (`hollow_archer`)

Idle | Attack
--- | ---
![idle](game/art/sprites/hollow_archer.png?v=greek3) | ![attack](game/art/sprites/hollow_archer_attack.png?v=greek3)


## Norse
### Einherjar (`einherjar`)

Idle | Attack
--- | ---
![idle](game/art/sprites/einherjar.png?v=norse) | ![attack](game/art/sprites/einherjar_attack.png?v=norse)
### Shieldmaiden (`shieldmaiden`)

Idle | Attack
--- | ---
![idle](game/art/sprites/shieldmaiden.png?v=norse) | ![attack](game/art/sprites/shieldmaiden_attack.png?v=norse)
### Raven of Odin (`raven_of_odin`)

Idle | Attack
--- | ---
![idle](game/art/sprites/raven_of_odin.png?v=norse) | ![attack](game/art/sprites/raven_of_odin_attack.png?v=norse)
### Berserker (`berserker`)

Idle | Attack
--- | ---
![idle](game/art/sprites/berserker.png?v=norse) | ![attack](game/art/sprites/berserker_attack.png?v=norse)
### Valkyrie (`valkyrie`)

Idle | Attack
--- | ---
![idle](game/art/sprites/valkyrie.png?v=norse) | ![attack](game/art/sprites/valkyrie_attack.png?v=norse)
### Thor (`thor`)

Idle | Attack
--- | ---
![idle](game/art/sprites/thor.png?v=norse) | ![attack](game/art/sprites/thor_attack.png?v=norse)
### Odin (`odin`)

Idle | Attack
--- | ---
![idle](game/art/sprites/odin.png?v=norse) | ![attack](game/art/sprites/odin_attack.png?v=norse)
### Raider (`raider`)

Idle | Attack
--- | ---
![idle](game/art/sprites/raider.png?v=norse) | ![attack](game/art/sprites/raider_attack.png?v=norse)
### Ulfhednar (`ulfhednar`)

Idle | Attack
--- | ---
![idle](game/art/sprites/ulfhednar.png?v=norse) | ![attack](game/art/sprites/ulfhednar_attack.png?v=norse)
### Loki (`loki`)

Idle | Attack
--- | ---
![idle](game/art/sprites/loki.png?v=norse) | ![attack](game/art/sprites/loki_attack.png?v=norse)
### Shieldthane (`shield_raid`)

Idle | Attack
--- | ---
![idle](game/art/sprites/shield_raid.png?v=norse) | ![attack](game/art/sprites/shield_raid_attack.png?v=norse)
### Ulfr Hunter (`ulfr_hunter`)

Idle | Attack
--- | ---
![idle](game/art/sprites/ulfr_hunter.png?v=norse) | ![attack](game/art/sprites/ulfr_hunter_attack.png?v=norse)
### Geri (`geri`)

Idle | Attack
--- | ---
![idle](game/art/sprites/geri.png?v=norse) | ![attack](game/art/sprites/geri_attack.png?v=norse)
### Freki (`freki`)

Idle | Attack
--- | ---
![idle](game/art/sprites/freki.png?v=norse) | ![attack](game/art/sprites/freki_attack.png?v=norse)
### Skoll and Hati (`skoll_and_hati`)

Idle | Attack
--- | ---
![idle](game/art/sprites/skoll_and_hati.png?v=norse) | ![attack](game/art/sprites/skoll_and_hati_attack.png?v=norse)
### Doomrunner (`reckless_charge`)

Idle | Attack
--- | ---
![idle](game/art/sprites/reckless_charge.png?v=norse) | ![attack](game/art/sprites/reckless_charge_attack.png?v=norse)
### Carrion Wolf (`carrion_wolf`)

Idle | Attack
--- | ---
![idle](game/art/sprites/carrion_wolf.png?v=norse) | ![attack](game/art/sprites/carrion_wolf_attack.png?v=norse)
### Packrunner (`packrunner`)

Idle | Attack
--- | ---
![idle](game/art/sprites/packrunner.png?v=norse) | ![attack](game/art/sprites/packrunner_attack.png?v=norse)
### Wolf (`wolf`)

Idle | Attack
--- | ---
![idle](game/art/sprites/wolf.png?v=norse) | ![attack](game/art/sprites/wolf_attack.png?v=norse)
