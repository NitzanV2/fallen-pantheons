# Art spec

Drop a PNG or JPG into the right folder, named after the content id from `scripts/core/data.gd`.
The game picks it up automatically; anything missing shows a tinted placeholder with initials.

| Folder | File name (.png or .jpg) | Used for |
|---|---|---|
| `art/cards/` | card id, e.g. `thor.png` | card art box, and the unit's portrait on the battle grid |
| `art/enemies/` | enemy id, e.g. `void_herald.png` | enemy portrait on the battle grid |
| `art/relics/` | relic id, e.g. `ember_of_faith.png` | relic icon (reward, shop, sidebar) |
| `art/patrons/` | `norse.png`, `greek.png`, `egypt.png` | patron portrait on the main menu |

## Image format

- Square, 512x512 or 1024x1024. The extension must match the real format
  (a JPEG renamed to .png fails to import).
- The same image is cropped two ways, always from the center:
  - card art box: a wide band (about 2:1), so the top and bottom quarters are cut off;
  - battle grid portrait: a tall strip (about 3:5), so the left and right thirds are cut off.
- Keep the subject's head and key silhouette inside the central ~40% of the image.
- Relic icons: centered object, simple background, readable at 28x28. The outer 15% on
  each side is cropped away, so keep the object inside the middle 70%.
- Dark or muted backgrounds; card text is drawn outside the art, never on top of it.

## Style consistency

- One style and one lighting direction across the whole set.
- Faction palette hints: Norse blue/steel, Greek gold/bronze, Egyptian green/sand,
  Void enemies purple/black, elites red, the Herald crimson.

## Temporary AI art

Style prompt used for the placeholder set (append to every subject description, and pass
`art/cards/thor.jpg` as a style reference image):

> 16-bit retro SNES-era RPG pixel art, chunky visible pixels, limited palette, clean dark
> outlines, flat cel shading with light dithering, flat dark navy background with scattered
> single-pixel stars and a subtle glow behind the subject (<faction/subject accent color>).
> Square, waist-up, centered, head inside the central 40 percent. No text, no border,
> no frame, no watermark.

Textures are imported with mipmaps (see `[importer_defaults]` in project.godot) because the
1024px images are shown at 60-150px; without them they shimmer and look jagged.

## Importing

Opening the project in the Godot editor imports new files automatically.
Without the editor: `godot --headless --path . --import`
