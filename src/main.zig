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
    
    // Initialize our game object
    gameState.physicsComponents[0].position = .{.x = 400, .y = 200 };

    // Main game loop
    while (!rl.WindowShouldClose()) { // Detect window close button or ESC key

            var PressingRight : bool = false;
            var PressingLeft : bool = false;

            if(rl.IsWindowFocused() and rl.IsGamepadAvailable(0))
            {
                if(rl.IsGamepadButtonDown(0, rl.GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_UP))
                {
                    // PolledInput |= static_cast<unsigned int>(InputCommand::Up);
                }

                if(rl.IsGamepadButtonDown(0, rl.GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_DOWN))
                {
                    // PolledInput |= static_cast<unsigned int>(InputCommand::Down);
                }

                if(rl.IsGamepadButtonDown(0, rl.GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_LEFT))
                {
                    // PolledInput |= static_cast<unsigned int>(InputCommand::Left);
                    PressingLeft = true;
                }

                if(rl.IsGamepadButtonDown(0, rl.GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_RIGHT))
                {
                    // PolledInput |= static_cast<unsigned int>(InputCommand::Right);
                    PressingRight = true;
                }
            }

            
        // Game Simulation
        {
            
            //  Update position of object base on player input
            {
                const entity = &gameState.physicsComponents[0];
                if(PressingLeft)
                {
                     entity.velocity.x = -1;
                }
                else if(PressingRight)
                {
                     entity.velocity.x = 1;
                }
                else
                {
                    entity.velocity.x = 0; 
                }
            }

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

