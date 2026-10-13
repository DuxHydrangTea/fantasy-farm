using Godot;
namespace FantasyFarm.Characters;

[GlobalClass]
public partial class PlayerInputController : Controller
{
    [Export]
    public StringName ActionLeft { get; set; } = "ui_left";

    [Export]
    public StringName ActionRight { get; set; } = "ui_right";

    [Export]
    public StringName ActionUp { get; set; } = "ui_up";

    [Export]
    public StringName ActionDown { get; set; } = "ui_down";

    [Export]
    public StringName ActionUseItem { get; set; } = "use_item";

    [Export]
    public StringName ActionToggleInventory { get; set; } = "toggle_inventory";

    private Player _player = null!;
    private static readonly string[] HotbarActions = { "hotbar_1", "hotbar_2", "hotbar_3", "hotbar_4", "hotbar_5", "hotbar_6", "hotbar_7", "hotbar_8", "hotbar_9", "hotbar_0" };

    public override void _Ready()
    {
        base._Ready();
        _player = (Player)Actor;
    }

    public override void _PhysicsProcess(double delta) => Actor.MovementVector = _player.UIController.IsInventoryOpen() ? Vector2.Zero : Input.GetVector(ActionLeft, ActionRight, ActionUp, ActionDown);

    public override void _UnhandledKeyInput(InputEvent @event)
    {
        if (@event.IsEcho())
            return;
        for (int i = 0; i < HotbarActions.Length; i++)
            if (@event.IsActionPressed(HotbarActions[i]))
            {
                _player.UIController.SelectHotbarSlot(i);
                GetViewport().SetInputAsHandled();
                return;
            }
        if (@event.IsActionPressed(ActionUseItem))
        {
            _player.UseSelectedItem();
            GetViewport().SetInputAsHandled();
        }
    }

    public override void _Input(InputEvent @event)
    {
        if (!@event.IsEcho() && @event.IsActionPressed(ActionToggleInventory))
        {
            _player.UIController.ToggleInventory();
            GetViewport().SetInputAsHandled();
        }
    }
}
