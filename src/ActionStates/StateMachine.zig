const std = @import("std");
const Component = @import("../Component.zig");
const Input = @import("../Input.zig");
const CharacterData = @import("../CharacterData.zig");
// Identifies common character states.
pub const CombatStateID = enum(u32) 
{
    Standing,
    Crouching,
    WalkingForward,
    WalkingBackward,
    Jump,
    Attack,
    Reaction,
    _
};

// A context is passed into the combat state callbacks.
pub const CombatStateContext = struct 
{ 
    bTransition: bool = false,                           // indicates that a state transition has been triggered
    NextState: CombatStateID = CombatStateID.Standing,    // indicates the next state to transition to.
    InputCommand: Input.InputCommand = .{},
    PhysicsComponent: *Component.PhysicsComponent = undefined,
    TimelineComponent: *Component.TimelineComponent = undefined,
    ReactionComponent: *Component.ReactionComponent = undefined,
    ActionData: ?*CharacterData.ActionProperties = null,
};

// Provides an interface for combat states to respond to various events
pub const CombatStateCallbacks = struct
{
    Name: []const u8 = "",
    OnStart: ?fn(context: *CombatStateContext) void = null,         // Called when starting an action
    OnUpdate: ?fn(context: *CombatStateContext) void = null,        // Called every frame
    OnEnd: ?fn(context: *CombatStateContext) void = null            // Called when finishing an action
};


// Stores the combat states used for a character.
pub const CombatStateRegistery = struct 
{
    const MAX_STATES = 256;
    CombatStates: [MAX_STATES]?*CombatStateCallbacks = [_]?*CombatStateCallbacks{null} ** MAX_STATES,

    pub fn RegisterCommonState(self: *CombatStateRegistery, StateID: CombatStateID, StateCallbacks:*CombatStateCallbacks) void
    {
        // TODO: assert(StateID <= LastCommonStateID). Whatever the zig way of doing this is...
        // condition might be ''' StateID < std.meta.fields(CombatStateID).len '''
        self.CombatStates[@enumToInt(StateID)] = StateCallbacks;        
    }
};

pub fn HandleTransition(stateMachine: *CombatStateMachineProcessor, context: *CombatStateContext, characterData: CharacterData.CharacterProperties,
                                actionmap: std.StringHashMap(usize)) void
{
    if(stateMachine.Registery.CombatStates[@enumToInt(stateMachine.CurrentState)]) | State |
    {
        // Perform a state transition when requested
        if(context.bTransition) 
        {
            // Call the OnEnd function of the previous state to do any cleanup required.
            if(State.OnEnd) | OnEnd | { OnEnd(context); }

            // Call the OnStart function on the next state to do any setup required
            if(stateMachine.Registery.CombatStates[@enumToInt(context.NextState)]) | NextState |
            {
                if(NextState.OnStart) | OnStart | { OnStart(context); }                              
            }

            // Make sure the transition isn't performed more than once.
            context.bTransition = false;

            // Make the next state current.
            stateMachine.CurrentState = context.NextState;

            if(stateMachine.Registery.CombatStates[@enumToInt(context.NextState)]) | NextState |
            {
                context.ActionData = CharacterData.FindAction(characterData, actionmap, NextState.Name);
            }

            // Reset the timeline when a transition has occurred. 
            context.TimelineComponent.framesElapsed = 0;

            // Make it possible for the new action to hit an opponent
            context.ReactionComponent.attackHasHit = false;
        } 
    }
}

