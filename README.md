# 👨‍💻 SkidBindables

**SkidBindables** is a high performance, doubly linked list signal system for Roblox. It is designed to be a faster, safer, and more memory efficient replacement for `BindableEvents`.

## Why use this?
- **Speed:** Disconnecting a listener is **O(1)** in SkidBindables (doubly linked list node unlink).
- **Safety:** You can disconnect listeners *while* the event is firing without bugs.
- **Memory:** Handles garbage collection automatically to prevent memory leaks.
- **Features:** Includes threaded firing, immediate sync firing, and deferred (batched) firing.

## API
- `SkidBindables.new()`
- `Signal:Connect(fn)` → `Connection`
- `Signal:Once(fn)` → `Connection`
- `Signal:Wait()` → `...any`
- `Signal:Fire(...)`
- `Signal:FireSync(...)`
- `Signal:FireDeferred(batchSize?, ...)`
- `Signal:DisconnectAll()`
- `Signal:Destroy()`
- `Connection:Disconnect()`

---

## 🚀 Usage

### Create a Signal
```lua
local SkidBindables = require(path.SkidBindables)

local MySignal = SkidBindables.new()
```

### 🔗 Connect Listeners
```lua
local connection1 = MySignal:Connect(function(message)
	print("Listener 1 received:", message)
end)

local connection2 = MySignal:Connect(function(message)
	print("Listener 2 received:", message)
end)
```

### 🔥 Fire the Signal
```lua
MySignal:Fire("Event Fired!")
```

### Output (Output order may vary due to threaded firing)
```
Listener 1 received: Event Fired!
Listener 2 received: Event Fired!
```

### ❌ Disconnect a Listener
```lua
connection1:Disconnect()
```

### 🔥 Fire Again
```lua
MySignal:Fire("Fired again!")
```

### Output
```
Listener 2 received: Fired again!
```

### 🔁 Disconnect All Listeners
```lua
MySignal:DisconnectAll()
```

### 🔥 Fire After DisconnectAll
```lua
MySignal:Fire("Event Fired!")
```

### Output
```
(no output)
```

---

## Extra Features

### Once (Auto disconnect)
```lua
MySignal:Once(function()
	print("Runs once then disconnects")
end)

MySignal:Fire()
MySignal:Fire()
```

### Wait (Yield until fired)
```lua
task.spawn(function()
	task.wait(1)
	MySignal:Fire("hello", 123)
end)

local a, b = MySignal:Wait()
print(a, b) -- hello 123
```

### FireSync (Immediate / Synchronous)
Runs listeners immediately in the current thread.  
**Note:** If one listener errors, later listeners will not run.

```lua
MySignal:FireSync("sync")
```

### FireDeferred (Batched)
Useful when you have a lot of listeners and want to spread work across frames.

**Note:** listeners connected AFTER this call starts will NOT receive this specific event.

```lua
MySignal:FireDeferred(500, "big event")
```

---

## Cleanup

### Destroy
Permanently kills the signal and clears all listeners. After this, the signal should not be used again.

```lua
MySignal:Destroy()
```

---

## 📝 Note
- **Listener order:** Newest connections run first (LIFO) because `Connect()` inserts at the head.
- **Bindable comparison:** Multiple `BindableEvent` listeners execute in an **unpredictable order**, and tables passed through bindables are **copied** (table identity changes) and **lose metatable information**.
- **FireDeferred defaults:** `FireDeferred()` defaults to a batch size of `2000` in this module, and it yields using `task.wait()`. `task.wait()` resumes the thread on the next **Heartbeat** step (and with no duration it resumes on the next step).
- **Sharing signals:** To use signals across multiple scripts, create a shared ModuleScript (for example `Events`) that stores your signal instances and `require()` it wherever needed.
- **SkidTypes:** please parent the `SkidTypes` module under `SkidBindables` or change the path to it in `SkidBindables`.

