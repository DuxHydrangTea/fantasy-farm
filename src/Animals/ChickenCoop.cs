using Godot;
using System.Collections.Generic;
namespace FantasyFarm.Animals;

[GlobalClass]
public partial class ChickenCoop : Node2D
{
    [Export(PropertyHint.Range, "0.1,10")]
    public double NeedsTickSeconds { get; set; } = 1;

    private readonly List<AnimalNeedsComponent> _needs = new();
    private double _elapsed;

    public override void _Ready() => Collect(this);

    private void Collect(Node node)
    {
        foreach (var child in node.GetChildren())
        {
            if (child is AnimalNeedsComponent needs)
                RegisterNeeds(needs);
            Collect(child);
        }
    }

    public void RegisterNeeds(AnimalNeedsComponent needs)
    {
        if (GodotObject.IsInstanceValid(needs) && needs.Model.Initialized && !_needs.Contains(needs))
            _needs.Add(needs);
    }

    public override void _Process(double delta)
    {
        _elapsed += delta;
        if (_elapsed < NeedsTickSeconds)
            return;
        double seconds = _elapsed;
        _elapsed = 0;
        for (int i = _needs.Count - 1; i >= 0; i--)
        {
            if (!GodotObject.IsInstanceValid(_needs[i]))
                _needs.RemoveAt(i);
            else
                _needs[i].AdvanceTime(seconds);
        }
    }
}
