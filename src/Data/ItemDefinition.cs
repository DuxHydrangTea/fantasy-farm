using Godot;
using FantasyFarm.Core;
namespace FantasyFarm.Data;

[Tool, GlobalClass]
public partial class ItemDefinition : Resource, IItemSpec
{
    public enum ToolKind
    {
        Hoe,
        WateringCan
    }

    [Export]
    public StringName ItemId { get; set; } = "";

    [Export]
    public string DisplayName { get; set; } = "";

    [Export]
    public Texture2D? Icon
    {
        get; set;
    }

    private ItemCategory _itemType;

    [Export]
    public ItemCategory ItemType
    {
        get => _itemType; set
        {
            _itemType = value;
            NotifyPropertyListChanged();
        }
    }

    [Export]
    public ToolKind ToolType
    {
        get; set;
    }

    [Export]
    public CropDefinition? Crop
    {
        get; set;
    }

    [Export(PropertyHint.Range, "1,32000")]
    public int MaxStack { get; set; } = 99;

    [Export(PropertyHint.Range, "1,32000")]
    public int FoodUnitsPerItem { get; set; } = 300;

    public ItemCategory Category => ItemType;

    public int StackLimit => ItemType == ItemCategory.Tool ? 1 : MaxStack;

    public override void _ValidateProperty(Godot.Collections.Dictionary property)
    {
        var name = property["name"].AsString();
        bool hide = name switch
        {
            nameof(ToolType) => ItemType != ItemCategory.Tool,
            nameof(Crop) => ItemType != ItemCategory.Seed,
            nameof(FoodUnitsPerItem) => ItemType != ItemCategory.Feed,
            _ => false
        };
        if (hide)
            property["usage"] = property["usage"].AsInt32() & ~(int)PropertyUsageFlags.Editor;
    }
}
