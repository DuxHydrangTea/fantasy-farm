using Godot;
using System.Collections.Generic;
namespace FantasyFarm.Characters;

[GlobalClass]
public partial class StateMachine : Node
{
    [Signal]
    public delegate void StateChangedEventHandler(State? from, State to);

    [Export]
    public State? InitialState
    {
        get; set;
    }

    [Export]
    public State? DefaultState
    {
        get; set;
    }

    public State? CurrentState
    {
        get; private set;
    }

    private readonly Dictionary<StateId, State> _states = new();

    public void Initialize(CharacterBase actor)
    {
        foreach (var child in GetChildren())
            if (child is State state)
            {
                _states.Add(state.Id, state);
                state.Setup(actor, this);
            }
        DefaultState ??= InitialState;
        if (InitialState is null)
        {
            GD.PushWarning($"{actor.Name}: no initial state");
            return;
        }
        TransitionTo(InitialState);
    }

    public override void _Process(double delta) => CurrentState?.Update(delta);

    public override void _PhysicsProcess(double delta) => CurrentState?.PhysicsUpdate(delta);

    public void ChangeState(StateId id)
    {
        if (_states.TryGetValue(id, out var state))
            TransitionTo(state);
        else
            GD.PushWarning($"Missing state {id}");
    }

    public void ChangeToDefault()
    {
        if (DefaultState is not null)
            TransitionTo(DefaultState);
    }

    public void TransitionTo(State target)
    {
        if (CurrentState == target)
            return;
        var previous = CurrentState;
        previous?.Exit();
        CurrentState = target;
        target.Enter();
        EmitSignal(SignalName.StateChanged, previous is null ? default(Variant) : Variant.From(previous), target);
    }

    public override void _ExitTree()
    {
        CurrentState?.Exit();
        CurrentState = null;
    }
}
