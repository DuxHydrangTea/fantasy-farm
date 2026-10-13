using Godot;
namespace FantasyFarm.World;

[Tool, GlobalClass]
public partial class House3 : BuildingVariant
{
    protected override string[] Textures => new[] { "res://assets/Buildings/Buildings/Houses/Limestone/House_3_Limestone_Base_Black.png", "res://assets/Buildings/Buildings/Houses/Limestone/House_3_Limestone_Base_Blue.png", "res://assets/Buildings/Buildings/Houses/Limestone/House_3_Limestone_Base_Red.png", "res://assets/Buildings/Buildings/Houses/Stone/House_3_Stone_Base_Black.png", "res://assets/Buildings/Buildings/Houses/Stone/House_3_Stone_Base_Blue.png", "res://assets/Buildings/Buildings/Houses/Stone/House_3_Stone_Base_Red.png", "res://assets/Buildings/Buildings/Houses/Stone/House_3_Stone_Green_Black.png", "res://assets/Buildings/Buildings/Houses/Stone/House_3_Stone_Green_Blue.png", "res://assets/Buildings/Buildings/Houses/Stone/House_3_Stone_Green_Red.png", "res://assets/Buildings/Buildings/Houses/Stone/House_3_Stone_Red_Black.png", "res://assets/Buildings/Buildings/Houses/Stone/House_3_Stone_Red_Blue.png", "res://assets/Buildings/Buildings/Houses/Stone/House_3_Stone_Red_Red.png", "res://assets/Buildings/Buildings/Houses/Wood/House_3_Wood_Base_Black.png", "res://assets/Buildings/Buildings/Houses/Wood/House_3_Wood_Base_Blue.png", "res://assets/Buildings/Buildings/Houses/Wood/House_3_Wood_Base_Red.png", "res://assets/Buildings/Buildings/Houses/Wood/House_3_Wood_Green_Black.png", "res://assets/Buildings/Buildings/Houses/Wood/House_3_Wood_Green_Blue.png", "res://assets/Buildings/Buildings/Houses/Wood/House_3_Wood_Green_Red.png", "res://assets/Buildings/Buildings/Houses/Wood/House_3_Wood_Red_Black.png", "res://assets/Buildings/Buildings/Houses/Wood/House_3_Wood_Red_Blue.png", "res://assets/Buildings/Buildings/Houses/Wood/House_3_Wood_Red_Red.png" };

    protected override int[] Frames => new int[] { };

    protected override string Labels => "LIMESTONE_BLACK,LIMESTONE_BLUE,LIMESTONE_RED,STONE_BASE_BLACK,STONE_BASE_BLUE,STONE_BASE_RED,STONE_GREEN_BLACK,STONE_GREEN_BLUE,STONE_GREEN_RED,STONE_RED_BLACK,STONE_RED_BLUE,STONE_RED_RED,WOOD_BASE_BLACK,WOOD_BASE_BLUE,WOOD_BASE_RED,WOOD_GREEN_BLACK,WOOD_GREEN_BLUE,WOOD_GREEN_RED,WOOD_RED_BLACK,WOOD_RED_BLUE,WOOD_RED_RED";
}
