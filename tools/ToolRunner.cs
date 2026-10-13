using Godot;
using System;
using System.Linq;
namespace FantasyFarm.Tools;
public partial class ToolRunner : Node
{
    public override async void _Ready()
    {
        int exit = 0;
        try
        {
            var args = OS.GetCmdlineUserArgs(); string command = args.FirstOrDefault() ?? "validate";
            string Option(string key, string fallback) => args.FirstOrDefault(x => x.StartsWith(key + "=", StringComparison.Ordinal))?.Substring(key.Length+1) ?? fallback;
            string root = Option("--output-root", "res://.godot/generator-check"); bool overwrite = args.Contains("--overwrite");
            switch (command)
            {
                case "validate": await ProjectChecks.Run(this); break;
                case "generate": GD.Print($"Generated {new ResourceGenerator().Generate(Option("--group","all"),root,overwrite)} resources"); break;
                case "objects": GD.Print($"Generated {ObjectSceneGenerator.Generate(root,overwrite)} object scenes"); break;
                case "house-decor": GD.Print($"Generated {ResourceGenerator.GenerateHouseDecor(root,overwrite)} TileSet"); break;
                case "merge": GD.Print($"Merged {ResourceGenerator.MergeTilesets(root,overwrite)} atlas sources"); break;
                case "animate": GD.Print($"Updated {TileSetTools.AnimateDecor(Option("--kind","grass"),root,overwrite)} animated sheets"); break;
                case "buildings": GD.Print($"Updated {TileSetTools.Buildings(root,overwrite)} building atlas sources"); break;
                case "collisions": GD.Print($"Updated {ObjectSceneGenerator.RemoveVisualCollisions()} scenes"); break;
                default: throw new ArgumentException($"Unknown command {command}");
            }
        }
        catch (Exception error) { GD.PushError(error.ToString()); exit = 1; }
        GetTree().Quit(exit);
    }
}
