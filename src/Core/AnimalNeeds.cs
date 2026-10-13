using System;
namespace FantasyFarm.Core;

public sealed class AnimalNeeds
{
    public double Satiety { get; private set; } = 100;

    public double Hydration { get; private set; } = 100;

    public double Threshold { get; set; } = 100;

    public bool Initialized
    {
        get; private set;
    }

    public bool Hungry => Satiety <= Threshold;

    public bool Thirsty => Hydration <= Threshold;

    public bool CanGrow => Initialized && Satiety > 0 && Hydration > 0;

    private double _satietyDuration, _hydrationDuration;
    public event Action? Changed;
    public event Action? FlagsChanged;

    public bool Initialize(double satietyDuration, double hydrationDuration, double satiety, double hydration)
    {
        if (!double.IsFinite(satietyDuration) || !double.IsFinite(hydrationDuration) || satietyDuration <= 0 || hydrationDuration <= 0)
            return false;
        _satietyDuration = satietyDuration;
        _hydrationDuration = hydrationDuration;
        Satiety = Math.Clamp(satiety, 0, 100);
        Hydration = Math.Clamp(hydration, 0, 100);
        Initialized = true;
        Changed?.Invoke();
        FlagsChanged?.Invoke();
        return true;
    }

    public void Advance(double seconds)
    {
        if (!Initialized || !double.IsFinite(seconds) || seconds <= 0)
            return;
        Set(Satiety - 100 / _satietyDuration * seconds, Hydration - 100 / _hydrationDuration * seconds);
    }

    public void RestoreFood()
    {
        if (Initialized)
            Set(100, Hydration);
    }

    public void RestoreWater()
    {
        if (Initialized)
            Set(Satiety, 100);
    }

    private void Set(double food, double water)
    {
        var oldHungry = Hungry;
        var oldThirsty = Thirsty;
        food = Math.Clamp(food, 0, 100);
        water = Math.Clamp(water, 0, 100);
        if (Satiety == food && Hydration == water)
            return;
        Satiety = food;
        Hydration = water;
        Changed?.Invoke();
        if (oldHungry != Hungry || oldThirsty != Thirsty)
            FlagsChanged?.Invoke();
    }
}
