--!nocheck
--!native
--[[
	MIT License

	Copyright (c) 2026 Force Warrior

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

	SkidBindables:
	
	What:
		Replacement for roblox's BindableEvents
		Doubly Linked List Signal Implementation
	
	Why:
		Speed: disconnecting a listener is O(1) in SkidBindables (doubly linked list node unlink)
		Safety: you can disconnect listeners *while* the event is firing without bugs
		Memory: handles garbage collection automatically to prevent memory leaks
		Features: includes yield safe async firing, fast pooled firing, immediate sync firing, and async batching
]]

--// [Implementions]
local SkibidiWire = {}
SkibidiWire.__index = SkibidiWire

local SkidBindables = {}
SkidBindables.__index = SkidBindables

local _pool = {}


--// [Thread pooling]


local function _runner()
	while true do
		local args = table.pack(coroutine.yield())
		local fn = args[1]
		local ok, err = pcall(fn, table.unpack(args, 2, args.n))
		if not ok then warn(err) end
		_pool[#_pool + 1] = coroutine.running()
	end
end

local function _spawnPooled(fn, ...)
	local co = _pool[#_pool]
	if co then
		_pool[#_pool] = nil
	else
		co = coroutine.create(_runner)
		coroutine.resume(co)
	end
	return coroutine.resume(co, fn, ...)
end


--// [Creation And Cleanup]


--[[
	What: creates a new signal (the alpha)
	
	Usage: local event = SkidBindables.new()
--]]
function SkidBindables.new(): SkidBindables
	local self = setmetatable({
		_alpha = nil --// The "Head" of our linked list
	}, SkidBindables)
	return (self :: any) :: SkidBindables
end
--[[
	What: permanently destroys the signal and disconnects everything
	
	Usage: when an object (like a part or GUI) is being destroyed to free memory
--]]
function SkidBindables:Destroy()
	if getmetatable(self) ~= SkidBindables then return end

	debug.profilebegin("SkidBindables:Destroy")
	local selfTyped: SkidBindables = (self :: any)
	local node = selfTyped._alpha

	--// Go through the entire list and kill every connection manually
	while node do
		local nextNode = node._nextSimp

		--// break memory cycles
		node._rizzler = nil
		node._yap = nil
		node._noCap = false
		node._prevSimp = nil
		node._nextSimp = nil 
		
		node = nextNode
	end

	selfTyped._alpha = nil
	setmetatable((self :: any), nil) --// Kill the signal itself
	debug.profileend()
end

--[[
	What: disconnects this specific listener so it stops receiving events
	
	Usage: call this when a specific script is done listening, for example: closing a menu
--]]
function SkibidiWire:Disconnect()
	local me: SkibidiWire = (self :: any)

	if not me._noCap then return end --// already disconnected
	me._noCap = false

	local bigBoss = me._rizzler
	if not bigBoss then return end

	--// if i am the head, the next node becomes the new head
	if bigBoss._alpha == me then
		bigBoss._alpha = me._nextSimp
	end

	--// connect previous node to next node
	local prevNode = me._prevSimp
	local nextNode = me._nextSimp

	if prevNode then
		prevNode._nextSimp = nextNode
	end

	if nextNode then
		nextNode._prevSimp = prevNode
	end

	--// help garbage collection
	me._rizzler = nil
	me._prevSimp = nil
	me._nextSimp = nil
	me._yap = nil
end

--[[
	What: disconnects everything without permanently destroying the signal
	
	Usage: for example when resetting a game round or state but keeping the signal alive for later reuse
--]]
function SkidBindables:DisconnectAll()
	debug.profilebegin("SkidBindables:DisconnectAll")
	local selfTyped: SkidBindables = (self :: any)
	local node = selfTyped._alpha

	--// Go through the entire list and kill every connection manually
	while node do
		local nextNode = node._nextSimp

		--// break memory cycles
		node._rizzler = nil
		node._yap = nil
		node._noCap = false
		node._prevSimp = nil
		node._nextSimp = nil 

		node = nextNode
	end

	selfTyped._alpha = nil
	debug.profileend()
end


--// [Event Handling]


--[[
	What: connects a function to run whenever the signal fires (Newest runs first)
	
	Usage: to listen for game events like clicks, damage, or round changes
--]]
function SkidBindables:Connect(yapperFn: (...any) -> ()): SkibidiWire
	assert(getmetatable(self) == SkidBindables, "Cannot Connect, signal is destroyed")
	assert(type(yapperFn) == "function", "Cannot Connect, expected function, got " .. type(yapperFn))
	
	local orbiter = {
		_rizzler = self, -- reference to the signal
		_yap = yapperFn, -- reference to your function
		_nextSimp = self._alpha, -- point to the current head
		_prevSimp = nil, -- no previous yet
		_noCap = true -- connected state
	}

	--// if we have a list, tell the old head that this new guy is before him
	if self._alpha then
		self._alpha._prevSimp = (orbiter :: any) :: SkibidiWire
	end

	--// update the signal to point to this new node as the head
	self._alpha = (orbiter :: any) :: SkibidiWire

	return (setmetatable(orbiter, SkibidiWire) :: any) :: SkibidiWire
end

--[[
	What: connects a function that runs exactly one time, then self destructs
	
	Usage: for single use triggers like initialization or a bullet hitting once
--]]
function SkidBindables:Once(yapperFn: (...any) -> ()): SkibidiWire 
	assert(getmetatable(self) == SkidBindables, "Cannot connect Once, signal is destroyed")
	
	local connection: SkibidiWire? = nil

	--// connect a wrapper that disconnects immediately, then yaps
	connection = (self:Connect(function(...)
		local c = connection
		connection = nil
		if c then c:Disconnect() end
		yapperFn(...)
	end) :: SkibidiWire)

	return connection :: SkibidiWire
end

--[[
	What: yields the script until the signal fires
	
	Usage: to stop code execution until something happens, like waiting for a gui to open
--]]
function SkidBindables:Wait(): ...any
	assert(getmetatable(self) == SkidBindables, "Cannot Wait, signal is destroyed")
	
	debug.profilebegin("SkidBindables:Wait")
	local thread = coroutine.running()
	local connection: SkibidiWire? = nil

	--// temporary listener to resume the thread
	connection = (self:Connect(function(...)
		if connection then connection:Disconnect() end
		task.spawn(thread, ...)
	end) :: SkibidiWire)
	
	debug.profileend()
	return coroutine.yield()
end


--// [Firing Methods]


--[[
	What: fast pooled dispatch (runner reuse)
	
	Usage: High frequency signals (per frame / tight loops).
	Note: callbacks run on the pooled runner (not task.spawn), so don't yield.
	Note: for yield safe async dispatch use FireAsync().
--]]
function SkidBindables:Fire(...)
	assert(getmetatable(self) == SkidBindables, "Cannot Fire, signal is destroyed")
	
	debug.profilebegin("SkidBindables:Fire")
	local currentSimp = self._alpha

	--// go through the linked list
	while currentSimp do
		local nextSimp = currentSimp._nextSimp --// save next in case current disconnects
		if currentSimp._noCap then
			local callback = currentSimp._yap
			if callback then
				_spawnPooled(callback, ...)
			end
		end
		currentSimp = nextSimp
	end
	debug.profileend()
end

--[[
	What: yield-safe async dispatch
	
	Usage: UI / gameplay events where callbacks might yield
	Note: Uses task.spawn per listener
--]]
function SkidBindables:FireAsync(...)
	assert(getmetatable(self) == SkidBindables, "Cannot FireAsync, signal is destroyed")

	debug.profilebegin("SkidBindables:FireAsync")
	local currentSimp = self._alpha
	while currentSimp do
		local nextSimp = currentSimp._nextSimp
		if currentSimp._noCap then
			local callback = currentSimp._yap
			if callback then
				task.spawn(callback, ...) -- yield-safe async
			end
		end
		currentSimp = nextSimp
	end
	debug.profileend()
end

--[[
	What: synchronous dispatch
	
	Usage: fastest option for heavy math or physics calculations
	Note: one error will stop everything
--]]
function SkidBindables:FireSync(...)
	assert(getmetatable(self) == SkidBindables, "Cannot FireSync, signal is destroyed")
	
	debug.profilebegin("SkidBindables:FireSync")
	local currentSimp = self._alpha
	
	while currentSimp do
		local nextSimp = currentSimp._nextSimp
		if currentSimp._noCap then
			local callback = currentSimp._yap
			if callback then
				callback(...) --// direct call (no task.spawn overhead)
			end
		end
		currentSimp = nextSimp
	end
	debug.profileend()
end

--[[
	What: fires listeners in batches across frames (prevents spikes)
	
	Usage: prevents lag spikes when firing massive events, for example: loading 10,000 items in a single frame
	Note: listeners connected AFTER this call starts will NOT receive this specific event
	Note: callbacks are pooled here too, or swap to task.spawn if you need yield safe callbacks.
--]]
function SkidBindables:FireDeferred(batchSize: number?, ...)
	assert(getmetatable(self) == SkidBindables, "Cannot FireDeferred, signal is destroyed")
	
	if batchSize then
		assert(type(batchSize) == "number" and batchSize > 0, "FireDeferred, batchSize must be a positive number")
	end
	
	local currentSimp = self._alpha
	local count = 0
	local args = table.pack(...)
	local unpack = table.unpack

	task.spawn(function()
		debug.profilebegin("SkidBindables:FireDeferredLoop")
		while currentSimp do
			local nextSimp = currentSimp._nextSimp
			
			if currentSimp._noCap then
				local callback = currentSimp._yap
				if callback then
					_spawnPooled(callback, unpack(args, 1, args.n))
				end
			end

			currentSimp = nextSimp
			count = count + 1

			--// if we hit the batch limit, wait for the next frame
			if count >= (batchSize or 2000) then
				count = 0
				
				debug.profileend()
				task.wait()
				debug.profilebegin("SkidBindables:FireDeferredLoop")
			end
		end
		debug.profileend()
	end)
end

return SkidBindables
