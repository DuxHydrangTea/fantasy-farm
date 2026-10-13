using Godot;
namespace FantasyFarm.Characters;

[GlobalClass]
public partial class CharacterBase : CharacterBody2D
{
    public AnimationComponent AnimationComponent { get; private set; } = null!;

    public StateMachine StateMachine { get; private set; } = null!;

    public MovementComponent MovementComponent { get; private set; } = null!;

    public Vector2 MovementVector
    {
        get; set;
    }

    public override void _Ready()
    {
        AnimationComponent = GetNode<AnimationComponent>("AnimationComponent");
        MovementComponent = GetNode<MovementComponent>("MovementComponent");
        StateMachine = GetNode<StateMachine>("StateMachine");
        StateMachine.Initialize(this);
    }

    public bool HasMoveIntent() => MovementVector.LengthSquared() > 0.01f;
}
