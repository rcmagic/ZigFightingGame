const std = @import("std");
const rl = @import("raylib");
const Game = @import("Game.zig");


pub fn main() anyerror!void {

    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.InitWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");

    rl.SetTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Run the game
    try Game.GameLoop();

    // De-Initialization
    //--------------------------------------------------------------------------------------
    rl.CloseWindow(); // Close window and OpenGL context
    //--------------------------------------------------------------------------------------

}

