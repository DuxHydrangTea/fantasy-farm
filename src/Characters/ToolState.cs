using Godot;
namespace FantasyFarm.Characters;

[GlobalClass]
public partial class ToolState : State
{
    [Signal]
    public delegate void ActionStartedEventHandler();
    [Signal]
    public delegate void EffectRequestedEventHandler();
    [Signal]
    public delegate void ActionEndedEventHandler();

    [Export]
    public StringName Action { get; set; } = "tool";

    [Export]
    public int ImpactFrame { get; set; } = 3;

    private bool _effectApplied, _connected;

    public override void Enter()
    {
        _effectApplied = false;
        Movement.Stop();
        Animation.ActionFinished += OnActionFinished;
        Animation.AnimatedSprite.FrameChanged += OnFrameChanged;
        _connected = true;
        EmitSignal(SignalName.ActionStarted);
        Animation.Play(Action.ToString(), true);
        OnFrameChanged();
    }

    private void OnFrameChanged()
    {
        if (Machine.CurrentState != this || _effectApplied || Animation.AnimatedSprite.Frame < ImpactFrame)
            return;
        _effectApplied = true;
        EmitSignal(SignalName.EffectRequested);
    }

    public override void PhysicsUpdate(double delta) => Movement.Stop();

    private void OnActionFinished(string action)
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
        if (!_connected)
            return;
        Animation.ActionFinished -= OnActionFinished;
        Animation.AnimatedSprite.FrameChanged -= OnFrameChanged;
        _connected = false;
        EmitSignal(SignalName.ActionEnded);
    }
}
