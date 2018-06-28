---
title: Constructing JSON-shaped types
layout: post
---

Following my recent
quest for understanding what type-level programming
is and what we
can achieve with it, I've been toying with the idea of having a more
strongly
typed version of an `Aeson` `Value`. For example, using `Aeson` we would
have:

```haskell
Object $
  HashMap.fromList [ ("a", Number 3), ("c", Bool False) ] :: Value

Array $ Vector.fromList [ Bool True ] :: Value
```

Being both of them _valid_ `JSON`-like values but having a different
_schema_. With this article I show a way in which we can track the
_schema_ of the `JSON` value at the type level.

The `Json` kind
-----------------

``` haskell
{-# LANGUAGE DataKinds, TypeFamilies, PolyKinds, UndecidableInstances, GADTs, TypeOperators #-}

 import GHC.Types
 import GHC.TypeLits
 import Data.Proxy

 data Json = Leaf | Array Json | Object [(Symbol, Json)]

```
After enabling the usual extensions we define the `Json` type. We do not define it because we want to use it as a type (we won't use it as one
during the whole post) but because we want to use it as a kind (where the promotion from type to kind has been done by the `DataKinds` extension). With this type definition we are making three simplifications:

1. Our schema model is not going to be concerned with the primitives
used as leafs. We could easily change that by using different
constructors as `Number | Text | Boolean` instead of `Leaf`.
2. The `Json` arrays are going to be homogeneous. This means that in our model of a JSON schema, all the elements in an array are going to have the same schema. Modeling the more general settings is still possible but it's not worth it for the sake of the post.
2. We are going to use a `fromList` representation of a map. We'll take care later that different order of items in that list does not affect our judgement of whether two schemas are equivalent. I believe it'd be possible to use a binary-search-like structure which is crazy considering that we are at the type level.

The reason we are using `Symbol` instead of `String` is that GHC allows
us to use string literals as types as in:
```haskell
Proxy :: Proxy "this is a type"
```
And the kind to which all those type-promoted string literals belong
turns out to be `Symbol`. As far as I know, there's no suitable
promotion for the `String` type.

So we can already express schemas:

``` haskell
 type UserSchema = Object ['("username", Leaf), '("email", Leaf)]
 type Database = Object [ '("name", Leaf), '("users", Array UserSchema) ]
```
Note the required use of `'` to promote the tuple constructor to a kind
constructor so that there's no ambiguity.

Constructing values
----------------------
We will now use the `GADTs` language extension to keep track of the
schema while building values.

``` haskell
 data Value (leafType :: *) (schema :: Json) where
   VLeaf :: leafType - Value leafType Leaf

   VEmptyArray :: Value anyLeafType (Array anySchema)
   VArrayCons :: Value leafType schema -> Value leafType (Array schema) -> Value leafType (Array schema)

   VEmptyObject :: Value anyLeafType (Object '[])
   VAddObject :: (Proxy (a::Symbol), Value leafType schema) -> Value leafType (Object otherKeys) -> Value leafType (Object ('(a, schema):otherKeys))
```


Using a `GADT` was necessary to make this code compile because if we were using
a vanilla data type declaration we could not restrict the type of the value constructors,
as we do in `VLeaf`, for example. If you don't see it quite clear, try to define
`Value` as a normal datatype (with the same two type parameters).

Now we can have values like these:

``` haskell
 a :: Value Bool Leaf
 a = VLeaf True

 user :: Value String UserSchema
 user = VAddObject (Proxy :: Proxy "username", VLeaf "rga@example.com") $ VAddObject (Proxy :: Proxy "email", VLeaf "braulio") VEmptyObject
```

If we mess the name of the keys up the code will not compile. That
could mean an extra level of safety (against 10 extra levels of verbosity, arguably).

The current approach has two problems though:
1. The schema model is too permissive: what would `Object ['("a", Leaf), '("a", Array Leaf)]` be supposed to mean?
We should not allow a key to be used twice in the same object schema.
2. The schema model is not permissive enough: we have to define object keys in the same order to get
the same schema. If we swap the `"username"` and `"email"` keys in the example above the code will not compile.

