---
layout: post
title: "Trying out this web design thing"
---

I am much more comfortable writing code than I am designing user
interfaces. That's something I've meant to take action on for a while,
given that coding and designing is such a good skill tandem. I feel
like I have made a humble breakthrough in my design journey, and
wanted to share an update.

My previous attempts at design have been one of either:

-  Desperately tweaking a HTML file and some CSS code from scratch and
   ending up with terrible designs.
-  Using some component library like
   [`material-ui`](https://material-ui.com/) and sticking to the
   default styles and simple layouts as much as possible.  This is not
   too bad, to be honest. This is the approach I would recommend to
   people that lack design skills. I was able to get a very generic
   yet usable design. However, as soon as I tried to step off the
   guardrails by even just a bit, the results looked pretty bad.
   
In both cases, HTML&CSS were the tools I used to tinker with the
different design ideas I had. Even if you know these web technologies
pretty well, I now think they are not the best medium for
experimenting with design. Instead, I recommend prototyping your
layout in a design app (of which there are many different kinds, I
bet). Figma is the one I used, and I am glad I did because it was so
easy to learn. For my humble usecase anyway. Create 10 different
versions of your layout by dragging and dropping, and only when you're
happy with the result is it time to start writing the code.

The other resource that helped me was Dribbble. Search for things that
are similar to what you're trying to build and take them as a reference.


For practice, I came up with an idea for a habit-tracker kind of
product.  In this web application, you can create a series of _habits_
to be tracked, and the application will send you an e-mail every day
with a number of tasks that you have to mark as completed (if/when
completed). For example, the habit I was thinking of was "Study
Chinese", and each task was basically "read this text" and a link to
that text. 

It is a basic CRUD application. The first screen I tried to design was
the one that would show you your _habits_ and let you create a new
one. Pretty simple. This is the prototype I created in figma:

![My figma prototype]({{site.baseurl}}/assets/figma-habit.png)

This is not the sort of design that would gather me any like on
Dribbble, and I bet any designer can easily find many mistakes. It's
very prototypey, and may not make a lot of sense functionality-wise,
yet it looks real! And I created it myself! It even uses `monospace`
fonts to give it a more programmer-y look (see, creativity).

I then implemented this design using HTML, CSS and Tailwind:

![My web prototype]({{site.baseurl}}/assets/web-habit.png)

And it doesn't look the same but that's fine.

This is just a very small step for my design skills. Designers'
talents are clearly (and will forever be) hundreds of miles ahead of
mine. However, this I now know: if I need to, I can come up with _a_
design.

