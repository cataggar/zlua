# runtime.gc

## Navigation

- [API Index](../README.md)
- Previous: [runtime.debug](../runtime/debug.md)
- Next: [runtime.host](../runtime/host.md)
- Parent: [runtime](../runtime.md)

## Functions

- [noteAllocation](#fn-noteallocation)
- [noteAllocationFreed](#fn-noteallocationfreed)
- [refreshAllocationTotal](#fn-refreshallocationtotal)
- [currentAllocationTotal](#fn-currentallocationtotal)
- [tableCapacityBytes](#fn-tablecapacitybytes)
- [tableGcBytes](#fn-tablegcbytes)
- [noteTableCapacityDelta](#fn-notetablecapacitydelta)
- [collectGarbageValue](#fn-collectgarbagevalue)
- [collectGarbageParam](#fn-collectgarbageparam)
- [collectGarbageStep](#fn-collectgarbagestep)
- [collectGarbage](#fn-collectgarbage)
- [collectGarbageStepPublic](#fn-collectgarbagesteppublic)
- [allocationByteCount](#fn-allocationbytecount)
- [gcIsRunning](#fn-gcisrunning)
- [stopGc](#fn-stopgc)
- [restartGc](#fn-restartgc)
- [switchGcMode](#fn-switchgcmode)
- [gcParam](#fn-gcparam)
- [setGcParam](#fn-setgcparam)
- [collectGarbageConservatively](#fn-collectgarbageconservatively)
- [collectGarbageWithFinalizers](#fn-collectgarbagewithfinalizers)
- [collectGarbageWithFinalizersMode](#fn-collectgarbagewithfinalizersmode)
- [shouldRunAutoGc](#fn-shouldrunautogc)
- [resetAutoGcThreshold](#fn-resetautogcthreshold)
- [resetMarks](#fn-resetmarks)
- [markRoots](#fn-markroots)
- [markValue](#fn-markvalue)
- [markRuntimeErrorPayload](#fn-markruntimeerrorpayload)
- [markString](#fn-markstring)
- [markTable](#fn-marktable)
- [markUserdata](#fn-markuserdata)
- [markWeakTableStrings](#fn-markweaktablestrings)
- [markWeakString](#fn-markweakstring)
- [markClosure](#fn-markclosure)
- [markCClosure](#fn-markcclosure)
- [markUpvalue](#fn-markupvalue)
- [markCUpvalue](#fn-markcupvalue)
- [markThread](#fn-markthread)
- [markThreadStack](#fn-markthreadstack)
- [markStackRange](#fn-markstackrange)
- [weakMode](#fn-weakmode)
- [hasWeakTables](#fn-hasweaktables)
- [markEphemeronValues](#fn-markephemeronvalues)
- [convergeEphemerons](#fn-convergeephemerons)
- [markValueChanged](#fn-markvaluechanged)
- [valueIsMarked](#fn-valueismarked)
- [valueIsWeaklyCleared](#fn-valueisweaklycleared)
- [valueIsCollectableUnmarked](#fn-valueiscollectableunmarked)
- [clearWeakValues](#fn-clearweakvalues)
- [clearWeakTables](#fn-clearweaktables)
- [clearDeadHashKeys](#fn-cleardeadhashkeys)
- [clearWeakTableValues](#fn-clearweaktablevalues)
- [clearWeakTableKeys](#fn-clearweaktablekeys)
- [writeTableBarrier](#fn-writetablebarrier)
- [writeBarrier](#fn-writebarrier)
- [runPendingFinalizers](#fn-runpendingfinalizers)
- [runPendingUserdataFinalizers](#fn-runpendinguserdatafinalizers)
- [callableValue](#fn-callablevalue)
- [sweepStrings](#fn-sweepstrings)
- [sweepUserdata](#fn-sweepuserdata)
- [sweepTables](#fn-sweeptables)
- [sweepClosures](#fn-sweepclosures)
- [sweepCClosures](#fn-sweepcclosures)
- [sweepUpvalues](#fn-sweepupvalues)
- [sweepCUpvalues](#fn-sweepcupvalues)
- [sweepThreads](#fn-sweepthreads)
- [findStringAllocation](#fn-findstringallocation)
- [isTrackedThread](#fn-istrackedthread)
- [isTrackedTable](#fn-istrackedtable)
- [isTrackedUserdata](#fn-istrackeduserdata)
- [isTrackedClosure](#fn-istrackedclosure)
- [isTrackedCClosure](#fn-istrackedcclosure)
- [isTrackedUpvalue](#fn-istrackedupvalue)
- [isTrackedCUpvalue](#fn-istrackedcupvalue)
- [destroyTable](#fn-destroytable)
- [destroyUserdata](#fn-destroyuserdata)
- [destroyClosure](#fn-destroyclosure)
- [destroyCClosure](#fn-destroycclosure)
- [destroyThread](#fn-destroythread)
- [allocationStats](#fn-allocationstats)
- [noteTableMetatableChanged](#fn-notetablemetatablechanged)
- [unlinkTableMetatable](#fn-unlinktablemetatable)

<a id="fn-noteallocation"></a>

## noteAllocation

```zig
pub fn noteAllocation(comptime State: type, self: *State, bytes: usize) void
```

<a id="fn-noteallocationfreed"></a>

## noteAllocationFreed

```zig
pub fn noteAllocationFreed(comptime State: type, self: *State, bytes: usize) void
```

<a id="fn-refreshallocationtotal"></a>

## refreshAllocationTotal

```zig
pub fn refreshAllocationTotal(comptime State: type, self: *State) usize
```

<a id="fn-currentallocationtotal"></a>

## currentAllocationTotal

```zig
pub fn currentAllocationTotal(comptime State: type, self: *State) usize
```

<a id="fn-tablecapacitybytes"></a>

## tableCapacityBytes

```zig
pub fn tableCapacityBytes(table: *const Table) usize
```

<a id="fn-tablegcbytes"></a>

## tableGcBytes

```zig
pub fn tableGcBytes(table: *const Table) usize
```

<a id="fn-notetablecapacitydelta"></a>

## noteTableCapacityDelta

```zig
pub fn noteTableCapacityDelta(comptime State: type, self: *State, table: *const Table, old_capacity_bytes: usize) void
```

<a id="fn-collectgarbagevalue"></a>

## collectGarbageValue

```zig
pub fn collectGarbageValue(comptime State: type, self: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-collectgarbageparam"></a>

## collectGarbageParam

```zig
pub fn collectGarbageParam(comptime State: type, self: *State, value: Value) !GcParam
```

<a id="fn-collectgarbagestep"></a>

## collectGarbageStep

```zig
pub fn collectGarbageStep(comptime State: type, self: *State, thread: ?*Thread, budget: i64) !bool
```

<a id="fn-collectgarbage"></a>

## collectGarbage

```zig
pub fn collectGarbage(comptime State: type, self: *State) !void
```

<a id="fn-collectgarbagesteppublic"></a>

## collectGarbageStepPublic

```zig
pub fn collectGarbageStepPublic(comptime State: type, self: *State, budget: i64) !bool
```

<a id="fn-allocationbytecount"></a>

## allocationByteCount

```zig
pub fn allocationByteCount(comptime State: type, self: State) usize
```

<a id="fn-gcisrunning"></a>

## gcIsRunning

```zig
pub fn gcIsRunning(comptime State: type, self: State) bool
```

<a id="fn-stopgc"></a>

## stopGc

```zig
pub fn stopGc(comptime State: type, self: *State) void
```

<a id="fn-restartgc"></a>

## restartGc

```zig
pub fn restartGc(comptime State: type, self: *State) void
```

<a id="fn-switchgcmode"></a>

## switchGcMode

```zig
pub fn switchGcMode(comptime State: type, self: *State, mode: GcMode) GcMode
```

<a id="fn-gcparam"></a>

## gcParam

```zig
pub fn gcParam(comptime State: type, self: State, param: GcParam) i64
```

<a id="fn-setgcparam"></a>

## setGcParam

```zig
pub fn setGcParam(comptime State: type, self: *State, param: GcParam, value: i64) void
```

<a id="fn-collectgarbageconservatively"></a>

## collectGarbageConservatively

```zig
pub fn collectGarbageConservatively(comptime State: type, self: *State, thread: ?*Thread) !void
```

<a id="fn-collectgarbagewithfinalizers"></a>

## collectGarbageWithFinalizers

```zig
pub fn collectGarbageWithFinalizers(comptime State: type, self: *State, thread: ?*Thread) !void
```

<a id="fn-collectgarbagewithfinalizersmode"></a>

## collectGarbageWithFinalizersMode

```zig
pub fn collectGarbageWithFinalizersMode(comptime State: type, self: *State, thread: ?*Thread, mark_all_stack_registers: bool) !void
```

<a id="fn-shouldrunautogc"></a>

## shouldRunAutoGc

```zig
pub fn shouldRunAutoGc(comptime State: type, self: *State) bool
```

<a id="fn-resetautogcthreshold"></a>

## resetAutoGcThreshold

```zig
pub fn resetAutoGcThreshold(comptime State: type, self: *State) void
```

<a id="fn-resetmarks"></a>

## resetMarks

```zig
pub fn resetMarks(comptime State: type, self: *State) void
```

<a id="fn-markroots"></a>

## markRoots

```zig
pub fn markRoots(comptime State: type, self: *State) void
```

<a id="fn-markvalue"></a>

## markValue

```zig
pub fn markValue(comptime State: type, self: *State, value: Value) void
```

<a id="fn-markruntimeerrorpayload"></a>

## markRuntimeErrorPayload

```zig
pub fn markRuntimeErrorPayload(comptime State: type, self: *State, payload: ?RuntimeErrorPayload) void
```

<a id="fn-markstring"></a>

## markString

```zig
pub fn markString(comptime State: type, self: *State, bytes: []const u8) void
```

<a id="fn-marktable"></a>

## markTable

```zig
pub fn markTable(comptime State: type, self: *State, table: *Table) void
```

<a id="fn-markuserdata"></a>

## markUserdata

```zig
pub fn markUserdata(comptime State: type, self: *State, userdata: *Userdata) void
```

<a id="fn-markweaktablestrings"></a>

## markWeakTableStrings

```zig
pub fn markWeakTableStrings(comptime State: type, self: *State, table: *Table, keys: bool, values: bool) void
```

<a id="fn-markweakstring"></a>

## markWeakString

```zig
pub fn markWeakString(comptime State: type, self: *State, value: Value) void
```

<a id="fn-markclosure"></a>

## markClosure

```zig
pub fn markClosure(comptime State: type, self: *State, closure: *Closure) void
```

<a id="fn-markcclosure"></a>

## markCClosure

```zig
pub fn markCClosure(comptime State: type, self: *State, closure: *CClosure) void
```

<a id="fn-markupvalue"></a>

## markUpvalue

```zig
pub fn markUpvalue(comptime State: type, self: *State, upvalue: *Upvalue) void
```

<a id="fn-markcupvalue"></a>

## markCUpvalue

```zig
pub fn markCUpvalue(comptime State: type, self: *State, upvalue: *CUpvalue) void
```

<a id="fn-markthread"></a>

## markThread

```zig
pub fn markThread(comptime State: type, self: *State, thread: *Thread) void
```

<a id="fn-markthreadstack"></a>

## markThreadStack

```zig
pub fn markThreadStack(comptime State: type, self: *State, thread: *Thread) void
```

<a id="fn-markstackrange"></a>

## markStackRange

```zig
pub fn markStackRange(comptime State: type, self: *State, thread: *Thread, base: usize, count: usize) void
```

<a id="fn-weakmode"></a>

## weakMode

```zig
pub fn weakMode(comptime State: type, self: *State, table: *Table) WeakMode
```

<a id="fn-hasweaktables"></a>

## hasWeakTables

```zig
pub fn hasWeakTables(comptime State: type, self: *State) bool
```

<a id="fn-markephemeronvalues"></a>

## markEphemeronValues

```zig
pub fn markEphemeronValues(comptime State: type, self: *State, table: *Table) bool
```

<a id="fn-convergeephemerons"></a>

## convergeEphemerons

```zig
pub fn convergeEphemerons(comptime State: type, self: *State) void
```

<a id="fn-markvaluechanged"></a>

## markValueChanged

```zig
pub fn markValueChanged(comptime State: type, self: *State, value: Value) bool
```

<a id="fn-valueismarked"></a>

## valueIsMarked

```zig
pub fn valueIsMarked(comptime State: type, self: *State, value: Value) bool
```

<a id="fn-valueisweaklycleared"></a>

## valueIsWeaklyCleared

```zig
pub fn valueIsWeaklyCleared(comptime State: type, self: *State, value: Value) bool
```

<a id="fn-valueiscollectableunmarked"></a>

## valueIsCollectableUnmarked

```zig
pub fn valueIsCollectableUnmarked(comptime State: type, self: *State, value: Value) bool
```

<a id="fn-clearweakvalues"></a>

## clearWeakValues

```zig
pub fn clearWeakValues(comptime State: type, self: *State) void
```

<a id="fn-clearweaktables"></a>

## clearWeakTables

```zig
pub fn clearWeakTables(comptime State: type, self: *State) void
```

<a id="fn-cleardeadhashkeys"></a>

## clearDeadHashKeys

```zig
pub fn clearDeadHashKeys(comptime State: type, self: *State) void
```

<a id="fn-clearweaktablevalues"></a>

## clearWeakTableValues

```zig
pub fn clearWeakTableValues(comptime State: type, self: *State, table: *Table) void
```

<a id="fn-clearweaktablekeys"></a>

## clearWeakTableKeys

```zig
pub fn clearWeakTableKeys(comptime State: type, self: *State, table: *Table) void
```

<a id="fn-writetablebarrier"></a>

## writeTableBarrier

```zig
pub fn writeTableBarrier(comptime State: type, self: *State, table: *Table, key: Value, value: Value) void
```

<a id="fn-writebarrier"></a>

## writeBarrier

```zig
pub fn writeBarrier(comptime State: type, self: *State, parent_marked: bool, child: Value) void
```

<a id="fn-runpendingfinalizers"></a>

## runPendingFinalizers

```zig
pub fn runPendingFinalizers(comptime State: type, self: *State, thread: ?*Thread) !void
```

<a id="fn-runpendinguserdatafinalizers"></a>

## runPendingUserdataFinalizers

```zig
pub fn runPendingUserdataFinalizers(comptime State: type, self: *State) void
```

<a id="fn-callablevalue"></a>

## callableValue

```zig
pub fn callableValue(comptime State: type, self: *State, value: Value) bool
```

<a id="fn-sweepstrings"></a>

## sweepStrings

```zig
pub fn sweepStrings(comptime State: type, self: *State) void
```

<a id="fn-sweepuserdata"></a>

## sweepUserdata

```zig
pub fn sweepUserdata(comptime State: type, self: *State) void
```

<a id="fn-sweeptables"></a>

## sweepTables

```zig
pub fn sweepTables(comptime State: type, self: *State) void
```

<a id="fn-sweepclosures"></a>

## sweepClosures

```zig
pub fn sweepClosures(comptime State: type, self: *State) void
```

<a id="fn-sweepcclosures"></a>

## sweepCClosures

```zig
pub fn sweepCClosures(comptime State: type, self: *State) void
```

<a id="fn-sweepupvalues"></a>

## sweepUpvalues

```zig
pub fn sweepUpvalues(comptime State: type, self: *State) void
```

<a id="fn-sweepcupvalues"></a>

## sweepCUpvalues

```zig
pub fn sweepCUpvalues(comptime State: type, self: *State) void
```

<a id="fn-sweepthreads"></a>

## sweepThreads

```zig
pub fn sweepThreads(comptime State: type, self: *State) void
```

<a id="fn-findstringallocation"></a>

## findStringAllocation

```zig
pub fn findStringAllocation(comptime State: type, self: *State, bytes: []const u8) ?usize
```

<a id="fn-istrackedthread"></a>

## isTrackedThread

```zig
pub fn isTrackedThread(comptime State: type, self: *State, thread: *Thread) bool
```

<a id="fn-istrackedtable"></a>

## isTrackedTable

```zig
pub fn isTrackedTable(comptime State: type, self: *State, table: *Table) bool
```

<a id="fn-istrackeduserdata"></a>

## isTrackedUserdata

```zig
pub fn isTrackedUserdata(comptime State: type, self: *State, userdata: *Userdata) bool
```

<a id="fn-istrackedclosure"></a>

## isTrackedClosure

```zig
pub fn isTrackedClosure(comptime State: type, self: *State, closure: *Closure) bool
```

<a id="fn-istrackedcclosure"></a>

## isTrackedCClosure

```zig
pub fn isTrackedCClosure(comptime State: type, self: *State, closure: *CClosure) bool
```

<a id="fn-istrackedupvalue"></a>

## isTrackedUpvalue

```zig
pub fn isTrackedUpvalue(comptime State: type, self: *State, upvalue: *Upvalue) bool
```

<a id="fn-istrackedcupvalue"></a>

## isTrackedCUpvalue

```zig
pub fn isTrackedCUpvalue(comptime State: type, self: *State, upvalue: *CUpvalue) bool
```

<a id="fn-destroytable"></a>

## destroyTable

```zig
pub fn destroyTable(comptime State: type, self: *State, table: *Table) void
```

<a id="fn-destroyuserdata"></a>

## destroyUserdata

```zig
pub fn destroyUserdata(comptime State: type, self: *State, userdata: *Userdata) void
```

<a id="fn-destroyclosure"></a>

## destroyClosure

```zig
pub fn destroyClosure(comptime State: type, self: *State, closure: *Closure) void
```

<a id="fn-destroycclosure"></a>

## destroyCClosure

```zig
pub fn destroyCClosure(comptime State: type, self: *State, closure: *CClosure) void
```

<a id="fn-destroythread"></a>

## destroyThread

```zig
pub fn destroyThread(comptime State: type, self: *State, thread: *Thread) void
```

<a id="fn-allocationstats"></a>

## allocationStats

```zig
pub fn allocationStats(comptime State: type, self: State) RuntimeAllocationStats
```

<a id="fn-notetablemetatablechanged"></a>

## noteTableMetatableChanged

```zig
pub fn noteTableMetatableChanged(comptime State: type, self: *State, table: *Table, old_has_metatable: bool) void
```

<a id="fn-unlinktablemetatable"></a>

## unlinkTableMetatable

```zig
pub fn unlinkTableMetatable(comptime State: type, self: *State, table: *Table) void
```

