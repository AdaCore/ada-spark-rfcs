- Feature Name: Adjust_Indexing
- Start Date: 2020-10-25
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Summary
=======

Ada standard gives the possibility of User-Defined Indexing (§4.1.6).
In this proposal, Adjust_Indexing new aspect adds the possibility of a deferred
post-traitement after a container indexing assignment.

Motivation
==========

Ada 2012 brings, among others, the aspect Variable_Indexing which permits to simplify
the writing of updating operation of an element from its index.
Typically, an updating operation on a list container might be for the whole element, before:

``` ada
Replace_Element (My_List, Index, New_Element);
```

Now, we could write in short (assuming we have provided all variable indexing stuff):

``` ada
My_List(Index) := New_Element;
```
We might have similar mechanism for partial updating of element components, before:

``` ada
procedure Modulus(E: in out Element_Type; R : Float) is
  begin
  E.Rho := R;
  end;
Update_Element (My_List, Index, Modulus'Access);
```

Now, we could simply write in short:
``` ada
My_List(Index).Rho := R;
```

However, in these two previous cases, with the short writing, we have lost the possibility
to keep some properties verified at element level or at the whole container level.
It was before possible to add some post-traitement inside Replace\_Element or Update\_Element
procedures but no more with Variable_Indexing aspect mechanism.

It might happen also that the internal structure of the container couldn't support direct
access of its elements with Variable_Indexing aspect.

An extra mechanism is needed to give more control on the assign operation.

Guide-level explanation
=======================

Given a tagged type T, the following type-related, operational aspect may be specified: Adjust_Indexing.

