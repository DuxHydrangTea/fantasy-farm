using Godot;
namespace FantasyFarm.World;

[Tool, GlobalClass]
public partial class MarketStalls : BuildingVariant
{
    protected override string[] Textures => new[] { "res://assets/Buildings/Buildings/Unique_Buildings/Stalls/Market_Stalls.png", "res://assets/Buildings/Buildings/Unique_Buildings/Stalls/Market_Stalls.png", "res://assets/Buildings/Buildings/Unique_Buildings/Stalls/Market_Stalls.png", "res://assets/Buildings/Buildings/Unique_Buildings/Stalls/Market_Stalls.png" };

    protected override int[] Frames => new int[] { 0, 1, 2, 3 };

    protected override string Labels => "RED,GREEN,BLUE,ORANGE";
}
