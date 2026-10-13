using Godot;
namespace FantasyFarm.Data;

[Tool, GlobalClass]
public partial class CropDefinition : Resource
{
    [Export]
    public StringName CropId { get; set; } = "";

    [Export]
    public Godot.Collections.Array<Texture2D> StageTextures { get; set; } = new();

    [Export(PropertyHint.Range, "1,86400")]
    public double GrowthSeconds { get; set; } = 1200;

    [Export]
    public ItemDefinition? HarvestItem
    {
        get; set;
    }

    [Export(PropertyHint.Range, "0,32000")]
    public int HarvestAmount { get; set; } = 1;

    public bool IsValid()
    {
        if (GrowthSeconds <= 0 || !double.IsFinite(GrowthSeconds) || StageTextures.Count != 4)
            return false;
        foreach (var texture in StageTextures)
            if (texture is null)
                return false;
        return true;
    }

    public bool HasValidHarvest() => HarvestItem?.ItemType == Core.ItemCategory.Produce && HarvestAmount > 0;
}
