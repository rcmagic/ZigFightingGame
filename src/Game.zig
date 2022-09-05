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
    flipped: bool = false,
    texture: rl.Texture2D = undefined
};

const GroundOffset = 390;
const ScreenCenter = 400;

// Prepare state struct which describes how to draw a character
fn PrepareDrawState(gameState: GameState, entity: usize) DrawState
{


    const position = gameState.physicsComponents[entity].position;

    const ScreenX = math.WorldToScreen(position.x) + ScreenCenter;
    const ScreenY = -math.WorldToScreen(position.y) + GroundOffset;
    

    var drawState = DrawState{.x = ScreenX, .y = ScreenY};


    const facingLeft = gameState.physicsComponents[entity].facingLeft;
    // Drawing the sprite flipped when the entity is facing left.
    if(facingLeft)
    {
        drawState.xScale = -1.0;
    }

    drawState.flipped = facingLeft;

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
                drawState.x += if(facingLeft) -image.x else image.x;
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
                        rl.Vector2{.x=@intToFloat(f32, 
                        if(state.flipped) (state.x - state.texture.width) else state.x),.y= @intToFloat(f32, state.y)}, rl.WHITE);
}

fn GetActiveHitboxes(hitboxGroups: []const CharacterData.HitboxGroup, hitboxes: []CharacterData.Hitbox, framesElapsed: i32) usize
{
    var count: usize = 0;
    for(hitboxGroups) | hitboxGroup |
    {                
        if(hitboxGroup.IsActiveOnFrame(framesElapsed))
        {
            for(hitboxGroup.Hitboxes.items) | hitbox |
            {
                hitboxes[count] = hitbox;
                count += 1;
            }
        }
    }

    return count;
}

// Hitboxes to draw.
var debugDrawHitboxes : [100]CharacterData.Hitbox = [_]CharacterData.Hitbox{.{}} ** 100;

fn DrawCharacterHitboxes(gameState: GameState, entity: usize) void
{
    const position = gameState.physicsComponents[entity].position;
    const framesElapsed = gameState.timelineComponents[entity].framesElapsed;

    const ScreenX = math.WorldToScreen(position.x) + ScreenCenter;
    const ScreenY = -math.WorldToScreen(position.y) + GroundOffset;
    
    const AxisLength = 40;
    const AxisThickness = 2;
    // Draw axis
    rl.DrawRectangle(ScreenX - AxisLength/2, ScreenY, AxisLength, AxisThickness, rl.BLACK);
    rl.DrawRectangle(ScreenX, ScreenY-AxisLength/2, AxisThickness, AxisLength, rl.BLACK);

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

            const vulCount = GetActiveHitboxes(actionData.VulnerableHitboxGroups.items,
                                    debugDrawHitboxes[0..], framesElapsed);

            if(vulCount > 0)
            {
                var temp = debugDrawHitboxes[0..vulCount];
                for(temp) | hitbox|
                {
                    const left = ScreenX + math.WorldToScreen(hitbox.left);
                    const top = ScreenY - math.WorldToScreen(hitbox.top);
                    const width = math.WorldToScreen(hitbox.right - hitbox.left);
                    const height = math.WorldToScreen(hitbox.top - hitbox.bottom);
                    rl.DrawRectangleLines(left, top, width, height, rl.BLUE); 
                }
            }


            const atkCount = GetActiveHitboxes(actionData.AttackHitboxGroups.items,
                        debugDrawHitboxes[0..], framesElapsed);

            if(atkCount > 0)
            {
                var temp = debugDrawHitboxes[0..atkCount];
                for(temp) | hitbox|
                {
                    const left = ScreenX + math.WorldToScreen(hitbox.left);
                    const top = ScreenY - math.WorldToScreen(hitbox.top);
                    const width = math.WorldToScreen(hitbox.right - hitbox.left);
                    const height = math.WorldToScreen(hitbox.top - hitbox.bottom);
                    rl.DrawRectangleLines(left, top, width, height, rl.RED); 
                }
            }
        }
    }
}

pub fn GameLoop() !void
{
    // The ArenaAllocator lets use free all the persistent store memory at once.
    var ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    // We create this allocator to easily release all our assets at once without influencing other systems.
    var AssetAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    // Free all memory used by the allocator at once
    defer AssetAllocator.deinit();

    // Free all memory used by the allocator at once
    defer ArenaAllocator.deinit();

    // Our game state

    var gameState: GameState = undefined;
    try gameState.init(ArenaAllocator.allocator());
    try gameState.LoadPersistentGameAssets(AssetAllocator.allocator());


    // Initialize our game objects
    gameState.physicsComponents[0].position = .{.x = -200000, .y = 0 };
    gameState.physicsComponents[1].position = .{.x = 200000, .y = 0 };
    gameState.physicsComponents[0].facingLeft = false;
    gameState.physicsComponents[1].facingLeft = true;


    // Flag for showing hitboxes
    var bDebugShowHitboxes = false;

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
            // Toggle hitbox display
            else if(rl.IsKeyPressed(rl.KeyboardKey.KEY_F4))
            {
                bDebugShowHitboxes = !bDebugShowHitboxes;
            }
            // Force reload assets with ctrl+F5
            else if(rl.IsKeyDown(rl.KeyboardKey.KEY_LEFT_CONTROL) and rl.IsKeyPressed(rl.KeyboardKey.KEY_F5))
            {
                std.debug.print("Reloading assets...\n", .{}); 
                AssetAllocator.deinit();
                AssetAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
                try gameState.LoadPersistentGameAssets(AssetAllocator.allocator());
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


        // Draw hitboxes when enabled.
        if(bDebugShowHitboxes)
        {
            DrawCharacterHitboxes(gameState, 0);
            DrawCharacterHitboxes(gameState, 1);
        }

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
