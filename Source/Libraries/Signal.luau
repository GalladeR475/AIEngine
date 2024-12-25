--[=[
    Signal
        lightweight signal module
        adapted from https://github.com/Scythe-Technology/luau-roblox

    modified: GalladeR475
]=]

local Signal = {};
Signal.__index = Signal;


type Connection = {
	Signal: Signal;
    Next: Connection?,
    Previous: Connection?,
    Callback: (...any) -> (),
    Connected: boolean,
    Disconnect: (self: Connection) -> (),
};

export type Signal = typeof(setmetatable(
    {} :: {
        Firing: boolean;
        Processing: boolean;
        Fire: {{ any }};
        Queue: { Connection? };
        Head: Connection?;
    },
    {} :: typeof(Signal)
));

local function Is(Value: any): boolean
    return (type(Value) == "table" and getmetatable(Value) == Signal);
end

function Signal.new(): Signal
    return setmetatable({
        Firing = false,
        Processing = false,
        Fire = {},
        Queue = {},
        Head = nil,
    }, Signal);
end

Signal.Is = Is;

local function Disconnect(Connection: Connection)
    Connection.Connected = false;
    Connection.Callback = nil::any;
    if (Connection.Previous) then
        Connection.Previous.Next = Connection.Next;
    end
    local Signal = Connection.Signal;
    if (Signal.Head == Connection) then
        Signal.Head = Connection.Next;
        return;
    end
end

local function ApplyConnectionToNode(self: Signal, Connection: Connection)
    local current = self.Head;
    Connection.Next = current;
    if (current) then
        current.Previous = Connection;
    end
    self.Head = Connection;
end

function Signal.Connect(self: Signal, Callback: (...any) -> ()): Connection
    assert(self.Fire, "Signal is destroyed");
    local Connection: Connection = {
        Signal = self,
        Callback = Callback,
        Connected = true,
        Disconnect = Disconnect,
    };
    if (self.Firing) then
        table.insert(self.Queue, Connection);
        return Connection;
    end
    ApplyConnectionToNode(self, Connection);
    return Connection;
end

function Signal.Once(self: Signal, Callback: (...any) -> ()): Connection
    local Connection;
    Connection = Signal.Connect(self, function(...)
        Connection:Disconnect();
        Callback(...);
    end);
    return Connection;
end

function Signal.Wait(self: Signal): ...any
    local Thread = coroutine.running();
    local Connection;
    Connection = Signal.Connect(self, function(...)
        Connection:Disconnect();
        task.spawn(Thread, ...);
    end);
    return coroutine.yield();
end

local function ProcessFireQueue(self: Signal)
    if (self.Processing) then
        return;
    end
    self.Processing = true;
    local Queue = self.Fire;
    while (#Queue > 0) do
        self.Firing = true;
        local Args = table.remove(Queue, 1)::{any};
        local Current = self.Head;
        while (Current) do
            task.spawn(Current.Callback, unpack(Args));
            Current = Current.Next;
        end
        self.Firing = false;
        for _, Connection in self.Queue do
            ApplyConnectionToNode(self, Connection);
        end
        table.clear(self.Queue);
    end
    table.clear(self.Fire);
    self.Processing = false;
end

function Signal.Fire(self: Signal, ...)
    table.insert(self.Fire, {...});
    ProcessFireQueue(self);
end

function Signal.Destroy(self: Signal)
    local Current = self.Head;
    while Current do
        Current:Disconnect();
        Current = Current.Next;
    end
    table.clear(self.Fire);
    table.clear(self.Queue);
    self.Head = nil;
    self.Fire = nil::any;
end

return Signal;