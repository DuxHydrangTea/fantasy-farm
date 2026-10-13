using Godot;
using System;
using System.Linq;
using FantasyFarm.Core;
using FantasyFarm.Data;
namespace FantasyFarm.Inventory;

[GlobalClass]
public partial class Inventory : Node2D
{
    [Signal]
    public delegate void SlotChangedEventHandler(int index);
    public const int SlotCount = 16;

    public ItemSlot[] Slots { get; private set; } = System.Array.Empty<ItemSlot>();

    public IInventoryStore<ItemDefinition> Store { get; private set; } = null!;

    private Action[] _handlers = System.Array.Empty<Action>();

    public override void _Ready()
    {
        Slots = Enumerable.Range(0, SlotCount).Select(_ => new ItemSlot()).ToArray();
        _handlers = new Action[Slots.Length];
        for (int i = 0; i < Slots.Length; i++)
        {
            int index = i;
            _handlers[i] = () => EmitSignal(SignalName.SlotChanged, index);
            Slots[i].Model.Changed += _handlers[i];
        }
        Store = new InventoryStore<ItemDefinition>(Slots.Select(s => s.Model).ToArray(), item => item.ItemType == ItemCategory.Produce);
    }

    public int AddItem(ItemDefinition? item, int amount) => Store.Add(item, amount);

    public bool TryAddItem(ItemDefinition? item, int amount) => Store.TryAdd(item, amount);

    public override void _ExitTree()
    {
        for (int i = 0; i < _handlers.Length; i++)
            Slots[i].Model.Changed -= _handlers[i];
    }
}
