# Word Magic — Forest Terrain Transitions (Reference v1)

This package contains a generated visual reference sheet for the forest terrain transition pass.

## Included
- `forest_terrain_transitions_reference.png` — 1536x1024 RGB concept atlas.

## Important production notes
- The checkerboard visible in the image is part of the RGB pixels; it is NOT transparency.
- The image is not a validated 32x32 tile atlas. Individual pieces have varying sizes and spacing.
- Do not import this image as a production TileSet or assume tiles will autotile seamlessly.
- Use it as an art-direction reference while creating clean, hand-aligned 32x32 tiles.

## Recommended Godot 4 setup for the production version
- Tile size: 32x32 logical pixels.
- Texture filter: Nearest.
- Mipmaps: disabled for pixel art.
- Build terrain transitions with a consistent 3x3 / bitmask layout and test every edge and corner combination.
- Keep collision shapes separate from the texture atlas.
