using Godot;
using System;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using FantasyFarm.Data;
using FantasyFarm.Core;
using FantasyFarm.Farming;
using FantasyFarm.Characters;
using FantasyFarm.Interactions;
using FantasyFarm.UI;
using FantasyFarm.Animals;
using FileAccess = Godot.FileAccess;
namespace FantasyFarm.Tools;
public static class ProjectChecks
{
    private static int _checks;
    private static void Check(bool condition, string message)
    { if (!condition) throw new InvalidOperationException(message); _checks++; }
    public static async Task Run(Node host)
    {
        _checks = 0;
        int resources = 0, scenes = 0;
        var loadedResources = new System.Collections.Generic.List<Resource>();
        foreach (var directory in new[] { "crops", "items", "animals", "icons", "sprite_frames", "tilesets", "weather" })
            foreach (string file in Directory.EnumerateFiles(ProjectSettings.GlobalizePath("res://"+directory), "*.tres",SearchOption.AllDirectories))
            {
                string path = "res://" + Path.GetRelativePath(ProjectSettings.GlobalizePath("res://"),file).Replace('\\','/');
                var resource = GD.Load<Resource>(path); Check(resource is not null,$"Cannot load {path}"); ResourceGenerator.ValidateResource(resource!); loadedResources.Add(resource!);
                if (resource is CropDefinition crop) Check(crop.IsValid() && crop.HasValidHarvest(), $"Invalid crop {path}");
                if (resource is AnimalDefinition animal) Check(animal.IsValid(),$"Invalid animal {path}");
                if (resource is AnimalProductionDefinition production) Check(production.IsValid(),$"Invalid production {path}");
                resources++;
            }
        foreach (string file in Directory.EnumerateFiles(ProjectSettings.GlobalizePath("res://scenes"),"*.tscn",SearchOption.AllDirectories))
        {
            string path = "res://" + Path.GetRelativePath(ProjectSettings.GlobalizePath("res://"),file).Replace('\\','/');
            var scene = GD.Load<PackedScene>(path); Check(scene is not null,$"Cannot load scene {path}"); loadedResources.Add(scene!);
            var root = scene!.Instantiate(); Check(root is not null,$"Cannot instantiate scene {path}"); root!.Free(); scenes++;
        }
        using (var recipes = JsonDocument.Parse(FileAccess.GetFileAsString("res://tools/data/resource_recipes.json")))
        {
            foreach (var entry in recipes.RootElement.GetProperty("resources").EnumerateArray())
            {
                string path = entry.GetProperty("path").GetString()!;
                var resource = GD.Load<Resource>(path);
                foreach (var prop in entry.GetProperty("value").GetProperty("props").EnumerateArray())
                {
                    string key = prop[0].GetString()!;
                    bool custom = resource is ItemDefinition or CropDefinition or AnimalDefinition or AnimalProductionDefinition;
                    if (custom && key != "resource_name" && !key.StartsWith("metadata/")) key = ResourceGenerator.Pascal(key);
                    var expected = prop[1]; var actual = resource.Get(key);
                    if (expected.ValueKind == JsonValueKind.Number) Check(Math.Abs(actual.AsDouble()-expected.GetDouble()) < 0.00001,$"Changed numeric data {path}:{key}");
                    else if (expected.ValueKind == JsonValueKind.String) Check(actual.AsString()==expected.GetString(),$"Changed text data {path}:{key}");
                    else if (expected.ValueKind is JsonValueKind.True or JsonValueKind.False) Check(actual.AsBool()==expected.GetBoolean(),$"Changed boolean data {path}:{key}");
                }
            }
        }
        new ResourceGenerator().ValidateSheets();
        var world = GD.Load<PackedScene>("res://scenes/world.tscn").Instantiate<Node2D>(); host.AddChild(world);
        for (int i=0;i<3;i++) await host.ToSignal(host.GetTree(),SceneTree.SignalName.ProcessFrame);
        var inventory = world.GetNode<Inventory.Inventory>("Inventory"); Check(inventory.Slots.Length==16,"Inventory slot count");
        var player = world.GetNode<Player>("Player"); var bar = player.UIController.Hotbar;
        Check(player.StateMachine.CurrentState is IdleState,"Player initial state");
        Check(bar.GetSelectedSlot() is not null,"Hotbar initialized");
        player.UIController.ToggleInventory(); Check(player.UIController.IsInventoryOpen(),"Inventory opens");
        player.UseSelectedItem(); Check(player.StateMachine.CurrentState is IdleState,"Inventory blocks tool action");
        player.UIController.ToggleInventory(); Check(!player.UIController.IsInventoryOpen(),"Inventory closes");
        var land = world.GetNode<FarmLand>("MapContainer/FarmLand"); var plot = land.GetChildren().OfType<FarmPlot>().First();
        Check(land.GetChildren().OfType<FarmPlot>().Count()==land.Rows*land.Cols,"Farm grid count");
        land.CreateGrid(); Check(land.GetChildren().OfType<FarmPlot>().Count()==land.Rows*land.Cols,"Farm grid rebuild count"); plot=land.GetChildren().OfType<FarmPlot>().First();
        var seed = GD.Load<ItemDefinition>("res://items/seeds/wheat_seed.tres");
        player.GetNode<PlayerInputController>("PlayerInputController").SetPhysicsProcess(false);
        bar.SelectSlot(0); bar.Slots[0].SetItem(seed,2);
        var focus = player.GetNode<InteractionFocusComponent>("InteractionFocusComponent");
        var plotFocus = plot.GetNode<FocusComponent>("FocusComponent");
        player.GlobalPosition = plotFocus.GlobalPosition;
        focus.EmitSignal(Area2D.SignalName.AreaEntered,plotFocus);
        player.UseSelectedItem();
        Check(player.StateMachine.CurrentState is ToolState && !plot.HasCrop() && bar.Slots[0].Quantity==2,"Tool animation delays planting until effect frame");
        var toolState=player.GetNode<ToolState>("StateMachine/ToolState");
        player.AnimationComponent.AnimatedSprite.Frame=toolState.ImpactFrame;
        Check(plot.HasCrop() && bar.Slots[0].Quantity==1,"Effect frame plants and consumes once");
        player.AnimationComponent.AnimatedSprite.Frame=toolState.ImpactFrame+1;
        Check(bar.Slots[0].Quantity==1 && focus.Locked,"Later frames cannot repeat planting");
        player.StateMachine.ChangeState(StateId.Idle);
        Check(!focus.Locked,"Tool exit unlocks focus");
        plot._Process(seed.Crop!.GrowthSeconds+5); plot.Harvest();
        var slot = new ItemSlot(); Check(slot.SetItem(seed,2),"Seed slot setup");
        var plant = Interactable.PrepareFor(plot,slot,inventory.Store); Check(plant is not null && plant.Kind==ActionKind.Plant,"Plant action prepared");
        Check(plant!.ExecuteOnce() && slot.Quantity==1 && plot.HasCrop(),"Plant consumes one seed"); Check(!plant.ExecuteOnce() && slot.Quantity==1,"Plant cannot execute twice");
        Check(Interactable.PrepareFor(plot,slot,inventory.Store) is null,"Occupied plot rejects seed");
        var water = GD.Load<ItemDefinition>("res://items/tools/watering_can.tres"); var waterSlot = new ItemSlot(); waterSlot.SetItem(water);
        var watering = Interactable.PrepareFor(plot,waterSlot,inventory.Store)!;
        double elapsed = plot.Progress.Elapsed; Check(watering.ExecuteOnce(),"Water soil"); Check(Math.Abs(plot.Progress.Elapsed-elapsed-seed.Crop!.GrowthSeconds*0.05)<0.001,"Water adds five percent");
        Check(!plot.Water(),"Wet plot cannot be watered again"); plot._Process(seed.Crop.GrowthSeconds+5); Check(plot.IsMature(),"Crop reaches maturity");
        var produce = seed.Crop.HarvestItem!;
        inventory.AddItem(produce,produce.StackLimit*16);
        var harvest = Interactable.PrepareFor(plot,null,inventory.Store)!; Check(!harvest.ExecuteOnce() && plot.HasCrop(),"Full inventory keeps crop");
        foreach(var stack in inventory.Slots) if(!stack.IsEmpty()) stack.Consume(stack.Quantity);
        harvest=Interactable.PrepareFor(plot,null,inventory.Store)!; Check(harvest.ExecuteOnce() && !plot.HasCrop(),"Harvest clears crop after accepting produce");
        Check(inventory.Slots.Sum(x=>x.Quantity)==seed.Crop.HarvestAmount,"Exact harvest amount"); Check(!harvest.ExecuteOnce(),"Harvest cannot duplicate produce");
        var stale = Interactable.PrepareFor(plot,slot,inventory.Store)!; slot.SetItem(water); Check(!stale.ExecuteOnce() && !plot.HasCrop(),"Changed item cancels prepared action");
        var doomed=GD.Load<PackedScene>("res://scenes/farm_plot.tscn").Instantiate<FarmPlot>(); host.AddChild(doomed); slot.SetItem(seed); var deleted=Interactable.PrepareFor(doomed,slot,inventory.Store)!; doomed.Free(); Check(!deleted.ExecuteOnce(),"Freed target cancels action");
        var second=GD.Load<PackedScene>("res://scenes/world.tscn").Instantiate<Node2D>();host.AddChild(second);
        await host.ToSignal(host.GetTree(),SceneTree.SignalName.ProcessFrame);
        var secondBar=second.GetNode<Player>("Player").UIController.Hotbar;
        Check(bar.Slots[0]!=secondBar.Slots[0],"Hotbar instances own runtime slots");
        var firstQuantity=bar.Slots[0].Quantity; secondBar.Slots[0].Quantity+=1; Check(bar.Slots[0].Quantity==firstQuantity,"Slot mutation is isolated");
        var needs=world.FindChildren("AnimalNeedsComponent","",true,false).OfType<AnimalNeedsComponent>().ToArray();
        Check(needs.Length>0 && needs.All(n=>n.Model.Initialized),"Animal needs initialize in world");
        var trough=world.FindChildren("*","",true,false).OfType<FeedTrough>().First(); int free=trough.GetFreeCapacity(); Check(trough.AddFood(free+1)==free && trough.GetFreeCapacity()==0,"Feed trough clamps capacity"); Check(trough.TryConsume(1),"Feed trough consumption");
        var waterTrough=world.FindChildren("*","",true,false).OfType<WaterTrough>().First(); free=waterTrough.GetFreeCapacity();Check(waterTrough.AddWater(free+1)==free && waterTrough.GetFreeCapacity()==0,"Water trough clamps capacity");
        second.QueueFree(); world.QueueFree();
        await host.ToSignal(host.GetTree(),SceneTree.SignalName.ProcessFrame);
        await host.ToSignal(host.GetTree(),SceneTree.SignalName.ProcessFrame);
        GC.KeepAlive(loadedResources);
        GD.Print($"PASS: {_checks} checks; {resources} resources, {scenes} scenes; farming, inventory, UI, animal needs and lifecycle exercised.");
    }
}
