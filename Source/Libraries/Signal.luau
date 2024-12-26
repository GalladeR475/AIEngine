--[=[
    Signal
        lightweight signal module
        adapted from https://github.com/Scythe-Technology/luau-roblox

    modified: GalladeR475
]=]

local Signal = {};
Signal.__index = Signal;


export type Connection = {
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
        FireQueue: {{ any }};
        ProcessingQueue: { Connection? };
        Head: Connection?;
    },
    {} :: typeof(Signal)
));

local function Is(Value: any): boolean
    return (type(Value) == "table" and getmetatable(Value) == Signal);
end

Signal.Is = Is;

function Signal.new(): Signal
    return setmetatable({
        Firing = false,
        Processing = false,
        FireQueue = {},
        ProcessingQueue = {},
        Head = nil,
    }, Signal);
end

local function Disconnect(Connection: Connection)
    Connection.Connected = false;
    Connection.Callback = nil :: any;
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
    local Current = self.Head;
    Connection.Next = Current;
    if (Current) then
        Current.Previous = Connection;
    end
    self.Head = Connection;
end

function Signal.Connect(self: Signal, Callback: (...any) -> ()): Connection
    assert(self.FireQueue, "Signal is destroyed");
    local Connection: Connection = {
        Signal = self,
        Callback = Callback,
        Connected = true,
        Disconnect = Disconnect,
    };
    if (self.Firing) then
        table.insert(self.ProcessingQueue, Connection);
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
    local Queue = self.FireQueue;
    while (#Queue > 0) do
        self.Firing = true;
        local Args = table.remove(Queue, 1) :: { any };
        local Current = self.Head;
        while (Current) do
            task.spawn(Current.Callback, unpack(Args));
            Current = Current.Next;
        end
        self.Firing = false;
        for _, Connection in self.ProcessingQueue do
            ApplyConnectionToNode(self, Connection);
        end
        table.clear(self.ProcessingQueue);
    end
    table.clear(self.FireQueue);
    self.Processing = false;
end

function Signal.Fire(self: Signal, ...)
    table.insert(self.FireQueue, { ... });
    ProcessFireQueue(self);
end

function Signal.Destroy(self: Signal)
    local Current = self.Head;
    while (Current) do
        Current:Disconnect();
        Current = Current.Next;
    end
    table.clear(self.FireQueue);
    table.clear(self.ProcessingQueue);
    self.Head = nil;
    self.FireQueue = nil :: any;
end

return Signal;