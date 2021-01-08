- Feature Name: allow_discriminants_to_constrain_scalar_type
- Start Date: 2020-01-08
- RFC PR: 
- RFC Issue: 

Summary
=======

Allow a discriminant to constrain a scalar type in a record.

Motivation
==========
An example of use:

.. code-block:: ada

   type ChangeList is array (Natural range <>) of CacheChange;
   protected type HistoryCache (CacheSize : Positive) is
      procedure add_change (a_change : in CacheChange);
      procedure remove_change (a_change : out CacheChange);
   private
      changes : ChangeList (1 .. CacheSize);
      count : Natural range 1 .. CacheSize := 0;
   end HistoryCache;

Using GNAT Community 2020 (20200818-93), the compiler will throw the following error:

.. code-block:: bash

   discriminant cannot constrain scalar type

Given that in ADA 2012 a composite type can be parameterized using a discrimant, a range (consisting of a bound based on a discriminant value) specified for a scalar field would result in a constant range declaration. 

References:  

- [1] Discussion on Computer-programming-forum.com_ 
- [2] Ycombinator_ thread

.. _Computer-programming-forum.com: http://computer-programming-forum.com/44-ada/82b646ab38d529af.htm
.. _Ycombinator: https://news.ycombinator.com/item?id=11583698

Guide-level explanation
=======================
Type discriminants can be used to contrain 

Reference-level explanation
===========================
WIP

Rationale and alternatives
==========================
As discussed in the Computer-programming-forum.com_ thread, this can also be attained by employing the following construct:

.. code-block:: ada

  generic
    CacheSize : in POSITIVE;
  package HistoryCache is
    type count is Natural range 0 .. CacheSize;
    changes : ChangeList (1 .. CacheSize);
  end Queue;

Drawbacks
=========
Not clear at this time.

Prior art
=========
N/A at this time

Unresolved questions
====================
N/A at this time

Future possibilities
====================
N/A at this time