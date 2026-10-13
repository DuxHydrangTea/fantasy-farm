using Godot;
namespace FantasyFarm.Data;

[Tool, GlobalClass]
public partial class AnimalDefinition : Resource
{
    [Export]
    public StringName AnimalId { get; set; } = "";

    [Export]
    public string DisplayName { get; set; } = "";

    [Export]
    public AnimalSpecies Species
    {
        get; set;
    }

    [ExportGroup("Growth")]
    [Export(PropertyHint.Range, "0,86400")]
    public double MaturitySeconds { get; set; } = 120;

    [ExportGroup("Needs")]
    [Export(PropertyHint.Range, "1,86400")]
    public double SatietyDepletionSeconds { get; set; } = 600;

    [Export(PropertyHint.Range, "1,86400")]
    public double HydrationDepletionSeconds { get; set; } = 600;

    [Export(PropertyHint.Range, "1,32000")]
    public int FoodPerMeal { get; set; } = 1;

    [Export(PropertyHint.Range, "1,32000")]
    public int WaterPerDrink { get; set; } = 1;

    [ExportGroup("Production")]
    [Export]
    public AnimalProductionDefinition? Production
    {
        get; set;
    }

    [ExportGroup("Visuals")]
    [Export]
    public SpriteFrames? AdultFrames
    {
        get; set;
    }

    [Export]
    public SpriteFrames? JuvenileFrames
    {
        get; set;
    }

    public bool IsValid() => !AnimalId.IsEmpty && MaturitySeconds >= 0 && SatietyDepletionSeconds > 0 && HydrationDepletionSeconds > 0 && FoodPerMeal > 0 && WaterPerDrink > 0 && AdultFrames is not null && (Production is null || Production.IsValid());
}
