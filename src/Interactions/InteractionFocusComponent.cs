using Godot;
using System.Collections.Generic;
using FantasyFarm.Characters;
namespace FantasyFarm.Interactions;

[GlobalClass]
public partial class InteractionFocusComponent : Area2D
{
    [Export(PropertyHint.Range, "0.05,1")]
    public double UpdateInterval { get; set; } = 0.1;

    [Export(PropertyHint.Range, "0,32")]
    public float FacingWeight { get; set; } = 12;

    [Export(PropertyHint.Range, "0,16")]
    public float SwitchMargin { get; set; } = 4;

    public bool Active { get; set; } = true;

    public bool Locked
    {
        get; set;
    }

    private CharacterBase _actor = null!;
    private readonly List<FocusComponent> _candidates = new();
    private FocusComponent? _focused;
    private double _elapsed;

    public override void _Ready()
    {
        _actor = GetParent<CharacterBase>();
        AreaEntered += OnEntered;
        AreaExited += OnExited;
    }

    public override void _ExitTree()
    {
        AreaEntered -= OnEntered;
        AreaExited -= OnExited;
        SetFocused(null);
    }

    public override void _PhysicsProcess(double delta)
    {
        if (!Active)
        {
            _elapsed = 0;
            SetFocused(null);
            return;
        }
        if (Locked)
            return;
        _elapsed += delta;
        if (_elapsed < UpdateInterval)
            return;
        _elapsed = 0;
        RefreshFocus();
    }

    private static bool Eligible(FocusComponent? candidate) => GodotObject.IsInstanceValid(candidate) && candidate!.FocusEnabled && GodotObject.IsInstanceValid(candidate.GetInteractionTarget());

    public void RefreshFocus()
    {
        if (!Active || Locked)
            return;
        FocusComponent? best = null;
        float bestScore = float.PositiveInfinity;
        for (int i = _candidates.Count - 1; i >= 0; i--)
        {
            var candidate = _candidates[i];
            if (!GodotObject.IsInstanceValid(candidate))
            {
                _candidates.RemoveAt(i);
                continue;
            }
            if (!Eligible(candidate))
                continue;
            var score = Score(candidate);
            if (score < bestScore)
            {
                best = candidate;
                bestScore = score;
            }
        }
        if (best is not null && best != _focused && Eligible(_focused) && _candidates.Contains(_focused!) && bestScore >= Score(_focused!) - SwitchMargin)
            return;
        SetFocused(best);
    }

    private float Score(FocusComponent candidate)
    {
        var offset = candidate.GlobalPosition - GlobalPosition;
        float distance = offset.Length();
        return distance < 0.001f ? 0 : distance - _actor.AnimationComponent.FacingVector.Dot(offset / distance) * FacingWeight;
    }

    private void SetFocused(FocusComponent? next)
    {
        if (_focused == next)
            return;
        if (GodotObject.IsInstanceValid(_focused))
            _focused!.SetFocused(false);
        _focused = next;
        if (GodotObject.IsInstanceValid(next))
            next!.SetFocused(true);
    }

    private void OnEntered(Area2D area)
    {
        if (area is FocusComponent focus && !_candidates.Contains(focus))
            _candidates.Add(focus);
    }

    private void OnExited(Area2D area)
    {
        if (area is FocusComponent focus)
        {
            _candidates.Remove(focus);
            if (_focused == focus)
                SetFocused(null);
        }
    }

    public Node2D? GetFocusedTarget() => Active && Eligible(_focused) ? _focused!.GetInteractionTarget() : null;
}
