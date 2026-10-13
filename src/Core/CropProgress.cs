using System;
namespace FantasyFarm.Core;

public sealed class CropProgress
{
    public double Duration
    {
        get; private set;
    }

    public double Elapsed
    {
        get; private set;
    }

    public double WetRemaining
    {
        get; private set;
    }

    public bool HasCrop => Duration > 0;

    public bool Mature => HasCrop && Elapsed >= Duration;

    public bool Wet => WetRemaining > 0;

    public int Stage => !HasCrop ? -1 : Mature ? 3 : Math.Clamp((int)(Elapsed / Duration * 3), 0, 2);

    public bool Plant(double duration)
    {
        if (HasCrop || !double.IsFinite(duration) || duration <= 0)
            return false;
        Duration = duration;
        Elapsed = 0;
        return true;
    }

    public void Advance(double seconds)
    {
        if (!double.IsFinite(seconds) || seconds <= 0)
            return;
        WetRemaining = Math.Max(0, WetRemaining - seconds);
        if (HasCrop && !Mature)
            Elapsed = Math.Min(Duration, Elapsed + seconds);
    }

    public bool Water(double wetDuration = 5)
    {
        if (Wet)
            return false;
        WetRemaining = wetDuration;
        if (HasCrop && !Mature)
            Elapsed = Math.Min(Duration, Elapsed + Duration * 0.05);
        return true;
    }

    public bool Harvest()
    {
        if (!Mature)
            return false;
        Duration = 0;
        Elapsed = 0;
        return true;
    }
}
public sealed class ActionGate
{
    public bool Attempted
    {
        get; private set;
    }

    public bool Execute(Func<bool> action)
    {
        if (Attempted)
            return false;
        Attempted = true;
        return action();
    }
}
