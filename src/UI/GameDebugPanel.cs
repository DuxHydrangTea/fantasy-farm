using Godot;
namespace FantasyFarm.UI;

[GlobalClass]
public partial class GameDebugPanel : PanelContainer
{
    [Export]
    public Inventory.Inventory Inventory { get; set; } = null!;

    public override async void _Ready()
    {
        if (!OS.IsDebugBuild())
        {
            Hide();
            return;
        }
        var status = GetNode<Label>("MarginContainer/VBoxContainer/Status");
        if (!GodotObject.IsInstanceValid(Inventory))
        {
            status.Text = "Chưa gán Inventory";
            return;
        }
        if (!Inventory.IsNodeReady())
            await ToSignal(Inventory, Node.SignalName.Ready);
        if (!IsInsideTree())
            return;
        var button = new Button { Text = "+10.000 wheat", FocusMode = FocusModeEnum.None, MouseDefaultCursorShape = CursorShape.PointingHand };
        button.AddThemeFontSizeOverride("font_size", 6);
        button.Pressed += () => { int remaining = Inventory.AddItem(GD.Load<Data.ItemDefinition>("res://items/harvest_produces/wheat_produces.tres"), 10000); status.Text = remaining == 0 ? "Thêm thành công" : "Thêm thành công nhưng không đủ chỗ"; };
        GetNode<VBoxContainer>("MarginContainer/VBoxContainer/Actions").AddChild(button);
    }
}
