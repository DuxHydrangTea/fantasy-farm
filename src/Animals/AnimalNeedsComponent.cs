using Godot;
using FantasyFarm.Data;
using FantasyFarm.Core;
namespace FantasyFarm.Animals;

[GlobalClass]
public partial class AnimalNeedsComponent : Node
{
    [Signal]
    public delegate void NeedsChangedEventHandler(double satiety, double hydration);
    [Signal]
    public delegate void NeedFlagsChangedEventHandler(bool hungry, bool thirsty);

    [Export(PropertyHint.Range, "0,100")]
    public double InitialSatiety { get; set; } = 100;

    [Export(PropertyHint.Range, "0,100")]
    public double InitialHydration { get; set; } = 100;

    [Export(PropertyHint.Range, "0,100")]
    public double SeekThreshold { get; set; } = 100;

    public AnimalNeeds Model { get; } = new();

    private bool _subscribed;

    public bool Initialize(AnimalDefinition? definition)
    {
        if (definition?.IsValid() != true)
        {
            GD.PushError("Invalid animal definition");
            return false;
        }
        Model.Threshold = SeekThreshold;
        if (!_subscribed)
        {
            Model.Changed += OnNeeds;
            Model.FlagsChanged += OnFlags;
            _subscribed = true;
        }
        return Model.Initialize(definition.SatietyDepletionSeconds, definition.HydrationDepletionSeconds, InitialSatiety, InitialHydration);
    }

    private void OnNeeds() => EmitSignal(SignalName.NeedsChanged, Model.Satiety, Model.Hydration);

    private void OnFlags() => EmitSignal(SignalName.NeedFlagsChanged, Model.Hungry, Model.Thirsty);

    public void AdvanceTime(double seconds) => Model.Advance(seconds);

    public void RestoreSatiety() => Model.RestoreFood();

    public void RestoreHydration() => Model.RestoreWater();

    public override void _ExitTree()
    {
        Model.Changed -= OnNeeds;
        Model.FlagsChanged -= OnFlags;
        _subscribed = false;
    }
}
