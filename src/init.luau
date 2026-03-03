--!strict

--- Services
local RunService = game:GetService("RunService")

--- Dependencies
local Types = require(script.types)
local Remote = require(script.Classes.Remote)
local external = require(script.external)

--- Variables
local Cache = {}
local Folder = nil

--- Import Types
export type ServerResponse<A... = (), B... = ()> = Types.ServerResponse<A..., B...>
export type ClientResponse<A... = (), B... = ()> = Types.ClientResponse<A..., B...>

export type NetworkRemoteClient = Types.NetworkRemoteClient
export type NetworkRemoteServer = Types.NetworkRemoteServer
export type ClientChannel<A... = (), B... = ()> = Types.ClientChannel<A..., B...>
export type AttributeServer<A... = (), B... = ()> = Types.ServerChannel<A..., B...>

export type NetworkSignal<A... = ()> = Types.NetworkSignal<A...>
export type NetworkConnection<A... = ()> = Types.NetworkConnection<A...>

--- Init
if RunService:IsServer() then
	Folder = Instance.new("Folder")
	Folder.Name = "Networks"
	Folder.Parent = script
else
	Folder = script:WaitForChild("Networks")
end

--- Util Function
local function create(remoteName: string, customParent: Folder?)
	if Cache[remoteName] then
		return Cache[remoteName]
	end

	local parent = customParent or Folder
	local remote = RunService:IsServer() and Remote.RemoteServer(remoteName, parent) :: any
		or Remote.RemoteClient(remoteName, parent) :: any

	Cache[remoteName] = remote
	remote._trove:Add(function()
		Cache[remoteName] = nil
	end)

	return remote
end

return {
	client = function(remoteName: string, customParent: Folder?): NetworkRemoteClient
		assert(RunService:IsClient(), `"Client()"; can only be used on the client.`)
		return create(remoteName, customParent)
	end,
	server = function(remoteName: string, customParent: Folder?): NetworkRemoteServer
		assert(RunService:IsServer(), `"Server()"; can only be used on the server.`)
		return create(remoteName, customParent)
	end,
	signal = external.Signal.new,
	wrapSignal = external.Signal.wrap,
}
