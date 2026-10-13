using Godot;
using FantasyFarm.Data;
using FantasyFarm.Characters;
namespace FantasyFarm.Animals;

[GlobalClass]
public partial class Chicken : CharacterBase
{
    [Export]
    public AnimalDefinition? Definition
    {
        get; set;
    }

    public override void _Ready()
    {
        base._Ready();
        GetNode<AnimalNeedsComponent>("AnimalNeedsComponent").Initialize(Definition);
    }
}
