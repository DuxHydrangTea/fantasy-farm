using Godot;
namespace FantasyFarm.World;

public partial class CursorController : Node
{
    public override void _Ready() => Input.SetCustomMouseCursor(GD.Load<Texture2D>("res://assets/Ui/Mouse sprites/Catpaw pointing Mouse icon.png"), Input.CursorShape.PointingHand, new Vector2(16, 3));
}
