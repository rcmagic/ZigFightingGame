const std = @import("std");
const rl = @import("raylib");
const game = @import("game.zig");

pub fn main() anyerror!void {

    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.setConfigFlags(rl.ConfigFlags{ .window_resizable = true });
    rl.initWindow(screenWidth, screenHeight, "Zig Fighting Game");

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Run the game
    try game.gameLoop();

    // De-Initialization
    //--------------------------------------------------------------------------------------
    rl.closeWindow(); // Close window and OpenGL context
    //--------------------------------------------------------------------------------------

}
