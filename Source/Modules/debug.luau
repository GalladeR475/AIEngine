--[=[
	Debug
	  Special Debugging Module for AIEngine

	author: Sythivo
--]=]

local AIEngine = script.Parent.Parent;
local Libraries = AIEngine:WaitForChild("Libraries");

local Memory = require(Libraries:WaitForChild("Memory"));

local Debug = {};

Debug.prototype = {};
Debug.prototype.__index = Debug.prototype;

local New = function(Class: string): (Properties: any) -> Instance
	local Object = Instance.new(Class);
	return function(Properties: any)
		if (type(Properties) ~= "table") then
			return Object;
		end;

		for Index, Value in Properties do
			if (typeof(Value) == "Instance" and type(Index) == "number") then
				Value.Parent = (Object);
				continue;
			end

			Object[Index] = Value;
		end

		return Object;
	end;
end

local CreateVisualPart = function()
	return New "Part" {
		CanQuery = false;
		CanCollide = false;
		CanTouch = false;
		Anchored = true;
		TopSurface = Enum.SurfaceType.Smooth;
		Material = Enum.Material.Neon;
		BottomSurface = Enum.SurfaceType.Smooth;
		Size = Vector3.new(0.5, 0.5, 0.5);
	};
end

local CreatePointVisualizer = function(Color: Color3, Text: string?)
	local StartAttachment = New "Attachment" {};
	local EndAttachment = New "Attachment" {
		Position = Vector3.new(0, 9, 0);
	};
	local Beam = New "Beam" {
		Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color), ColorSequenceKeypoint.new(1, Color)};
		LightInfluence = 1;
		FaceCamera = true;
		Width0 = 0.5;
		Width1 = 0.5;
		TextureSpeed = 0.2;
		TextureLength = 2;
		Texture = "rbxassetid://3517446796";
		Attachment0 = StartAttachment;
		Attachment1 = EndAttachment;
	};
	if (Text) then
		New "BillboardGui" {
			Parent = EndAttachment;
			LightInfluence = 0;
			StudsOffset = Vector3.new(0, 0.75, 0);
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
			ClipsDescendants = true;
			Active = true;
			AlwaysOnTop = false;
			Brightness = 2;
			Size = UDim2.new(3, 5, 0.75, 5);
			New "TextLabel" {
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal);
				TextColor3 = Color;
				Text = Text;
				Size = UDim2.new(1, 0, 1, 0);
				BackgroundTransparency = 1;
				TextWrapped = true;
				TextScaled = true;
			};
		};
	end

	return StartAttachment, EndAttachment, Beam;
end

function Debug.new()
	return (setmetatable({
		Memory = Memory.new();
	}, Debug.prototype));
end

type Point = {
	Visualizer: {
		StartAttachment: Attachment?;
		EndAttachment: Attachment?;
		Beam: Beam?;
	};
	Element: Part;
	InMemory: (self: Point) -> Point;
	SetParent: (self: Point, parent: Instance) -> Point;
	SetVisualizer: (self: Point, Color: Color3, Text: string?) -> Point;
	SetPosition: (self: Point, Vector: Vector3) -> Point;
	DestroyVisualizer: (self: Point) -> Point;
	Destroy: (self: Point) -> ();
}

function Debug.prototype:RenderPoint(Vector: Vector3, Color: Color3, Text: string?): Point
	local Debugger = self;
	local Point = ({});
	
	Point.Visualizer = {
		StartAttachment = nil;
		EndAttachment = nil;
		Beam = nil;
	};

	Point.Element = CreateVisualPart();

	function Point:InMemory()
		Debugger.Memory:Add(self.Element);
		return self;
	end

	function Point:SetParent(parent: Instance)
		self.Element.Parent = parent;
		return self;
	end

	function Point:DestroyVisualizer()
		for Index, Value in Point.Visualizer do
			if (Value) then
				Value:Destroy();
				Point.Visualizer[Index] = nil;
			end
		end

		return self;
	end

	function Point:SetVisualizer(Color: Color3, Text: string?)
		self:DestroyVisualizer();

		if (Text) then
			local StartAttachment, EndAttachment, Beam = CreatePointVisualizer(Color, Text);
			Point.Visualizer.StartAttachment = StartAttachment; Point.Visualizer.EndAttachment = EndAttachment; Point.Visualizer.Beam = Beam;
			StartAttachment.Parent = self.Element; EndAttachment.Parent = self.Element; Beam.Parent = self.Element;
		end

		self.Element.Color = Color;

		return self;
	end

	function Point:SetPosition(Vector)
		self.Element.Position = Vector;
		return self;
	end

	function Point:Destroy()
		self:DestroyVisualizer();
		self.Element:Destroy();
	end

	Point:SetVisualizer(Color, Text);
	Point:SetPosition(Vector);

	return Point;
end

function Debug.prototype:Clear()
	self.Memory:Empty();
end

return Debug;