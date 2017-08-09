---
title: Enforce lists to be monotonic at compile time
---

In this post we'll se how we can use haskell's type system to
enforce certain invariants at compile time. The particular example
we'll elaborate will consist of enforcing that fixed constant lists
are increasingly monotonic, but I suspect this very same approach could
be naturally extended to much more general settings. Future posts may
treat the reach of this technique.

For making this happen, we are going to need various language extensions,
These extensions will be introduced as needed along some resources I've
found useful for learning about them.



## Type-level Nats
It's no surprise that if we want to have the type-checker enforce a
numeric property (of course we don't actually need
any numbers for monotony to make sense, but we'll use numbers
here for the sake of simplicity).

We know the usual peano naturals can be encoded as a type in haskell:

``` haskell
data Nat = Z | Succ Nat

-- Then we can have values as
one :: Nat
one = Succ Z

two :: Nat
two = Succ one
```

But using the `DataKinds` language extension we can promote the type
`Nat`, `Z` to a type with kind `Nat` and `Succ` to a type constructor
that takes one `Nat` and returns another `Nat`.

So using DataKinds we can do the following thing:

``` haskell
data Nat = Z | Succ Nat

type One = Succ Z
type Two = Succ One
```

And now `One` and `Two` are types of kind `Nat`. Note that with
DataKinds, `Nat` is both a type (of kind `*`) and a
kind at the same time (but as separate things, and actually, if there
is ambiguity as to what you are referring two, be it the type or the
kind, GHC will understand that you mean `Nat` the type unless you precede
it with a quote as in `'Nat`). Following this logic, we can have both
`one` and `two` as values of type `Nat` and `One` and `Two` as types of
kind `Nat`.

As a beginner, I was used to haskell types having values (except for
`Void`, maybe) and wondered why would a type be useful without values
(except, again, for the use cases of `Void`). I hope this posts answers
somehow this question, because nor `Z` nor `One`, nor `Two` (considering
`Z` as the type, not the type constructor) have values. Only types with
kind `*` have values and as we said before the types we just defined
have kind `Nat`. So there it is, we are going to use different types
that have no values for something *useful*.

## Checking type equality
How do we check whether two types are equal? Well we can do
things like these sometimes:

``` haskell
data Eq a = Eq a a

type A = Int

a = Eq (3 :: A) (3 :: Int)
b = (3 :: A) :: Int
```

If the types are not equal, we'll have errors at compile time. However,
it's easy to say we can't always use this trick because we are relying
on having a value, which may not be true as we've already talked about.
`Proxy` is a really useful tool in this case:

``` haskell
data Proxy a = Proxy -- or import Data.Proxy
```

`Proxy` always has a value no matter what the type `a` is, and the
value is really easy to construct. So we can use the previous technique
with `Proxy`:

``` haskell
a = Eq (Proxy :: Proxy One) (Proxy :: Proxy Two) -- compile-time error

b = Eq (Proxy :: Proxy (Suc (Suc Z))) (Proxy :: Proxy Two) -- everythings' cool
```

## Type-level functions
We can sum values of type `Nat` using the following function:

``` haskell
sum :: Nat -> Nat -> Nat
sum Z n = n
sum (Succ n) m = Succ (sum n m)
```

Can we *promote* this notion of a function adding values
of type `Nat` to a function adding types of kind `Nat`? Turns
out we can do so using the `TypeFamilies` language extension.
With it, we can write the following code:

``` haskell
type family Sum (a :: Nat) (b :: Nat) :: Nat where
    Sum Z a = a
    Sum (Succ a) b = Succ (Sum a b)
```

which is surprisingly similar to the value level function. Checking
`Add One One == Two` can be done with the `Proxy` trick:

``` haskell
Eq (Proxy :: Proxy (Add One One)) (Proxy :: Proxy Two)
```

We can have a notion of typelevel predicates the same way we have
value level predicates. As `DataKinds` does not only promote the
types we write but all the *suitable* types and `Bool` is one of
those *suitable* types, we have a `Bool` kind which only contains
two types `True`, and `False`. That means we can have type-level
predicates:

``` haskell
type family IsZero (a :: Nat) :: Bool where
  IsZero Z = True
  IsZero _ = False


a = Eq (Proxy :: Proxy (IsZero Two)) (Proxy :: Proxy True) -- type error
```

We can now define the type-level version of `<=`:

``` haskell
type familiy LessThan (a :: Nat) (b :: Nat) :: Bool where
  LessThan Z b = True
  LessThan a Z = False
  LessThan (Succ n) (Succ m) = LessThan n m
```

More code

``` haskell
class ToInt (a :: Nat) where
    toInt :: Proxy a -> Int

instance ToInt Z where
    toInt _ = 0

instance ToInt a => ToInt (Succ a) where
    toInt (_ :: Proxy (Succ a)) = 1 + toInt (Proxy :: Proxy a)

type family Increasing (nats :: [Nat]) where
  Increasing '[] = True
  Increasing '[a] = True
  Increasing (a:(b:others)) = (a <= b) && Increasing (b:others)
  Increasing _ = False

type If type = (type ~ True)

class If (Increasing nats) => ToIncreasing (nats :: [Nat]) where
    doIt :: Proxy nats -> [Int]

instance ToIncreasing '[] where
    doIt _ = []

instance (ToInt a, ToIncreasing others, If (Increasing (a:others)) => ToIncreasing (a:others) where
  doIt (_ :: Proxy (a:others)) = toInt (Proxy :: Proxy a) : doIt (Proxy :: Proxy others)


doIt (Proxy :: Proxy [One, Two]) -- = [1, 2]
doIt (Proxy :: Proxy [Two, One]) -- compile-time error

```