// Runs and keeps track of a state machine
pub const CombatStateMachineProcessor = struct
{
    Registery: CombatStateRegistery = .{},
    CurrentState: CombatStateID = CombatStateID.Standing,


    pub fn UpdateStateMachine(self: *CombatStateMachineProcessor, context: *CombatStateContext, characterData: CharacterData.CharacterProperties,
                                actionmap: std.StringHashMap(usize)) void
    { 
        if(self.Registery.CombatStates[@enumToInt(self.CurrentState)]) | State |
        {
            // Run the update function on the current action
            if(State.OnUpdate) | OnUpdate | { OnUpdate(context); }

            // Advance the timeline              
            context.TimelineComponent.framesElapsed += 1; 
            
            // Handle returning to idle or looping at the end of an action.
            if(self.Registery.CombatStates[@enumToInt(self.CurrentState)]) | CurrentState |
            {
                if(CharacterData.FindAction(characterData, actionmap, CurrentState.Name)) | actionData |
                {   
                    if(context.TimelineComponent.framesElapsed >= actionData.Duration)
                    {
                        // Reset the timeline for actions that loop
                        if(actionData.IsLooping)
                        {
                            context.TimelineComponent.framesElapsed = 0;                        
                        }
                        // Otherwise return to idle
                        else 
                        {
                            // TODO: Support going back to idle
                        }
                    }
                }
            }         

            // Perform a state transition when requested
            HandleTransition(self, context, characterData, actionmap);                              
        }
    }

};


test "Register a combat state." 
{
    var Registery = CombatStateRegistery{};
    var TestState = CombatStateCallbacks{};

    try std.testing.expect(Registery.CombatStates[0] == null);

    Registery.RegisterCommonState(CombatStateID.Standing, &TestState);

    try std.testing.expect(Registery.CombatStates[0] != null);
}


const TestContext = struct
{
    base: CombatStateContext = .{},    
    TestVar: bool = false,
    TestVar2: bool = false,
};

fn TestOnUpdate(context: *CombatStateContext) void 
{ 
    const context_sub = @fieldParentPtr(TestContext, "base", context);
    context_sub.TestVar = true;
}

test "Test running a state update on a state machine processor." 
{    
    var context = TestContext{};
    var Processor = CombatStateMachineProcessor{.Context = &context.base};

    var TestState = CombatStateCallbacks { .OnUpdate = TestOnUpdate };
    Processor.Registery.RegisterCommonState(CombatStateID.Standing, &TestState);

    Processor.UpdateStateMachine();

    try std.testing.expect(context.TestVar == true);
}

test "Test transitioning the state machine from one state to another." 
{    
    const Dummy = struct
    {
        // Test transitioning from one common state to another
        fn StandingOnUpdate(context: *CombatStateContext) void
        {
            context.bTransition = true;
            context.NextState = CombatStateID.Jump;
        }

        fn StandingOnEnd(context: *CombatStateContext) void
        {
            const context_sub = @fieldParentPtr(TestContext, "base", context);
            context_sub.TestVar = true;
        }

        fn JumpOnStart(context: *CombatStateContext) void
        {
            const context_sub = @fieldParentPtr(TestContext, "base", context);
            context_sub.TestVar2 = true;
        }
    };

    var context = TestContext{};
    var Processor = CombatStateMachineProcessor{.Context = &context.base};

    var StandingCallbacks = CombatStateCallbacks { .OnUpdate = Dummy.StandingOnUpdate, .OnEnd = Dummy.StandingOnEnd };
    var JumpCallbacks = CombatStateCallbacks { .OnStart = Dummy.JumpOnStart };
    
    Processor.Registery.RegisterCommonState(CombatStateID.Standing, &StandingCallbacks);
    Processor.Registery.RegisterCommonState(CombatStateID.Jump, &JumpCallbacks);
    
    Processor.UpdateStateMachine();

    // Test that the transition is finished
    try std.testing.expect(context.base.bTransition == false);

    // Test that the state machine correctly transitioned to the jump state
    try std.testing.expectEqual(Processor.CurrentState, CombatStateID.Jump);

    // Test to see if OnEnd was called on the previous state.
    try std.testing.expect(context.TestVar == true);

    // Test to see if OnStart was called on the next state.
    try std.testing.expect(context.TestVar2 == true);
}