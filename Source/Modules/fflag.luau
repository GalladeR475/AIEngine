--[=[
	Fast Flag
	  A module to manage fast flags settings and access to experimental features.

	author: Sythivo
--]=]

type FlagInfo = {
	Name: string;
	Value: any;
	Type: string;
};

type DEFINE_FLAG = <T>(self: FastFlag, Name: string, Value: T) -> ();
type FastFlag = {
	Flags: { 
		[string]: FlagInfo
	};
	DEFINE: DEFINE_FLAG;
	SETFASTFLAG: DEFINE_FLAG;
	DUMP: (self: FastFlag) -> string;
};

local FastFlag = ({});

local CreateFlagInfo = function(Name: string, Value: any): FlagInfo
	return ({
		Name = Name;
		Value = Value;
		Type = typeof(Value);
	});
end

function FastFlag:__index(Key)
	local Flag: FlagInfo? = self.Flags[Key];
	if (Flag) then
		return (Flag.Value);
	end
	return rawget(self, Key) or rawget(FastFlag, Key);
end

function FastFlag.new(): FastFlag
	local self = setmetatable({
		Flags = ({});
	}, FastFlag);

	return self;
end

function FastFlag:DEFINE(Name: string, Value: any)
	self.Flags[Name] = CreateFlagInfo(Name, Value);
end

function FastFlag:SETFASTFLAG(Name: string, Value: any)
	return self:DEFINE(Name, Value);
end

function FastFlag:DUMP(): string
	local list = ({});
	for i, v in self.Flags do
		table.insert(list, ("%s: {default: %s, type: %s}"):format(i, v.Value, v.type));
	end
	return table.concat(list, "\n");
end

return FastFlag;