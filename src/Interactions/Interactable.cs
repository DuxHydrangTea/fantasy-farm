using Godot;
using FantasyFarm.Data;
using FantasyFarm.Core;
namespace FantasyFarm.Interactions;

[GlobalClass]
public partial class Interactable : Node, IInteractable
{
    public virtual ActionContext? PrepareAction(ItemSlot? slot, IInventoryStore<ItemDefinition>? inventory) => null;

    public virtual bool Interact(ActionContext context) => false;

    public static ActionContext? PrepareFor(Node? target, ItemSlot? slot, IInventoryStore<ItemDefinition>? inventory)
    {
        if (GodotObject.IsInstanceValid(target) && target!.GetNodeOrNull<Node>("Interactable") is IInteractable component)
        {
            var prepared = component.PrepareAction(slot, inventory);
            if (prepared is not null)
                return prepared;
        }
        if (slot is null || slot.IsEmpty())
            return null;
        return slot.Item!.ItemType is ItemCategory.Tool or ItemCategory.Hoe ? new ActionContext(null, ActionKind.Swing, slot, inventory, "tool") : null;
    }
}
