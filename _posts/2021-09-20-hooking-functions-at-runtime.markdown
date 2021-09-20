---
layout: post
title: Hooking functions at runtime (Linux x86-64)
---

See [`transmogrify`](https://github.com/BraulioVM/transmogrify).

Interposing functions using `LD_PRELOAD` is pretty cool, but you
cannot do that when the functions are linked statically into the
program. What can we do in that case? The only thing I've been able to
come up with is re-writing the assembly of the function that we want
to hook.

When I disassemble some object files produced by GCC (in debug mode),
I can see the following preamble for functions:

```
    11dc:       f3 0f 1e fa             endbr64 
    11e0:       55                      push   %rbp
    11e1:       48 89 e5                mov    %rsp,%rbp
    11e4:       (more instructions...)
```

I don't really understand what `endbr64` is supposed to do, but I can
see in the documentation that it's a no-op in older
architectures. That means that the code can work without it, and I can
get rid of it for the purposes of this hack. The next two instructions
are stack manipulation instructions (save the stack frame pointer of
the caller, update our stack frame pointer...). Those two instructions
do not care about what the program counter is. Because of that, my
plan is:

1. Overwrite the first 8 bytes of the function code (the three
   instructions in the excerpt above) with a `jmp` instruction to some
   other piece of code that I control.
   
2. That piece of code will execute
   ```
   push %rbp
   mov %rsp, %rbp
   ```
   as if it were the original function.

3. After that, it will call the hooking function.
4. And finally, it will `jmp` back to the original function.


I've learned the following interesting things while getting my code to work:

- In order to rewrite the code of the original function, you'll have
  to call `mprotect`. Memory pages where your code is loaded up in
  memory are not writable by default (why should they?) so you will
  have ask the OS very politely to let you write in them.

- GCC (and I guess compilers in general) will use different preambles
  in different optimization levels. My code works for the preamble I
  described above, and that's the one GCC emits in code compiled with
  `-O0` (`CMAKE_BUILD_TYPE=Debug`), but it won't work with code
  compiled with a higher optimization level. I know there are compiler
  settings that let you control these preambles in a more precise way.

- I am completely incapable of encoding x86-64 instructions by hand. I
  have looked at some documentation but I barely understand any of
  it. What I have ended up doing is writing C++ code on Compiler
  Explorer, seeing what code is emitted and then copying and pasting
  and doing the appropriate substitutions.

- Writing assembly without knowing assembly is hard (duh).  The thing
  I found hardest is not getting types checked, knowing whether
  something was a pointer, a pointer to a pointer... Fortunately, I
  had to write very [little
  assembly](https://github.com/BraulioVM/transmogrify/blob/main/transmogrify/stub.s).
  
- I spent quite a while fighting segmentation faults. That is to be
  expected when you don't know whether your assembly code is dealing
  with a pointer, a value, a pointer to a pointer... But also, I have
  discovered that:
      1. Some SIMD instructions expect your stack to be aligned to a
         multiple of 16 bytes.
      2. GCC makes sure to keep the stack aligned that way when
         calling functions, but when you are writing your own assembly
         you're own your own. Failing to keep this invariant will
         result in a segfault that's hard to track.

- I am fortunate enough that the jump instruction I overwrite the
  function preamble with is only 5 bytes long. I can only achieve that
  if my assembly hook and the function I'm hooking are at a 32-bit
  offset apart (I'm doing a relative jump). If they are further than
  that, I would need more than 8 bytes to encode the jump, and I would
  get past the function preamble. That is a significantly harder
  problem to solve, given that I am not sure whether the next
  instruction that I would be writing is agnostic to the program
  counter (a relative jump, for example, is not agnostic to the
  program counter). In that case, I wouldn't be able to simply copy
  that instruction into my assembly hook, because I would perhaps
  alter the semantics of the original instruction. The one solution I
  can think of is copying the original instructions of the hooked
  function to a buffer, overwriting the the function with the `jmp`
  instruction (using more than 8 bytes, overwriting instructions that
  are outside the preamble), and then, once the hook is called,
  pasting back the original instructions into the original function
  right before jumping back. This is not thread-safe though lol.

- GDB can get very confused when you're modifying the assembly code of
  functions underneath it.

My final goal is to be able to hook a function linked statically into
an executable without having to re-compile the executable. I still
cannot do this, given that I need the address of the function I want
to hook into, and I'm not sure how to get such an address without
being linked to the executable. I have tried using `dlsym` from the
constructor of a shared object that I `LD_PRELOAD` into the program
execution, but I have not been able to get it to work yet.
