--[=[
	AIEngine
	  AI Engine for Roblox

	author: Sythivo
	fork: GalladeR475
--]=]

type AgentParameters = {
	AgentRadius: number?;
	AgentHeight: number?;
	AgentCanJump: boolean?;
	Costs: {
		[string]: number;
	}?;
	PathSettings: {
		SupportPartialPath: boolean?;
	}?;
};

local RunService = game:GetService("RunService");
local PathfindingService = game:GetService("PathfindingService");

local Modules = script:WaitForChild("Modules");
local Libraries = script:WaitForChild("Libraries");

local Signal = require(Libraries:WaitForChild("Signal"));

local FFlag = require(Modules:WaitForChild("FFlag")).new();
local Debug = require(Modules:WaitForChild("Debug"));

export type Signal = Signal.Signal;
export type Connection = Signal.Connection;

type Shared = {
	createSignal: () -> Signal;
};

type Referenced = {
	__ref: AI;
};

export type State = { [string]: any } & {
	Value: number | string;
	Changed: boolean;
};

export type Mechanism = Referenced & Shared & {
	Name: string?;

	OnLoaded: Signal;

	OnState: (self: Mechanism, State: number | string, Callback: (state: State) -> ()) -> Signal.Connection;
	WhileState: (self: Mechanism, State: number | string, Callback: (state: State) -> ()) -> Signal.Connection;
};

export type AI = Shared & {
	Debug: typeof(Debug.new());
	Mechanisms: { Mechanism };
	Agent: Model;
	AgentParameters: AgentParameters?;
	Path: Path;
	State: State;

	OnHeartbeat: Signal<>;
	OnStateChange: Signal<>;
	OnFallingLimit: Signal<>;
	Destroyed: Signal<>;

	Heartbeat: RBXScriptConnection;

	EmitState: (self: AI, State: State | number | string) -> ();
	createMechanism: () -> Mechanism;
	LoadMechanism: (self: AI, Mechanism: Mechanism) -> ();

	Physical: Physical;
	Movement: Movement;
};
type Physical = Referenced & {
	GetHumanoidRoot: (self: Physical) -> (Humanoid?, BasePart?);
	OnTouched: (self: Physical, callback: (part: BasePart) -> (), onlyChild: boolean?) -> {RBXScriptConnection};
};
type Movement = Referenced & {
	MovingSpeed: number;
	
	MoveTo: (self: Movement, Position: Vector3) -> RBXScriptSignal;
	IsStuck: (self: Movement) -> boolean;
	IsMoving: (self: Movement) -> boolean;
	CancelMoveTo: (self: Movement) -> ();
	SetWalkSpeed: (self: Movement, Speed: number) -> ();
	ComputePathAsync: (self: Movement, Position: Vector3) -> (number, {PathWaypoint});
	CyclicLoopAsync: (self: Movement, state: State | number | string, Vectors: {Vector3}, iteration: (number, Vector3) -> number?) -> ();
};

local GeometricXZPlane = Vector3.new(1, 0, 1);
local ToXZPlane = function(Vector: Vector3): Vector3
	return (GeometricXZPlane * Vector);
end

local FloorResolution = function(num: number, resolution: number): number
	return math.floor(num*resolution)/resolution;
end

local function IsLiteral(Value: any): boolean
	return (typeof(Value) == "number" or typeof(Value) == "string");
end

local AIEngine = {};

AIEngine.FFlag = FFlag;

FFlag:DEFINE("EngineDebuggingLevel", RunService:IsStudio() and 1 or 0);

AIEngine.FFlags = {
	EngineDebuggingLevel = "EngineDebuggingLevel";
};

--// AI Engine Prototype
AIEngine.prototype = ({});
function AIEngine.prototype:__index(Key)
	local Value = self.Isolated[Key];
	if (Value) then
		return (Value);
	end
	return rawget(self, Key) or rawget(AIEngine.prototype, Key);
end
function AIEngine.prototype:__newindex(Key, Value)
	if (Key == "State") then
		self:EmitState(Value);
	else
		rawset(self.Isolated, Key, Value);
	end
end

--// Mechanism Prototype
AIEngine.mechanics_prototype = ({});
AIEngine.mechanics_prototype.__index = AIEngine.mechanics_prototype;

