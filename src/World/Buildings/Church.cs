using Godot;
namespace FantasyFarm.World;

[Tool, GlobalClass]
public partial class Church : BuildingVariant
{
    protected override string[] Textures => new[] { "res://assets/Buildings/Buildings/Unique_Buildings/Church/Church_Black.png", "res://assets/Buildings/Buildings/Unique_Buildings/Church/Church_Black.png", "res://assets/Buildings/Buildings/Unique_Buildings/Church/Church_Black.png", "res://assets/Buildings/Buildings/Unique_Buildings/Church/Church_Black.png", "res://assets/Buildings/Buildings/Unique_Buildings/Church/Church_Blue.png", "res://assets/Buildings/Buildings/Unique_Buildings/Church/Church_Blue.png", "res://assets/Buildings/Buildings/Unique_Buildings/Church/Church_Blue.png", "res://assets/Buildings/Buildings/Unique_Buildings/Church/Church_Blue.png", "res://assets/Buildings/Buildings/Unique_Buildings/Church/Church_Red.png", "res://assets/Buildings/Buildings/Unique_Buildings/Church/Church_Red.png", "res://assets/Buildings/Buildings/Unique_Buildings/Church/Church_Red.png", "res://assets/Buildings/Buildings/Unique_Buildings/Church/Church_Red.png" };

    protected override int[] Frames => new int[] { 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3 };

    protected override string Labels => "BLACK_FRAME_1,BLACK_FRAME_2,BLACK_FRAME_3,BLACK_FRAME_4,BLUE_FRAME_1,BLUE_FRAME_2,BLUE_FRAME_3,BLUE_FRAME_4,RED_FRAME_1,RED_FRAME_2,RED_FRAME_3,RED_FRAME_4";
}
