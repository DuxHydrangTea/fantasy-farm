using Godot;
namespace FantasyFarm.World;

[Tool, GlobalClass]
public partial class FishermanHouse : BuildingVariant
{
    protected override string[] Textures => new[] { "res://assets/Buildings/Buildings/Unique_Buildings/Fisherman_House/Fisherman_House_Base_Black.png", "res://assets/Buildings/Buildings/Unique_Buildings/Fisherman_House/Fisherman_House_Base_Blue.png", "res://assets/Buildings/Buildings/Unique_Buildings/Fisherman_House/Fisherman_House_Base_Red.png", "res://assets/Buildings/Buildings/Unique_Buildings/Fisherman_House/Fisherman_House_Green_Black.png", "res://assets/Buildings/Buildings/Unique_Buildings/Fisherman_House/Fisherman_House_Green_Blue.png", "res://assets/Buildings/Buildings/Unique_Buildings/Fisherman_House/Fisherman_House_Green_Red.png", "res://assets/Buildings/Buildings/Unique_Buildings/Fisherman_House/Fisherman_House_Red_Black.png", "res://assets/Buildings/Buildings/Unique_Buildings/Fisherman_House/Fisherman_House_Red_Blue.png", "res://assets/Buildings/Buildings/Unique_Buildings/Fisherman_House/Fisherman_House_Red_Red.png" };

    protected override int[] Frames => new int[] { 0, 0, 0, 0, 0, 0, 0, 0, 0 };

    protected override string Labels => "BASE_BLACK,BASE_BLUE,BASE_RED,GREEN_BLACK,GREEN_BLUE,GREEN_RED,RED_BLACK,RED_BLUE,RED_RED";
}
