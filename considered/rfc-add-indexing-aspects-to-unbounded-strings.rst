Summary
=======

When Variable_Indexing, Constant_Indexing and the iterators were introduced in
Ada2012, they were added to the Ada.Containers hierarchy, but somehow
Ada.Strings.Unbounded got forgotten.

This proposal is about adding those aspects to unbounded_string.

See also the blog post on GNATCOLL.Strings:
http://blog.adacore.com/admin/entries/blog/1531-user-friendly-strings-api
for an example of actual code where these aspects are used.

Motivation
==========

The standard Ada strings are quite convenient to use (at least once you
understand that you should use declare blocks since you need to know their size
in advance). For instance, one can access characters with expressions like:

.. code-block:: ada

   A : constant Character := S (2);             --  assuming 2 is a valid index
   B : constant Character := S (S'First + 1);   --  better, of course
   C : constant Character := S (S'Last);

The first line of the above example hides one of the difficulties for
newcomers: strings can have any index range, so using just "2" is likely to be
wrong here. Instead, the second line should be used. The GNATCOLL strings avoid
this pitfall by always indexing from 1. As was explained in the first blog
post, this is both needed for the code (so that internally we can reallocate
strings as needed without changing the indexes manipulated by the user), and
more intuitive for a lot of users.

The Ada unbounded string has a similar approach, and all strings are indexed
starting at 1. But you can't use the same code as above, and instead you need
to write the more cumbersome:

.. code-block:: ada

   S := To_Unbounded_String (...);
   A : constant Character := Element (S, 2);                         --  second character of the string, always
   B : constant Character := Ada.Strings.Unbounded.Element (S, 2);   --  when not using use-clauses

Also, if you want to loop on the characters of a regular string, you can write

.. code-block:: ada

   for C of S loop
      Put_Char (A);
   end loop;

Whereas with unbounded strings we'll have to write

.. code-block:: ada

   use Ada.Strings;

   for I in Unbounded.First_Index (S) .. Unbounded.Last_Index (S) loop
      Put_Char (Unbounded.Element (S, I));
   end loop;

Guide-level explanation
=======================

Like on regular strings, it is possible to index Unbounded_Strings, and to loop
on them via the ``for .. of`` syntax.

Reference-level explanation
===========================

The proposal implies:

* Making Unbounded_String visibly tagged. Unbounded_String implementations need
  it to be controlled anyway in terms of memory managements, so nothing is won
  by making it privately tagged.

* Adding the aspects, and implementations of ``Constant_Indexing``,
  ``Variable_Indexing``, ``Default_Iterator`` and ``Iterator_Element``

Rationale and alternatives
==========================

This proposal makes the ``Unbounded_String`` type easier to use. In addition to
the aforementioned benefits, making the type tagged would allow users to call
methods via the dot notation:

.. code-block:: ada

   use Ada.Strings.Unbounded;

   Length (My_String);

versus

.. code-block:: ada
   My_String.Length;

An alternative would be to use another type defined either in the standard
library or in another library. However, we believe having too many string types
is a big pain on users, so should be avoided.

Drawbacks
=========

It's unclear yet whether there would be compatibility issues caused by making
the ``Unbounded_String`` type tagged.

It's also unclear whether making it tagged would require to change it's
existing API, which would be worse, guaranteeing incompatibility with some
existing code.

Prior art
=========

A lot of languages have a string type equivalent to Ada's ``Unbounded_String``
which allows iteration and element access in the same way that you would use
for regular arrays. Such languages include C++ and Rust.

Unresolved questions
====================

See drawbacks.
