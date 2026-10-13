using Godot;
namespace FantasyFarm.Characters;

[GlobalClass]
public partial class IdleState : State
{
    public override void Enter() => Animation.Play("idle");

    public override void PhysicsUpdate(double delta)
    {
        Movement.Move(Vector2.Zero, delta);
        if (Actor.HasMoveIntent())
            Machine.ChangeState(StateId.Walk);
    }
}
