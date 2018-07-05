---
layout: post
title: "Targeting The Python Virtual Machine II: CPython Marshalling Format"
---

_Targeting The Python Virtual Machine is a series of posts I'm writing
trying to create a programming language whose compile target is python
bytecode. You can see the first post of this series in
[Targeting The Python Virtual Machine I: The Internal Structure of .pyc Files](http://blog.braulio.me/2018/06/28/internal-structure-pyc-files.html)._

In the first post of this series, we saw what the structure of `.pyc`
files was. We finished that post by saying that any cached bytecode
file ends with the serialized module code object. The internal format
used by cpython in `.pyc` files is called `marshal`, and so
understanding
the basics of the `marshal` format will be the goal of this post.
Once we can marshal code objects, we will be able to construct
valid `.pyc` files.

As I said in the previous post, the python version we are targeting
here is python3.5. The marshal format is an internal part of the
interpreter, and thus is subject to changes from version to version.
That's why it does not have any official documentation.
A summary of python2's `marshal` format can be found
[here](http://demoseen.com/blog/2010-02-20_Python_Marshal_Format.html).
For figuring all this stuff out, I had to read the source
of the interpreter, especially
[`marshal.c`](https://github.com/python/cpython/blob/3.5/Python/marshal.c).

In order to explain how data is serialized
using `marshal`, I'll follow a top-down approach. We will
start by seeing how code objects are marshalled, and then proceed with
other native types as we need them. Finally, a full `.pyc` example
will be analyzed.

### Marshalling Code Objects
There are various interesting resources to learn about what
python code objects are. [This post](https://late.am/post/2012/03/26/exploring-python-code-objects.html)
contains some notes on python2 code objects. [This talk](https://www.youtube.com/watch?v=mxjv9KqzwjI)
on python bytecode also touches on them.

We can represent a python code object using the following
haskell type.

```haskell
-- | Python code object
data CodeObject = CodeObject
  { argCount :: Int -- ^  Arguments of the function (not including
                    -- *args and **kwargs)
  , kwOnlyArgCount :: Int -- ^ Number of keyword-only arguments
  , nLocals :: Int  -- ^ Number of local variables
  , stackSize :: Int -- ^ Stack size required for the function
  , flags :: Int -- ^ Interpreter flags
  , codeString :: CodeString -- ^ Function's bytecode
  , constants :: PTuple PyExpr -- ^ Tuple containing the constants
                              -- used during the execution of the function
  , names :: PTuple String -- ^ Global variable's names used during
                           -- the execution of the function.
  , varNames :: PTuple String -- ^ Local variable's names.
  , filename :: String -- ^ Source filename containing the code
  , name :: String -- ^ The function's name
  , firstLineNo :: Int -- ^ First source file line where the function
                       -- is implemented.
  , lnotab :: ByteString -- ^ Maps source lines to bytecode instructions
                         -- (don't know how).
  , freeVars :: PTuple String -- ^ Variables used in the function
                              -- that are neither local nor global
  , cellVars :: PTuple String  -- ^ Local variables used by inner functions
  }
```

Code objects are used to describe code both in functions and in
modules, and that's why we have fields like `argCount` in there. The
format for marshalling a code object is:

1. Type: the character `c`. This will tell the `marshal` parser that a
   code object is coming next.
2. Argument count: a little endian 4-bytes integer. We can set this
   field to 0 for module code objects.
3. [Keyword-only argument](https://www.python.org/dev/peps/pep-3102/)
   count: a little endian 4-bytes integer. We will set this to 0
   again when working with modules.
4. Number of local variables: little endian 4-bytes integer.
5. Stack size: little endian 4 bytes integer.
6. Flags: little endian 4 bytes integer.
7. Code: a bytestring containing the bytecode instructions that
   will be executed by the cpython virtual machine.
   We will explain how this
   bytestring is marshalled
   later.
8. Constants: a marshalled python tuple containing the
   constant values used
   throughout the module/function. Tuple marshalling will be
   discussed
   below as well.
9. Names: a python tuple containing strings.
10. VarNames: another string tuple.
12. Free Variables: another string tuple.
13. Cell Vars: another string tuple.
14. Filename: a string.
15. Name: another string.
16. First Line Number: another little endian 4-byte integer. We
    will set this to 0 when serializing module code objects.
17. lnotab: this is a bytestring that maps source file
    code lines to bytecode
    instructions (I guess this is done for displaying nice
    error messages). The empty bytestring is ok if we do not have
    that kind of information.

In order to check this is really how code objects are marshalled,
you can check [`marshal.c#L1304`](https://github.com/python/cpython/blob/3.5/Python/marshal.c#L1304)
(that's the code that parses marshalled code objects).

### Marshalling Tuples
There are two ways to marshal tuples. The format used to be:

1. The byte `(`.
2. A little endian 4-byte integer, indicating the number
   in elements of the tuple.
3. The items of the tuple, marshalled in order.

However, a new method was introduced to reduce the size of `.pyc`
files. This method only applies to _small tuples_ a.k.a
tuples whose number of items fits in a single byte
(I wonder who uses tuples with more than
256 elements). The format is:

1. The byte `)`.
2. A single byte, indicating the number of elements in the tuple.
3. The items of the tuple, marshsalled in order.

The code that handles thie behaviour is
to be found in [`marshal.c#L467`](https://github.com/python/cpython/blob/3.5/Python/marshal.c#L467).

### Marshalling Integers
Integers can have arbitrary size on python, but we will just focus
on how to marshal 32-bit integers. The format for these is simple:

1. The byte `i`.
2. The four byte integer, encoded with the little endian byte order.

The code responsible for marshalling integers can be read on
[`marshal.c#L338`](https://github.com/python/cpython/blob/3.5/Python/marshal.c#L338).

As an example, the tuple `(0, 1)` would marshal to:

```
0x29 0x02
0x69 0x00 0x00 0x00 0x00
0x69 0x01 0x00 0x00 0x00
```

where `0x29` is the ascii code for `)` and `0x69` is the ascii
code for `i`. Line breaks have been added for the sake of clarity.

### Marshalling Strings
There are many ways to marshal strings, but we will focus on
the simplest one that allows to use the whole unicode character
map. The format for unicode strings is:

1. The character `u`.
2. A little endian four bytes integer that stores the size, in bytes,
   of the UTF-8 encoded string.
3. The UTF-8 encoded string.

As there are multiple ways to encode strings, the
interpreter code reponsible for that has to decide which one is the
best way to encode a given one. However, you can check
that the parser admits the particular
format we explained here by reading
[`marshal.c#L1138`](https://github.com/python/cpython/blob/3.5/Python/marshal.c#L1138).

The tuple `(1, "a", "abb")` would marshal to:

```
0x29 0x03
0x69 0x01 0x00 0x00 0x00
0x75 0x01 0x00 0x00 0x00 0x61
0x75 0x02 0x00 0x00 0x00 0x61 0x62
```

You can try these examples yourself on the python repl
```
>>> import marshal
>>> marshal.loads(bytearray([
        0x29, 0x02,
        0x69, 0x01, 0x00, 0x00, 0x00,
        0x69, 0x01, 0x00, 0x00, 0x00
    ]))
(1, 1)
>>> marshal.dumps((1, "a", "ab"))
```
although, when using `dumps`, python
may use methods to marshal
your data that are different to the ones explained here.
It may use references, for example, which won't be covered
in this post.

### Other basic values
The format for boolean values is quite easy. The value `True`
is encoded as the character `T` and `False` is encoded as
`F`. `None` is encoded as `N`.

### Marshalling bytecode instructions
The last thing we need for making a valid `.pyc` file is some code.
The cpython virtual machine is a stack machine that is able
to execute [many different instructions](https://docs.python.org/3/library/dis.html#opcode-NOP).
In this post we we'll just focus on the minimum number of instructions
that will let us check that we are actually doing something. Those
instructions are:

```
LOAD_CONST
BINARY_ADD
PRINT_EXPR
RETURN_VALUE
```
Every instruction has an associated 1-byte opcode.
You can check what opcode
any given instruction is associated with using the python repl:

```
>>> import dis
>>> dis.opmap['BINARY_ADD']
23
```
Instructions might or might not have parameters. How the instructions
are encoded will depend on this fact. The instructions we mentioned
earlier are encoded as:

* `LOAD_CONST`: first, the 1-byte opcode `0x64`. Then a little endian
  16-bits integer we'll call `i`.
  This instruction tells the interpreter to put the value
  `constants[i]` on top of the stack.
* `BINARY_ADD`: the opcode is `0x17`. It has no arguments. This instruction
  tells the interpreter to pop the two elements on top of the stack,
  add them, and put the result on top of the stack.
* `PRINT_EXPR`: the opcode is `0x46`. It has no arguments. This
  instruction pops the element on top of the stack and prints it.
* `RETURN_VALUE`: whose opcode is `0x53` and has no arguments either.
  It just tells the interpreter to return the value which is on top
  of the stack.
  We will need this because, apparently, modules have to return
  the `None` value.

You can find more documentation on bytecode instructions
[here](https://docs.python.org/3/library/dis.html), although I
think the best introduction to this topic is
[this talk](https://www.youtube.com/watch?v=mxjv9KqzwjI).

The code string is then just a bytestring. Bytestrings are marshalled
in a way that is similar to regular strings:

1. The byte `s`.
2. The bytestring size in bytes, encoded
   as a little endian four bytes integer.
3. The bytestring itself.

Bytestring marshalling is implemented in
[`marshal.c#L427`](https://github.com/python/cpython/blob/3.5/Python/marshal.c#L427).

We now have all that we need to display a full example.

### Full Example
I have generated the following `.pyc` file:
```
0000000 16 0d 0d 0a a6 4f 3b 5b 00 00 00 00 63 00 00 00
0000020 00 00 00 00 00 00 00 00 00 00 00 00 00 40 00 00
0000040 00 73 0c 00 00 00 64 01 00 64 02 00 17 46 64 00
0000060 00 53 29 03 4e 69 05 00 00 00 69 06 00 00 00 29
0000100 00 29 00 29 00 29 00 75 00 00 00 00 75 00 00 00
0000120 00 01 00 00 00 73 00 00 00 00
0000132
```

I'll describe the structure of this file taking into
account what we have learned
so far (I'll freely use line breaks and the python comment
syntax to annotate the example):

```
16 0d 0d 0a # python 3.5.2 magic number
a6 4f 3b 5b # unix modification timestamp
00 00 00 00 # original source file size
```
We saw these fields in the
[first post of this series](http://blog.braulio.me/2018/06/28/internal-structure-pyc-files.html).
You can have the second and the third fields be whatever you want,
as long as they match with the associated `.py` file. If they do not
match cpython will not consider you `.pyc` file.

```
63 # ascii for the `c` byte. A code object follows
00 00 00 00 # argcount
00 00 00 00 # keyword-only argcount
00 00 00 00 # number of local variables
02 00 00 00 # required stack size
40 00 00 00 # flags

73 # ascii for `s`. A bytestring (the code strings) follows
0c 00 00 00 # the bytestring is 12 bytes long
64 01 00 # LOAD_CONST 1 (5)
64 02 00 # LOAD_CONST 2 (6)
17 # BINARY_ADD
46 # PRINT_EXPR
64 00 00 # LOAD_CONST 0 (None)
53 # RETURN_VALUE

29 # ascii for `)`. A tuple of constants follow
03 # the tuple has 3 items
4e # ascii for `N` a.k.a `None`
69 05 00 00 00 # the integer 5
69 06 00 00 00 # the integer 6

29 00 # names, a small empty tuple
29 00 # varNames
29 00 # freeVars
29 00 # cellVars
75 00 00 00 00 # filename, an empty unicode string is ok here
75 00 00 00 00 # name

01 00 00 00 # first line no
73 00 00 00 00 # lnotab, an empty bytestring
```

The final steps for executing the `.pyc` file would be:

1. Create an empty `mod.py` file and set its modification time
   to the unix timestamp `0x5b3b4fa6` (or change the timestamp in the
   `.pyc` file accordingly) .
2. Create a `__pycache__` directory.
3. Create a `mod.cpython-35.pyc` file inside the
   `__pycache__` directory, with the content described
   above.
4. Open up the python3.5 repl and `>>> import mod`.

You will see that the number 11 gets printed, meaning that our
`.pyc` file got executed. Automatically generating working bytecode
was one of the goals of my project. In the next post of this
series we will see how to leverage the power of haskell to construct
code objects in a convenient and type-safe way.
