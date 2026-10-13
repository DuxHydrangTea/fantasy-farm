using Godot;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using FantasyFarm.Data;
using GArray = Godot.Collections.Array;
using GDictionary = Godot.Collections.Dictionary;
using FileAccess = Godot.FileAccess;
namespace FantasyFarm.Tools;
/// <summary>Rebuilds prepared native resources from checked-in, editable recipes.</summary>
public sealed class ResourceGenerator
{
    private readonly JsonDocument _document;
    private readonly Dictionary<string, JsonElement> _recipes;
    private readonly Dictionary<string, Resource> _cache = new();
    public ResourceGenerator()
    {
        _document = JsonDocument.Parse(FileAccess.GetFileAsString("res://tools/data/resource_recipes.json"));
        _recipes = _document.RootElement.GetProperty("resources").EnumerateArray().ToDictionary(x => x.GetProperty("path").GetString()!, x => x.GetProperty("value"));
    }
    public int ValidateSheets()
    {
        int count = 0;
        foreach (var sheet in _document.RootElement.GetProperty("sheets").EnumerateObject())
        {
            var texture = GD.Load<Texture2D>(sheet.Name) ?? throw new InvalidOperationException($"Missing sheet: {sheet.Name}");
            var size = sheet.Value.GetProperty("size");
            if (texture.GetWidth() != size[0].GetInt32() || texture.GetHeight() != size[1].GetInt32() || FileAccess.GetSha256(sheet.Name) != sheet.Value.GetProperty("sha256").GetString())
                throw new InvalidOperationException($"Sheet changed; review recipes before regenerating: {sheet.Name}");
            count++;
        }
        return count;
    }
    public int Generate(string group, string outputRoot, bool overwrite)
    {
        ValidateSheets(); int saved = 0;
        foreach (var pair in _recipes)
        {
            if (group != "all" && !pair.Key.StartsWith("res://" + group + "/", StringComparison.Ordinal)) continue;
            string output = OutputPath(pair.Key, outputRoot);
            if (FileAccess.FileExists(output) && !overwrite) continue;
            var resource = DecodeResource(pair.Value); ValidateResource(resource);
            Save(resource, output); saved++;
        }
        return saved;
    }
    public static string OutputPath(string path, string root)
    {
        if (!root.StartsWith("res://", StringComparison.Ordinal) || root.Contains("..")) throw new ArgumentException("Output root must be a project-local res:// path without '..'");
        return root.TrimEnd('/') + "/" + path.Substring(6);
    }
    public static void Save(Resource resource, string path)
    {
        var error = DirAccess.MakeDirRecursiveAbsolute(path.GetBaseDir());
        if (error == Error.Ok) error = ResourceSaver.Save(resource, path);
        if (error != Error.Ok) throw new IOException($"Cannot save {path}: {error}");
    }
    public static void ValidateResource(Resource resource)
    {
        if (resource is AtlasTexture atlas)
        {
            if (atlas.Atlas is null || atlas.Region.Size.X <= 0 || atlas.Region.Size.Y <= 0 || !new Rect2(Vector2.Zero, atlas.Atlas.GetSize()).Encloses(atlas.Region))
                throw new InvalidOperationException("Invalid atlas region");
        }
        if (resource is SpriteFrames frames)
            foreach (var animation in frames.GetAnimationNames())
                for (int i = 0; i < frames.GetFrameCount(animation); i++)
                    if (frames.GetFrameTexture(animation, i) is AtlasTexture frame) ValidateResource(frame);
    }
    private Resource DecodeResource(JsonElement recipe)
    {
        var name = recipe.GetProperty("class").GetString()!;
        Resource resource = name switch
        {
            "ItemDefinition" => new ItemDefinition(), "CropDefinition" => new CropDefinition(),
            "AnimalDefinition" => new AnimalDefinition(), "AnimalProductionDefination" or "AnimalProductionDefinition" => new AnimalProductionDefinition(),
            _ => ClassDB.Instantiate(name).AsGodotObject() as Resource ?? throw new InvalidOperationException($"Unknown resource class {name}")
        };
        bool custom = resource is ItemDefinition or CropDefinition or AnimalDefinition or AnimalProductionDefinition;
        foreach (var property in recipe.GetProperty("props").EnumerateArray())
        {
            string key = property[0].GetString()!;
            if (custom && key != "resource_name" && !key.StartsWith("metadata/")) key = Pascal(key);
            resource.Set(key, Decode(property[1]));
        }
        return resource;
    }
    private Variant Decode(JsonElement value)
    {
        switch (value.ValueKind)
        {
            case JsonValueKind.Null: return default;
            case JsonValueKind.True: return true;
            case JsonValueKind.False: return false;
            case JsonValueKind.String: return value.GetString()!;
            case JsonValueKind.Number: return value.TryGetInt64(out long integer) ? Variant.From(integer) : Variant.From(value.GetDouble());
        }
        string type = value.GetProperty("type").GetString()!;
        if (type == "Resource") return DecodeResource(value);
        if (type == "External")
        {
            string path = value.GetProperty("path").GetString()!;
            if (_cache.TryGetValue(path, out var cached)) return cached;
            Resource resource;
            if (ResourceLoader.Exists(path)) resource = GD.Load<Resource>(path);
            else if (_recipes.TryGetValue(path, out var recipe)) { resource = DecodeResource(recipe); resource.TakeOverPath(path); }
            else throw new InvalidOperationException($"Missing external resource {path}");
            _cache[path] = resource; return resource;
        }
        var data = value.GetProperty("value");
        float F(int i) => data[i].GetSingle(); int I(int i) => data[i].GetInt32();
        switch (type)
        {
            case "StringName": return new StringName(data.GetString()!);
            case "NodePath": return new NodePath(data.GetString()!);
            case "Vector2": return new Vector2(F(0), F(1));
            case "Vector2i": return new Vector2I(I(0), I(1));
            case "Rect2": return new Rect2(F(0), F(1), F(2), F(3));
            case "Rect2i": return new Rect2I(I(0), I(1), I(2), I(3));
            case "Vector3": return new Vector3(F(0), F(1), F(2));
            case "Vector3i": return new Vector3I(I(0), I(1), I(2));
            case "Vector4": return new Vector4(F(0), F(1), F(2), F(3));
            case "Vector4i": return new Vector4I(I(0), I(1), I(2), I(3));
            case "Color": return new Color(F(0), F(1), F(2), F(3));
            case "Array": var array = new GArray(); foreach (var item in data.EnumerateArray()) array.Add(Decode(item)); return array;
            case "Dictionary": var dict = new GDictionary(); foreach (var pair in data.EnumerateArray()) dict[Decode(pair[0])] = Decode(pair[1]); return dict;
            case "PackedByteArray": return data.EnumerateArray().Select(x => x.GetByte()).ToArray();
            case "PackedInt32Array": return data.EnumerateArray().Select(x => x.GetInt32()).ToArray();
            case "PackedInt64Array": return data.EnumerateArray().Select(x => x.GetInt64()).ToArray();
            case "PackedFloat32Array": return data.EnumerateArray().Select(x => x.GetSingle()).ToArray();
            case "PackedFloat64Array": return data.EnumerateArray().Select(x => x.GetDouble()).ToArray();
            case "PackedStringArray": return data.EnumerateArray().Select(x => x.GetString()!).ToArray();
            case "PackedVector2Array": return data.EnumerateArray().Select(x => Decode(x).AsVector2()).ToArray();
            case "PackedVector3Array": return data.EnumerateArray().Select(x => Decode(x).AsVector3()).ToArray();
            case "PackedColorArray": return data.EnumerateArray().Select(x => Decode(x).AsColor()).ToArray();
            default: throw new InvalidOperationException($"Unsupported recipe type {type}");
        }
    }
    internal static string Pascal(string name) => string.Concat(name.Split('_').Select(part => part.Length == 0 ? "" : char.ToUpperInvariant(part[0]) + part.Substring(1)));
    public static int GenerateHouseDecor(string outputRoot, bool overwrite)
    {
        const string matrixPath = "res://scripts/setup/data/house_decor_selection_matrix_v2.json";
        using var matrix = JsonDocument.Parse(FileAccess.GetFileAsString(matrixPath));
        var tiles = new TileSet { TileSize = new Vector2I(16, 16), ResourceName = "house_decor_tiles" };
        tiles.SetMeta("selection_matrix", matrixPath);
        foreach (var config in matrix.RootElement.GetProperty("sources").EnumerateArray())
        {
            string path = "res://assets/Buildings/House_Decor/" + config.GetProperty("file").GetString();
            if (FileAccess.GetSha256(path) != config.GetProperty("sha256").GetString()) throw new InvalidOperationException($"Matrix source changed: {path}");
            var texture = GD.Load<Texture2D>(path); var image = texture.GetImage();
            var expectedSize = config.GetProperty("size_px");
            if (image.GetWidth() != expectedSize[0].GetInt32() || image.GetHeight() != expectedSize[1].GetInt32()) throw new InvalidOperationException($"Matrix size mismatch: {path}");
            var source = new TileSetAtlasSource { Texture = texture, TextureRegionSize = tiles.TileSize, UseTexturePadding = true };
            var covered = new HashSet<Vector2I>();
            foreach (var group in config.GetProperty("groups").EnumerateArray())
                foreach (var rect in group.GetProperty("rects").EnumerateArray())
                {
                    var coords = new Vector2I(rect[0].GetInt32(), rect[1].GetInt32()); var size = new Vector2I(rect[2].GetInt32(), rect[3].GetInt32());
                    var pixels = new Rect2I(coords * 16, size * 16);
                    if (size.X <= 0 || size.Y <= 0 || !new Rect2I(Vector2I.Zero, image.GetSize()).Encloses(pixels) || image.GetRegion(pixels).IsInvisible()) throw new InvalidOperationException($"Invalid matrix selection: {path} {coords}");
                    for (int y = coords.Y; y < coords.Y + size.Y; y++) for (int x = coords.X; x < coords.X + size.X; x++) if (!covered.Add(new Vector2I(x, y))) throw new InvalidOperationException($"Matrix overlap: {path}");
                    source.CreateTile(coords, size);
                }
            for (int y = 0; y < image.GetHeight() / 16; y++) for (int x = 0; x < image.GetWidth() / 16; x++)
                if (!covered.Contains(new Vector2I(x,y)) && !image.GetRegion(new Rect2I(x*16,y*16,16,16)).IsInvisible()) throw new InvalidOperationException($"Matrix missed pixels: {path}");
            tiles.AddSource(source, config.GetProperty("source_id").GetInt32());
        }
        string output = OutputPath("res://tilesets/house_decor/house_decor_tiles.tres", outputRoot);
        if (FileAccess.FileExists(output) && !overwrite) return 0;
        Save(tiles, output);
        var images = new Dictionary<string, string>();
        foreach (var config in matrix.RootElement.GetProperty("sources").EnumerateArray())
        {
            string filename = config.GetProperty("file").GetString()!;
            images[filename] = "data:image/png;base64," + Convert.ToBase64String(FileAccess.GetFileAsBytes("res://assets/Buildings/House_Decor/"+filename));
        }
        string preview = FileAccess.GetFileAsString("res://scripts/setup/data/house_decor_tiles_v2_preview.template.html")
            .Replace("__MATRIX_JSON__",matrix.RootElement.GetRawText()).Replace("__IMAGES_JSON__",JsonSerializer.Serialize(images));
        string previewPath = OutputPath("res://docs/house_decor_tiles_v2_preview.html",outputRoot);
        DirAccess.MakeDirRecursiveAbsolute(previewPath.GetBaseDir());
        using var file = FileAccess.Open(previewPath,FileAccess.ModeFlags.Write) ?? throw new IOException(previewPath);
        file.StoreString(preview); return 1;
    }
    public static int MergeTilesets(string outputRoot, bool overwrite) => TileSetTools.Merge(outputRoot,overwrite);
}
