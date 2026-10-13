using Godot;
namespace FantasyFarm.Characters;

[GlobalClass]
public partial class State : Node, IState
{
    [Export]
    public StateId Id
    {
        get; set;
    }

    protected CharacterBase Actor { get; private set; } = null!;

    protected StateMachine Machine { get; private set; } = null!;

    protected AnimationComponent Animation => Actor.AnimationComponent;

    protected MovementComponent Movement => Actor.MovementComponent;

    public void Setup(CharacterBase actor, StateMachine machine)
    {
        Actor = actor;
        Machine = machine;
    }

    public virtual void Enter()
    {
    }

    public virtual void Exit()
    {
    }

    public virtual void Update(double delta)
    {
    }

    public virtual void PhysicsUpdate(double delta)
    {
    }
}
