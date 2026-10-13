using Godot;
using FantasyFarm.Characters;
namespace FantasyFarm.Animals;

[GlobalClass]
public partial class ChickenActionState : State
{
    private enum Phase
    {
        Start,
        Hold,
        Finish
    }

    [Export]
    public string StartAction { get; set; } = "";

    [Export]
    public string HoldAction { get; set; } = "";

    [Export]
    public string FinishAction { get; set; } = "";

    [Export(PropertyHint.Range, "0,60")]
    public double HoldSeconds
    {
        get; set;
    }

    private Phase _phase;
    private double _remaining;
    private bool _connected;

    public override void Enter()
    {
        Actor.MovementVector = Vector2.Zero;
        Movement.Stop();
        Animation.ActionFinished += OnFinished;
        _connected = true;
        if (StartAction.Length == 0)
            BeginHold();
        else
        {
            _phase = Phase.Start;
            Animation.Play(StartAction, true);
        }
    }

    private void OnFinished(string action)
    {
        if (Machine.CurrentState != this)
            return;
        if (_phase == Phase.Start && action == StartAction)
            BeginHold();
        else if (_phase == Phase.Finish && action == FinishAction)
            Machine.ChangeToDefault();
    }

    private void BeginHold()
    {
        _phase = Phase.Hold;
        _remaining = HoldSeconds;
        if (HoldAction.Length > 0)
            Animation.Play(HoldAction, true);
        if (_remaining <= 0)
            BeginFinish();
    }

    private void BeginFinish()
    {
        if (FinishAction.Length == 0)
            Machine.ChangeToDefault();
        else
        {
            _phase = Phase.Finish;
            Animation.Play(FinishAction, true);
        }
    }

    public override void Update(double delta)
    {
        if (_phase != Phase.Hold)
            return;
        _remaining = System.Math.Max(0, _remaining - delta);
        if (_remaining <= 0)
            BeginFinish();
    }

    public override void PhysicsUpdate(double delta) => Movement.Stop();

    public override void Exit()
    {
        if (_connected)
        {
            Animation.ActionFinished -= OnFinished;
            _connected = false;
        }
    }
}
