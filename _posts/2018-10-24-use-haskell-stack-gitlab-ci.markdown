---
layout: post
title: "Use haskell's stack in gitlab-ci"
---

This will be a short post aimed at beginners,
describing things you have to do to make sure your stack project
builds quickly on gitlab-ci. The simplest `.gitlab-ci.yml` that you
could write that builds your project would be:

```yaml
before-script:
    - apt-get update
    - curl -sSL https://get.haskellstack.org/ | sh

build:
    script:
        - stack install
        - stack test
```

This approach is slow for several reasons:
1. It has to install stack from scratch every time.
2. It has to download all the dependencies your project needs in order to be built. That means
   downloading GHC, stack's dependencies, and your project dependencies. Every time.
3. It has to build your whole project and your test whole suite (right, every time, even if
   you don't change it).

The three problems can be addressed very simply.

### Use `haskell` docker image
There is a docker image you can use instead of the default one that gitlab-ci assigns
to your build. That image is [\_/haskell](https://hub.docker.com/_/haskell/), and it
comes with stack preinstalled.

```yaml
image: haskell

build:
    script:
        - stack install
        - stack test
```

### Cache your project dependencies
You can use [gitlab-ci caching feature](https://docs.gitlab.com/ee/ci/caching/)
to avoid rebuilding your project dependencies. Stack
keeps all the libraries you install in a directory called `STACK_ROOT`. You can modify
what that directory is by using environment variables or command line flags, but you normally
don't need to do it. The usual stack root is `~/.stack/`. You could find what `STACK_ROOT` is
on the gitlab-ci runner and then, state in the `.gitlab-ci.yml` file that you want that
directory to be cached.

There is a problem though. Gitlab won't cache paths that fall out of the `/builds/` directory
it builds your projects in. The right thing to do is to modify `STACK_ROOT` so that it is inside
that directory, and then cache it. 

```yaml
image: haskell
variables:
    STACK_ROOT: /builds/.stack

build:
    script:
        - stack install
        - stack test
    cache:
        paths:
            - /builds/.stack
```

### Cache your project build
If you just tweak a haskell module in your project, why should your whole thing
build from scratch? Your
project build does not get cached on `STACK_ROOT`, but in a directory that is local to your
project's. That directory is called `.stack-work`. Cache that
too and you will be set.

The final yaml file would then be:
```yaml
image: haskell
variables:
    STACK_ROOT: /builds/.stack

build:
    script:
        - stack install
        - stack test
    cache:
        paths:
            - /builds/.stack
            - .stack-work
```


So that's all.
