const std = @import("std");
const component = @import("../component.zig");
const input = @import("../input.zig");
const character_data = @import("../character_data.zig");

// Identifies common character states.
pub const CombatStateID = enum(u32) {
    Standing,
    Crouching,
    WalkingForward,
    WalkingBackward,
    Jump,
    Attack,
    Special,
    Reaction,
    LaunchReaction,
    GuardReaction,
    GrabReaction,
    _,
};

// A context is passed into the combat state callbacks.
pub const CombatStateContext = struct {
    bTransition: bool = false, // indicates that a state transition has been triggered
    NextState: CombatStateID = .Standing, // indicates the next state to transition to.
    next_named_action: []const u8 = "",
    next_action: *const character_data.ActionProperties = undefined,
    ref_transition: bool = false,
    named_transition: bool = false,
    input_command: input.InputCommand = .{},
    input_component: *component.InputComponent = undefined,
    physics_component: *component.PhysicsComponent = undefined,
    timeline_component: *component.TimelineComponent = undefined,
    reaction_component: *component.ReactionComponent = undefined,
    action_flags_component: *component.ActionFlagsComponent = undefined,
    ActionData: *const character_data.ActionProperties = undefined,
    character_asset: *const character_data.CharacterProperties = undefined,

    // Trigger a transition to a new state.
    pub fn TransitionToState(self: *CombatStateContext, StateID: CombatStateID) void {
        self.bTransition = true;
        self.NextState = StateID;
        self.next_named_action = "";
        self.named_transition = false;
        self.ref_transition = false;
    }

    pub fn TransitionToStateRef(self: *CombatStateContext, action_data: *const character_data.ActionProperties) void {
        self.bTransition = true;
        self.next_named_action = "";
        self.named_transition = false;
        self.next_action = action_data;
        self.ref_transition = true;
    }

    pub fn TransitionToNamedAction(self: *CombatStateContext, next_state: []const u8) void {
        self.bTransition = true;
        self.NextState = .Attack;
        self.next_named_action = next_state;
        self.named_transition = true;
        self.ref_transition = false;
    }
};

// Provides an interface for combat states to respond to various events
pub const CombatStateCallbacks = struct {
    OnStart: ?*const fn (context: *CombatStateContext) void = null, // Called when starting an action
    OnUpdate: ?*const fn (context: *CombatStateContext) void = null, // Called every frame
    OnEnd: ?*const fn (context: *CombatStateContext) void = null, // Called when finishing an action
};

// Stores the combat states used for a character.
pub const CombatStateRegistery = struct {
    const MAX_STATES = 256;
    CombatStates: [MAX_STATES]?CombatStateCallbacks = [_]?CombatStateCallbacks{null} ** MAX_STATES,

    pub fn RegisterCommonState(self: *CombatStateRegistery, state_id: CombatStateID, state: anytype) void {
        var Callbacks: CombatStateCallbacks = .{};

        if (@hasDecl(state, "OnStart")) {
            Callbacks.OnStart = @field(state, "OnStart");
        }

        if (@hasDecl(state, "OnUpdate")) {
            Callbacks.OnUpdate = @field(state, "OnUpdate");
        }

        if (@hasDecl(state, "OnEnd")) {
            Callbacks.OnEnd = @field(state, "OnEnd");
        }
        self.CombatStates[@intFromEnum(state_id)] = Callbacks;
    }
};

pub fn HandleTransition(
    stateMachine: *CombatStateMachineProcessor,
    context: *CombatStateContext,
    characterData: *const character_data.CharacterProperties,
    actionmap: std.StringHashMap(*const character_data.ActionProperties),
) void {
    if (!context.bTransition) return;

    if (stateMachine.Registery.CombatStates[@intFromEnum(stateMachine.CurrentState)]) |State| {
        // Perform a state transition when requested

        // Call the OnEnd function of the previous state to do any cleanup required.
        if (State.OnEnd) |OnEnd| {
            OnEnd(context);
        }

        // Call the OnStart function on the next state to do any setup required
        if (stateMachine.Registery.CombatStates[@intFromEnum(context.NextState)]) |NextState| {
            if (NextState.OnStart) |OnStart| {
                OnStart(context);
            }
        }

        // Make sure the transition isn't performed more than once.
        context.bTransition = false;

        if (context.named_transition) {
            context.named_transition = false;

            context.ActionData = character_data.findAction(
                context.character_asset.*,
                actionmap,
                context.next_named_action,
            );

            stateMachine.CurrentState = context.ActionData.combat_state;
            stateMachine.current_action = context.ActionData;
        } else if (context.ref_transition) {
            context.ActionData = context.next_action;
            stateMachine.CurrentState = context.next_action.combat_state;
            stateMachine.current_action = context.ActionData;
        } else {
            if (stateMachine.Registery.CombatStates[@intFromEnum(context.NextState)]) |NextState| {
                _ = NextState;
                context.ActionData = character_data.findAction(
                    characterData.*,
                    actionmap,
                    @tagName(context.NextState),
                );
            }
            // Make the next state current.
            stateMachine.CurrentState = context.NextState;
            stateMachine.current_action = context.ActionData;
        }

        // Reset the timeline when a transition has occurred.
        context.timeline_component.framesElapsed = 0;

        // Make it possible for the new action to hit an opponent
        context.reaction_component.attackHasHit = false;

        // Disable special canceling on state transition
        context.reaction_component.attackHasHitForSpecialCancel = false;
    }
}

