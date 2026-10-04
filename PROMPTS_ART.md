# Final art prompt set

Mode: built-in imagegen. These five outputs are original concept game assets.
The four background calls used transparent_background=false; the character atlas call used transparent_background=true.

## Shared background prompt

Use case: stylized-concept. Asset type: an actual background texture for a Godot 2D mobile top-down RPG, landscape 16:9, ideally 1536x864. Hand-painted anime game environment, polished colorful readable surfaces, crisp controlled detail. Camera high overhead looking down, orthographic, NO horizon or sky. The playable area is an unobstructed continuous flat clearing occupying the central 85% of the canvas, not a narrow path; characters must be able to move over the whole clearing. Put ALL tall objects, walls, dense trees, cliffs and water around the outermost edges only. Flat ground can have subtle grass tufts, leaf litter, paving cracks and unobtrusive small markings. Leave the left and right center edges open as walkable entrances. Broad readable composition at mobile resolution, gentle lighting, muted floor so characters stand out. No characters, monsters, people, text, logos, UI, labels, grids, borders or frame. Do not draw buildings, water, holes, rocks or barriers in the central clearing.

Append the corresponding scene paragraph below for each background call.

### file_island.png

Scene: a lush tropical digital-world island forest clearing with golden sandy and soft green grass ground, tropical foliage and mossy ancient stone fragments at the top and bottom edges, a hint of turquoise sea restricted to the extreme corner. Cheerful early-adventure atmosphere. Central floor light desaturated green and beige.

### server_continent.png

Scene: an ancient desert continent arena clearing, broad ochre sandy flat ground with subtle stone paving patches, distant ruined sandstone arches, palm trees and weathered columns ONLY along the topmost and bottommost edges. Afternoon golden light, faint digital turquoise motifs in decorative border stones. Central floor warm muted tan.

### odaiba.png

Scene: a Tokyo bayside urban plaza at dusk, broad flat pale slate tiled paving, urban greenery benches and modern building facades along the outermost edges, a tiny hint of waterfront railing at the bottom edge. Japanese anime urban adventure aesthetic, soft blue dusk and warm amber window accents. Central floor desaturated cool blue-gray.

### spiral_mountain.png

Scene: a dramatic dark mountain summit arena, broad continuous flat lavender-gray weathered stone floor with shallow non-obstructive spiral engravings. Jagged cliffs, dark angular ruins and glowing violet crystals ONLY at the outermost rim. Eerie purple ambient light, stormy final-chapter mood, no sky visible. Central floor pale desaturated slate-purple.

## Character atlas prompt

Use case: stylized-concept. Asset type: production game character atlas PNG for a 2D top-down mobile RPG, exactly a 4 by 4 grid of sixteen equal cells, canvas 1024x1024, each cell 256x256. Actual fully transparent background with alpha, no white background, no checkerboard painted into image, no text, no gridlines. Every figure is entirely isolated with generous transparent padding, no parts crossing cells, centered horizontally in its own cell, feet at 80% cell height, width under 190px and height under 195px. Style: consistent polished chibi anime RPG sprites viewed from a high three-quarter top-down camera; strong dark outline, cel shaded, readable at 64px, no scenery and no drop shadows. ORIGINAL digital-world-adventure characters, no existing franchise characters. Row 1 left to right: same teen boy tamer in cobalt blue short jacket, dark shorts, orange scarf and small silver wrist device: front-facing, right-facing, back-facing, left-facing. Consistent clothing and hair in all 4. Row 2 left to right: four forms of one original turquoise/orange companion dragon: small cute turquoise baby dragon with orange forehead gem; muscular turquoise horned biped dragon with orange dorsal fins; armored turquoise winged dragon knight with white armor and orange energy core; majestic turquoise dragon champion with golden armor and folded radiant wings. Row 3 left to right: four different ORIGINAL boss archetypes: black violet horned bat demon; golden-brown monkey warlord with magenta scarf; pale vampiric mage in burgundy cloak; sinister purple jester magician with diamond patterned tunic. All 4 complete full-body compact upright sprites, not horror, no extra weapons extending beyond cell. Row 4 left to right: small lime leaf-backed reptile wild monster; small lilac crystal shell crab wild monster; cute turquoise baby dragon NPC; elderly robed sage NPC with white beard and modest blue hat. All complete full-body game sprites; no cropped feet or wings; atlas cell positions must be strictly evenly spaced in a 4x4 grid.

## Output integration

Actual backgrounds are 1672x941 RGB. Actual atlas is 1254x1254 RGBA. Godot scales the background to 1280x720.
Because generation did not produce exact integer grid dimensions, AtlasTexture regions use the detected alpha bounds of the 16 separate figures rather than the requested cell dimensions. PNG pixels are preserved unchanged.
