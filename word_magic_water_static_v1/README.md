# Word Magic — Forest Water Static Reference v1

This package contains a generated concept/reference atlas for the forest water system.

## Contents
- `forest_water_static_reference.png`: 1536x1024 generated water/shore/river/waterfall/prop reference atlas.

## Important status
This is a visual reference, NOT a production-ready Godot TileSet.
The image contains a painted background and irregularly sized assets. Do not slice it on a guessed 32x32 grid or treat the background as transparency. The source has an alpha channel, but the rendered background is still visible; alpha presence alone does not mean the background is cleanly transparent.

## Recommended next production steps
1. Recreate/clean individual water tiles on a strict 32x32 logical grid.
2. Build shore autotile transitions (straight edges, inner corners, outer corners).
3. Validate seamless adjacency in a Godot test map.
4. Add animated water as separate frame sequences; keep static terrain and animation layers separate.
5. Create waterfall top/middle/bottom pieces and foam animation independently.

## Godot import guidance
- Use nearest-neighbor filtering for pixel art.
- Disable mipmaps for pixel-art tiles.
- Keep water visuals separate from collision geometry.
- Use TileSet terrain painting only after edge/corner variants have been validated.
