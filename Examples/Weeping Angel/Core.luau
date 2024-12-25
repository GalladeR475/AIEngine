local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local AIEngine = require(ServerScriptService.AIEngine)

type AI = AIEngine.AI & {
    CanMove: boolean;
};

export type CoreMechanism = AIEngine.Mechanism & {
    OnPlayerFound: AIEngine.Signal;
    OnPlayerLost: AIEngine.Signal;
};

export type Solver = {
    Validate: () -> boolean;
    ValidateScan: () -> boolean;
};

local States = {
    Idle = 0;
    Active = 1;
};

return function(AI: AI, Solver: Solver): CoreMechanism
    local Mechanism = AIEngine.createMechanism();
    Mechanism.Name = "Core";

    Mechanism.OnPlayerFound = Mechanism.createSignal();
    Mechanism.OnPlayerLost = Mechanism.createSignal();

    Mechanism.OnLoaded:Once(function(...): ()
        local function EnterIdleState(): ()
            AI:EmitState(States.Idle);
        end;

        AI.OnHeartBeat:Connect(function(...): ()
            AI:EmitState(States.Active);
            AI.CanMove = true;
        end);

        Mechanism:WhileState(States.Active, function(State: AIEngine.State): ()
            if (not Solver.ValidateScan()) then
                EnterIdleState();
                return;
            end;

            local Player = Players.LocalPlayer;
            local Character = Player.Character;
            local Status, Waypoints = AI.Movement:ComputePathAsync(Character:GetPivot().Position);

            if (Status <= 0) then
                AI.Movement:CyclicLoopAsync(States.Active, AIEngine.WaypointToVector(Waypoints), function(Index: number, Waypoint: Vector3): number?
                    if (Index == 1) then
                        return 2;
                    end;
                    return;
                end);
            end;
        end);
    end);

    return Mechanism;
end;
