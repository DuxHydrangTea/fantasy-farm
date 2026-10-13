using Godot;
namespace FantasyFarm.World;

[Tool, GlobalClass]
public partial class Silo : BuildingVariant
{
    protected override string[] Textures => new[] { "res://assets/Buildings/Buildings/Unique_Buildings/Silo/Silo.png" };

    protected override int[] Frames => new int[] { 0 };

    protected override string Labels => "DEFAULT";
}
