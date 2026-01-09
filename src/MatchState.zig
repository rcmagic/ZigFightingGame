const std = @import("std");
const component = @import("component.zig");
const GameState = @import("GameState.zig");

// Used to inform a match state which callback is being made.
const CallbackType = enum(u32) {
    Enter, // Called once when transitioning into the match state
    Exit, // Called once when transitioning from the match state
    Tick, // Called every frame when the match state is active
};

pub const MatchStateContext = struct {
    ElapsedTime: i32 = 0,
    Transition: ?*const fn (context: *MatchStateContext, callback: CallbackType) void = null,
    gameState: *GameState.GameState,
};

fn EntryState(context: *MatchStateContext, callback: CallbackType) void {
    switch (callback) {
        .Enter => std.debug.print("EntryState: Enter\n", .{}),
        .Exit => std.debug.print("EntryState: Exit\n", .{}),
        .Tick => {
            std.debug.print("EntryState Tick {}\n", .{context.ElapsedTime});
            context.Transition = MatchIntroState;
        },
    }
}

fn MatchIntroState(context: *MatchStateContext, callback: CallbackType) void {
    switch (callback) {
        .Enter => std.debug.print("MatchIntroState:  Enter\n", .{}),
        .Exit => std.debug.print("MatchIntroState: Exit\n", .{}),
        .Tick => {
            if (context.ElapsedTime > 60 * 2) {
                context.Transition = FightingState;
            }
        },
    }
}

fn FightingState(context: *MatchStateContext, callback: CallbackType) void {
    switch (callback) {
        .Enter => std.debug.print("FightingState:  Enter\n", .{}),
        .Exit => std.debug.print("FightingState: Exit\n", .{}),
        .Tick => {
            std.debug.print("FightingState Tick {}\n", .{context.ElapsedTime});

            for (context.gameState.stats_components) |stat| {
                if (stat.health <= 0) {
                    context.Transition = RoundEnd;
                }
            }
        },
    }
}

fn RoundEnd(context: *MatchStateContext, callback: CallbackType) void {
    switch (callback) {
        .Enter => std.debug.print("RoundEnd:  Enter\n", .{}),
        .Exit => std.debug.print("RoundEnd: Exit\n", .{}),
        .Tick => std.debug.print("RoundEnd Tick {}\n", .{context.ElapsedTime}),
    }
}

// Manages the match state machine
pub const MatchHandler = struct {
    ElapsedTime: i32 = 0,
    CurrentStateCallback: *const fn (context: *MatchStateContext, callback: CallbackType) void = undefined,

    pub fn Tick(self: *MatchHandler, gameState: *GameState.GameState) !void {
        self.ElapsedTime += 1;

        var Context: MatchStateContext = .{ .ElapsedTime = self.ElapsedTime, .gameState = gameState };
        self.CurrentStateCallback(&Context, CallbackType.Tick);

        if (Context.Transition) |NextState| {
            self.CurrentStateCallback(&Context, CallbackType.Exit);

            self.ElapsedTime = 0;

            NextState(&Context, CallbackType.Enter);
            self.CurrentStateCallback = NextState;
        }
    }

    pub fn init() MatchHandler {
        return .{ .CurrentStateCallback = EntryState };
    }

    pub fn Start(self: *MatchHandler, gameState: *GameState.GameState) !void {
        var Context: MatchStateContext = .{ .gameState = gameState };
        self.CurrentStateCallback(&Context, CallbackType.Enter);
    }
};
