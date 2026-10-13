using Godot;
using FantasyFarm.Characters;
namespace FantasyFarm.UI;

[GlobalClass]
public partial class PlayerUIComponent : Node
{
    [Signal]
    public delegate void InventoryOpenChangedEventHandler(bool isOpen);

    [Export]
    public Hotbar Hotbar { get; set; } = null!;

    [Export]
    public InventoryPanel InventoryPanel { get; set; } = null!;

    [Export]
    public BaseButton InventoryButton { get; set; } = null!;

    private CharacterBase _actor = null!;

    public override void _Ready()
    {
        _actor = GetParent<CharacterBase>();
        InventoryButton.Pressed += ToggleInventory;
        InventoryPanel.VisibilityChanged += OnVisibleChanged;
    }

    public bool IsInventoryOpen() => InventoryPanel.Visible;

    public void ToggleInventory()
    {
        if (!IsInventoryOpen() && _actor.StateMachine.CurrentState is not (IdleState or WalkState))
            return;
        InventoryPanel.Toggle();
    }

    private void OnVisibleChanged()
    {
        bool open = IsInventoryOpen();
        if (open)
            _actor.MovementVector = Vector2.Zero;
        EmitSignal(SignalName.InventoryOpenChanged, open);
    }

    public void SelectHotbarSlot(int index)
    {
        if (!IsInventoryOpen())
            Hotbar.SelectSlot(index);
    }

    public override void _ExitTree()
    {
        if (GodotObject.IsInstanceValid(InventoryButton))
            InventoryButton.Pressed -= ToggleInventory;
        if (GodotObject.IsInstanceValid(InventoryPanel))
            InventoryPanel.VisibilityChanged -= OnVisibleChanged;
    }
}
