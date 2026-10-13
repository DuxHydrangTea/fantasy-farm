using Godot;
using FantasyFarm.Core;
using FantasyFarm.Data;
using FantasyFarm.Interactions;
namespace FantasyFarm.Animals;

[GlobalClass]
public partial class FeedTroughInteractable : Interactable
{
    [Export(PropertyHint.Range, "1,32000")]
    public int RefillAmount { get; set; } = 100;

    private FeedTrough _trough = null!;

    public override void _Ready() => _trough = GetParent<FeedTrough>();

    public override ActionContext? PrepareAction(ItemSlot? slot, IInventoryStore<ItemDefinition>? inventory)
    {
        return slot is not null && !slot.IsEmpty() && slot.Item!.ItemType == ItemCategory.Feed && slot.Item.FoodUnitsPerItem > 0 && _trough.GetFreeCapacity() > 0 ? new(this, ActionKind.FillFeed, slot, inventory, "tool") : null;
    }

    public override bool Interact(ActionContext context)
    {
        if (context.Kind != ActionKind.FillFeed || context.Item is null || context.Slot is null)
            return false;
        int amount = System.Math.Min(context.Item.FoodUnitsPerItem, _trough.GetFreeCapacity());
        return amount > 0 && context.Slot.Consume() && _trough.AddFood(amount) > 0;
    }
}
