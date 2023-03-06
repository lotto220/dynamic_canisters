import Cycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";
import Error "mo:base/Error";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Iter "mo:base/Iter";

import IC "./ic.types";
import Child "./child";

actor Maker {
  private var numChildrenCreated: Nat = 0;

  private var children: [Child.Child] = [];
  private let startingChildBalance = 5_000_000_000_000; // amount of cycles to endow a child with
  private let childActionBalance = 1_000_000_000_000; // amount of cycles which sparks a refill to a child
  private let childRefillAmount = 1_000_000_000_000; // amount of cycles which is given to a poor child once childActionBalance is hit
  private let staleSecondsAllowed: Nat64 = 20; // amount of seconds to allow a child to be stale
  private let tolerance = 2_000_000_000; // absolute minimum amount of cycles which a child must have (even when dead)

  private let timerPeriod: Nat64 = 5 * 1_000_000_000; // run timer function every 5 seconds

  private let ic : IC.Self = actor "aaaaa-aa";

  public shared({ caller }) func init(): async (Principal) {
    Cycles.add(startingChildBalance);
    let child = await Child.Child(Principal.fromActor(Maker), "User" # Nat.toText(numChildrenCreated), staleSecondsAllowed);
    let canisterId = ?Principal.fromActor(child);
    numChildrenCreated := numChildrenCreated + 1;


    switch (canisterId) {
      case null {
        throw Error.reject("Child init error");
      };
      case (?canisterId) {
        children := Array.append<Child.Child>(children, [child]);
        let self: Principal = Principal.fromActor(Maker);

        let controllers: ?[Principal] = ?[canisterId, caller, self];

        await ic.update_settings(({canister_id = canisterId; 
          settings = {
            controllers = controllers;
            freezing_threshold = null;
            memory_allocation = null;
            compute_allocation = null;
          }}));

        return canisterId;
      };
    };
  };

  public query func getCanisterIds() : async ?[Principal] {
    let numChildren = Array.size(children);
    if(numChildren == 0) {
      null;
    } else {
      var ids: [Principal] = [];
      for(child in children.vals()) {
        ids := Array.append(ids, [Principal.fromActor(child)]);
      };
      ?ids;
    }
  };

  public func upgradeChildren(arg0: Blob, wasm: Blob) : async () {
    for(child in children.vals()) {
      await ic.install_code({arg=arg0; wasm_module=wasm; mode=#upgrade; canister_id=Principal.fromActor(child)});
      ignore await child.upgradeVersion();
    };
  };

  public func redistributeCycles(numCycles: Nat): async () {
    let numChildren = Array.size(children);
    let cyclesPerChild = numCycles / numChildren;
    for(i in Iter.range(0, numChildren - 1)) {
      ignore await transfer(i, cyclesPerChild);
    };
  };

  public shared func acceptCyclesWrapper(numCycles: Nat) : async Nat {
    Cycles.accept(numCycles)
  };

  public func drain(childIndex: Nat, numCycles: Nat) : async Nat {
    let child = children[childIndex];
    await child.transfer(acceptCyclesWrapper, numCycles);
  };

  public func transfer(childIndex: Nat, amount: Nat) : async Nat {
    Cycles.add(amount);
    ignore await children[childIndex].acceptCyclesWrapper(amount);
    Cycles.refunded();
  };

  system func timer(setGlobalTimer : Nat64 -> ()) : async () {
    var newChildren: [Child.Child] = [];
    var i = 0;
    // loop over children and either destroy them or refill them based on activity and balance
    for(child in children.vals()) {
      let isStale = await child.isStale();
      if(isStale) {
        // drain and destroy
        ignore await drain(i, (await child.getBalance()) - tolerance);
        Debug.print("Drained and forgot stale canister: " # Nat.toText(i));
      } else {
        // we might desire to refill child's account
        let balance = await child.getBalance();
        if(balance < childActionBalance) {
          ignore await transfer(i, childRefillAmount);
        };
        newChildren := Array.append<Child.Child>(newChildren, [child]);
        Debug.print("Not stale: " # Nat.toText(i));
      };
      i += 1;
    };
    children := newChildren;

    Debug.print("Myself: " # Nat.toText(Cycles.balance()));
    i := 0;
    for(child in children.vals()) {
      let balance = await child.getBalance();
      Debug.print(Nat.toText(i) # ": " # Nat.toText(balance));
      i += 1;
    };
    Debug.print("");

    let next = Nat64.fromIntWrap(Time.now()) + timerPeriod; // every 5 sec
    setGlobalTimer(next);
  };
};