// Runs and keeps track of a state machine
pub const CombatStateMachineProcessor = struct {
    Registery: CombatStateRegistery = .{},
    CurrentState: CombatStateID = .Standing,
    current_action: *const character_data.ActionProperties,

    pub fn UpdateStateMachine(
        self: *CombatStateMachineProcessor,
        context: *CombatStateContext,
        characterData: *const character_data.CharacterProperties,
        actionmap: std.StringHashMap(*const character_data.ActionProperties),
    ) void {
        context.character_asset = characterData;

        // Perform a state transition when requested
        HandleTransition(
            self,
            context,
            characterData,
            actionmap,
        );

        if (self.Registery.CombatStates[@intFromEnum(self.CurrentState)]) |State| {
            // Advance the timeline when there is no hitstop
            if (context.reaction_component.hitStop <= 0) {
                context.timeline_component.framesElapsed += 1;
            }

            // Run the update function on the current action
            if (State.OnUpdate) |OnUpdate| {
                OnUpdate(context);
            }

            // Handle returning to idle or looping at the end of an action.
            if (self.Registery.CombatStates[@intFromEnum(self.CurrentState)]) |CurrentState| {
                _ = CurrentState;
                const actionData = context.ActionData;

                if (context.timeline_component.framesElapsed >= actionData.duration) {
                    // Reset the timeline for actions that loop
                    if (actionData.isLooping) {
                        context.timeline_component.framesElapsed = 0;
                    }
                    // Otherwise return to idle
                    else if (!context.bTransition) {
                        // Go back to idle
                        if (context.physics_component.position.y > 0) {
                            context.TransitionToState(.Jump);
                        } else {
                            context.TransitionToState(.Standing);
                        }
                    }
                }
            }

            // Perform a state transition when requested
            HandleTransition(
                self,
                context,
                characterData,
                actionmap,
            );
        }
    }
};

test "Register a combat state." {
    var Registery = CombatStateRegistery{};
    var TestState = CombatStateCallbacks{};

    try std.testing.expect(Registery.CombatStates[0] == null);

    Registery.RegisterCommonState(.Standing, &TestState);

    try std.testing.expect(Registery.CombatStates[0] != null);
}

const TestContext = struct {
    base: CombatStateContext = .{},
    TestVar: bool = false,
    TestVar2: bool = false,
};

fn TestOnUpdate(context: *CombatStateContext) void {
    const context_sub: TestContext = @fieldParentPtr("base", context);
    context_sub.TestVar = true;
}

test "Test running a state update on a state machine processor." {
    var context = TestContext{};
    var Processor = CombatStateMachineProcessor{ .Context = &context.base };

    var TestState = CombatStateCallbacks{ .OnUpdate = TestOnUpdate };
    Processor.Registery.RegisterCommonState(.Standing, &TestState);

    Processor.UpdateStateMachine();

    try std.testing.expect(context.TestVar == true);
}

test "Test transitioning the state machine from one state to another." {
    const Dummy = struct {
        // Test transitioning from one common state to another
        fn StandingOnUpdate(context: *CombatStateContext) void {
            context.TransitionToState(.Jump);
        }

        fn StandingOnEnd(context: *CombatStateContext) void {
            const context_sub: TestContext = @fieldParentPtr("base", context);
            context_sub.TestVar = true;
        }

        fn JumpOnStart(context: *CombatStateContext) void {
            const context_sub: TestContext = @fieldParentPtr("base", context);
            context_sub.TestVar2 = true;
        }
    };

    var context = TestContext{};
    var Processor = CombatStateMachineProcessor{ .Context = &context.base };

    var StandingCallbacks = CombatStateCallbacks{ .OnUpdate = Dummy.StandingOnUpdate, .OnEnd = Dummy.StandingOnEnd };
    var JumpCallbacks = CombatStateCallbacks{ .OnStart = Dummy.JumpOnStart };

    Processor.Registery.RegisterCommonState(.Standing, &StandingCallbacks);
    Processor.Registery.RegisterCommonState(.Jump, &JumpCallbacks);

    Processor.UpdateStateMachine();

    // Test that the transition is finished
    try std.testing.expect(context.base.bTransition == false);

    // Test that the state machine correctly transitioned to the jump state
    try std.testing.expectEqual(Processor.CurrentState, .Jump);

    // Test to see if OnEnd was called on the previous state.
    try std.testing.expect(context.TestVar == true);

    // Test to see if OnStart was called on the next state.
    try std.testing.expect(context.TestVar2 == true);
}
