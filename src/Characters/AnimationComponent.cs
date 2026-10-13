using Godot;
using System.Collections.Generic;
namespace FantasyFarm.Characters;

[GlobalClass]
public partial class AnimationComponent : Node
{
    [Signal]
    public delegate void ActionFinishedEventHandler(string action);

    [Export]
    public AnimatedSprite2D AnimatedSprite { get; set; } = null!;

    [Export]
    public StringName FallbackAnimation { get; set; } = "idle_down";

    [Export]
    public bool FlipLeft { get; set; } = true;

    [Export]
    public bool SingleDirection
    {
        get; set;
    }

    [Export]
    public bool SingleDirectionFacesLeft { get; set; } = true;

    public string FacingDirection { get; private set; } = "down";

    public string CurrentAction { get; private set; } = "";

    public Vector2 FacingVector => FacingDirection switch { "up" => Vector2.Up, "left" => Vector2.Left, "right" => Vector2.Right, _ => Vector2.Down };

    private readonly HashSet<string> _warned = new();

    public override void _Ready()
    {
        AnimatedSprite.AnimationFinished += OnAnimationFinished;
    }

    public override void _ExitTree()
    {
        if (GodotObject.IsInstanceValid(AnimatedSprite))
            AnimatedSprite.AnimationFinished -= OnAnimationFinished;
    }

    private void OnAnimationFinished() => EmitSignal(SignalName.ActionFinished, CurrentAction);

    public void Play(string action, bool restart = false)
    {
        if (AnimatedSprite.SpriteFrames is null)
            return;
        CurrentAction = action;
        string direction = FacingDirection;
        bool flip = false;
        if (SingleDirection)
        {
            direction = "down";
            flip = SingleDirectionFacesLeft ? FacingDirection == "right" : FacingDirection == "left";
        }
        else if (direction == "left" && FlipLeft)
        {
            direction = "right";
            flip = true;
        }
        string animation = $"{action}_{direction}";
        if (!AnimatedSprite.SpriteFrames.HasAnimation(animation))
        {
            if (_warned.Add(animation))
                GD.PushWarning($"{GetParent().Name}: missing animation {animation}");
            animation = FallbackAnimation.ToString();
            flip = false;
        }
        AnimatedSprite.FlipH = flip;
        if (!restart && AnimatedSprite.Animation == animation && AnimatedSprite.IsPlaying())
            return;
        if (restart)
            AnimatedSprite.Stop();
        AnimatedSprite.Play(animation);
    }

    public bool UpdateFacingDirection(Vector2 direction)
    {
        if (direction.IsZeroApprox())
            return false;
        string old = FacingDirection;
        if (SingleDirection)
        {
            if (!Mathf.IsZeroApprox(direction.X))
                FacingDirection = direction.X > 0 ? "right" : "left";
        }
        else
        {
            string horizontal = direction.X > 0 ? "right" : "left", vertical = direction.Y > 0 ? "down" : "up";
            if (Mathf.Abs(direction.X) > Mathf.Abs(direction.Y))
                FacingDirection = horizontal;
            else if (Mathf.Abs(direction.Y) > Mathf.Abs(direction.X))
                FacingDirection = vertical;
            else if (FacingDirection != horizontal && FacingDirection != vertical)
                FacingDirection = horizontal;
        }
        return old != FacingDirection;
    }

    public void Face(Vector2 direction)
    {
        if (UpdateFacingDirection(direction) && CurrentAction.Length > 0)
            Play(CurrentAction);
    }
}
