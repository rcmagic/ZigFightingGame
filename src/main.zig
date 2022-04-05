const std = @import("std");
const rl = @import("raylib");
const math = @import("utils/math.zig");
const GameSimulation = @import("GameSimulation.zig");


pub fn main() anyerror!void {

    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.InitWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");

    rl.SetTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Our game state
    var gameState = GameSimulation.GameState{};

    gameState.Init();
    
    // Initialize our game object
    gameState.physicsComponents[0].position = .{.x = 400, .y = 200 };

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

        // Reflect the position of our game object on screen.
        rl.DrawCircle(gameState.physicsComponents[0].position.x, gameState.physicsComponents[0].position.y, 50, rl.MAROON);

        rl.EndDrawing();
        //----------------------------------------------------------------------------------
    }

    // De-Initialization
    //--------------------------------------------------------------------------------------
    rl.CloseWindow(); // Close window and OpenGL context
    //--------------------------------------------------------------------------------------
}

