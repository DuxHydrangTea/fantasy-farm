using Godot;
using FantasyFarm.Core;
using FantasyFarm.Data;
using FantasyFarm.Interactions;
namespace FantasyFarm.Animals;

[GlobalClass]
public partial class WaterTroughInteractable : Interactable
{
    [Export(PropertyHint.Range, "1,32000")]
    public int RefillAmount { get; set; } = 100;

    private WaterTrough _trough = null!;

    public override void _Ready() => _trough = GetParent<WaterTrough>();

    public override ActionContext? PrepareAction(ItemSlot? slot, IInventoryStore<ItemDefinition>? inventory)
    {
        return slot is not null && !slot.IsEmpty() && slot.Item!.ItemType == ItemCategory.Tool && slot.Item.ToolType == ItemDefinition.ToolKind.WateringCan && _trough.GetFreeCapacity() > 0 ? new(this, ActionKind.FillWater, slot, inventory, "water") : null;
    }

    public override bool Interact(ActionContext context) => context.Kind == ActionKind.FillWater && _trough.AddWater(RefillAmount) > 0;
}
