using Godot;
namespace FantasyFarm.World;

[Tool, GlobalClass]
public partial class Inn : BuildingVariant
{
    protected override string[] Textures => new[] { "res://assets/Buildings/Buildings/Unique_Buildings/Inn/Inn_Black.png", "res://assets/Buildings/Buildings/Unique_Buildings/Inn/Inn_Blue.png", "res://assets/Buildings/Buildings/Unique_Buildings/Inn/Inn_Red.png" };

    protected override int[] Frames => new int[] { 0, 0, 0 };

    protected override string Labels => "BLACK,BLUE,RED";
}
