using Godot;
using System;
using System.Linq;
using System.Text.Json;
using System.IO;
namespace FantasyFarm.Tools;
public static class ObjectSceneGenerator
{
    public static int Generate(string outputRoot, bool overwrite)
    {
        using var index = JsonDocument.Parse(Godot.FileAccess.GetFileAsString("res://docs/object_scenes_index.json"));
        int saved = 0;
        foreach (var entry in index.RootElement.GetProperty("scenes").EnumerateArray())
        {
            string original = entry.GetProperty("scene").GetString()!, output = ResourceGenerator.OutputPath(original, outputRoot);
            if (Godot.FileAccess.FileExists(output) && !overwrite) continue;
            var visual = GD.Load<Resource>(entry.GetProperty("source").GetString()!);
            var options = new Godot.Collections.Array<Texture2D>();
            foreach (var path in entry.GetProperty("texture_options").EnumerateArray()) options.Add(GD.Load<Texture2D>(path.GetString()!));
            if (entry.GetProperty("atlas_cells").GetArrayLength() > 0)
            {
                var rect = entry.GetProperty("atlas_cells");
                visual = new AtlasTexture { Atlas = (Texture2D)visual, Region = new Rect2(rect[0].GetSingle()*16, rect[1].GetSingle()*16, rect[2].GetSingle()*16, rect[3].GetSingle()*16), FilterClip = true };
            }
            string animation = entry.GetProperty("animation").GetString()!;
            Texture2D texture = visual is SpriteFrames frames ? frames.GetFrameTexture(animation, 0) : (Texture2D)visual;
            var bounds = texture.GetImage().GetUsedRect();
            foreach (var option in options) bounds = bounds.Merge(option.GetImage().GetUsedRect());
            if (bounds.Size == Vector2I.Zero) throw new InvalidOperationException($"Empty initial visual: {original}");
            bool movable = entry.GetProperty("body").GetString() == "CharacterBody2D";
            PhysicsBody2D body = movable ? new CharacterBody2D() : new StaticBody2D();
            try
            {
                body.Name = ResourceGenerator.Pascal(Path.GetFileNameWithoutExtension(original)); body.TextureFilter = CanvasItem.TextureFilterEnum.Nearest;
                body.SetMeta("object_id", entry.GetProperty("object_id").GetString()!); body.SetMeta("object_kind", entry.GetProperty("kind").GetString()!); body.SetMeta("source_visual", entry.GetProperty("source").GetString()!);
                if (options.Count > 0) body.SetMeta(entry.GetProperty("kind").GetString() == "berry_bush" ? "appearance_textures" : "growth_textures", options);
                Node2D sprite;
                if (visual is SpriteFrames animatedFrames)
                    sprite = new AnimatedSprite2D { Name = "AnimatedSprite2D", SpriteFrames = animatedFrames, Animation = animation, Autoplay = animatedFrames.GetAnimationLoopMode(animation) != SpriteFrames.LoopMode.None ? animation : "" };
                else sprite = new Sprite2D { Name = "Sprite2D", Texture = texture };
                sprite.Position = new Vector2(0, texture.GetHeight()*0.5f - bounds.End.Y); body.AddChild(sprite); sprite.Owner = body;
                if (entry.GetProperty("has_collision").GetBoolean())
                {
                    var shape = new RectangleShape2D { Size = movable ? new Vector2(10,4) : new Vector2(Mathf.Max(4,bounds.Size.X*0.7f),Mathf.Clamp(bounds.Size.Y*0.2f,3,12)) };
                    var collision = new CollisionShape2D { Name = "CollisionShape2D", Shape = shape, Disabled = true, Position = new Vector2(0,-shape.Size.Y*0.5f) };
                    body.AddChild(collision); collision.Owner = body;
                }
                var packed = new PackedScene(); var error = packed.Pack(body);
                if (error != Error.Ok) throw new IOException($"Pack {original}: {error}");
                ResourceGenerator.Save(packed, output); saved++;
            }
            finally { body.Free(); }
        }
        return saved;
    }
    public static int RemoveVisualCollisions()
    {
        using var index = JsonDocument.Parse(Godot.FileAccess.GetFileAsString("res://docs/object_scenes_index.json")); int saved = 0;
        foreach (var entry in index.RootElement.GetProperty("scenes").EnumerateArray())
        {
            if (entry.GetProperty("has_collision").GetBoolean()) continue;
            string path = entry.GetProperty("scene").GetString()!;
            var root = GD.Load<PackedScene>(path).Instantiate();
            try
            {
                bool changed = false;
                foreach (var collision in root.GetChildren().OfType<CollisionShape2D>().ToArray())
                { if (collision.GetChildCount() > 0) throw new InvalidOperationException($"Collider has children: {path}"); root.RemoveChild(collision); collision.Free(); changed = true; }
                if (!changed) continue;
                var packed = new PackedScene(); if (packed.Pack(root) != Error.Ok) throw new IOException(path); ResourceGenerator.Save(packed,path); saved++;
            }
            finally { root.Free(); }
        }
        return saved;
    }
}