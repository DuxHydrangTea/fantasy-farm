using Godot;
namespace FantasyFarm.Characters;

[GlobalClass]
public partial class MovementComponent : Node
{
    [Export]
    public float Speed { get; set; } = 150;

    [Export]
    public float Acceleration { get; set; } = 1200;

    [Export]
    public float Friction { get; set; } = 1600;

    private CharacterBody2D _body = null!;

    public override void _Ready()
    {
        _body = GetParent<CharacterBody2D>();
    }

    public void Move(Vector2 direction, double delta)
    {
        var target = direction.LimitLength() * Speed;
        _body.Velocity = _body.Velocity.MoveToward(target, (direction.IsZeroApprox() ? Friction : Acceleration) * (float)delta);
        _body.MoveAndSlide();
    }

    public void Stop()
    {
        _body.Velocity = Vector2.Zero;
    }
}
