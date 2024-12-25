local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService");
local AIEngine = require(ServerScriptService.AIEngine);

local Player = Players.LocalPlayer;

local AI = AIEngine.new((script.Parent :: any) :: Model, {
    AgentHeight = 5;
    AgentRadius = 2;
    AgentCanJump = false;
    Costs = {
        Avoid = math.huge;
    };
    PathSettings = {
        SupportPartialPath = true;
    };
});

local VisionRange = 100;

local RayParams = RaycastParams.new();
RayParams.RespectCanCollide = true;
RayParams.IgnoreWater = true;
RayParams.FilterType = Enum.RaycastFilterType.Exclude;
RayParams.FilterDescendantsInstances = ({ AI.Character });

local Solver = {};

function Solver.Validate(): boolean
    local Character = Player.Character;
    if (Character) then
        local Humanoid: Humanoid = Character:FindFirstChild("Humanoid");
        return (Humanoid and Humanoid.Health > 0);
    end;
    return false;
end;

function Solver.ValidateScan(): boolean
    if (not Solver.Validate()) then
        return false;
    end;

    local PlayerCharacter = Player.Character;
    local Character = AI.Character;

    local Origin = PlayerCharacter:GetPivot().Position;
    local Direction = (Character:GetPivot().Position - Origin).Unit;
    local RayResult = workspace:Raycast(Origin, Direction * VisionRange, RayParams);

    if (RayResult) then
        if (RayResult.Instance:IsDescendantOf(PlayerCharacter)) then
            local DotProduct = Direction:Dot(PlayerCharacter:GetPivot().LookVector);

            if (DotProduct <= 0) then
                return true;
            end;
        end;
    end;

    return false;
end


local Examples = ServerScriptService:WaitForChild("Examples"):WaitForChild("Weeping Angel");

local CoreMechanism = require(Examples:WaitForChild("Core"));
local CoreInstance = CoreMechanism(AI, Solver);

AI:LoadMechanism(CoreInstance);

AI:EmitState(0);