using Godot;
namespace FantasyFarm.Characters;

[GlobalClass]
public partial class WaterState : State
{
    [Export]
    public string Action { get; set; } = "water";

    private bool _connected;

    public override void Enter()
    {
        Movement.Stop();
        Animation.ActionFinished += OnFinished;
        _connected = true;
        Animation.Play(Action, true);
    }

    public override void PhysicsUpdate(double delta) => Movement.Stop();

    private void OnFinished(string action)
    {
        if (Machine.CurrentState == this && action == Action)
        {
            if (Actor.HasMoveIntent())
                Machine.ChangeState(StateId.Walk);
            else
                Machine.ChangeToDefault();
        }
    }

    public override void Exit()
    {
        if (_connected)
        {
            Animation.ActionFinished -= OnFinished;
            _connected = false;
        }
    }
}
