const std = @import("std");
const rl = @import("raylib");
const math = @import("utils/math.zig");
const GameSimulation = @import("GameSimulation.zig");
const GameState = @import("GameState.zig").GameState;
const CharacterData = @import("CharacterData.zig");
const CombatStateID = @import("ActionStates/StateMachine.zig").CombatStateID;
const common = @import("common.zig");


var texture : rl.Texture2D = undefined;


const DrawState = struct 
{
    x: i32 = 0,
    y: i32 = 0,
    xScale: f32 = 1.0,
    yScale: f32 = 1.0,
    flipped: bool = false,
    color: rl.Color = rl.WHITE,
    texture: rl.Texture2D = undefined
};

const GroundOffset = 390;
const ScreenCenter = 400;

// Indicate whether or not we draw the debug colors for various character states
var bDebugColorEnabled = false;


// Prepare state struct which describes how to draw a character
fn PrepareDrawState(gameState: GameState, entity: usize) DrawState
{


    const position = gameState.physics_components[entity].position;

    const ScreenX = math.WorldToScreen(position.x) + ScreenCenter;
    const ScreenY = -math.WorldToScreen(position.y) + GroundOffset;
    

    var drawState = DrawState{.x = ScreenX, .y = ScreenY};


    const facingLeft = gameState.physics_components[entity].facingLeft;
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

    const reaction = gameState.reactionComponents[entity];
    
    // Hit shake during hitstop of a character in hit or guard stun.
    if((reaction.hitStop > 0) and ((reaction.hitStun > 0) or (reaction.guardStun > 0)))
    {
        const hitShakeDist = 4;
        const hitShake = -(hitShakeDist / 2) + hitShakeDist*@mod(gameState.reactionComponents[0].hitStop,2);
        drawState.x += hitShake;
    }

    if(bDebugColorEnabled)
    {
        const CurrentState = gameState.stateMachineComponents[entity].stateMachine.CurrentState;

        drawState.color = switch(CurrentState)
        {
            .Standing, .WalkingForward, 
            .WalkingBackward, .Jump => rl.YELLOW,
            .Attack => rl.RED,
            else => rl.WHITE
        };


        // Color the character when they are hit.
        if(gameState.reactionComponents[entity].hitStun > 0)
        {
            drawState.color = rl.BLUE;
        }
    }

    return drawState;
}

