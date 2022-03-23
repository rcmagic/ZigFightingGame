const std = @import("std");
const rl = @import("raylib");


const GameObject = struct {
    x: i32, // variable with the type float 32
    y: i32,
};

pub fn main() anyerror!void {

    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.InitWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");

    rl.SetTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------


    // Initial state of our object
    var TestObject = GameObject {
        .x = 400, 
        .y = 400,
    };

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
            // Update position of object base on player input
            if(PressingLeft)
            {
                TestObject.x -= 1;
            }
            else if(PressingRight)
            {
                TestObject.x += 1;
            }

        }

        // Draw
        rl.BeginDrawing();

        rl.ClearBackground(rl.WHITE);

        // Reflect the position of our game object on screen.
        rl.DrawCircle(TestObject.x, TestObject.y, 50, rl.MAROON);

        rl.EndDrawing();
        //----------------------------------------------------------------------------------
    }

    // De-Initialization
    //--------------------------------------------------------------------------------------
    rl.CloseWindow(); // Close window and OpenGL context
    //--------------------------------------------------------------------------------------
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}

