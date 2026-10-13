using System;
using System.Collections.Generic;
namespace FantasyFarm.Core;

public enum ItemCategory
{
    Tool,
    Seed,
    Produce,
    Feed,
    Hoe
}
public interface IItemSpec
{
    ItemCategory Category
    {
        get;
    }

    int StackLimit
    {
        get;
    }
}
public interface IInventoryStore<T> where T : class, IItemSpec
{
    IReadOnlyList<ItemStack<T>> Stacks
    {
        get;
    }

    int Add(T? item, int amount);

    bool TryAdd(T? item, int amount);
}
public sealed class ItemStack<T> where T : class, IItemSpec
{
    public T? Item
    {
        get; set;
    }

    public int Quantity
    {
        get; set;
    }

    public bool IsEmpty => Item is null || Quantity <= 0;

    public event Action? Changed;

    public bool Set(T? item, int amount)
    {
        if (item is null || amount <= 0 || amount > item.StackLimit)
            return false;
        Item = item;
        Quantity = amount;
        Changed?.Invoke();
        return true;
    }

    public bool Consume(int amount)
    {
        if (IsEmpty || amount <= 0 || amount > Quantity)
            return false;
        Quantity -= amount;
        if (Quantity == 0)
            Item = null;
        Changed?.Invoke();
        return true;
    }

    internal void Increase(int amount)
    {
        Quantity += amount;
        Changed?.Invoke();
    }
}
public sealed class InventoryStore<T> : IInventoryStore<T> where T : class, IItemSpec
{
    private readonly Predicate<T> _accepts;

    public IReadOnlyList<ItemStack<T>> Stacks
    {
        get;
    }

    public InventoryStore(IReadOnlyList<ItemStack<T>> stacks, Predicate<T> accepts)
    {
        Stacks = stacks;
        _accepts = accepts;
    }

    public int CapacityFor(T item)
    {
        int total = 0;
        foreach (var slot in Stacks)
            if (slot.IsEmpty)
                total += item.StackLimit;
            else if (ReferenceEquals(slot.Item, item))
                total += Math.Max(0, item.StackLimit - slot.Quantity);
        return total;
    }

    public int Add(T? item, int amount)
    {
        if (item is null || amount <= 0 || !_accepts(item))
            return amount > 0 ? amount : 0;
        var remaining = amount;
        foreach (var slot in Stacks)
        {
            if (slot.IsEmpty || !ReferenceEquals(slot.Item, item))
                continue;
            var accepted = Math.Min(Math.Max(0, item.StackLimit - slot.Quantity), remaining);
            if (accepted > 0)
            {
                slot.Increase(accepted);
                remaining -= accepted;
            }
            if (remaining == 0)
                return 0;
        }
        foreach (var slot in Stacks)
        {
            if (!slot.IsEmpty)
                continue;
            var accepted = Math.Min(item.StackLimit, remaining);
            if (accepted > 0 && slot.Set(item, accepted))
                remaining -= accepted;
            if (remaining == 0)
                return 0;
        }
        return remaining;
    }

    public bool TryAdd(T? item, int amount)
    {
        if (item is null || amount <= 0 || !_accepts(item) || CapacityFor(item) < amount)
            return false;
        return Add(item, amount) == 0;
    }
}
