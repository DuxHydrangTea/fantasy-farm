using Godot;
using FantasyFarm.Interactions;
using FantasyFarm.UI;
namespace FantasyFarm.Characters;

[GlobalClass]
public partial class Player : CharacterBase
{
    [Export]
    public Inventory.Inventory Inventory { get; set; } = null!;

    public PlayerUIComponent UIController { get; private set; } = null!;

    private ToolState _toolState = null!;
    private InteractionFocusComponent _focus = null!;
    private ActionContext? _pending;

    public override void _Ready()
    {
        base._Ready();
        _toolState = GetNode<ToolState>("StateMachine/ToolState");
        _focus = GetNode<InteractionFocusComponent>("InteractionFocusComponent");
        UIController = GetNode<PlayerUIComponent>("PlayerUIController");
        _toolState.ActionStarted += OnStarted;
        _toolState.ActionEnded += OnEnded;
        _toolState.EffectRequested += OnEffect;
        UIController.InventoryOpenChanged += OnInventoryChanged;
        OnInventoryChanged(UIController.IsInventoryOpen());
    }

    private void OnStarted() => _focus.Locked = true;

    private void OnEnded()
    {
        _pending = null;
        _focus.Locked = false;
    }

    private void OnEffect() => _pending?.ExecuteOnce();

    private void OnInventoryChanged(bool open) => _focus.Active = !open;

    public override void _ExitTree()
    {
        _pending = null;
        if (GodotObject.IsInstanceValid(_toolState))
        {
            _toolState.ActionStarted -= OnStarted;
            _toolState.ActionEnded -= OnEnded;
            _toolState.EffectRequested -= OnEffect;
        }
        if (GodotObject.IsInstanceValid(UIController))
            UIController.InventoryOpenChanged -= OnInventoryChanged;
    }

    public void UseSelectedItem()
    {
        if (UIController.IsInventoryOpen() || StateMachine.CurrentState is not (IdleState or WalkState))
            return;
        _focus.RefreshFocus();
        var context = Interactable.PrepareFor(_focus.GetFocusedTarget(), UIController.Hotbar.GetSelectedSlot(), Inventory.Store);
        if (context is null)
            return;
        if (!context.RequiresAnimation)
        {
            context.ExecuteOnce();
            return;
        }
        _pending = context;
        _toolState.Action = context.AnimationAction;
        StateMachine.TransitionTo(_toolState);
    }
}
