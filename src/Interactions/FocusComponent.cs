using Godot;
namespace FantasyFarm.Interactions;

[GlobalClass]
public partial class FocusComponent : Area2D
{
    [Signal]
    public delegate void FocusChangedEventHandler(bool focused);

    [Export]
    public bool FocusEnabled { get; set; } = true;

    [Export(PropertyHint.Range, "0,8")]
    public float BobHeight { get; set; } = 3;

    [Export(PropertyHint.Range, "0.1,1")]
    public double BobDuration { get; set; } = 0.35;

    private Node2D _marker = null!;
    private Sprite2D _pointer = null!;
    private Vector2 _rest;
    private bool _focused;
    private Tween? _tween;

    public override void _Ready()
    {
        _marker = GetNode<Node2D>("FocusMarker");
        _pointer = GetNode<Sprite2D>("FocusMarker/Pointer");
        _rest = _pointer.Position;
        _marker.Hide();
    }

    public Node2D? GetInteractionTarget() => GetParent() as Node2D;

    public void SetFocused(bool value)
    {
        value &= FocusEnabled;
        if (value == _focused)
            return;
        _focused = value;
        _marker.Visible = value;
        StopBobbing();
        if (value)
        {
            _tween = CreateTween().SetLoops().SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
            _tween.TweenProperty(_pointer, "position:y", _rest.Y - BobHeight, BobDuration);
            _tween.TweenProperty(_pointer, "position:y", _rest.Y, BobDuration);
        }
        EmitSignal(SignalName.FocusChanged, value);
    }

    private void StopBobbing()
    {
        _tween?.Kill();
        _tween = null;
        if (GodotObject.IsInstanceValid(_pointer))
            _pointer.Position = _rest;
    }

    public override void _ExitTree() => StopBobbing();
}