--[=[
	Creates a new AI Engine
	
	@param character The character to control
	@param agent The pathfinding agent
]=]
function AIEngine.new(Agent: Model, AgentParameters: AgentParameters): AI
	local self = setmetatable({
		Isolated = ({});
		Debug = Debug.new();
		Mechanisms = ({});
		Agent = Agent;
		AgentParameters = AgentParameters;
		Path = PathfindingService:CreatePath(AgentParameters);

		OnHeartbeat = Signal.new();
		OnStateChange = Signal.new();
		
		OnFallingLimit = Signal.new();
		Destroyed = Signal.new();
	}, AIEngine.prototype);

	self.Physical = table.clone(self.Physical);
	self.Physical.__ref = self; self.Physical:__init();
	self.Movement = table.clone(self.Movement);
	self.Movement.__ref = self; self.Movement:__init();

	self.State = AIEngine.newState(-1, true); --// State of the AI, default: Unknown(-1)

	self.Heartbeat = RunService.Heartbeat:Connect(function(Step)
		self.OnHeartbeat:Fire(Step);
	end);

	if (FFlag.EngineDebuggingLevel >= 2) then
		local Debug = self.Debug;
		local Humanoid, RootPart = self.Physical:GetHumanoidRoot();
		if (Humanoid and RootPart) then
			local WalkingPoint = Debug:RenderPoint(Humanoid.WalkToPoint, Color3.fromRGB(0, 165, 96), "Humanoid Walk Point");
			self.OnHeartbeat:Connect(function(deltaTime)
				WalkingPoint.element.Position = WalkingPoint.element.Position:Lerp(Humanoid.WalkToPoint, math.clamp(deltaTime/60, 0, 1));
				WalkingPoint:SetPosition(Humanoid.WalkToPoint);
			end)
			WalkingPoint:SetParent(workspace);
		end
	end

	return self;
end

type newState = 
	& ((Value: number | string) -> State) 
	& ((Value: number | string, Changed: boolean?) -> State);

AIEngine.newState = function(Value: number | string, Changed: boolean?)
	return ({
		Value = Value;
		Changed = Changed;
	});
end :: newState;

type WaypointToVector = 
	& ((Waypoints: PathWaypoint) -> Vector3)
	& ((Waypoints: { PathWaypoint }) -> { Vector3 });

