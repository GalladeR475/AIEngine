--[=[
	Memory
		A light-weight janitor module
		adapted from https://github.com/Sythivo/AIEngine

	author: GalladeR475
]=]

local Memory = ({});

local Dispose = function(Object: any)
    local Method = (Memory.Methods[typeof(Object)]);

    if (Method and type(Method) == "function") then
        local Success, Error = pcall(Method, Object);
        if (not Success) then
            warn(`[Memory] Failed to clean up: {Error}`);
        end
    end
end

Memory.Methods = ({
    ["function"] = function(Callback: () -> ())
        Callback();
    end;
    ["table"] = function(Table: {any})
        for Index, Value in Table do
            Dispose(Value);
            Table[Index] = (nil);
        end
    end;
    Instance = function(Instance: Instance)
        if (Instance:IsA("Tween")) then
            Instance:Cancel();
        end
        Instance:Destroy();
    end;
    RBXScriptConnection = function(RBXScriptConnection: RBXScriptConnection)
        RBXScriptConnection:Disconnect();
    end;
});

Memory.__index = Memory;

function Memory.new()
    return setmetatable({
        Collection = {};
    }, Memory);
end

function Memory:Add<T...>(...: T...): T...
    local Pack = table.pack(...);
    Pack.n = nil;
    for _, Value in Pack do
        table.insert(self.Collection, Value);
    end
    return ...;
end

function Memory:Empty()
    for Index: number, Value: any in self.Collection do
        Dispose(Value);
    end
    table.clear(self.Collection);
end

return Memory;