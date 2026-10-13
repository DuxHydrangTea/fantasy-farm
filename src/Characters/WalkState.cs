using Godot;
namespace FantasyFarm.Characters;

[GlobalClass]
public partial class WalkState : State
{
    [Export]
    public float Speed { get; set; } = 120;

    public override void Enter()
    {
        Animation.UpdateFacingDirection(Actor.MovementVector);
        Animation.Play("walk");
    }

    public override void PhysicsUpdate(double delta)
    {
        if (!Actor.HasMoveIntent())
        {
            Machine.ChangeToDefault();
            return;
        }
        Animation.Face(Actor.MovementVector);
        Movement.Move(Actor.MovementVector, delta);
    }
}
