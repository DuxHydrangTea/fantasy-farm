# Legacy setup reference

`create_animal_resources.gd` is preserved as a reference for the game rewrite.
Its old dependencies (`AnimalDefinition`, `AnimalProductionDefination`,
`ItemDefinition`, and `AnimalTypes`) and gameplay resources were intentionally
removed. It cannot run until those definitions are redesigned.

The `.gdignore` file keeps Godot from importing this reference directory.
Move the script back into `tools/setup/` only after updating its dependencies.
