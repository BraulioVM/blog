---
title: Constructing JSON-shaped types
---

Following my quest for understanding what type-level is and what it
can achieve, I've been toying with the idea of having a more strongly
typed version of `Aeson` `Value`. For example, using `Aeson` we would
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

>{-# LANGUAGE DataKinds, TypeFamilies, PolyKinds, UndecidableInstances, GADTs, TypeOperators #-}
>
> import GHC.Types
> import GHC.TypeLits
> import Data.Proxy
>
> data Json = Leaf | Array Json | Object [(Symbol, Json)]
>

After enabling the usual extensions we define the `Json` type. We do not define it because we want to use it as a type (we won't use it as one
during the whole post) but because we want to use it as a kind (where the promotion from type to kind has been done by the `DataKinds` extension). With this type definition we are making three simplifications:

1. Our schema model is not going to be concerned with the primitives
used as leafs. We could easily change that by using different
constructors as `Number | Text | Boolean` instead of `Leaf`.
2. The `Json` arrays are going to be homogeneous. This means that in our model of a JSON schema, all the elements in an array are going to have the same schema. Modeling the more general settings is still possible but it's not worth it for the sake of the post.
2. We are going to use a `fromList` representation of a map. We'll take care later that different order of items in that list does not affect our judgement of whether two schemas are the same. I believe it'd be possible to use a binary-search-like structure which is crazy considering that we are at the type level.

The reason we are using `Symbol` instead of `String` is that GHC allows
us to use string literals as types as in:
```haskell
Proxy :: Proxy "this is a type"
```
And the kind to which all those type-promoted string literals belong
turns out to be `Symbol`. As far as I know, there's no suitable
promotion for the `String` type.

So we can already express schemas:

> type UserSchema = Object ['("username", Leaf), '("email", Leaf)]
> type Database = Object [ '("name", Leaf), '("users", Array UserSchema) ]

Note the required use of `'` to promote the tuple constructor to a kind
constructor so that there's no ambiguity.

Constructing values
----------------------
We will now use the `GADTs` language extension to keep track of the
schema while building values.

> data Value (leafType :: *) (schema :: Json) where
>   VLeaf :: leafType -> Value leafType Leaf
>
>   VEmptyArray :: Value anyLeafType (Array anySchema)
>   VArrayCons :: Value leafType schema -> Value leafType (Array schema) -> Value leafType (Array schema)
>
>   VEmptyObject :: Value anyLeafType (Object '[])
>   VAddObject :: (Proxy (a::Symbol), Value leafType schema) -> Value leafType (Object otherKeys) -> Value leafType (Object ('(a, schema):otherKeys))

Using a `GADT` was necessary to make this code compile because if we were using
a vanilla data type declaration we could not restrict the type of the value constructors,
as we do in `VLeaf`, for example. If you don't see it quite clear, try to define
`Value` as a normal type constructor (with the same two type parameters) with just
the `VLeaf` data constructor (note: you won't be able).

Now we can have values like these:

> a :: Value Bool Leaf
> a = VLeaf True

> user :: Value String UserSchema
> user = VAddObject (Proxy :: Proxy "username", VLeaf "rga@example.com") $ VAddObject (Proxy :: Proxy "email", VLeaf "braulio") VEmptyObject

If we mess the name of the keys up the code will not compile. That
could mean an extra level of safety (against 10 extra levels of verbosity though).

The current approach has two problems though:
1. The schema model is too permissive: what would `Object ['("a", Leaf), '("a", Array Leaf)]` be supposed to mean?
We should not allow a key to be used twice in the same object schema.
2. The schema model is not permissive enough: we have to define object keys in the same order to get
the same schema. If we swap the `"username"` and `"email"` keys in the example above the code will not compile.

We'll address those problems in the rest of the post.

Some type-level combinators
------------------------------
We'll define some type-level combinators to pave our way for checking
whether two schemas are equivalent.
