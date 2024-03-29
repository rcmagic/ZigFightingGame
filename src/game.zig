const std = @import("std");
const rl = @import("raylib");
const math = @import("utils/math.zig");
const game_simulation = @import("game_simulation.zig");
const GameState = @import("GameState.zig").GameState;
const asset = @import("asset.zig");
const character_data = @import("character_data.zig");
const CombatStateID = @import("ActionStates/StateMachine.zig").CombatStateID;
const common = @import("common.zig");
const input = @import("input.zig");
const editor = @import("editor.zig");
const c = @cImport({
    @cDefine("NO_FONT_AWESOME", "1");
    @cInclude("rlImGui.h");
});
const z = @import("zgui");

var texture: rl.Texture2D = undefined;

const DrawState = struct { x: i32 = 0, y: i32 = 0, xScale: f32 = 1.0, yScale: f32 = 1.0, flipped: bool = false, color: rl.Color = rl.WHITE, texture: rl.Texture2D = undefined };

const GroundOffset = 390;
const ScreenCenter = 400;

// Indicate whether or not we draw the debug colors for various character states
var bDebugColorEnabled = false;

// Prepare state struct which describes how to draw a character
fn prepareDrawState(gameState: GameState, entity: usize) DrawState {
    const position = gameState.physics_components[entity].position;

    const ScreenX = math.WorldToScreen(position.x) + ScreenCenter;
    const ScreenY = -math.WorldToScreen(position.y) + GroundOffset;

    var drawState = DrawState{ .x = ScreenX, .y = ScreenY };

    const facingLeft = gameState.physics_components[entity].facingLeft;
    // Drawing the sprite flipped when the entity is facing left.
    if (facingLeft) {
        drawState.xScale = -1.0;
    }

    drawState.flipped = facingLeft;

    // Get textured used to render the sprite
    if (gameState.gameData) |gameData| {
        const stateMachine = &gameState.state_machine_components[entity].stateMachine;

        const CurrentState = stateMachine.CurrentState;

        var actionName: []const u8 = "";
        if (stateMachine.Registery.CombatStates[@intFromEnum(CurrentState)]) |state| {
            actionName = state.name;
        }

        if (character_data.findAction(gameData.CharacterAssets.items[entity].*, gameData.ActionMaps.items[entity], actionName)) |actionData| {
            const imageRange = actionData.getActiveImage(gameState.timeline_components[entity].framesElapsed);

            // Get the sprite texture
            if (gameData.findSequenceTextures(entity, imageRange.sequence)) |sequence| {
                drawState.texture = sequence.textures.items[@intCast(imageRange.index)];
            }

            // Get the sprite offset
            if (gameData.CharacterAssets.items[entity].findSequence(gameData.ImageSequenceMap.items[entity], imageRange.sequence)) |sequence| {
                const image = sequence.images.items[@intCast(imageRange.index)];
                drawState.x += if (facingLeft) -image.x else image.x;
                drawState.y += image.y;
            }
        }
    }

    const reaction = gameState.reaction_components[entity];

    // Hit shake during hitstop of a character in hit or guard stun.
    if ((reaction.hitStop > 0) and ((reaction.hitStun > 0) or (reaction.guardStun > 0))) {
        const hitShakeDist = 4;
        const hitShake = -(hitShakeDist / 2) + hitShakeDist * @mod(gameState.reaction_components[0].hitStop, 2);
        drawState.x += hitShake;
    }

    if (bDebugColorEnabled) {
        const CurrentState = gameState.state_machine_components[entity].stateMachine.CurrentState;

        drawState.color = switch (CurrentState) {
            .Standing, .WalkingForward, .WalkingBackward, .Jump => rl.YELLOW,
            .Attack => rl.RED,
            else => rl.WHITE,
        };

        // Color the character when they are hit.
        if (gameState.reaction_components[entity].hitStun > 0) {
            drawState.color = rl.BLUE;
        }
    }

    return drawState;
}

// Render a single DrawState. Uses the results from prepareDrawState() and renders one Character.
fn renderDrawState(state: DrawState) void {
    const x: f32 = @floatFromInt(if (state.flipped) (state.x - state.texture.width) else state.x);
    //rl.DrawTexture(state.texture, state.x, state.y, rl.WHITE);
    const width: f32 = @floatFromInt(state.texture.width);
    const height: f32 = @floatFromInt(state.texture.height);
    const rect = rl.Rectangle{ .x = 0, .y = 0, .width = (state.xScale * width), .height = (state.yScale * height) };
    const pos = rl.Vector2{ .x = x, .y = @floatFromInt(state.y) };
    rl.DrawTextureRec(state.texture, rect, pos, state.color);
}

