using Godot;
using FantasyFarm.Data;
namespace FantasyFarm.Animals;

[GlobalClass]
public partial class FeedTrough : StaticBody2D
{
    [Signal]
    public delegate void FoodChangedEventHandler(int amount, int capacity);

    [Export]
    public AnimalSpecies AnimalSpecies
    {
        get; set;
    }

    [Export(PropertyHint.Range, "1,32000")]
    public int Capacity { get; set; } = 32000;

    [Export]
    public Rect2 EmptyRegion { get; set; } = new Rect2(144, 0, 16, 32);

    [Export]
    public Rect2 FilledRegion { get; set; } = new Rect2(96, 0, 16, 32);

    private int _amount;

    [Export(PropertyHint.Range, "0,32000")]
    public int FoodAmount
    {
        get => _amount;
        set
        {
            int next = Mathf.Clamp(value, 0, Capacity);
            if (_amount == next)
                return;
            _amount = next;
            if (IsNodeReady())
            {
                UpdateVisual();
                EmitSignal(SignalName.FoodChanged, _amount, Capacity);
            }
        }
    }

    private Sprite2D _sprite = null!;

    public Marker2D EatPoint { get; private set; } = null!;

    public override void _Ready()
    {
        _sprite = GetNode<Sprite2D>("Sprite2D");
        EatPoint = GetNode<Marker2D>("EatPoint");
        UpdateVisual();
        EmitSignal(SignalName.FoodChanged, _amount, Capacity);
    }

    private void UpdateVisual() => _sprite.RegionRect = _amount > 0 ? FilledRegion : EmptyRegion;

    public int GetFreeCapacity() => System.Math.Max(0, Capacity - _amount);

    public bool HasFood(int amount = 1) => amount > 0 && _amount >= amount;

    public bool TryConsume(int amount)
    {
        if (!HasFood(amount))
            return false;
        FoodAmount -= amount;
        return true;
    }

    public int AddFood(int amount)
    {
        int accepted = System.Math.Min(System.Math.Max(0, amount), GetFreeCapacity());
        if (accepted > 0)
            FoodAmount += accepted;
        return accepted;
    }
}
