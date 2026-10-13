using Godot;
using System;
using System.Linq;
using System.Collections.Generic;
using FantasyFarm.Data;
using FantasyFarm.Core;
namespace FantasyFarm.UI;

[GlobalClass]
public partial class Hotbar : HBoxContainer
{
    [Signal]
    public delegate void SlotSelectedEventHandler(int index);

    [Export]
    public Godot.Collections.Array<ItemSlot> Slots { get; set; } = new();

    public int SelectedIndex { get; private set; } = -1;

    public IInventoryStore<ItemDefinition> Store { get; private set; } = null!;

    private readonly List<ItemSlotView> _buttons = new();
    private readonly List<Action> _handlers = new();

    public override void _Ready()
    {
        var scene = GD.Load<PackedScene>("res://scenes/item_slot_view.tscn");
        for (int i = 0; i < Slots.Count; i++)
        {
            var config = Slots[i];
            var slot = new ItemSlot();
            if (config is not null && !config.IsEmpty() && !slot.SetItem(config.Item, config.Quantity))
                GD.PushError($"Invalid hotbar quantity in slot {i}");
            Slots[i] = slot;
            var button = scene.Instantiate<ItemSlotView>();
            button.FocusMode = FocusModeEnum.None;
            int index = i;
            button.Pressed += () => SelectSlot(index);
            AddChild(button);
            _buttons.Add(button);
            Action handler = () => RefreshSlot(index);
            _handlers.Add(handler);
            slot.Model.Changed += handler;
            RefreshSlot(i);
        }
        Store = new InventoryStore<ItemDefinition>(Slots.Select(s => s.Model).ToArray(), item => item.ItemType != ItemCategory.Produce);
        if (Slots.Count > 0)
            SelectSlot(0);
    }

    public void SelectSlot(int index)
    {
        if (index < 0 || index >= Slots.Count || SelectedIndex == index)
            return;
        int previous = SelectedIndex;
        SelectedIndex = index;
        if (previous >= 0)
            RefreshSlot(previous);
        RefreshSlot(index);
        EmitSignal(SignalName.SlotSelected, index);
    }

    private void RefreshSlot(int index)
    {
        _buttons[index].ThemeTypeVariation = index == SelectedIndex ? "SelectedItemSlotButton" : "ItemSlotButton";
        _buttons[index].DisplaySlot(Slots[index]);
    }

    public ItemSlot? GetSelectedSlot() => SelectedIndex >= 0 && SelectedIndex < Slots.Count ? Slots[SelectedIndex] : null;

    public bool TryAddItem(ItemDefinition? item, int amount) => Store.TryAdd(item, amount);

    public override void _ExitTree()
    {
        for (int i = 0; i < _handlers.Count; i++)
            Slots[i].Model.Changed -= _handlers[i];
    }
}
