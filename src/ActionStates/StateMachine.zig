const std = @import("std");

// Identifies common character states.
const CombatStateID = enum(u32) 
{
    Standing,
    Crouching,
    WalkingForward,
    WalkingBackwards,
    Jump,
    _
};

// A context is passed into the combat state callbacks.
const CombatStateContext = struct 
{ 
    dummy: i32 = 0 // Zig can sometimes have trouble with empty structs.
};

// Provides an interface for combat states to respond to various events
const CombatStateCallbacks = struct
{
    OnStart: ?fn(context: *CombatStateContext) void = null,         // Called when starting an action
    OnUpdate: ?fn(context: *CombatStateContext) void = null,        // Called every frame
    OnEnd: ?fn(context: *CombatStateContext) void = null            // Called when finishing an action
};


// Stores the combat states used for a character.
const CombatStateRegistery = struct 
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

// Runs and keeps track of a state machine
const CombatStateMachineProcessor = struct
{
    Registery: CombatStateRegistery = .{},
    CurrentState: CombatStateID = CombatStateID.Standing,

    Context: ?*CombatStateContext,

    pub fn UpdateStateMachine(self: *CombatStateMachineProcessor) void
    { 
        if(self.Registery.CombatStates[@enumToInt(self.CurrentState)]) | State |
        {
            if(State.OnUpdate) | OnUpdate |
            {
                if(self.Context) | context |
                {
                    OnUpdate(context);
                }
            }
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