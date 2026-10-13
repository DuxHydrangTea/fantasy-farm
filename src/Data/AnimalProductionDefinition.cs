using Godot;
namespace FantasyFarm.Data;

[Tool, GlobalClass]
public partial class AnimalProductionDefinition : Resource
{
    public enum CollectionKind
    {
        WorldDrop,
        DirectInteraction
    }

    [Export]
    public ItemDefinition? ProductionItem
    {
        get; set;
    }

    [Export(PropertyHint.Range, "1,32000")]
    public int ProductionAmount { get; set; } = 1;

    [Export(PropertyHint.Range, "1,86400")]
    public double ProductionSeconds { get; set; } = 1;

    [Export]
    public CollectionKind CollectionMode
    {
        get; set;
    }

    public bool IsValid() => ProductionItem?.ItemType == Core.ItemCategory.Produce && ProductionAmount > 0 && ProductionSeconds > 0;
}
