using Godot;
namespace FantasyFarm.World;

[Tool, GlobalClass]
public partial class Barn : BuildingVariant
{
    protected override string[] Textures => new[] { "res://assets/Buildings/Buildings/Unique_Buildings/Barn/Barn_Base_Black.png", "res://assets/Buildings/Buildings/Unique_Buildings/Barn/Barn_Base_Blue.png", "res://assets/Buildings/Buildings/Unique_Buildings/Barn/Barn_Base_Red.png", "res://assets/Buildings/Buildings/Unique_Buildings/Barn/Barn_Green_Black.png", "res://assets/Buildings/Buildings/Unique_Buildings/Barn/Barn_Green_Blue.png", "res://assets/Buildings/Buildings/Unique_Buildings/Barn/Barn_Green_Red.png", "res://assets/Buildings/Buildings/Unique_Buildings/Barn/Barn_Red_Black.png", "res://assets/Buildings/Buildings/Unique_Buildings/Barn/Barn_Red_Blue.png", "res://assets/Buildings/Buildings/Unique_Buildings/Barn/Barn_Red_Red.png" };

    protected override int[] Frames => new int[] { 0, 0, 0, 0, 0, 0, 0, 0, 0 };

    protected override string Labels => "BASE_BLACK,BASE_BLUE,BASE_RED,GREEN_BLACK,GREEN_BLUE,GREEN_RED,RED_BLACK,RED_BLUE,RED_RED";
}
