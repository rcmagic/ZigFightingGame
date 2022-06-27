const std = @import("std");
const rl = @import("raylib");
const math = @import("utils/math.zig");
const GameSimulation = @import("GameSimulation.zig");
const GameState = @import("GameState.zig").GameState;

pub fn GameLoop() !void
{
    // The ArenaAllocator lets use free all the persistent store memory at once.
    var ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    // Free all memory used by the allocator at once
    defer ArenaAllocator.deinit();

    // Our game state

    var gameState = try GameState.init( ArenaAllocator.allocator());
    
    // Initialize our game object
    gameState.physicsComponents[0].position = .{.x = 400000, .y = 200000 };

    // Main game loop
    while (!rl.WindowShouldClose()) { // Detect window close button or ESC key


            // Reset input to not held down before polling
            gameState.inputComponents[0].inputCommand.Reset();

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
            }

            
        // Game Simulation
        {
            GameSimulation.UpdateGame(&gameState);
        }
        
        // Draw
        rl.BeginDrawing();

        rl.ClearBackground(rl.WHITE);

        const ScreenX = math.WorldToScreen(gameState.physicsComponents[0].position.x);
        const ScreenY = math.WorldToScreen(gameState.physicsComponents[0].position.y);

        // Reflect the position of our game object on screen.
        rl.DrawCircle(ScreenX, ScreenY, 50, rl.MAROON);

        // if(gameState.gameData) | gameData |
        // {
        //     const hitbox = gameData.HitboxGroup.Hitboxes.items[0]; 
        //    rl.DrawRectangleLines(hitbox.left, hitbox.top, hitbox.right - hitbox.left, hitbox.top - hitbox.bottom, rl.RED);    
        // }

        rl.EndDrawing();
        //----------------------------------------------------------------------------------
    }
}