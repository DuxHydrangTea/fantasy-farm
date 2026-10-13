using Godot;
namespace FantasyFarm.World;

[Tool, GlobalClass]
public partial class Greenhouse : BuildingVariant
{
    protected override string[] Textures => new[] { "res://assets/Buildings/Buildings/Unique_Buildings/Greenhouse/GreenHouse_Green.png", "res://assets/Buildings/Buildings/Unique_Buildings/Greenhouse/GreenHouse_Green.png", "res://assets/Buildings/Buildings/Unique_Buildings/Greenhouse/GreenHouse_Green.png", "res://assets/Buildings/Buildings/Unique_Buildings/Greenhouse/GreenHouse_Green.png", "res://assets/Buildings/Buildings/Unique_Buildings/Greenhouse/GreenHouse_Metal.png", "res://assets/Buildings/Buildings/Unique_Buildings/Greenhouse/GreenHouse_Metal.png", "res://assets/Buildings/Buildings/Unique_Buildings/Greenhouse/GreenHouse_Metal.png", "res://assets/Buildings/Buildings/Unique_Buildings/Greenhouse/GreenHouse_Metal.png", "res://assets/Buildings/Buildings/Unique_Buildings/Greenhouse/GreenHouse_Wood.png", "res://assets/Buildings/Buildings/Unique_Buildings/Greenhouse/GreenHouse_Wood.png", "res://assets/Buildings/Buildings/Unique_Buildings/Greenhouse/GreenHouse_Wood.png", "res://assets/Buildings/Buildings/Unique_Buildings/Greenhouse/GreenHouse_Wood.png" };

    protected override int[] Frames => new int[] { 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3 };

    protected override string Labels => "GREEN_FRAME_1,GREEN_FRAME_2,GREEN_FRAME_3,GREEN_FRAME_4,METAL_FRAME_1,METAL_FRAME_2,METAL_FRAME_3,METAL_FRAME_4,WOOD_FRAME_1,WOOD_FRAME_2,WOOD_FRAME_3,WOOD_FRAME_4";
}
