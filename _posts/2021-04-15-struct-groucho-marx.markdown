---
layout: post
title: "`struct GrouchoMarx`"
---

> I don't want to belong to any `struct` that would accept me as one of its data-members.

We can try:

```c++
struct GrouchoMarx {
  GrouchoMarx() = delete;
};
```

which works to some extent. You _can_ define a structure that would have a
`GrouchoMarx` data-member:

```c++
struct FriarsStruct {
  GrouchoMarx grouchoMarx;
};
```

but how would you _construct_ a `FriarsStruct`? How would `grouchoMarx` get constructed
in that constructor? It is still possible to construct `FriarsStruct` by cheating:

```c++
#include <utility>

struct FriarsStruct {
  GrouchoMarx grouchoMarx;
  
  FriarsStruct()
  : grouchoMarx(std::declval<GrouchoMarx>())
  {} 
};
```

or if your compiler/stdlib does not let you _run_ `std::declval` then you can write your own
sketchy version:

```c++
template<typename T>
T& sketchyDeclval() {
  int lol;
  return reinterpret_cast<T&>(lol);
}

struct FriarsStruct {
  GrouchoMarx grouchoMarx;
  
  FriarsStruct()
  : grouchoMarx(sketchyDeclval<GrouchoMarx>())
  {}
  
};
```

but of course, this only works because the `GrouchoMarx`'s copy constructor hasn't been deleted.
We can honour `GrouchoMarx` a bit further by deleting its copy constructor:

```c++
struct GrouchoMarx {
    GrouchoMarx() = delete;
    GrouchoMarx(const GrouchoMarx&) = delete;
};
```

I don't think one would be able to construct a `FriarsStruct` now. Yes, you can get _references_ to
a `FriarsStruct` (by using `sketchyDeclval`, for example), but not actually _construct_ one. 

Still, `GrouchoMarx` is a member of `FriarsStruct`, even if the latter cannot be constructed. Would
`GrouchoMarx` be satisfied with that? Not sure, but we can try a bit harder:

```c++
template<typename T>
constexpr bool falseIndirection = false;

template<typename T>
struct GrouchoMarx {
  static_assert(
      falseIndirection<T>, 
      "By the way, I don't want to belong to any `struct` that would accept me as one of its data-members.");
};
```

We say `falseIndirection<T>` instead of `false` so that the boolean expression in the `static_assert` happens in a dependent-context
and cannot be evaluated by the compiler until the template gets instantiated. Now if `FriarsStruct` dares to:

```c++
struct FriarsStruct {
  GrouchoMarx<struct Whatever> grouchoMarx; 
};
```

we will get an error like

> error: static assertion failed: By the way, I don't want to belong to any `struct` that would accept me as one of its data-members.

regardless of whether we try to construct it. We can kick the can down the road and do:

```c++
template<typename T>
struct FriarsStruct {
  GrouchoMarx<T> grouchoMarx;
};
```

but a joke can only go so far.
