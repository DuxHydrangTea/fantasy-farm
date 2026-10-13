using Godot;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
namespace FantasyFarm.Tools;
public static class TileSetTools
{
    public static int AnimateDecor(string kind, string outputRoot, bool overwrite)
    {
        var config = kind switch
        {
            "grass" => ("Grass_Animations", "grass", 8, false),
            "rock" => ("Rock_Animations", "rock", 8, false),
            "water" => ("Water_Decor_Animations", "water", 8, false),
            "mushroom" => ("Muschroom_Animations", "muschroom", 6, false),
            "potted" => ("Flower_Animations/Potted", "potted_flower", 6, true),
            "flowers" => ("Flower_Animations/Not_Potted", "not_potted_flower", 6, true),
            _ => throw new ArgumentException("Unknown decor kind")
        };
        string folder = "res://assets/Outdoor decoration/Outdoor_Decor_Animations/"+config.Item1;
        string original = "res://tilesets/my_decor_"+config.Item2+"_tileset.tres";
        string output = ResourceGenerator.OutputPath(original,outputRoot);
        if (Godot.FileAccess.FileExists(output) && !overwrite) return 0;
        var tiles = (TileSet)GD.Load<TileSet>(original).Duplicate(true);
        int count = 0;
        foreach (string file in Directory.EnumerateFiles(ProjectSettings.GlobalizePath(folder),"*.png",SearchOption.AllDirectories).OrderBy(x=>x))
        {
            string path = "res://"+Path.GetRelativePath(ProjectSettings.GlobalizePath("res://"),file).Replace('\\','/');
            var texture = GD.Load<Texture2D>(path);
            if (texture.GetWidth()<config.Item3*16 || texture.GetHeight()%16!=0) throw new InvalidOperationException($"Invalid decor sheet dimensions: {path}");
            TileSetAtlasSource? source = null;
            for (int i=0;i<tiles.GetSourceCount();i++)
                if (tiles.GetSource(tiles.GetSourceId(i)) is TileSetAtlasSource candidate && candidate.Texture.ResourcePath==path) { source=candidate;break; }
            if (source is null) { source = new TileSetAtlasSource {Texture=texture,TextureRegionSize=new Vector2I(16,16)}; tiles.AddSource(source); }
            int rows = config.Item4 ? texture.GetHeight()/16 : 1;
            for(int row=0;row<rows;row++)
            {
                var coords=new Vector2I(0,row);if(!source.HasTile(coords))source.CreateTile(coords);
                source.SetTileAnimationColumns(coords,config.Item3);source.SetTileAnimationFramesCount(coords,config.Item3);source.SetTileAnimationSpeed(coords,8);
            }
            count++;
        }
        ResourceGenerator.Save(tiles,output);return count;
    }
    public static int Buildings(string outputRoot, bool overwrite)
    {
        var paths = Enumerable.Range(1,5).Select(i=>$"res://tilesets/house_building_tilesets/buildings_house_{i}_tiles.tres")
            .Concat(new[]{"barn","blacksmith_house","church","coop","fisherman_house","green_house","inn","shed","silo","stalls","windmill"}
                .Select(name=>$"res://tilesets/unique_building_tilesets/{name}_building_tiles.tres")).ToArray();
        var sets=new List<TileSet>();
        foreach(string path in paths)
        {
            var tiles=(TileSet)GD.Load<TileSet>(path).Duplicate(true);
            var master=(TileSetAtlasSource)tiles.GetSource(0);
            for(int i=0;i<tiles.GetSourceCount();i++)
            {
                int id=tiles.GetSourceId(i);if(id==0||tiles.GetSource(id) is not TileSetAtlasSource target)continue;
                var coords=Enumerable.Range(0,target.GetTilesCount()).Select(target.GetTileId).ToArray();foreach(var tile in coords)target.RemoveTile(tile);
                for(int tile=0;tile<master.GetTilesCount();tile++)
                {
                    var anchor=master.GetTileId(tile);target.CreateTile(anchor,master.GetTileSizeInAtlas(anchor));
                    var from=master.GetTileData(anchor,0);var to=target.GetTileData(anchor,0);to.YSortOrigin=from.YSortOrigin;
                    for(int layer=0;layer<tiles.GetPhysicsLayersCount();layer++)
                    {
                        int polygons=from.GetCollisionPolygonsCount(layer);to.SetCollisionPolygonsCount(layer,polygons);
                        for(int polygon=0;polygon<polygons;polygon++)to.SetCollisionPolygonPoints(layer,polygon,from.GetCollisionPolygonPoints(layer,polygon));
                    }
                }
            }
            sets.Add(tiles);string output=ResourceGenerator.OutputPath(path,outputRoot);
            if(!Godot.FileAccess.FileExists(output)||overwrite)ResourceGenerator.Save(tiles,output);
        }
        var merged=(TileSet)sets[0].Duplicate(true);
        foreach(int id in Enumerable.Range(0,merged.GetSourceCount()).Select(merged.GetSourceId).ToArray())merged.RemoveSource(id);
        foreach(var tiles in sets)for(int i=0;i<tiles.GetSourceCount();i++)merged.AddSource((TileSetSource)tiles.GetSource(tiles.GetSourceId(i)).Duplicate(true));
        string mergedOutput=ResourceGenerator.OutputPath("res://tilesets/merged_tilesets/buildings_all_tiles.tres",outputRoot);
        if(!Godot.FileAccess.FileExists(mergedOutput)||overwrite)ResourceGenerator.Save(merged,mergedOutput);
        return merged.GetSourceCount();
    }