fn getActiveHitboxes(hitboxGroups: []const character_data.HitboxGroup, hitboxes: []character_data.Hitbox, framesElapsed: i32) usize {
    var count: usize = 0;
    for (hitboxGroups) |hitboxGroup| {
        if (hitboxGroup.isActiveOnFrame(framesElapsed)) {
            for (hitboxGroup.hitboxes.items) |hitbox| {
                hitboxes[count] = hitbox;
                count += 1;
            }
        }
    }

    return count;
}

// Hitboxes to draw.
var debugDrawHitboxes: [100]character_data.Hitbox = [_]character_data.Hitbox{.{}} ** 100;

fn drawCharacterHitboxes(gameState: GameState, entity: usize) void {
    const position = gameState.physics_components[entity].position;
    const framesElapsed = gameState.timeline_components[entity].framesElapsed;
    const facingLeft = gameState.physics_components[entity].facingLeft;

    const ScreenX = math.WorldToScreen(position.x) + ScreenCenter;
    const ScreenY = -math.WorldToScreen(position.y) + GroundOffset;

    const AxisLength = 40;
    const AxisThickness = 2;
    // Draw axis
    rl.DrawRectangle(ScreenX - AxisLength / 2, ScreenY, AxisLength, AxisThickness, rl.BLACK);
    rl.DrawRectangle(ScreenX, ScreenY - AxisLength / 2, AxisThickness, AxisLength, rl.BLACK);

    if (gameState.gameData) |gameData| {
        const stateMachine = &gameState.state_machine_components[entity].stateMachine;
        const CurrentState = stateMachine.CurrentState;

        var actionName: []const u8 = "";
        if (stateMachine.Registery.CombatStates[@intFromEnum(CurrentState)]) |state| {
            actionName = state.name;
        }

        if (character_data.findAction(gameData.CharacterAssets.items[entity].*, gameData.ActionMaps.items[entity], actionName)) |actionData| {
            const vulCount = getActiveHitboxes(actionData.vulnerable_hitbox_groups.items, debugDrawHitboxes[0..], framesElapsed);

            if (vulCount > 0) {
                const temp = debugDrawHitboxes[0..vulCount];
                for (temp) |hitboxTmp| {
                    const hitbox = if (facingLeft) common.translate_hitbox_flipped(hitboxTmp, .{}) else common.translate_hitbox(hitboxTmp, .{});
                    const left = ScreenX + math.WorldToScreen(hitbox.left);
                    const top = ScreenY - math.WorldToScreen(hitbox.top);
                    const width = math.WorldToScreen(hitbox.right - hitbox.left);
                    const height = math.WorldToScreen(hitbox.top - hitbox.bottom);
                    rl.DrawRectangleLines(left, top, width, height, rl.BLUE);
                }
            }

            const atkCount = getActiveHitboxes(actionData.attack_property.hitbox_groups.items, debugDrawHitboxes[0..], framesElapsed);

            if (atkCount > 0) {
                const temp = debugDrawHitboxes[0..atkCount];
                for (temp) |hitboxTmp| {
                    const hitbox = if (facingLeft) common.translate_hitbox_flipped(hitboxTmp, .{}) else common.translate_hitbox(hitboxTmp, .{});

                    const left = ScreenX + math.WorldToScreen(hitbox.left);
                    const top = ScreenY - math.WorldToScreen(hitbox.top);
                    const width = math.WorldToScreen(hitbox.right - hitbox.left);
                    const height = math.WorldToScreen(hitbox.top - hitbox.bottom);
                    rl.DrawRectangleLines(left, top, width, height, rl.RED);
                }
            }
            // Draw Default Hitbox
            {
                const data = gameData.CharacterAssets.items[entity];

                const hitbox = if (facingLeft) common.translate_hitbox_flipped(data.default_pushbox, .{}) else common.translate_hitbox(data.default_pushbox, .{});

                const left = ScreenX + math.WorldToScreen(hitbox.left);
                const top = ScreenY - math.WorldToScreen(hitbox.top);
                const width = math.WorldToScreen(hitbox.right - hitbox.left);
                const height = math.WorldToScreen(hitbox.top - hitbox.bottom);
                rl.DrawRectangleLines(left, top, width, height, rl.GREEN);
            }
        }
    }
}

pub fn drawCharacterDebugInfo(allocator: std.mem.Allocator, gameState: GameState, entity: usize) !void {
    const reaction = gameState.reaction_components[entity];
    const player: i32 = @intCast(entity);
    const framesElapsed = gameState.timeline_components[entity].framesElapsed;
    const XOffset: i32 = player * 200 + 10;
    const YOffset: i32 = 80;
    rl.DrawText(try rl.TextFormat(allocator, "player: {}\nhitStop: {}\nhitStun: {}\nguardStun:{}\nframesElapsed:{}", .{ player, reaction.hitStop, reaction.hitStun, reaction.guardStun, framesElapsed }), XOffset, YOffset, 16, rl.BLACK);
}

