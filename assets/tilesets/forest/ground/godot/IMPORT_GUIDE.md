# Word Magic — Forest Ground Tiles v1

## Status (2026-11-11)

The PNG files next to this guide are the **production copies**: alpha flattened to fully
opaque, with 42 pale edge-contamination pixels inpainted (39 in dirt_grassy_edge).
The untouched originals (globally semi-transparent, alpha 224–254) live in
`assets/source/generated/ground_tiles_v0/`. Details: `docs/ART_ASSET_IMPLEMENTATION.md`.

## Contents

Eight 32×32 RGBA PNG ground samples: grass, flower grass, dense grass, dirt, dirt variant, grassy clearing/edge, stone paving and mossy stone.

## Godot 4 import setup

1. Copy this folder into `res://assets/tilesets/forest/ground/`.
2. Select all PNG files in the FileSystem dock.
3. In Import, set **Filter** off and **Mipmaps** off for crisp pixel art.
4. Set compression to Lossless, then Reimport.
5. Create a `TileSet` resource and set Tile Size to `32 × 32`.
6. Add each PNG as a separate Atlas Source (or combine them into a purpose-built atlas after visual QA).
7. Use nearest-neighbor filtering in project rendering settings.

## Important limitations

- These are prototype samples cropped/resized from generated concept art. They are not a production-ready seamless autotile set.
- The 32×32 size is the logical tile size; source detail was downscaled, so inspect pixel clarity at native size.
- Do not assume the edges tile seamlessly. Test a 10×10 patch before using them in a large map.
- The current `dirt_grassy_edge.png` is a clearing/edge-style sample, not a complete 16/47-tile terrain transition set.
- No collision shapes are included. Add collision only to solid props/cliffs, not ground tiles.

## Recommended next production step

Create a dedicated grass↔dirt transition set (center, four edges, four outer corners, four inner corners), then validate all combinations in Godot. Keep water, cliffs and props in separate sources.
