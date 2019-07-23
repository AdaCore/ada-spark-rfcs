- Feature Name: New syntax for Ada aggregates
- Start Date: 2019-07-24
- RFC PR:
- RFC Issue:

Summary
=======

We propose to follow
http://www.ada-auth.org/cgi-bin/cvsweb.cgi/ai12s/ai12-0212-1.txt?rev=1.28&raw=N
with a few crucial modifications:

1. Let's allow the new aggregate syntax for every aggregate
2. Let's deprecate old-syntax aggregates.
3. Let's use curly brackets for heterogeneous data structures, and square
   brackets for homogeneous ones (as well as container aggregates), in order to
   be coherent with other languages such as Python, Rust, C, C++ and Java.

This would mean that the following code is correct

.. code-block:: ada

   procedure Main is
      type Rec is record
         A, B : Integer;
      end record;

      type Rec_Array is array (Positive range <>) of Rec;

      Inst : Rec := {1, 2};

      Arr : Rec_Array := [{1, 2}, {3, 4}];
   begin
      null;
   end Main;

The following code would be correct but issue deprecation warnings by default.

.. code-block:: ada

   procedure Main is
      type Rec is record
         A, B : Integer;
      end record;

      type Rec_Array is array (Positive range <>) of Rec;

      Inst : Rec := (1, 2);

      Arr : Rec_Array := [{1, 2}, {3, 4}];
   begin
      null;
   end Main;

.. note::
   We would obviously make it possible to silence such warnings. However, we
   leave the door open to completely remove the syntax in a subsequent revision
   of Ada.

   Also, we have the necessary technology at AdaCore to engineer precise
   automatic code migrators if need be, like it is done for the Swift language.

The following code would be incorrect

.. code-block:: ada

   procedure Main is
      type Rec is record
         A, B : Integer;
      end record;

      type Rec_Array is array (Positive range <>) of Rec;

      Inst : Rec := [1, 2];

      Arr : Rec_Array := {[1, 2], [3, 4]};
   begin
      null;
   end Main;

Motivation
==========

This has several benefits over the existing proposals:

1. As the original proposal, but going even further, this provides a syntactic
   and visible clue for the reader for where aggregates are in the code. With
   this proposal, it is very easy to see where they're used in the code, and to
   distinguish them from every other uses of parentheses in the language.

2. With this proposal, there is even a visual clue about whether the aggregate
   is homogeneous or heterogeneous. Following pure Ada 202X, there would be a
   syntactic obligation for the programmer to distinguish the two.

3. It has the existing benefits of the square brackets proposal, insofar as it
   is very easy to implement, and solves existing ambiguities in the language
   syntax.

4. It simplifies the language rather than complicates it.

Guide-level explanation
=======================

* Curly brackets replace parentheses when expressing aggregates for records.

* Square brackets replace parentheses when expressing aggregates for arrays or
  containers.

* Parentheses for aggregate are now deprecated and will trigger a warning when
  used in Ada 2020 mode, while still being supported.

Reference-level explanation
===========================

TBD if the proposal gathers more following.

Rationale and alternatives
==========================

It is explained above why we think this would be a good alternative. However,
both https://github.com/AdaCore/ada-spark-rfcs/pull/21 and the original AI are
viable alternatives to this problem.

Drawbacks
=========

It has the obvious drawback of introducing backward incompatibility, if only as
a warning. However, we can make it as smooth as possible for users to
transition by still supporting the old syntax, and providing tools to migrate.

Prior art
=========

A lot of languages (C, C++, Java, Rust, Javascript) use `{}` for heterogeneous data
structures literals.

A lot of languages (Python, Rust, Javascript, Ruby) use `[]` for array/vector
literals.

This means that those choices will very likely look familiar to people coming
from other language, and even to Ada programmers that have used other
languages.

Unresolved questions
====================

There are likely some syntax tweaks to make, like, for example, for qualified
aggregates, should we write:

.. code-block:: ada

      Inst : Rec := Rec'{1, 2}
      Arr : Rec_Array := Rec_Array'[{1, 2}, {3, 4}];

or

.. code-block:: ada

      Inst : Rec := Rec'({1, 2})
      Arr : Rec_Array := Rec_Array'([{1, 2}, {3, 4}]);

But those questions have trivial solutions, even though I expect we could fight
endlessly over the best syntax, as always :)

Future possibilities
====================

Even though this RFC might be scary enough on its own, I think this opens the
possibility of thinking about "fixing" some bits of the syntax of Ada for
users.

By that I mean getting rid of the bits of the Ada syntax that are ambiguous/not
immediately explicit for a reader that doesn't have more context about the
code, such as:

* No parentheses for calls with no actuals. This makes it impossible to know if
  something is a call or not by just looking at it.

* Parentheses for indexing. Makes it impossible to distinguish function calls
  and array accesses.

Fixing those bits of syntax will make the language simpler and more familiar
for most newcomers, and might even make the implementation of an Ada 2020 only
parser/analyzer *simpler* rather than *more complicated* than doing it for Ada
2012, which is in itself a pretty nice feat.
