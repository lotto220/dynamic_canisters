# Dynamic Canisters

Made by the team members of Blotch.

This is template for implementing dynamic canister creation for an abstract application.

<h3>Actors</h3>

```
Maker = {
  acceptCyclesWrapper: (numCycles: nat) -> (nat);
  drain: (childIndex: nat, numCycles: nat) -> (nat);
  getCanisterIds: () -> (opt vec principal) query;
  init: () -> (principal);
  redistributeCycles: (numCycles: nat) -> ();
  transfer: (childIndex: nat, amount: nat) -> (nat);
  upgradeChildren: (arg0: blob, wasm: blob) -> ();
};
```

```
class Child = {
  acceptCyclesWrapper: (numCycles: nat) -> (nat);
  doActivity: () -> ();
  getBalance: () -> (nat) query;
  getIdentifierAndVersion: () -> (text) query;
  isStale: () -> (bool) query;
  transfer: (receiver: func (nat) -> (nat), amount: nat) -> (nat);
  upgradeVersion: () -> (nat);
};
```

<h3>Function Descriptions</h3>

<h4>Shared</h4>

```
acceptCyclesWrapper - wrapper for experimental cycles so that transfers can be made between maker and child
```
```
transfer - transfers cycles between the two types of entities (maker and child), working bidirectionally and in conjuntion with acceptCyclesWrapper
```

<h4>Maker</h4>

```
drain - selects a child by index and drains the corresponding amount, may error if too much is requested from child
```

```
getCanisterIds - returns the ids of the children who are active as of the latest cycle
```

```
init - spawns a child
```

```
redistributeCycles - distributes the corresponding amount of cycles equally amongst children
```

```
upgradeChildren - upgrades the existing children by using existing install code functionality, also increments version number
```

<h4>Child</h4>

```
doActivity - marks the child as last active at the current time
```

```
getBalance - returns the balance of the child
```

```
getIdentifierAndVersion - returns the identifier and version of the child as text
```

```
isStale - indicates whether or not the child is considered as stale
```

```
upgradeVersion - increments the version number of the child
```