This aspect shall be specified by a name that denotes one or more procedures declared immediately
within the same declaration list in which T is declared. All such procedures shall have at
least two parameters, the first of which is of type T or T'Class.
These aspects are inherited by descendants of T (including the class-wide type T'Class).

When a target object with Variable_Indexing and Adjusting\_Indexing aspects is assigned a value,
the assignment operation proceeds as follows: 
- The value of the target designated by Variable\_Indexing aspect becomes the assigned value.
- The value of the target is adjusted with the procedure designated by Adjust\_Indexing aspect and
which matches the calling profil. 

It is an error if Adjust\_Indexing is present without any Variable\_Indexing aspect.

### Example 1:

Let's take a container list of pointers on data with the property that there is no shared memory
among the pointers.
Each pointer of the list gives access to its own memory data.
All pointers are different from each other.
With Adjust\_Indexing aspect, the property is kept in the following code:

``` ada
   type Element_Access is access EleElement_Typement;
   type List is tagged private with
      Variable_Indexing => Reference,
      Adjust_Indexing => Adjust_List;

   type Pointer_Reference (E : not null access Element_Access) is limited private with
      Implicit_Dereference => E;
   function Reference (L : aliased in out List; Index : Positive) return Pointer_Reference;
   procedure Adjust_List (L : in out List; Index : Positive);

   -- ...

   procedure Adjust_List (L : in out List; Index : Positive) is
   begin
      L(Index).Ptr := new Element_Type'(L(Index).Ptr.all);
   end;

   -- ...

   LA : List;
   begin
      LA(3) := LA(4) -- Deep copy, the property is kept.
   end;
```

### Example 2:

Let's take a container with inner representation has components which can't be accessed
as for instance an Unbounded\_String where individual character can't be accessed.
With Adjust\_Indexing aspect the Unbounded\_String is updated in the following code:

``` ada
   type Script is tagged private with
      Variable_Indexing => Reference,
      Adjust_Indexing => Adjust_Script;

   type Character_Reference (Char : not null access Character) is limited private with
      Implicit_Dereference => Char;
   function Reference (Source : aliased in out Script; Index : Positive) return Character_Reference;
   procedure Adjust_Char (Source : in out Script; Index : Positive);

   -- ...

   function Reference (Source : aliased in out Script; Index : Positive) return Character_Reference is
   begin
      return (Char => Source.Char'Access);
   end;

   procedure Adjust_Script (Source : in out Script; Index : Positive) is
   begin
      Replace_Element (Source.Data, Index, Source.Char);
   end;

   -- ...

   SC : Script;
   begin
      SC(3) := 'Z'; -- Z is put in the Unbounded_String at the index 3.
   end;
```

### Example 3:

Let's take a container with inner representation has components which can't be individually
accessed as for instance a string with UTF-8 encoding where access to individual character
hasn't any meaning as UTF-8 codepoint may be represented with more than one character.
With Adjust\_Indexing aspect the UTF-8 string is updated in the following code:

``` ada
   type UXString is tagged private with
      Constant_Indexing => Element,
      Variable_Indexing => Reference,
      Adjust_Indexing => Adjust_Element;
   function Element (Source : UXString; Index : Positive) return Unicode_Character;
   type Unicode_Character_Reference (UChar : not null access Unicode_Character) is limited private with
      Implicit_Dereference => UChar;
   function Reference (Source : aliased in out UXString; Index : Positive) return Unicode_Character_Reference;
   procedure Adjust_Element (Source : in out UXString; Index : Positive; Substitute : Character := ' ');

   -- ...

   function Reference (Source : aliased in out UXString; Index : Positive) return Unicode_Character_Reference is
   begin
      return (UChar => Source.UChar'Access);
   end;

   procedure Adjust_Element (Source : in out UXString; Index : Positive; Substitute : Character := ' ') is
   begin
      Replace_Element (Source.Data, Index, Source.UChar);
   exception
      Replace_Element (Source.Data, Index, Substitute);
   end;

   -- ...

   SU, SA : UXString := Get_Device_Name;
   begin
      for CP of SU loop
         CP := Up_Case (CP); -- UTF-8 codepoints of SU are replaced by their upcase form.
                             -- If an exception occurs space is substituated.
      end loop;
      SA(1, '@') := Up_Case (SA(1)); -- UTF-8 codepoint position 1 of SA is replaced by it's upcase form.
                                     -- If an exception occurs '@' is substituated.
   end;
```

Reference-level explanation
===========================

After the objet designated by Variable\_Indexing reference is given its value,
the procedure named by Adjust\_Indexing and which matches the calling profil is called.

In example 1, the assignment instruction is divided in two operations:

- the value in index 4 of the list LA is copied in index 3 of the list LA via the Reference
function designated by the Variable\_Indexing aspect, but now there are two references of the
same memory, the property is not verified
- a new memory allocation of the data referenced by the list LA index 3 is created and
assigned to the list LA index 3 via the Adjust_List procedure designated by the Adjust\_Indexing
aspect, now even the data are the same, there isn't shared memory in the list LA,
so the property is enforced

Also in example 2, the assignment instruction is divided in two operations:

- the character 'Z' is copied in the component Char of the script SC via the Reference
function designated by the Variable\_Indexing aspect, it can't be directly copied
in the index 3 of the script SC as the implementation representation is an Unbounded_String for instance
- the value of the component Char of the script SC is put in the index 3 of the underlying
Data component via the procedure Repalce\_Element called by Adjust\_Script procedure
designated by the Adjust\_Indexing aspect

As for already existing Constant\_Indexing and Variable\_Indexing aspects, Adjust\_Indexing aspect may
designate some procedures with more than two parameters.

In example 3, the SU loop assignment calls the Adjust\_Element form with default substitute parameter:
``` ada
   Adjust_Element (SU, I);
```
Whereas the SA loop assignment calls the Adjust\_Element form with the given substitute parameter:
``` ada
   Adjust_Element (SA, 1, '@');
```

Rationale and alternatives
==========================

The aspect Adjust\_Indexing behaviour is similar of the one of Adjust procedure
of a Controlled type from package Ada.Finalization.

A other solution may be to achieve copy and adjust in one operation but will
make backward compatibility issues with already existing Variable\_Indexing aspect.

A more tedious solution might be a container of Controlled elements with a redefined Adjust procedure.

A workaround would be to store the index during the assignment and adjust at the fisrt get of an element.

Drawbacks
=========

It may have a delay between value copy and the call of the adjust procedure.

Prior art
=========

NA.

Unresolved questions
====================

How to make sure that value copy and the call of the adjust procedure is
not interrupted by an other assignment on the same index?

Does the assignment operations shouldn't be queued?

Future possibilities
====================

Achieve to execute the assignment with the adjustment in only one operation.
