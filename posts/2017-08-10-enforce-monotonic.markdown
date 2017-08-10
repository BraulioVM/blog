---
title: Enforce lists to be monotonic at compile time
---

In this post I'll show you briefly how we can enforce
monotonic behaviour in fixed constant
lists defined at compile time. I'll use 5 common type-level
programming tricks for achieving this goal.

## Type-level nats

These are the usual Peano naturals:

``` haskell
data Nat = Z | Succ Nat

zero :: Nat
zero = Z

one :: Nat
one = Succ Z

two :: Nat
two = Succ One
```

Using the `DataKinds` language extension we can promote those
values to types, and the `Nat` type to a kind. That would allow
us to have types like these:

``` haskell
type Zero = Z
type One = Succ Z
type Two = Succ One
```

## Type-level functions
The same way we can define the usual sum and order for values of
type `Nat`:

``` haskell
sum :: Nat -> Nat -> Nat
sum Z a = a
sum (Succ a) b = Succ (sum a b)

lessThan :: Nat -> Nat -> Bool
lessThan Z a = True
lessThan a Z = False
lessThan (Succ n) (Succ m) = lessThan n m
```

we can make functions that operate on the type level using
the `TypeFamilies` language extension:

``` haskell
type family Sum (a :: Nat) (b :: Nat) :: Nat where
    Sum Z a = a
    Sum (Succ a) b = Succ (Sum a b)

type familiy LessThan (a :: Nat) (b :: Nat) :: Bool where
  LessThan Z b = True
  LessThan a Z = False
  LessThan (Succ n) (Succ m) = LessThan n m
```

Note that in this example `Bool` is the kind `Bool` (thanks to
`DataKinds`) and `True` and `False` are both types of kind `Bool`.

With those type families we could have things like:

``` haskell
data Proxy a = Proxy -- Data.Proxy

proof :: Proxy True
proof = (Proxy :: Proxy (LessThan One Two)) -- compiles

fakeProof :: Proxy True
fakeProof = (Proxy :: Proxy (LessThan Two One)) -- compile time error
```

What's more, using the `TypeOperators` language extension we can
change the above type families to:

``` haskell
type family (a :: Nat) + (b :: Nat) :: Nat where
    Z + a = a
    Succ a + b = Succ (a +  b)

type familiy (a :: Nat) <= (b :: Nat) :: Bool where
  Z <= b = True
  a <= Z = False
  (Succ n) <= (Succ m) = n <= m

proof :: Proxy True
proof = (Proxy :: Proxy (One <= True))
```

## Turn type-level naturals into values
We want a function that turns any type of kind `Nat` into an
integer. You can't have a function from a type to a value in haskell
but we can model that with the `Proxy` type-constructor.

``` haskell
class ToInt (a :: Nat) where
    toInt :: Proxy a -> Int

instance ToInt Z where
    toInt _ = 0

instance ToInt a => ToInt (Succ a) where
    toInt (_ :: Proxy (Succ a)) = 1 + toInt (Proxy :: Proxy a)
```

In order to make this piece of code work we'll need
`FlexibleInstances`, `UndecidableInstances` and `ScopedTypeVariables`.
`FlexibleInstances` is a harmless extension (meaning nothing's gonna
hurt you), `ScopedTypeVariables` makes GHC understand that the
`a` type variable we use in the `Proxy (Succ a)` is the same
variable we are refering to later with `Proxy a`. `UndecidableInstances`
could make type checking your code undecidable, but we are safe for now.

## Increasing type-family
Taking advantage of the fact that the list type constructor is promoted
by `DataKinds` to a kind constructor we can define the following
type family:

``` haskell
type family Increasing (nats :: [Nat]) where
  Increasing '[] = True
  Increasing '[a] = True
  Increasing (a:(b:others)) = (a <= b) && Increasing (b:others)
  Increasing _ = False
```

That given a type-level list of type-level nats evaluates to the
type `True` if the `nats` are monotonically increasing.

## Get list of increasing integers
In the same vein we obtained an integer for every type-level nat,
we now want to get a list of integers for every type-level list
of types of kind `Nat`, but, we'll only do so for monotonically
increasing lists.

``` haskell
class (Increasing nats ~ True) => ToIncreasing (nats :: [Nat]) where
  toIncreasing :: Proxy nats -> [Int]

instance ToIncreasing '[] where
  toIncreasing _ = []

instances (ToInt a, ToIncreasing others, Increasing (a:others) ~ True) => ToIncreasing (a:others) where
    toIncreasing (_ :: Proxy (a:others)) =
        toInt (Proxy :: Proxy a) : toIncreasing (Proxy :: Proxy others)

toIncreasing (Proxy :: Proxy '[Zero, One, Two]) -- [0,1,2]
toIncreasing (Proxy :: Proxy '[Two, Zero, One]) -- compile-time error
```

## Observations
1. Interestingly enough we need more constraints in the last instance
   definition that would be *provably* needed. We know that every
   `a` is a `Nat` and that every `Nat` is a `ToInt` but we have to
   have that as a constraint anyway. Moreover, if
   `Increasing (a:others) ~ True` then necessarily `ToIncreasing others`
   is satisfied, but once again we need it as a constraint.

2. This approach can be easily extended to other invariants
   that can be defined inductively on lists. How much more
   extendable is this technique?

3. Nobody wants to define lists of numbers like
   `[ThreehundredThirtyTwo, Fifteen]` and that's ok. Type-literals
   would allow us to provide a more ergonomic API.

4. Some potentially useful type-level combinators arise from this
   code. There probably are libraries of type-level combinators out
   there. Have to take a look.
