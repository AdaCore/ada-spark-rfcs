- Feature Name: Standard OOP model
- Start Date: May 5th 2020
- RFC PR:
- RFC Issue:

Summary
=======

Motivation
==========

Guide-level explanation
=======================

One limitation of the tagged record to lift under this system is the ability to
declare a primitives in the body of a package. As long as the type itself is
also declared in the body, this should be legal:

.. code-block:: ada

   package body Pkg is
      type T is tagged record
         F : Integer;
      end T;

      procedure P (Self : in out T; V : Integer);

      procedure P (Self : in out T; V : Integer) is
      begin
         Self.F := V;
      end P;
   end Pkg;

Reference-level explanation
===========================

Rationale and alternatives
==========================

Drawbacks
=========

Prior art
=========

Unresolved questions
====================

Future possibilities
====================
