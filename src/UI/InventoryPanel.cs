using Godot;
using System.Collections.Generic;
namespace FantasyFarm.UI;

[GlobalClass]
public partial class InventoryPanel : PanelContainer
{
    [Export]
    public Inventory.Inventory Inventory { get; set; } = null!;

    private readonly List<ItemSlotView> _buttons = new();
    private bool _connected;

    public override async void _Ready()
    {
        Hide();
        if (!GodotObject.IsInstanceValid(Inventory))
        {
            GD.PushError("Inventory not assigned");
            return;
        }
        if (!Inventory.IsNodeReady())
            await ToSignal(Inventory, Node.SignalName.Ready);
        if (!IsInsideTree() || !GodotObject.IsInstanceValid(Inventory))
            return;
        var grid = GetNode<GridContainer>("MarginContainer/VBoxContainer/SlotsGrid");
        grid.Columns = 4;
        var scene = GD.Load<PackedScene>("res://scenes/item_slot_view.tscn");
        for (int i = 0; i < Inventory.Slots.Length; i++)
        {
            var button = scene.Instantiate<ItemSlotView>();
            grid.AddChild(button);
            _buttons.Add(button);
            RefreshSlot(i);
        }
        Inventory.SlotChanged += RefreshSlot;
        _connected = true;
    }

    private void RefreshSlot(int index)
    {
        if (GodotObject.IsInstanceValid(Inventory) && index >= 0 && index < _buttons.Count && index < Inventory.Slots.Length)
            _buttons[index].DisplaySlot(Inventory.Slots[index]);
    }

    public void Toggle()
    {
        if (Visible)
            Hide();
        else
        {
            for (int i = 0; i < _buttons.Count; i++)
                RefreshSlot(i);
            Show();
        }
    }

    public override void _ExitTree()
    {
        if (_connected && GodotObject.IsInstanceValid(Inventory))
            Inventory.SlotChanged -= RefreshSlot;
    }
}
