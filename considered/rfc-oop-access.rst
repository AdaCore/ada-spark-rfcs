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

This capability is available to all types (including simple records). The idea
here is to have an access type declared implicitely at the same level as the
type and accessible through the 'Ref notation. An attribute 'Unchecked_Free is
also declared, doing unchecked deallocation. 'Unchecked_Free can also be called
directly on the object. For example:

.. code-block:: ada

   package P is
      type T1 is tagged record
         procedure P (Self : in out T1);

         procedure P2 (Self : in out T1);
      end T1;
   end P;

   procedure Some_Procedure is
      V : T1'Ref := new T1;
      V2 : T1'Ref := new T1;
   begin
      T1'Unchecked_Free (V);
      V2'Unchecked_Free;
   end Some_Procedure;

For homogenity, 'Ref and 'Unchecked_Free are available to all Ada type -
including pointers themsleves. It's now possible to write:

.. code-block:: ada

    V : T1'Ref'Ref := new T1'Ref;

Contrary to tagged types, 'Ref access types for a given class object are
compatible in the case of upcast, but need explicit conversions to downcast.
You can write:

.. code-block:: ada

   package P is
      type A is tagged record
         procedure P (Self : in out T1);
      end A;

      type B is new T1 with record
         procedure P (Self : in out T1);
      end B;
   end P;

   procedure Some_Procedure is
      A1 : A'Ref := new B;
      A2 : A'Ref;

      B1 : B'Ref := new B;
      B2 : B'Ref;
   begin
      A2 := B1; -- OK, upcast, no need for pointer conversion
      B2 := A1; -- Illegal, downcast
      B2 := B'Ref (A1); -- OK, explicit downcast.
   end Some_Procedure;

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
