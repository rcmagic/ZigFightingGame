const std = @import("std");
const rl = @import("raylib");
const math = @import("utils/math.zig");
const GameSimulation = @import("GameSimulation.zig");
const GameState = @import("GameState.zig").GameState;

fn DrawCharacter(position: math.IntVector2D, color: rl.Color) void
{
    const GroundOffset = 390;
    const ScreenX = math.WorldToScreen(position.x);
    const ScreenY = -math.WorldToScreen(position.y) + GroundOffset;

    // Reflect the position of our game object on screen.
    rl.DrawCircle(ScreenX, ScreenY, 50, color);
}

pub fn GameLoop() !void
{
    // The ArenaAllocator lets use free all the persistent store memory at once.
    var ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    // Free all memory used by the allocator at once
    defer ArenaAllocator.deinit();

    // Our game state

    var gameState: GameState = undefined;
    try gameState.init(ArenaAllocator.allocator());
    
    // Initialize our game objects
    gameState.physicsComponents[0].position = .{.x = 200000, .y = 0 };
    gameState.physicsComponents[1].position = .{.x = 600000, .y = 0 };

    var bPauseGame = false;   

    var GameFrameCount : i32 = 0;

    // Main game loop
    while (!rl.WindowShouldClose()) { // Detect window close button or ESC key


        // Advance the game by one frame.
        var bAdvanceOnce = false;

        // Reset input to not held down before polling
        gameState.inputComponents[0].inputCommand.Reset();

        if(rl.IsWindowFocused())
        {
            if(rl.IsKeyPressed(rl.KeyboardKey.KEY_F3))
            {
                bPauseGame = !bPauseGame;
            }
            else if(rl.IsKeyPressed(rl.KeyboardKey.KEY_F2))
            {
                bAdvanceOnce = true;
            }
        }

        if(rl.IsWindowFocused() and rl.IsGamepadAvailable(0))
        {
            if(rl.IsGamepadButtonDown(0, rl.GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_UP))
            {
                gameState.inputComponents[0].inputCommand.Up = true;
            }

            if(rl.IsGamepadButtonDown(0, rl.GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_DOWN))
            {
                gameState.inputComponents[0].inputCommand.Down = true;
            }

            if(rl.IsGamepadButtonDown(0, rl.GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_LEFT))
            {

                gameState.inputComponents[0].inputCommand.Left = true;
            }

            if(rl.IsGamepadButtonDown(0, rl.GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_RIGHT))
            {
                gameState.inputComponents[0].inputCommand.Right = true;
            }

            if(rl.IsGamepadButtonDown(0, rl.GamepadButton.GAMEPAD_BUTTON_RIGHT_FACE_LEFT))
            {
                gameState.inputComponents[0].inputCommand.Attack = true;
            }
        }

            
        // Game Simulation
        if(!bPauseGame or bAdvanceOnce)
        {
            try GameSimulation.UpdateGame(&gameState);

            // Count the number of game frames that have been simulated. 
            GameFrameCount += 1;
        }
        
        // Draw
        rl.BeginDrawing();

        rl.ClearBackground(rl.WHITE);

        // const ScreenX = math.WorldToScreen(gameState.physicsComponents[0].position.x);
        // const ScreenY = math.WorldToScreen(gameState.physicsComponents[0].position.y);

        // // Reflect the position of our game object on screen.
        // rl.DrawCircle(ScreenX, ScreenY, 50, rl.MAROON);

        
        var hitShake  =  math.IntVector2D{.x =  -2000 + 4000*@mod(gameState.reactionComponents[0].hitStop,2), .y = 0};


        DrawCharacter(gameState.physicsComponents[0].position, rl.MAROON);
        DrawCharacter( gameState.physicsComponents[1].position.Add(hitShake), rl.BLUE);

        // if(gameState.gameData) | gameData |
        // {
        //     const hitbox = gameData.HitboxGroup.Hitboxes.items[0]; 
        //    rl.DrawRectangleLines(hitbox.left, hitbox.top, hitbox.right - hitbox.left, hitbox.top - hitbox.bottom, rl.RED);    
        // }

        // Debug information
        rl.DrawText(rl.FormatText("Game Frame: %d", GameFrameCount), 10, 10, 16, rl.DARKGRAY);

        if(bPauseGame)
        {
            rl.DrawText("(Paused)", 10 + 150, 10, 16, rl.DARKGRAY);
        }

        rl.EndDrawing();
        //----------------------------------------------------------------------------------
    }
}
