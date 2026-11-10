# Word Magic — Forest Water Reference v1

This package contains a generated visual reference sheet for the forest water asset family.

## Included
- `forest_water_reference.png` — 1536×1024 RGB concept sheet showing water surfaces, shore transitions, river bends, waterfalls, rocks, lily pads, reeds and splash accents.

## Important limitations
- The checkerboard pattern is baked into the RGB image; it is NOT transparency.
- The artwork is not guaranteed to follow an exact 32×32 pixel grid.
- Individual sprites have not been cleanly segmented, alpha-masked, or seam-tested.
- Do not import this reference as a production-ready Godot TileSet atlas.

## Suggested extraction plan
1. Select the water-surface motifs and rebuild them as true 32×32 tiles.
2. Create shoreline autotile pieces separately: straight edges, inner corners, outer corners, and isolated water corners.
3. Build river straight/bend/junction pieces as larger modular compositions, not by forcing every shape into one tile.
4. Separate waterfalls into top, middle, and bottom segments; animate with SpriteFrames or a shader only after the static pieces tile correctly.
5. Export decorative rocks, lily pads, reeds and splashes as individual transparent PNGs.
6. Validate seams in Godot using nearest-neighbor filtering and a test map before treating the assets as production-ready.

## Godot 4 import notes
- Set texture filtering to Nearest for pixel art.
- Disable mipmaps for the pixel-art texture set.
- Use a 32×32 atlas grid only after the source art has been rebuilt and verified against that grid.
