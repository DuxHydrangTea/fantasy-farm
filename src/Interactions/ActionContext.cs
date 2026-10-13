using Godot;
using FantasyFarm.Data;
using FantasyFarm.Core;
namespace FantasyFarm.Interactions;

public sealed class ActionContext
{
    public ActionKind Kind
    {
        get;
    }

    public IInteractable? Target
    {
        get;
    }

    public ItemSlot? Slot
    {
        get;
    }

    public ItemDefinition? Item
    {
        get;
    }

    public IInventoryStore<ItemDefinition>? Inventory
    {
        get;
    }

    public string AnimationAction
    {
        get;
    }

    public bool RequiresAnimation => AnimationAction.Length > 0;

    private readonly ActionGate _gate = new();

    public ActionContext(IInteractable? target, ActionKind kind, ItemSlot? slot, IInventoryStore<ItemDefinition>? inventory, string animation = "")
    {
        Target = target;
        Kind = kind;
        Slot = slot;
        Item = slot?.Item;
        Inventory = inventory;
        AnimationAction = animation;
    }

    public bool ExecuteOnce() => _gate.Execute(() =>
    {
        if (Kind != ActionKind.Harvest && (Slot is null || Slot.IsEmpty() || Item is null || Slot.Item != Item))
            return false;
        if (Kind == ActionKind.Swing)
            return true;
        if (Target is GodotObject obj && !GodotObject.IsInstanceValid(obj))
            return false;
        return Target?.Interact(this) ?? false;
    });
}
