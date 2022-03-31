const math = @import("utils/math.zig");
const StateMachine = @import("ActionStates/StateMachine.zig");
const StandState = @import("ActionStates/CommonStates.zig");

const PhysicsComponent = struct {
    position: math.IntVector2D = .{},
    velocity: math.IntVector2D = .{},
    acceleration: math.IntVector2D = .{}
};

pub const GameState = struct {
    frameCount: i32 = 0,
    entityCount: i32 = 5,
    physicsComponents: [10]PhysicsComponent = [_]PhysicsComponent{.{}} ** 10
};

// Handles moving all entities which have a physics component
fn PhysicsSystem(gameState: *GameState) void {

    var entityIndex:usize = 0;
    while(entityIndex < gameState.entityCount)
    {
        const component = &gameState.physicsComponents[entityIndex];

        // move position based on the current velocity.
        component.position = component.position.Add(component.velocity);
        component.velocity = component.velocity.Add(component.acceleration);

        entityIndex += 1;
    }
}

pub fn UpdateGame(gameState: *GameState) void {
    PhysicsSystem(gameState);
    gameState.frameCount += 1;    
}