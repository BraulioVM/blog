---
title: A short and potentially useful idris example
layout: post
---

Random use case:
Consider you are writing a service that allows users to
rent football courts. You need to know the ages of all
the people that are going to be playing but don't really
need to know all of their names. One would be enough,
but it's ok if more users provide their names.

Optional names sound like `Maybe` but we are going to use
a modified version of `Maybe` that keeps track at the
type-level of whether it is a `Just` or a `Nothing`.

``` idris
data Optional : Type -> Bool -> Type where
  One : a -> Optional a True
  Empty : Optional a False
```

Then we can define our users like:

``` idris
record User (hasName : Bool) where
    constructor MkUser
    name : Optional String hasName
    age : Int
```

Now we define our custom list of users that keeps track
of whether any of those users has a name:

``` idris
infixr 7 :+
data UserList : Bool -> Type where
    Nil' : UserList False
    (:+) : User hasName -> UserList anyHasName -> UserList (hasName || anyHasName)
```

And finally our type

``` idris
CourtRenters : Type
CourtRenters = UserList True
```

encodes the need to have at least one name. If we wanted to extract
one of those names we'd do:

``` idris
renterName : CourtRenters -> String
renterName ((MkUser (One name) _) :+ _) = name
renterName ((MkUser Empty _) :+ rest) = renterName rest
```

We can check that it works:
```
λΠ> renterName (MkUser Empty 23 :+ MkUser (One "hey") 21 :+ Nil')
"hey" : String
λΠ> renterName (MkUser Empty 23 :++ MkUser Empty 21 :++ Nil'')
-- type error
```

It's easy to see (for a human, that is) that if the user matches
the pattern `MkUser Empty _` then its type is `User False` and so
`rest : UserList True` so that the type of the whole list is
`UserList True`, but I'm not sure how idris is able to infer the
correct `rest` type.

At first, I tried to do this in haskell but couldn't make it work reliably.
[This is how I tried](https://www.reddit.com/r/haskell/comments/70g1jd/weekly_beginner_saturday_hask_anything_4/dnebo8f/)

So there's that, one more step towards having the type-system enforce all
of the invariants we care about.
