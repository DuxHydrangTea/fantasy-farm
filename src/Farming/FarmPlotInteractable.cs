using Godot;
using FantasyFarm.Core;
using FantasyFarm.Data;
using FantasyFarm.Interactions;
namespace FantasyFarm.Farming;

[GlobalClass]
public partial class FarmPlotInteractable : Interactable
{
    private FarmPlot _plot = null!;

    public override void _Ready() => _plot = GetParent<FarmPlot>();

    public override ActionContext? PrepareAction(ItemSlot? slot, IInventoryStore<ItemDefinition>? inventory)
    {
        if (_plot.IsMature())
            return inventory is not null && _plot.Crop!.HasValidHarvest() ? new ActionContext(this, ActionKind.Harvest, slot, inventory) : null;
        if (slot is null || slot.IsEmpty())
            return null;
        var item = slot.Item!;
        if (item.ItemType == ItemCategory.Seed && !_plot.HasCrop() && item.Crop?.IsValid() == true)
            return new(this, ActionKind.Plant, slot, inventory, "tool");
        if (item.ItemType == ItemCategory.Tool && item.ToolType == ItemDefinition.ToolKind.WateringCan)
            return new(this, ActionKind.WaterSoil, slot, inventory, "water");
        return null;
    }

    public override bool Interact(ActionContext context)
    {
        switch (context.Kind)
        {
            case ActionKind.Plant:
                if (context.Slot is null || context.Slot.IsEmpty() || context.Item?.Crop is null || context.Item.ItemType != ItemCategory.Seed || _plot.HasCrop())
                    return false;
                if (!_plot.Plant(context.Item.Crop))
                    return false;
                return context.Slot.ConsumeSeed();
            case ActionKind.WaterSoil:
                return _plot.Water();
            case ActionKind.Harvest:
                var crop = _plot.Crop;
                if (!_plot.IsMature() || crop?.HasValidHarvest() != true || context.Inventory is null || !context.Inventory.TryAdd(crop.HarvestItem, crop.HarvestAmount))
                    return false;
                return _plot.Harvest();
            default:
                return false;
        }
    }
}