// Render a single DrawState. Uses the results from PrepareDrawState() and renders one Character.
fn RenderDrawState(state: DrawState) void
{
    //rl.DrawTexture(state.texture, state.x, state.y, rl.WHITE);
    rl.DrawTextureRec(state.texture, rl.Rectangle{.x=0, .y=0, .width=@intToFloat(f32, state.texture.width)*state.xScale, .height=@intToFloat(f32, state.texture.height)*state.yScale}, 
                        rl.Vector2{.x=@intToFloat(f32, 
                        if(state.flipped) (state.x - state.texture.width) else state.x),.y= @intToFloat(f32, state.y)}, state.color);
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
    const position = gameState.physics_components[entity].position;
    const framesElapsed = gameState.timelineComponents[entity].framesElapsed;
    const facingLeft = gameState.physics_components[entity].facingLeft;

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
                for(temp) | hitboxTmp|
                {
                    const hitbox = if(facingLeft) common.TranslateHitboxFlipped(hitboxTmp,.{}) else common.TranslateHitbox(hitboxTmp,.{});
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
                for(temp) | hitboxTmp|
                {
                    const hitbox = if(facingLeft) common.TranslateHitboxFlipped(hitboxTmp,.{}) else common.TranslateHitbox(hitboxTmp,.{});

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

pub fn DrawCharacterDebugInfo(gameState: GameState, entity: usize) void
{
    const reaction = gameState.reactionComponents[entity];
    const player : i32 = @intCast(i32, entity);
    const framesElapsed = gameState.timelineComponents[entity].framesElapsed;
    const XOffset : i32 = player*200+10;
    const YOffset : i32 = 80;
    rl.DrawText(rl.FormatText("player: %d\nhitStop: %d\nhitStun: %d\nguardStun: %d\nframesElapsed: %d", player, reaction.hitStop, reaction.hitStun, reaction.guardStun, framesElapsed), XOffset, YOffset, 16, rl.BLACK);
}

pub fn DebugDrawTimeline(gameState: GameState, entity: usize) void
{
    _ = gameState;
    _ = entity;

    const player = @intCast(i32, entity);
    const timelineHeight = 10;
    const timelineXOffset = 10;
    const timelineYOffset = 30+player*(timelineHeight+10);
    const frameWidth = 15;
    const padding = 4;

    var totalFrames : i32 = 0;
    var activeFrame : i32 = 0;

    // Pull duration from the current action for the timelin
    if(gameState.stateMachineComponents[entity].context.ActionData) | actionData |
    {
        totalFrames = actionData.Duration;
        activeFrame = gameState.timelineComponents[entity].framesElapsed;
    }

    // When there is hitstun use the hitstun from the last hit for drawing the timeline
    const hitStun = gameState.reactionComponents[entity].hitStun;
    if(hitStun > 0)
    {
        totalFrames = gameState.statsComponents[entity].totalHitStun;
        activeFrame = totalFrames - hitStun;
    }

    // When there is guard stun use the guard stun from the last hit for drawing the timeline
    const guardStun = gameState.reactionComponents[entity].guardStun;
    if(guardStun > 0)
    {
        totalFrames = gameState.statsComponents[entity].totalGuardStun;
        activeFrame = totalFrames - guardStun;
    }

    var index : i32 = 0;
    while(index < totalFrames) : (index+=1)
    {
        const color = if(index == activeFrame) rl.YELLOW else rl.BLACK;
        rl.DrawRectangle(timelineXOffset+index*(frameWidth+padding), timelineYOffset, frameWidth, timelineHeight,  color);
    }
}

pub fn PollGamepadInput(gameState: *GameState, controller: i32, entity: usize) void
{
    if(!rl.IsGamepadAvailable(controller))
    {
        return;
    }

    var inputCommand = &gameState.inputComponents[entity].input_command;


    if(rl.IsGamepadButtonDown(controller, rl.GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_UP))
    {
        inputCommand.*.up = true;
    }

    if(rl.IsGamepadButtonDown(controller, rl.GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_DOWN))
    {
        inputCommand.*.down = true;
    }

    const bFlipInput = gameState.physics_components[entity].facingLeft;

    if(rl.IsGamepadButtonDown(controller, rl.GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_LEFT))
    {
        inputCommand.*.left = true;

        if(bFlipInput)
        {
            inputCommand.*.forward = true;
        }
        else
        {
            inputCommand.*.back = true;
        }
    }

    if(rl.IsGamepadButtonDown(controller, rl.GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_RIGHT))
    {
        inputCommand.*.right = true;

        if(bFlipInput)
        {
            inputCommand.*.back = true;
        }
        else
        {
            inputCommand.*.forward = true;
        }
    }


    if(rl.IsGamepadButtonDown(controller, rl.GamepadButton.GAMEPAD_BUTTON_RIGHT_FACE_LEFT))
    {
        inputCommand.*.attack = true;
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
    gameState.physics_components[0].position = .{.x = -200000, .y = 0 };
    gameState.physics_components[1].position = .{.x = 200000, .y = 0 };
    gameState.physics_components[0].facingLeft = false;
    gameState.physics_components[1].facingLeft = true;


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
        gameState.inputComponents[0].input_command.reset();
        gameState.inputComponents[1].input_command.reset();

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
            if(rl.IsKeyDown(rl.KeyboardKey.KEY_LEFT_CONTROL) and rl.IsKeyPressed(rl.KeyboardKey.KEY_F5))
            {
                std.debug.print("Reloading assets...\n", .{}); 
                AssetAllocator.deinit();
                AssetAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
                try gameState.LoadPersistentGameAssets(AssetAllocator.allocator());
            }

            // Debug color toggle
            if(rl.IsKeyPressed(rl.KeyboardKey.KEY_F9))
            {
                bDebugColorEnabled = !bDebugColorEnabled;
            }
        }

        if(rl.IsWindowFocused() )
        {
            PollGamepadInput(&gameState, 0, 0);
            PollGamepadInput(&gameState, 1, 1);
        }

        if(rl.IsWindowFocused())
        {
            if(rl.IsKeyDown(rl.KeyboardKey.KEY_W))
            {
                gameState.inputComponents[0].input_command.up = true;
            }

            if(rl.IsKeyDown(rl.KeyboardKey.KEY_S))
            {
                gameState.inputComponents[0].input_command.down = true;
            }

            if(rl.IsKeyDown(rl.KeyboardKey.KEY_A))
            {

                gameState.inputComponents[0].input_command.back = true;
            }

            if(rl.IsKeyDown(rl.KeyboardKey.KEY_D))
            {
                gameState.inputComponents[0].input_command.forward = true;
            }

            if(rl.IsKeyDown(rl.KeyboardKey.KEY_J))
            {
                gameState.inputComponents[0].input_command.attack = true;
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

        DrawCharacterDebugInfo(gameState, 0);
        DrawCharacterDebugInfo(gameState, 1);

        DebugDrawTimeline(gameState, 0);
        DebugDrawTimeline(gameState, 1);

        if(bPauseGame)
        {
            rl.DrawText("(Paused)", 10 + 150, 10, 16, rl.DARKGRAY);
        }
  
        rl.EndDrawing();
        //----------------------------------------------------------------------------------
    }
}
