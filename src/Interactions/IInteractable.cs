using FantasyFarm.Data;
using FantasyFarm.Core;
namespace FantasyFarm.Interactions;

public enum ActionKind
{
    Swing,
    Plant,
    WaterSoil,
    FillWater,
    FillFeed,
    Harvest
}
public interface IInteractable
{
    ActionContext? PrepareAction(ItemSlot? slot, IInventoryStore<ItemDefinition>? inventory);

    bool Interact(ActionContext context);
}
