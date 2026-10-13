using Godot;
using FantasyFarm.Data;
using FantasyFarm.Core;
namespace FantasyFarm.UI;

[GlobalClass]
public partial class ItemSlotView : Button
{
    private TextureRect _icon = null!;
    private Label _quantity = null!;

    public override void _Ready()
    {
        _icon = GetNode<TextureRect>("Icon");
        _quantity = GetNode<Label>("Quantity");
    }

    public void DisplaySlot(ItemSlot? slot)
    {
        _icon.Texture = null;
        _quantity.Text = "";
        TooltipText = "";
        if (slot is null || slot.IsEmpty())
            return;
        _icon.Texture = slot.Item!.Icon;
        TooltipText = slot.Item.DisplayName;
        if (slot.Item.ItemType != ItemCategory.Tool)
            _quantity.Text = slot.Quantity.ToString();
    }
}
