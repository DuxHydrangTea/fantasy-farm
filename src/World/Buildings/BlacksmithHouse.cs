using Godot;
namespace FantasyFarm.World;

[Tool, GlobalClass]
public partial class BlacksmithHouse : BuildingVariant
{
    protected override string[] Textures => new[] { "res://assets/Buildings/Buildings/Unique_Buildings/Blacksmith_House/Blacksmith_House_Black.png", "res://assets/Buildings/Buildings/Unique_Buildings/Blacksmith_House/Blacksmith_House_Blue.png", "res://assets/Buildings/Buildings/Unique_Buildings/Blacksmith_House/Blacksmith_House_Red.png" };

    protected override int[] Frames => new int[] { 0, 0, 0 };

    protected override string Labels => "BLACK,BLUE,RED";
}
