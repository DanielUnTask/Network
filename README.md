# Network
Network is an advanced abstraction on top of RemoteEvent that allows you to create typed and organized channels within a single remote, automatically synchronized between server and client using internal attributes.

Instead of creating multiple RemoteEvents, Network generates a single RemoteEvent that manages multiple channels identified by a GUID. Each channel is registered as an attribute of the remote, allowing the client to automatically discover and synchronize available channels.

[Wally Package](https://wally.run/package/danieluntask/network?version=0.0.5)

## Remote Example
A channel behaves like a normal RemoteEvent, but it lives inside a single managed remote.
You can create as many channels as you want without creating extra instances.

### Server
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Packages.Network)

local MyRemoteEvent = Network.server("MyRemoteEvent")
local PrintSomething = MyRemoteEvent:Get("PrintSomething")

PrintSomething.OnServerEvent:Connect(function(player: Player, message: string)
	print(player.Name, message) -- output will be "Player1 hello from client"
end)

PrintSomething:FireAllClients("Hello From Server")
```
### Client
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Packages.Network)

local MyRemoteEvent = Network.client("MyRemoteEvent")
local PrintSomething = MyRemoteEvent:Get("PrintSomething")

PrintSomething.OnClientEvent:Connect(function(message: string)
	print(message) -- output will be "hello from server"
end)

PrintSomething:FireServer("hello from client")
```
## Response Example
Response mode turns a channel into a request-response system, 
similar to RemoteFunction, but still using RemoteEvent internally.

It supports:
- Configurable timeout
- Up to 128 concurrent pending responses per player
- Automatic cleanup on timeout or player leave
### Server
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Packages.Network)

local MyRemoteEvent = Network.server("MyRemoteEvent")
local GetRandomItem = MyRemoteEvent:Get("GetRandomItem"):Response()

GetRandomItem:SetCallback(function(player: Player) 	
	return {
		item = "sword",
		rarity = "common"
	}
end)
```
### Client
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Packages.Network)

type ItemData = {
	item: string,
	rarity: string,
}

local MyRemoteEvent = Network.client("MyRemoteEvent")
local GetRandomItem = MyRemoteEvent:Get("GetRandomItem"):Response() :: Network.ClientChannel<(...any), (ItemData)>

local itemData = GetRandomItem:FireServer()
print(itemData) -- output will be { item = "sword", rarity = "common" }
```

## Signals Example
Network also includes a standalone signal system for same-context communication (server-server or client-client).
This does not replicate between server and client.
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Packages.Network)

local MySignal = Network.signal() :: Network.NetworkSignal<number, number>

MySignal:Connect(function(a: number, b: number)
   print(a + b) -- output will be 3	
end)

MySignal:Fire(1, 2)
```
## Wrap Signals Example
wrapSignal allows you to convert an existing RBXScriptSignal or another NetworkSignal into a typed NetworkSignal.

This is useful for:
- Keeping a consistent API
- Adding generics
- Abstracting Roblox services behind your own signal system
```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Packages.Network)

local MyWrappedSignal = Network.wrapSignal(Players.PlayerAdded) :: Network.NetworkSignal<Player>

MyWrappedSignal:Connect(function(player: Player)
	print(player.Name) -- output will be "Player1"
end)
```