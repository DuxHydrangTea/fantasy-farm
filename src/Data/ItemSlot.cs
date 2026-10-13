using Godot;
using FantasyFarm.Core;
namespace FantasyFarm.Data;

[Tool, GlobalClass]
public partial class ItemSlot : Resource
{
    public ItemStack<ItemDefinition> Model { get; } = new();

    [Export]
    public ItemDefinition? Item
    {
        get => Model.Item; set => Model.Item = value;
    }

    [Export(PropertyHint.Range, "0,32000")]
    public int Quantity
    {
        get => Model.Quantity; set => Model.Quantity = value;
    }

    public ItemSlot()
    {
        Model.Changed += EmitChanged;
    }

    public bool IsEmpty() => Model.IsEmpty;

    public bool SetItem(ItemDefinition? item, int amount = 1) => Model.Set(item, amount);

    public bool Consume(int amount = 1) => Model.Consume(amount);

    public bool ConsumeSeed(int amount = 1) => Item?.ItemType == ItemCategory.Seed && Consume(amount);
}
