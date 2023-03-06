import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Cycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Debug "mo:base/Debug";
import Bool "mo:base/Bool";

actor class Child(makerPrincipal: Principal, identifier: Text, staleSecondsAllowed: Nat64) = this {

  var version: Nat = 1;
  var lastActivity: Nat64 = Nat64.fromIntWrap(Time.now());

  public query func getIdentifierAndVersion() : async Text {
    return identifier # " v " # Nat.toText(version);
  };

  public func doActivity(): async () {
    lastActivity := Nat64.fromIntWrap(Time.now());
  };

  public func upgradeVersion(): async Nat {
    version += 1;
    version;
  };

  public query func isStale() : async Bool {
    let now = Nat64.fromIntWrap(Time.now());
    let timeInactive = now - lastActivity;
    let secondsInactive = timeInactive / 1_000_000_000;
    if(Nat64.greater(secondsInactive, staleSecondsAllowed)) {
      return true;
    };
    false;
  };

  public shared func acceptCyclesWrapper(numCycles: Nat) : async Nat {
    Cycles.accept(numCycles)
  };

  public shared(msg) func transfer(receiver: shared Nat -> async Nat, amount: Nat) : async Nat {
    if(msg.caller != makerPrincipal) {
      return 0;
    };

    Cycles.add(amount);
    ignore await receiver(amount);
    return Cycles.refunded();
  };

  public query func getBalance() : async Nat {
    Cycles.balance();
  };
}