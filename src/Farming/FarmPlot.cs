using Godot;
using FantasyFarm.Core;
using FantasyFarm.Data;
using FantasyFarm.Interactions;
namespace FantasyFarm.Farming;

[Tool, GlobalClass]
public partial class FarmPlot : Node2D
{
    [Export]
    public Texture2D DryTexture { get; set; } = null!;

    [Export]
    public Texture2D WetTexture { get; set; } = null!;

    public StringName PlotId { get; set; } = "";

    public CropDefinition? Crop
    {
        get; private set;
    }

    public CropProgress Progress { get; } = new();

    private Sprite2D _soil = null!, _plant = null!;
    private ProgressBar _bar = null!;
    private FocusComponent _focus = null!;
    private bool _focused;
    private StyleBox _normal = null!;
    private StyleBoxFlat _mature = null!;

    public override void _Ready()
    {
        _soil = GetNode<Sprite2D>("SoilSprite");
        _plant = GetNode<Sprite2D>("CropSprite");
        _bar = GetNode<ProgressBar>("CropSprite/GrowthBar");
        _bar.Hide();
        _normal = _bar.GetThemeStylebox("fill");
        _mature = new StyleBoxFlat { BgColor = new Color("#34eb4c") };
        if (Engine.IsEditorHint())
        {
            SetProcess(false);
            return;
        }
        _focus = GetNode<FocusComponent>("FocusComponent");
        _focus.FocusChanged += SetFocused;
        Refresh();
    }

    public override void _Process(double delta)
    {
        if (!Engine.IsEditorHint())
        {
            Progress.Advance(delta);
            Refresh();
        }
    }

    public bool Plant(CropDefinition? crop)
    {
        if (Engine.IsEditorHint() || crop is null || !crop.IsValid() || !Progress.Plant(crop.GrowthSeconds))
            return false;
        Crop = crop;
        Refresh();
        return true;
    }

    public bool Water()
    {
        if (Engine.IsEditorHint() || !Progress.Water())
            return false;
        Refresh();
        return true;
    }

    public bool IsMature() => Progress.Mature;

    public bool HasCrop() => Crop is not null;

    public bool Harvest()
    {
        if (Engine.IsEditorHint() || !Progress.Harvest())
            return false;
        Crop = null;
        Refresh();
        return true;
    }

    public void SetFocused(bool focused)
    {
        _focused = focused;
        RefreshBar();
    }

    private void Refresh()
    {
        _soil.Texture = Progress.Wet ? WetTexture : DryTexture;
        _plant.Visible = Crop is not null;
        _plant.Texture = Crop is null ? null : Crop.StageTextures[Progress.Stage];
        RefreshBar();
        SetProcess((HasCrop() && !IsMature()) || Progress.Wet);
    }

    private void RefreshBar()
    {
        if (!_focused || Crop is null)
        {
            _bar.Hide();
            return;
        }
        _bar.Value = Progress.Elapsed / Crop.GrowthSeconds * 100;
        _bar.AddThemeStyleboxOverride("fill", IsMature() ? _mature : _normal);
        _bar.Show();
    }

    public override void _ExitTree()
    {
        if (GodotObject.IsInstanceValid(_focus))
            _focus.FocusChanged -= SetFocused;
    }
}
