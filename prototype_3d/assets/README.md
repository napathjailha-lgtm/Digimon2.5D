# Main Tamer Model

Copy the supplied `masaru.fbx` file into this folder so the final path is `prototype_3d/assets/masaru.fbx`.

The player script loads this FBX as the main tamer and normalizes its mesh height to approximately 1.8 Godot units. If the FBX is absent or cannot be instantiated as a PackedScene, the prototype falls back to its simple placeholder model.

Open the project in Godot 4 and allow the FBX importer to finish before pressing Play. Check the imported model's facing direction and materials in the running scene; imported rig/animation tracks may need retargeting before they can be used for locomotion.