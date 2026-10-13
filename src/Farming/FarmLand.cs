using Godot;
namespace FantasyFarm.Farming;

[Tool, GlobalClass]
public partial class FarmLand : Node2D
{
    private PackedScene? _plotScene;
    private int _rows = 6, _cols = 6;
    private Vector2 _gap = new(16, 16);
    private bool _pending;

    [Export]
    public PackedScene? PlotScene
    {
        get => _plotScene; set
        {
            _plotScene = value;
            RequestRebuild();
        }
    }

    [Export]
    public int Rows
    {
        get => _rows; set
        {
            _rows = value;
            RequestRebuild();
        }
    }

    [Export]
    public int Cols
    {
        get => _cols; set
        {
            _cols = value;
            RequestRebuild();
        }
    }

    [Export]
    public Vector2 Gap
    {
        get => _gap; set
        {
            _gap = value;
            RequestRebuild();
        }
    }

    public override void _Ready() => RequestRebuild();

    private void RequestRebuild()
    {
        if (!IsNodeReady() || _pending)
            return;
        _pending = true;
        Callable.From(CreateGrid).CallDeferred();
    }

    public void CreateGrid()
    {
        _pending = false;
        if (!IsInsideTree())
            return;
        foreach (var child in GetChildren())
            if (child.HasMeta("generated_plot"))
            {
                RemoveChild(child);
                child.QueueFree();
            }
        if (PlotScene is null)
            return;
        for (int row = 0; row < Rows; row++)
            for (int col = 0; col < Cols; col++)
            {
                var plot = PlotScene.Instantiate<FarmPlot>();
                plot.PlotId = $"plot_{col}_{row}";
                plot.Position = new Vector2(col * Gap.X + 8, row * Gap.Y + 16);
                plot.SetMeta("generated_plot", true);
                AddChild(plot);
            }
    }
}
