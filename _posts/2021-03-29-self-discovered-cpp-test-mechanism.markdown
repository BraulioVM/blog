---
layout: post
title: "Self-discovered C++ Test Mechanism"
---

`pytest` has this cool feature where any function whose name begins by `test` is considered to be a test (it's a bit [more complicated](https://docs.pytest.org/en/stable/goodpractices.html#conventions-for-python-test-discovery), but anyway).
This is a very simple and convenient interface. All C++ testing frameworks require one to explicitly _register_ the entities (generally functions) that
comprise a test. The specific way in which these tests get registered is often hidden behind macros offered by the testing framework.

As an example, compare the following python (`pytest`) and C++ (gtest) test cases:

```python
def test_list_function_returns_empty_list():
  # GIVEN
  l = list()
  
  # THEN
  assert len(l) == 0
```

and

```c++
#include <vector>

#include <gtest/gtest.h>


TEST(VectorTests, DefaultConstructedVectorIsEmpty)
{
  // GIVEN
  std::vector<int> l;
  
  // THEN
  ASSERT_TRUE(l.empty());
}
```

Note, once again, the explicit registration of the test case using the `TEST` macro provided by gtest. Why is that registration needed? The simplest answer
is that, unlike python, C++ does not allow one to reflect on the context of a _unit_ (translation unit? namespace? there isn't really a perfect analogy to a
python module here). This may change in the future, once reflection makes its way into C++ (C++26 maybe). It will be very interesting how testing frameworks
adapt to the future versions of the standard, but there's not much that we can do until then. Or __is there?????????__

It's true that the language doesn't allow us to reflect on the functions defined in a _unit_, but we do not have to restrict our testing framework to
the language. Our testing framework can also encompass our build system! This is what we can do:

1. We let users write and compile their test drivers into object files.
2. Once built, we use `nm` to inspect the symbols defined within. Some of them will be functions that begin with `test`
3. We use this information to construct the source code for a program that will iterate over these functions and call them,
   build that source code, and link the object file against the other object files.
   
Iterating over the symbols in an object file is a poor man's reflection. But still reflection. There are still some decisions that one would have to
figure out like: how do test cases signal their failure to the framework? There are many possible interfaces. You could have the `test` functions return
a boolean value, or you could use exceptions. Both have pros and cons I guess.

I have implemented this testing framework as a CMake module. I think it has a reasonably good looking interface.
I called it [cooltests](https://github.com/brauliovm/cooltests). It is a terrible idea and has many [caveats](https://github.com/brauliovm/cooltests#caveats).
And most importantly, it does not have any advantage over gtest. Using macros for registering your test cases is not that bad. And actual
testing frameworks come with many cool bells and whistles.

PS: for a brainier take on this topic (and more), you may find [Future of Testing With C++20 - Kris Jusiak [ ACCU 2021 ]](https://www.youtube.com/watch?v=KlU0cb_tbuw&ab_channel=ACCUConference) interesting as well.




