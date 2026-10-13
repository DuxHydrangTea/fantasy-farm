using Godot;
namespace FantasyFarm.World;

[Tool]
public partial class BuildingVariant : StaticBody2D
{
    protected virtual string[] Textures => System.Array.Empty<string>();

    protected virtual int[] Frames => System.Array.Empty<int>();

    protected virtual string Labels => "";

    private int _variant;

    [Export]
    public int Variant
    {
        get => _variant; set
        {
            _variant = value;
            UpdateSprite();
        }
    }

    public override void _Ready() => UpdateSprite();

    public override void _ValidateProperty(Godot.Collections.Dictionary property)
    {
        if (property["name"].AsString() == nameof(Variant))
        {
            property["hint"] = (int)PropertyHint.Enum;
            property["hint_string"] = Labels;
        }
    }

    private void UpdateSprite()
    {
        var sprite = GetNodeOrNull<Sprite2D>("Sprite2D");
        if (sprite is null || Variant < 0 || Variant >= Textures.Length)
            return;
        sprite.Texture = GD.Load<Texture2D>(Textures[Variant]);
        if (Frames.Length > Variant)
            sprite.Frame = Frames[Variant];
    }
}