The first problem can be addressed using type families and a constraint in the `VAddObject`
constructor. I'll leave that as an exercise to the reader. We'll address the
second problem in the rest of the post.

Some type-level combinators
------------------------------
We'll define some type-level combinators to pave our way for checking
whether two schemas are equivalent.

``` haskell
 type family And (a :: Bool) (b :: Bool) :: Bool where
   And True True = True
   And _ _ = False

 type family If (cond :: Bool) (a :: k) (b :: k) :: k where
   If True a _ = a
   If False _ b = b

 type family Lookup (a :: k) (b :: [(k, v)]) :: Maybe v where
   Lookup _ '[] = Nothing
   Lookup a ('(a, v):_) = Just v
   Lookup a (_:rest) = Lookup a rest

 type family RemoveByKey (a :: k) (bs :: [(k, v)]) :: [(k, v)] where
   RemoveByKey k '[] = '[]
   RemoveByKey k ('(k, _):rest) = rest
   RemoveByKey k (a:rest) = a:RemoveByKey k rest
```


Now we can do what we were looking for:

``` haskell
 type family (a :: Json) ~=~ (b :: Json) :: Bool where
   Leaf ~=~ Leaf = True
   Array a ~=~ Array b = a ~=~ b

   -- now the interesting case
   Object '[] ~=~ Object '[] = True
   Object ('(key, schema):as) ~=~ Object bs = Case (Lookup key bs) as bs key schema
   _ ~=~ _ = False

 type family Case (mV :: Maybe Json) (as :: [(Symbol, Json)]) (bs :: [(Symbol, Json)]) (key :: Symbol) (schema :: Json) :: Bool where
   Case (Just v) as bs key schema =
     And (schema ~=~ v) (Object as ~=~ Object (RemoveByKey key bs))
   Case _ _ _ _ _ = False
```

Note how incredibly verbose the code due to not having type-level where
clauses, let, case syntax nor even partially applied type families. Fortunately, it does what we needed:

``` haskell
 proof1 :: Proxy True
 proof1 = Proxy :: Proxy (UserSchema ~=~ Object ['("email", Leaf), '("username", Leaf)]) -- compiles
```
Some more ideas
-------------
There are some other ideas that could be built on top of this:
1. `ToJson` and `FromJson` instances for the `Value` types we defined. This instances
  would be defined inductively on the `json` type variable and would allow us to parse
  json values that follow our schema by construction.
2. Existentials like: `data Record = forall schema1 schema2. (schema1 ~=~ schema2 ~ True) => Record (Value Bool schema1) (Value (Bool -> Int) schema2)`.
3. Canonical schemas and representations: we could choose a representative for every class
  defined by the `~=~` (the one that has keeps keys in ascending order, for example) and then
  build a type family that turns any schema into its representative. Then we could have a function
  `repr :: Value leaf schema -> Value leaf (Representative schema)` and a GADT like
```haskell
data CanonicalValue leaf schema where
  Canonical :: (schema ~ Representative schema) => Value leaf schema -> CanonicalValue leaf schema
```
  That could potentially make it easier to work with values with equivalent schemas.

Observations
--------------

1. Having a kind that's going to model some schema and then having a `GADT` constructing
 values that somehow resemble that schema seems like a common pattern. Look at `HList` [here](https://downloads.haskell.org/~ghc/7.8.4/docs/html/users_guide/promotion.html). You could even see length-indexed vectors as another example of this phenomenon.
2. Non-trivial type-level programming is exhausting due to not having most of the syntax you have for value-level programming. I'll look
  into whether this is currently being addressed.
3. Regarding the verbosity of the `~=~` type family implementation, the existence of the
  [`singletons`](https://hackage.haskell.org/package/singletons) package has been pointed
  out to me as a potential solution to this problem. This package uses template haskell to promote functions which would allow
  us to define type-level functions as easily as we define value-level functions.
