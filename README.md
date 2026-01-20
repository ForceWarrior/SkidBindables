# SkidBindables

**SkidBindables** is a high performance, doubly linked list Signal system for Roblox (a `BindableEvent` replacement).

## Why use this?
- **Speed:** Disconnecting a listener is O(1) (linked list unlink).
- **Safety:** Listeners can disconnect while the signal is firing without breaking iteration.
- **Memory:** References are cleared on disconnect/destroy to help garbage collection.
- **Firing modes:** Fast pooled firing, yield safe async firing, sync firing, and deferred (batched) firing.

---

## Install
Place the `SkidBindables` ModuleScript somewhere shared (example: `ReplicatedStorage/Modules/SkidBindables`) and require it:

```lua
local SkidBindables = require(ReplicatedStorage.Modules.SkidBindables)
```

---

## API

### Signal
```lua
local signal = SkidBindables.new()

local conn = signal:Connect(function(...) end)
local onceConn = signal:Once(function(...) end)

local a, b, c = signal:Wait()

signal:Fire(...) -- fast pooled (callbacks should not yield)
signal:FireAsync(...) -- yield safe async (task.spawn per listener)
signal:FireSync(...) -- synchronous / immediate
signal:FireDeferred(batchSize?, ...) -- batched across frames

signal:DisconnectAll()
signal:Destroy()
```

### Connection
```lua
conn:Disconnect()
```

---

## Quick start

### Create a signal
```lua
local SkidBindables = require(path.SkidBindables)
local MySignal = SkidBindables.new()
```

### Connect listeners
```lua
local c1 = MySignal:Connect(function(message)
	print("Listener 1:", message)
end)

local c2 = MySignal:Connect(function(message)
	print("Listener 2:", message)
end)
```

---

## Firing modes

### 1) Fire(...) - fast pooled (runner reuse)
Use for high frequency signals (per frame / tight loops) where callbacks are small and **do not yield**.

```lua
MySignal:Fire("hello")
```

### 2) FireAsync(...) - yield safe async
Use for UI/gameplay events where callbacks might yield (`task.wait`, tweens, retries, etc).

```lua
MySignal:FireAsync("hello async")
```

### 3) FireSync(...) - synchronous / immediate
Runs listeners immediately in the caller thread.  
**Note:** if a callback errors, later callbacks won’t run (by design).

```lua
MySignal:FireSync("sync")
```

### 4) FireDeferred(batchSize?, ...) - batched across frames
Spreads work across multiple frames to avoid spikes.  
If `batchSize` is `nil`, it defaults to `2000`.

```lua
MySignal:FireDeferred(500, "big event")
```

**Note:** callbacks are pooled here too, so don’t yield inside callbacks (or swap pooled dispatch to `task.spawn` if you need yield safe callbacks during deferred firing).

---

## Disconnecting

### Disconnect one listener
```lua
c1:Disconnect()
MySignal:Fire("only listener 2 now")
```

### Disconnect all listeners (keep signal alive)
```lua
MySignal:DisconnectAll()
MySignal:Fire("no listeners")
```

---

## Cleanup

### Destroy (permanent)
Destroys the signal and clears all listeners. Don’t use it after this.

```lua
MySignal:Destroy()
```

---

## Notes
- **Listener order:** Newest connections run first (LIFO) because `Connect()` inserts at the head.
- **Which fire should you use?**
  - `Fire` = fastest, callbacks shouldn’t yield.
  - `FireAsync` = safest general purpose option if callbacks might yield.
  - `FireSync` = immediate + deterministic, but one error stops later listeners.
  - `FireDeferred` = reduces spikes by batching across frames.
