using Godot;
namespace FantasyFarm.Characters;

[GlobalClass]
public partial class Controller : Node, ICharacterController
{
    public CharacterBase Actor { get; private set; } = null!;

    public override void _Ready()
    {
        Actor = GetParent<CharacterBase>();
        ProcessPhysicsPriority = -10;
    }
}
