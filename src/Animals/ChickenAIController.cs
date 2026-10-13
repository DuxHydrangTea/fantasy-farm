using Godot;
using FantasyFarm.Characters;
namespace FantasyFarm.Animals;

[GlobalClass]
public partial class ChickenAIController : Controller
{
    [Export]
    public Area2D WanderArea { get; set; } = null!;

    [Export(PropertyHint.Range, "0,32")]
    public float BoundaryMargin { get; set; } = 8;

    private CollisionShape2D _boundary = null!;
    private Rect2 _bounds;
    private Timer _timer = null!;

    public override void _Ready()
    {
        base._Ready();
        _boundary = WanderArea.GetNode<CollisionShape2D>("CollisionShape2D");
        var shape = (RectangleShape2D)_boundary.Shape;
        _bounds = new Rect2(-shape.Size / 2, shape.Size).Grow(-BoundaryMargin);
        if (_bounds.Size.X <= 0 || _bounds.Size.Y <= 0)
            throw new System.InvalidOperationException("Wander margin exceeds bounds");
        ProcessPhysicsPriority = 10;
        _timer = GetNode<Timer>("Timer");
        _timer.OneShot = true;
        _timer.Timeout += Choose;
        _timer.Start(1);
    }

    private void Choose()
    {
        _timer.Start(GD.RandRange(2, 4));
        if (Actor.StateMachine.CurrentState is not (WalkState or IdleState))
            return;
        switch (GD.Randi() % 5)
        {
            case 0:
                Actor.MovementVector = Vector2.Zero;
                Actor.StateMachine.ChangeState(StateId.Idle);
                break;
            case 1:
                Actor.MovementVector = Vector2.FromAngle((float)GD.RandRange(0, Mathf.Tau));
                Actor.StateMachine.ChangeState(StateId.Walk);
                break;
            case 2:
                Actor.StateMachine.ChangeState(StateId.Peck);
                break;
            case 3:
                Actor.StateMachine.ChangeState(StateId.Rest);
                break;
            case 4:
                Actor.StateMachine.ChangeState(StateId.Sleep);
                break;
        }
    }

    public override void _PhysicsProcess(double delta)
    {
        var local = _boundary.ToLocal(Actor.GlobalPosition);
        var limited = new Vector2(Mathf.Clamp(local.X, _bounds.Position.X, _bounds.End.X), Mathf.Clamp(local.Y, _bounds.Position.Y, _bounds.End.Y));
        if (local.IsEqualApprox(limited))
            return;
        Actor.GlobalPosition = _boundary.ToGlobal(limited);
        Actor.MovementComponent.Stop();
        if (Actor.StateMachine.CurrentState is not WalkState)
        {
            Actor.MovementVector = Vector2.Zero;
            return;
        }
        var direction = Actor.MovementVector;
        if (local.X < _bounds.Position.X)
            direction.X = Mathf.Abs(direction.X);
        else if (local.X > _bounds.End.X)
            direction.X = -Mathf.Abs(direction.X);
        if (local.Y < _bounds.Position.Y)
            direction.Y = Mathf.Abs(direction.Y);
        else if (local.Y > _bounds.End.Y)
            direction.Y = -Mathf.Abs(direction.Y);
        Actor.MovementVector = direction.Normalized();
        Actor.AnimationComponent.Face(Actor.MovementVector);
    }

    public override void _ExitTree()
    {
        if (GodotObject.IsInstanceValid(_timer))
            _timer.Timeout -= Choose;
    }
}
