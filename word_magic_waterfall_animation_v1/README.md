# Word Magic - Waterfall Animation Reference v1

Contents:
- waterfall_preview.gif: 9-frame looping preview (180 ms/frame).
- waterfall_spritesheet_3x3.png: 3x3 atlas assembled from the GIF frames.
- frames/waterfall_01.png ... waterfall_09.png: individual RGBA frames.

Frame size: 439 x 390 px.

Godot 4 usage:
1. Import the individual PNG frames as textures.
2. Create AnimatedSprite2D and a SpriteFrames resource.
3. Add frames in numerical order to an animation named `default`.
4. Set FPS to approximately 5.56 (180 ms/frame), then tune by eye.
5. Keep the rock/foliage silhouette stationary; only the water column, foam, and pool ripples should animate in a production revision.

Important limitations:
- This is a visual animation prototype, not a 32x32 tile animation.
- The frames are full-scene waterfall illustrations, not modular top/middle/bottom waterfall pieces.
- Check alpha edges and frame alignment in Godot before shipping.
- The checkerboard-looking areas must be inspected for actual alpha; do not assume the preview pattern is transparency.
