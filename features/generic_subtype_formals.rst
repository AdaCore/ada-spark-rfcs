- Feature Name: generic_subtype_formals
- Start Date: 2019-11-13
- Status: Planning

Summary
=======

This RFC shows a current limitation in the generic contract model, and
suggests a few possible ways that this could be solved.

Motivation
==========

I want to write a generic function to convert an image to a string.
I would declare:

.. code-block:: ada

   package Gen is
      generic
         type Index_Type is (<>);
         type Item_Type is private;
         type Array_Type is array (Index_Type range <>) of Item_Type;
         with function Index_Image (Value : Index_Type) return String;
         with function Item_Image (Value : Item_Type) return String;
      function Array_Image_1 (Value : Array_Type) return String;
   end Gen;

Say our code declares an array type, and a function to convert an integer
to a string.

.. code-block:: ada

   with Gen;
   package P is
      type My_Array is array (Natural range <>) of Positive;
      function Integer_Image (Value : Integer) return String
         is (Integer'Image (Value));
   end P;

When I want to instantiate Array_Image, I need to set Index_Type to precisely
Natural, and Item_Type to precisely Positive, so that the definition of the
array matches.  I can even pass Integer_Image for Index_Image and Item_Image,
even though the parameter's type is not exactly the same.

.. code-block:: ada

   function My_Array_Image_1 is new Gen.Array_Image_1
      (Natural, Positive, My_Array, Integer_Image, Integer_Image);
   --  OK

If I pass Integer for either the index or the item type, the compiler complains
that the array definition does not match the actual.

.. code-block:: ada

   function My_Array_Image_2 is new Gen.Array_Image_1
      (Integer, Positive, My_Array, Integer_Image, Integer_Image);
   --  ERROR: index types of actual do not match those of formal "Array_Type"


Let's say that I now generalize things a bit with a signature package, and
I adapt the signature of Array_Image to use these:

.. code-block:: ada

   package Gen is
      generic
         type T (<>) is limited private;
         with function T_Image (Value : T) return String;
      package Displayable is
      end Displayable;

      generic
         type Index_Type is (<>);
         type Item_Type is private;
         type Array_Type is array (Index_Type range <>) of Item_Type;
         with package Display_Index is new Displayable
            (T => Index_Type, others => <>);
         with package Display_Item is new Displayable
            (T => Item_Type, others => <>);
      function Array_Image_Signature (Value : Array_Type) return String;
   end Gen;

In my package, I will instantiate the signature for integer:

.. code-block:: ada

   package P is
      --  [...] same as before, plus:

      package Integer_Displayable is new Displayable (Integer, Integer_Image);
   end P;

I can however not instantiate my Array_Image using Integer_Displayable:

.. code-block:: ada

   function My_Array_Image is new Array_Image_Signature
      (Natural, Positive, My_Array, Integer_Displayable, Integer_Displayable);
   --  ERROR: actual for "T" in actual instance does not match formal

So with subprograms, subtypes are allows, but not with packages. This is
certainly a rule that makes sense in a lot of cases, but is inflexible here.

What I would like is a way to say: the instance that is used for Display_Index
should accept Index_Type (e.g. Natural) or a supertype of Index_Type (e.g.
Integer).

Conversely we can also add the flexibility for the array_type: if I can
pass Integer for Index_Type and indicate that Array_Type is either indexed
on Index_Type or a subtype of it then it would work.


One solution is to duplicate the types used for index and item. This is
somewhat unfriendly, since in a large number of cases users will simply pass
the same type twice (for instance for an array indexed on Integer).

.. code-block:: ada

   generic
      type Base_Index_Type is (<>);
      type Index_Type is Base_Index_Type;
      type Base_Item_Type is private;
      type Item_Type is Base_Item_Type;
      type Array_Type is array (Index_Type range <>) of Item_Type;
      with package Display_Index is new Displayable
         (T => Base_Index_Type, others => <>);
      with package Display_Item is new Displayable
         (T => Base_Item_Type, others => <>);
   function Array_Image (Value : Array_Type) return String;


Another possible approach would be to say the package accepts index_type or
its parent type. Using the 'Base attribute did not work here since it has a
different meaning.

.. code-block:: ada

   generic
      type Index_Type is (<>);
      type Item_Type is private;
      type Array_Type is array (Index_Type range <>) of Item_Type;
      with package Display_Index is new Displayable
         (T => Index_Type'Parent_Type, others => <>);  --  extension
      with package Display_Item is new Displayable
         (T => Item_Type, others => <>);
   function Array_Image (Value : Array_Type) return String;


A third approach would possible involve other extensions to the generic
contract model, via introspection:

.. code-block:: ada

   generic
      type Array_Type is array (<>) of <>;
      with package Display_Index is new Displayable
         (T => Array_Type'Index_Type, others => <>);  --  extension
      with package Display_Item is new Displayable
         (T => Array_Type'Component_Type, others => <>);  --  extension
   function Array_Image (Value : Array_Type) return String;



Guide-level explanation
=======================

The first section illustrates the issue in details. I feel there are much
better qualified persons to come up with a solution. As it is, I did not find
a solution within the current Ada 2012 language.


Reference-level explanation
===========================

Will wait until a new syntax is eventually proposed.

Rationale and alternatives
==========================

I feel there is a need to do something here because the current language
does not provide a solution.

Drawbacks
=========

Prior art
=========

Unresolved questions
====================

Future possibilities
====================

