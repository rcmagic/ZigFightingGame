const std = @import("std");
const rl = @import("raylib");
const math = @import("utils/math.zig");
const GameSimulation = @import("GameSimulation.zig");
const GameState = @import("GameState.zig").GameState;
const CharacterData = @import("CharacterData.zig");

var texture : rl.Texture2D = undefined;


const DrawState = struct 
{
    x: i32 = 0,
    y: i32 = 0,
    xScale: f32 = 1.0,
    yScale: f32 = 1.0,
    texture: rl.Texture2D = undefined
};

// Prepare state struct which describes how to draw a character
fn PrepareDrawState(gameState: GameState, entity: usize) DrawState
{

    const GroundOffset = 390;
    const ScreenCenter = 400;

    const position = gameState.physicsComponents[entity].position;

    const ScreenX = math.WorldToScreen(position.x) + ScreenCenter;
    const ScreenY = -math.WorldToScreen(position.y) + GroundOffset;
    

    var drawState = DrawState{.x = ScreenX, .y = ScreenY};


    // Drawing the sprite flipped when the entity is facing left.
    if(gameState.physicsComponents[entity].facingLeft)
    {
        drawState.xScale = -1.0;
    }

    // Get textured used to render the sprite
    if(gameState.gameData) | gameData |
    {
        const stateMachine = &gameState.stateMachineComponents[entity].stateMachine;
        
        const CurrentState = stateMachine.CurrentState;

        var actionName : []const u8 = "";
        if(stateMachine.Registery.CombatStates[@enumToInt(CurrentState)]) |state|
        {
            actionName = state.Name;
        }

        if(CharacterData.FindAction(gameData.Characters.items[entity], gameData.ActionMaps.items[entity], actionName)) | actionData |
        {                
            const imageRange = actionData.GetActiveImage(gameState.timelineComponents[entity].framesElapsed);

            // Get the sprite texture
            if(gameData.FindSequenceTextures(entity, imageRange.Sequence)) | sequence |
            {
                drawState.texture = sequence.textures.items[@intCast(usize,imageRange.Index)];
            }

            // Get the sprite offset
            if(gameData.Characters.items[entity].FindSequence(gameData.ImageSequenceMap.items[entity], imageRange.Sequence)) | sequence |
            {
                const image = sequence.Images.items[@intCast(usize,imageRange.Index)];
                drawState.x += image.x;
                drawState.y += image.y;
            }
        }
    }

    // Hit shake
    if(gameState.reactionComponents[0].hitStop > 0)
    {
        const hitShakeDist = 4;
        const hitShake = -(hitShakeDist / 2) + hitShakeDist*@mod(gameState.reactionComponents[0].hitStop,2);
        drawState.x += hitShake;
    }



    return drawState;
}

// Render a single DrawState. Uses the results from PrepareDrawState() and renders one Character.
fn RenderDrawState(state: DrawState) void
{
    //rl.DrawTexture(state.texture, state.x, state.y, rl.WHITE);
    rl.DrawTextureRec(state.texture, rl.Rectangle{.x=0, .y=0, .width=@intToFloat(f32, state.texture.width)*state.xScale, .height=@intToFloat(f32, state.texture.height)*state.yScale}, 
                        rl.Vector2{.x=@intToFloat(f32, state.x),.y= @intToFloat(f32, state.y)}, rl.WHITE);
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
    gameState.physicsComponents[0].position = .{.x = -200000, .y = 0 };
    gameState.physicsComponents[1].position = .{.x = 200000, .y = 0 };
    gameState.physicsComponents[0].facingLeft = false;
    gameState.physicsComponents[1].facingLeft = true;

    var bPauseGame = false;   

    var GameFrameCount : i32 = 0;
    
    //const texture = rl.LoadTexture("assets/animation/test_chara_1/color1/idle_00.png");

    if(gameState.gameData) | gameData |
    {
        if(gameData.FindSequenceTextures(0, "stand")) | sequence |
        {
            texture = sequence.textures.items[0];
        }
    }

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

        RenderDrawState(PrepareDrawState(gameState, 0));
        RenderDrawState(PrepareDrawState(gameState, 1));

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