    private sealed record TerrainConfig(TileSet.TerrainMode Mode, string[] Names, Color[] Colors);
    private sealed record TerrainTile(TileData Data,int Set,int Terrain,Dictionary<TileSet.CellNeighbor,int> Bits);
    public static int Merge(string outputRoot, bool overwrite)
    {
        string output=ResourceGenerator.OutputPath("res://tilesets/all_decor_tileset.tres",outputRoot);
        if(Godot.FileAccess.FileExists(output)&&!overwrite)return 0;
        var inputs=DirAccess.GetFilesAt("res://tilesets").Where(name=>name.EndsWith(".tres")&&name!="all_decor_tileset.tres")
            .OrderBy(name=>name).Select(name=>GD.Load<Resource>("res://tilesets/"+name)).OfType<TileSet>().ToArray();
        // TileData layer indexes are shared. Refuse incompatible layer layouts instead of losing data.
        var target=new TileSet{TileSize=new Vector2I(16,16)};
        foreach(var source in inputs)
        {
            if(source.TileSize!=target.TileSize||source.GetNavigationLayersCount()!=0||source.GetCustomDataLayersCount()!=0||source.GetOcclusionLayersCount()!=0)
                throw new InvalidOperationException("Merge requires 16px TileSets without navigation/custom/occlusion layers; use a dedicated mapping for other layouts.");
            for(int layer=0;layer<source.GetPhysicsLayersCount();layer++)
            {
                if(layer>=target.GetPhysicsLayersCount())
                {
                    target.AddPhysicsLayer();target.SetPhysicsLayerCollisionLayer(layer,source.GetPhysicsLayerCollisionLayer(layer));
                    target.SetPhysicsLayerCollisionMask(layer,source.GetPhysicsLayerCollisionMask(layer));target.SetPhysicsLayerPhysicsMaterial(layer,source.GetPhysicsLayerPhysicsMaterial(layer));
                }
                else if(target.GetPhysicsLayerCollisionLayer(layer)!=source.GetPhysicsLayerCollisionLayer(layer)||target.GetPhysicsLayerCollisionMask(layer)!=source.GetPhysicsLayerCollisionMask(layer)||target.GetPhysicsLayerPhysicsMaterial(layer)!=source.GetPhysicsLayerPhysicsMaterial(layer))
                    throw new InvalidOperationException("Physics layer definitions differ; merge requires explicit layer remapping.");
            }
        }
        var configs=new List<TerrainConfig>();var maps=new Dictionary<TileSet,int[]>();
        foreach(var source in inputs)
        {
            var map=new int[source.GetTerrainSetsCount()];
            for(int set=0;set<map.Length;set++)
            {
                map[set]=configs.Count;int count=source.GetTerrainsCount(set);
                configs.Add(new TerrainConfig(source.GetTerrainSetMode(set),Enumerable.Range(0,count).Select(i=>source.GetTerrainName(set,i)).ToArray(),Enumerable.Range(0,count).Select(i=>source.GetTerrainColor(set,i)).ToArray()));
            }
            maps[source]=map;
        }
        void ConfigureTerrains(TileSet tiles)
        {
            for(int i=tiles.GetTerrainSetsCount()-1;i>=0;i--)tiles.RemoveTerrainSet(i);
            for(int set=0;set<configs.Count;set++)
            {
                var config=configs[set];tiles.AddTerrainSet();tiles.SetTerrainSetMode(set,config.Mode);
                for(int terrain=0;terrain<config.Names.Length;terrain++){tiles.AddTerrain(set);tiles.SetTerrainName(set,terrain,config.Names[terrain]);tiles.SetTerrainColor(set,terrain,config.Colors[terrain]);}
            }
        }
        ConfigureTerrains(target);var seen=new Dictionary<string,TileSetAtlasSource>();
        foreach(var original in inputs)
        {
            var clone=(TileSet)original.Duplicate(true);var records=new List<TerrainTile>();
            for(int sourceIndex=0;sourceIndex<clone.GetSourceCount();sourceIndex++)
            {
                if(clone.GetSource(clone.GetSourceId(sourceIndex)) is not TileSetAtlasSource atlas)continue;
                for(int tile=0;tile<atlas.GetTilesCount();tile++)
                {
                    var coords=atlas.GetTileId(tile);
                    for(int altIndex=0;altIndex<atlas.GetAlternativeTilesCount(coords);altIndex++)
                    {
                        var data=atlas.GetTileData(coords,atlas.GetAlternativeTileId(coords,altIndex));if(data.TerrainSet<0)continue;
                        var bits=new Dictionary<TileSet.CellNeighbor,int>();foreach(var bit in Enum.GetValues<TileSet.CellNeighbor>())if(data.IsValidTerrainPeeringBit(bit))bits[bit]=data.GetTerrainPeeringBit(bit);
                        records.Add(new TerrainTile(data,data.TerrainSet,data.Terrain,bits));
                    }
                }
            }
            ConfigureTerrains(clone);
            foreach(var record in records)
            {
                record.Data.TerrainSet=maps[original][record.Set];record.Data.Terrain=record.Terrain;
                foreach(var bit in record.Bits)record.Data.SetTerrainPeeringBit(bit.Key,bit.Value);
            }
            for(int i=0;i<clone.GetSourceCount();i++)
            {
                if(clone.GetSource(clone.GetSourceId(i)) is not TileSetAtlasSource atlas)continue;
                string texture=atlas.Texture.ResourcePath;
                // A duplicate texture can have additional tiles. Keep each source if its layout differs.
                bool duplicate=seen.TryGetValue(texture,out var previous)&&previous.GetTilesCount()==atlas.GetTilesCount()
                    &&Enumerable.Range(0,atlas.GetTilesCount()).All(tile=>previous.HasTile(atlas.GetTileId(tile))&&previous.GetTileSizeInAtlas(atlas.GetTileId(tile))==atlas.GetTileSizeInAtlas(atlas.GetTileId(tile)));
                if(duplicate)continue;
                seen[texture]=atlas;target.AddSource((TileSetAtlasSource)atlas.Duplicate(true));
            }
        }
        ResourceGenerator.Save(target,output);return target.GetSourceCount();
    }
}