pub fn debugDrawTimeline(gameState: GameState, entity: usize) void {
    const player: i32 = @intCast(entity);
    const timelineHeight = 10;
    const timelineXOffset = 10;
    const timelineYOffset = 30 + player * (timelineHeight + 10);
    const frameWidth = 15;
    const padding = 4;

    var totalFrames: i32 = 0;
    var activeFrame: i32 = 0;

    // Pull duration from the current action for the timelin
    if (gameState.state_machine_components[entity].context.ActionData) |actionData| {
        totalFrames = actionData.duration;
        activeFrame = gameState.timeline_components[entity].framesElapsed;
    }

    // When there is hitstun use the hitstun from the last hit for drawing the timeline
    const hitStun = gameState.reaction_components[entity].hitStun;
    if (hitStun > 0) {
        totalFrames = gameState.stats_components[entity].totalHitStun;
        activeFrame = totalFrames - hitStun;
    }

    // When there is guard stun use the guard stun from the last hit for drawing the timeline
    const guardStun = gameState.reaction_components[entity].guardStun;
    if (guardStun > 0) {
        totalFrames = gameState.stats_components[entity].totalGuardStun;
        activeFrame = totalFrames - guardStun;
    }

    var index: i32 = 0;
    while (index < totalFrames) : (index += 1) {
        const color = if (index == activeFrame) rl.YELLOW else rl.BLACK;
        rl.DrawRectangle(timelineXOffset + index * (frameWidth + padding), timelineYOffset, frameWidth, timelineHeight, color);
    }
}

pub fn pollGamepadInput(gameState: *GameState, controller: i32, entity: usize) void {
    if (!rl.IsGamepadAvailable(controller)) {
        return;
    }

    const inputCommand = &gameState.input_components[entity].input_command;

    if (rl.IsGamepadButtonDown(controller, rl.GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_UP)) {
        inputCommand.*.up = true;
    }

    if (rl.IsGamepadButtonDown(controller, rl.GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_DOWN)) {
        inputCommand.*.down = true;
    }

    const bFlipInput = gameState.physics_components[entity].facingLeft;

    if (rl.IsGamepadButtonDown(controller, rl.GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_LEFT)) {
        inputCommand.*.left = true;

        if (bFlipInput) {
            inputCommand.*.forward = true;
        } else {
            inputCommand.*.back = true;
        }
    }

    if (rl.IsGamepadButtonDown(controller, rl.GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_RIGHT)) {
        inputCommand.*.right = true;

        if (bFlipInput) {
            inputCommand.*.back = true;
        } else {
            inputCommand.*.forward = true;
        }
    }

    if (rl.IsGamepadButtonDown(controller, rl.GamepadButton.GAMEPAD_BUTTON_RIGHT_FACE_LEFT)) {
        inputCommand.*.attack = true;
    }
}