AIEngine.WaypointToVector = function(Waypoints: PathWaypoint | { PathWaypoint })
	if (type(Waypoints) == "table") then
		local Vectors = table.create(#Waypoints);
		for _, waypoint in Waypoints do
			table.insert(Vectors, waypoint.Position);
		end
		return Vectors;
	else
		return Waypoints.Position;
	end
end :: WaypointToVector;

--[[
	Creates a new mechanism
]]
function AIEngine.createMechanism(): Mechanism
	local self = setmetatable({
		OnLoaded = Signal.new();
	}, AIEngine.mechanics_prototype);

	return self;
end

AIEngine.prototype.createSignal = Signal.new;
AIEngine.mechanics_prototype.createSignal = Signal.new;

--// AI Methods

function AIEngine.prototype:LoadMechanism(Mechanism: Mechanism)
	if (table.find(self.Mechanisms, Mechanism)) then
		warn("[AIEngine] Mechanism already loaded");
		return;
	end
	if (FFlag.EngineDebuggingLevel >= 2) then
		local name = Mechanism.Name or "Unnamed";
		print("[AIEngine] Loading Mechanism:", name);
	end
	table.insert(self.Mechanisms, Mechanism);
	Mechanism.__ref = self;
	Mechanism.OnLoaded:Fire();
end

function AIEngine.prototype:EmitState(state: State | number | string)
	if (FFlag.EngineDebuggingLevel >= 3) then
		print("[AI] State Emitted", state);
	end

	if (IsLiteral(state)) then
		local changed = self.State.Value ~= state;
		state = AIEngine.newState(state::(number|string), changed);
	end

	rawset(self.Isolated, "State", state);
	self.OnStateChange:Fire(state);
end

--[[ Physical ]] do
	local Physical = ({
		__init = function(self)
			local AI = self.__ref :: AI;
			local _, RootPart = self:GetHumanoidRoot();
			local _, Size = AI.Agent:GetBoundingBox();
			
			RootPart.Destroying:Once(function()
				AI.Destroyed:Fire();
			end);
			local limitHeight = workspace.FallenPartsDestroyHeight/2;
			RunService.Stepped:Connect(function()
				if (limitHeight + Size.Y > RootPart.Position.Y) then
					AI.OnFallingLimit:Fire();
				end
			end)
		end
	});

	function Physical:GetHumanoidRoot()
		local AI = self.__ref :: AI;
		local Agent = AI.Agent;
		if (Agent) then
			local Humanoid = Agent:FindFirstChild("Humanoid");
			if (Humanoid) then
				local RootPart = Humanoid.RootPart;
				if (RootPart) then
					return Humanoid, RootPart;
				end
			end
		end
		return;
	end

	function Physical:OnTouched(Callback: (part: BasePart) -> (), ChildOnly: boolean?)
		local AI = self.__ref :: AI;
		local Connections = {};
		local Agent = AI.Agent;
		for _, v in ChildOnly and Agent:GetChildren() or Agent:GetDescendants() do
			if (v:IsA("BasePart")) then
				table.insert(Connections, v.Touched:Connect(Callback));
			end
		end
		if (#Connections >= 20) then
			warn(`[AIEngine] You may experience degraded performance, due to high amount of connected touch events: {#Connections}`);
			if (not ChildOnly) then
				warn(`[AIEngine] Suggestion: Consider using 'onlyChild' parameter or a dedicated Part for touch events`);
			end
		end
		return Connections;
	end

	AIEngine.prototype.Physical = Physical;
end

--[[ Movement ]] do
	local Movement = ({
		__init = function(self)
			local AI = self.__ref :: AI;
			local Humanoid = AI.Physical:GetHumanoidRoot();
			if (Humanoid) then
				self.Running = Humanoid.Running:Connect(function(Speed: number)
					self.MovingSpeed = Speed;
				end)
			end
			self.MovingSpeed = 0;
		end
	});

	function Movement:MoveTo(Vector: Vector3): RBXScriptSignal?
		local AI = self.__ref :: AI;

		if (FFlag.EngineDebuggingLevel >= 4) then
			print("[AI] Moving To Vector<WorldSpace>", Vector);
		end
		local Humanoid = AI.Physical:GetHumanoidRoot();
		if (Humanoid) then
			Humanoid:MoveTo(Vector);
			return Humanoid.MoveToFinished;
		end
		return;
	end
	
	function Movement:CancelMoveTo()
		local AI = self.__ref :: AI;

		local Humanoid, RootPart = AI.Physical:GetHumanoidRoot();
		if (Humanoid) then
			Humanoid:MoveTo(RootPart.CFrame.Position);
		end
	end

	function Movement:IsMoving()
		return (self.MovingSpeed > 0);
	end

	function Movement:IsStuck()
		local AI = self.__ref :: AI;

		local Humanoid, RootPart = AI.Physical:GetHumanoidRoot();
		if (Humanoid) then
			local PointDistance = (ToXZPlane(RootPart.CFrame.Position) - ToXZPlane(Humanoid.WalkToPoint)).Magnitude;
			if (PointDistance <= 0.25) then
				return false;
			end
			
			if (FloorResolution(ToXZPlane(RootPart.AssemblyLinearVelocity).Magnitude, 10) == 0 and 
				FloorResolution(RootPart.AssemblyAngularVelocity.Magnitude, 10) == 0) then
				return true;
			end
		end
		return false;
	end

	function Movement:CyclicLoopAsync(State: State | number | string, Vectors: {Vector3}, Iteration: (number, Vector3) -> number, LifeTime: number?)
		if (#Vectors == 0) then
			return;
		end
		
		local OptimizedVectors = table.clone(Vectors);
		for Index = #OptimizedVectors, 1, -1 do
			local Last = OptimizedVectors[Index - 1];
			local Vector = OptimizedVectors[Index];
			if (Last and Vector and (Vector - Last).Magnitude <= 0.2) then
				table.remove(OptimizedVectors, Index);
			end
		end
		
		Vectors = OptimizedVectors;

		local AI = self.__ref :: AI;
		
		local Humanoid = AI.Physical:GetHumanoidRoot();
		
		local DEBUG = FFlag.EngineDebuggingLevel >= 1;
		
		local CycleSize = #Vectors;
		local DEBUG_RenderParts;
		if (DEBUG) then
			local Debug = AI.Debug;
			Debug:Clear();
			DEBUG_RenderParts = table.create(CycleSize);
			Debug:RenderPoint(Vectors[1], Color3.fromRGB(98, 255, 98), "START"):InMemory():SetParent(workspace);
			for Index = 2, CycleSize - 1, 1 do
				DEBUG_RenderParts[Index] = Debug:RenderPoint(Vectors[Index], Color3.fromRGB(50, 127, 131)):InMemory():SetParent(workspace);
			end
			Debug:RenderPoint(Vectors[CycleSize], Color3.fromRGB(255, 245, 98), "END"):InMemory():SetParent(workspace);
		end

		local IsStateLiteral = IsLiteral(State);
		
		local CompletedReason = 0;
		local StartedTime = time() + (LifeTime or 4);

		local HeartbeatConnection: RBXScriptConnection;
		HeartbeatConnection = AI.OnHeartbeat:Connect(function()
			if (self:IsStuck()) then
				if (StartedTime <= time()) then
					HeartbeatConnection:Disconnect();
					if (FFlag.EngineDebuggingLevel >= 3) then
						print("[AI] Stuck");
					end
					CompletedReason = 1;
					self:CancelMoveTo();
				elseif (Humanoid) then
					self:MoveTo(Humanoid.WalkToPoint);
				end
			end
		end);

		for Index, Vector: Vector3 in Vectors do
			if (CompletedReason ~= 0) then
				break;
			end
			local Action = Iteration(Index, Vector);
			if (Action) then
				if (Action == 1) then
					CompletedReason = 2;
					break;
				elseif (Action == 2) then
					continue;
				end
			end

			if (IsStateLiteral) then
				if (AI.State.Value ~= State) then
					CompletedReason = -1;
					break;
				end
			elseif (AI.State ~= State) then
				CompletedReason = -1;
				break;
			end

			if (DEBUG) then
				local LastRenderPart = DEBUG_RenderParts[Index - 1];
				if (LastRenderPart and not LastRenderPart.Locked) then
					LastRenderPart:SetVisualizer(Color3.fromRGB(50, 127, 131));
				end
				local RenderPart = DEBUG_RenderParts[Index];
				if (RenderPart) then
					RenderPart:SetVisualizer(Color3.fromRGB(98, 247, 255), "TARGET");
				end
			end
			
			local MovementFinished = self:MoveTo(Vector);
			if (MovementFinished) then
				MovementFinished:Wait();
			end
		end
		
		if (HeartbeatConnection.Connected) then
			HeartbeatConnection:Disconnect();
		end

		return CompletedReason;
	end
	
	function Movement:SetWalkSpeed(Speed: number)
		local AI = self.__ref :: AI;

		local Humanoid = AI.Physical:GetHumanoidRoot();
		if (Humanoid) then
			Humanoid.WalkSpeed = Speed;
		end
	end
	
	function Movement:ComputePathAsync(Vector: Vector3)
		local AI = self.__ref :: AI;

		local StartVector = AI.Agent:GetPivot().Position;
		AI.Path:ComputeAsync(StartVector, Vector);

		return AI.Path.Status.Value, AI.Path:GetWaypoints();
	end

	AIEngine.prototype.Movement = Movement;
end

--// Mechanism Methods

function AIEngine.mechanics_prototype:WhileState(State: number | string, Callback: (state: State) -> ())
	local AI = self.__ref :: AI;
	local Active = false;
	local Update = function()
		if (AI.State.Value == State and not Active) then
			if (FFlag.EngineDebuggingLevel >= 3) then
				print("[AI] Entering StateLoop", State);
			end
			Active = true;
			while (AI.State.Value == State) do
				Callback(AI.State);
				AI.OnHeartbeat:Wait();
			end
			if (FFlag.EngineDebuggingLevel >= 3) then
				print("[AI] Exitting StateLoop", State);
			end
			Active = false;
		end
	end
	task.spawn(Update);
	return AI.OnStateChange:Connect(Update);
end

function AIEngine.mechanics_prototype:OnState(State: number | string, Callback: (state: State) -> ())
	local AI = self.__ref :: AI;
	return AI.OnStateChange:Connect(function(NewState: State)
		if (NewState.Value == State) then
			Callback(NewState);
		end
	end);
end

return AIEngine;