pub fn gameLoop() !void {
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
    gameState.physics_components[0].position = .{ .x = -200000, .y = 0 };
    gameState.physics_components[1].position = .{ .x = 200000, .y = 0 };
    gameState.physics_components[0].facingLeft = false;
    gameState.physics_components[1].facingLeft = true;

    // Flag for showing hitboxes
    var bDebugShowHitboxes = false;

    // Flag for showing the editor
    var bShowEditor = false;

    var bPauseGame = false;
    var GameFrameCount: i32 = 0;

    //const texture = rl.LoadTexture("assets/animation/test_chara_1/color1/idle_00.png");

    if (gameState.gameData) |gameData| {
        if (gameData.findSequenceTextures(0, "stand")) |sequence| {
            texture = sequence.textures.items[0];
        }
    }

    // Imgui setup
    c.rlImGuiSetup(true);
    defer c.rlImGuiShutdown();

    // zgui setup
    z.initNoContext(std.heap.c_allocator);
    defer z.deinitNoContext();

    // Our 2D Camera
    var Camera: rl.Camera2D = .{
        .offset = .{ .x = 0, .y = 0 },
        .target = .{ .x = 0, .y = 0 },
        .rotation = 0,
        .zoom = 1,
    };

    Camera.offset.x = 0;

    const screenWidth: f32 = 800;
    const screenHeight: f32 = 450;

    // Main game loop
    while (!rl.WindowShouldClose()) { // Detect window close button or ESC key

        const widthF: f32 = @floatFromInt(rl.GetScreenWidth());
        const heightF: f32 = @floatFromInt(rl.GetScreenHeight());
        //float scale = MIN((float)GetScreenWidth()/gameScreenWidth, (float)GetScreenHeight()/gameScreenHeight);
        Camera.zoom = @min(widthF / screenWidth, heightF / screenHeight);
        // Advance the game by one frame.
        var bAdvanceOnce = false;

        // Reset input to not held down before polling
        gameState.input_components[0].input_command.reset();
        gameState.input_components[1].input_command.reset();

        if (rl.IsWindowFocused()) {
            if (rl.IsKeyPressed(rl.KeyboardKey.KEY_F3)) {
                bPauseGame = !bPauseGame;
            } else if (rl.IsKeyPressed(rl.KeyboardKey.KEY_F2)) {
                bAdvanceOnce = true;
            }
            // Toggle hitbox display
            else if (rl.IsKeyPressed(rl.KeyboardKey.KEY_F4)) {
                bDebugShowHitboxes = !bDebugShowHitboxes;
            }

            // Force reload assets with ctrl+F5
            if (rl.IsKeyDown(rl.KeyboardKey.KEY_LEFT_CONTROL) and rl.IsKeyPressed(rl.KeyboardKey.KEY_F5)) {
                std.debug.print("Reloading assets...\n", .{});
                AssetAllocator.deinit();
                AssetAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
                try gameState.LoadPersistentGameAssets(AssetAllocator.allocator());
            }

            if (rl.IsKeyPressed(rl.KeyboardKey.KEY_F8)) {
                bShowEditor = !bShowEditor;
            }

            // Debug color toggle
            if (rl.IsKeyPressed(rl.KeyboardKey.KEY_F9)) {
                bDebugColorEnabled = !bDebugColorEnabled;
            }
        }

        if (rl.IsWindowFocused()) {
            pollGamepadInput(&gameState, 0, 0);
            pollGamepadInput(&gameState, 1, 1);
        }

        if (!bShowEditor and rl.IsWindowFocused()) {
            if (rl.IsKeyDown(rl.KeyboardKey.KEY_W)) {
                gameState.input_components[0].input_command.up = true;
            }

            if (rl.IsKeyDown(rl.KeyboardKey.KEY_S)) {
                gameState.input_components[0].input_command.down = true;
            }

            const bFlipInput = gameState.physics_components[0].facingLeft;

            if (rl.IsKeyDown(rl.KeyboardKey.KEY_A)) {
                if (bFlipInput) {
                    gameState.input_components[0].input_command.forward = true;
                } else {
                    gameState.input_components[0].input_command.back = true;
                }
            }

            if (rl.IsKeyDown(rl.KeyboardKey.KEY_D)) {
                if (bFlipInput) {
                    gameState.input_components[0].input_command.back = true;
                } else {
                    gameState.input_components[0].input_command.forward = true;
                }
            }

            if (rl.IsKeyDown(rl.KeyboardKey.KEY_J)) {
                gameState.input_components[0].input_command.attack = true;
            }
        }

        // Game Simulation
        if (!bPauseGame or bAdvanceOnce) {
            try gameState.input_components[0].UpdateInput(gameState.input_components[0].input_command);

            try game_simulation.updateGame(&gameState);

            // Count the number of game frames that have been simulated.
            GameFrameCount += 1;
        }

        // Draw
        rl.BeginDrawing();
        rl.BeginMode2D(Camera);

        rl.ClearBackground(rl.WHITE);

        renderDrawState(prepareDrawState(gameState, 0));
        renderDrawState(prepareDrawState(gameState, 1));

        // Draw hitboxes when enabled.
        if (bDebugShowHitboxes) {
            drawCharacterHitboxes(gameState, 0);
            drawCharacterHitboxes(gameState, 1);
        }

        rl.EndMode2D();

        // if(gameState.gameData) | gameData |
        // {
        //     const hitbox = gameData.HitboxGroup.hitboxes.items[0];
        //    rl.DrawRectangleLines(hitbox.left, hitbox.top, hitbox.right - hitbox.left, hitbox.top - hitbox.bottom, rl.RED);
        // }

        // Debug information
        rl.DrawText(try rl.TextFormat(std.heap.c_allocator, "Game Frame: {}", .{GameFrameCount}), 10, 10, 16, rl.DARKGRAY);

        try drawCharacterDebugInfo(std.heap.c_allocator, gameState, 0);
        try drawCharacterDebugInfo(std.heap.c_allocator, gameState, 1);

        debugDrawTimeline(gameState, 0);
        debugDrawTimeline(gameState, 1);

        if (bPauseGame) {
            rl.DrawText("(Paused)", 10 + 150, 10, 16, rl.DARKGRAY);
        }

        //----------------------------------------------------------------------------------

        if (bShowEditor) {
            try editor.Tick(gameState, AssetAllocator.allocator());
        }

        rl.EndDrawing();
    }
}
