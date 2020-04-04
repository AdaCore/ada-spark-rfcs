- Generic Partial Instantiation of Generics
- Start Date: 2020-04-04
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Summary
=======

This RFC proposes adding a method to partially instantiate a generic
package or operation in order to allow for simpler client facing generic
packages or operations built off of the former.

Motivation
==========

When working in complex problems in Ada, it sometimes makes sense to use
a single "core" generic as the backbone for a lot of other generics.  This
"core" generic might have a rather large and/or unwieldly formal parameter
list that 99% of your userbase wouldn't need, but it makes developing the
intended userbase API much simpler/faster/safer.  Consider a complex
generic specification like:


.. code-block:: ada

    generic
       type Type1 is private;
       type Type2 is limited private;
       type Type3(<>);
       with package P1 is new Some_Generic_Package(<>);
       with function Image(Value : Type1) return String;
    package My_Package is
       procedure Yay(Value : Type1);  -- calls Image internally
       -- Other Stuff
    end My_Package;

Formal parameters Type2, Type3, and P1 might have been abstracted
out to make My_Package generic enough to usable across multiple
different situations.  However, it might be undesireable for one 
to expect an average user to know how to supply them or understand  
how/why those parameters would be needed.

Ideally one might want to provide the following API to the userbase:

.. code-block:: ada

    generic
       type Type1 is private;
       with function Image(Value : Type1) return String;
    package My_Client_Package is
       -- Same public API as before
    end My_Client_Package;

In order to do this the options might include:
1.  Instantiate My_Package publically inside of My_Client_Package.  This
might be ok in some cases but is awkward as one might have to chain package
calls (p1.p2.Yay) or perhaps expose Type2, Type3, and P1 to the intended
client interface when they don't want to directly.

2.  Instantiate My_Package privately inside of My_Client_Package.  This
then requires duplication of all the scaffolding of My_Package.  It can
sometimes be difficult to do (say if some public types were Reference
types from a container or similar ).  It can be error prone and a 
maintenance hazard as well.

Guide-level explanation
=======================

A deferred partial instantiation of a generic is simple to implement.  It
involves creating a new specification.  Consider the existing generic
specification:

.. code-block:: ada

    generic
       type Type1 is private;
       type Type2 is limited private;
       type Type3(<>);
       with procedure Something(Param1 : Type2; Param2 : Type3);
       with function Image(Value : Type1) return String;
    package My_Package is
       procedure Yay(Value : Type1);  -- calls Image internally
       -- Other Stuff
    end My_Package;

and you wanted to create the same API with a restricted formal parameter
list to easy user instantiation of your package to look like this:

.. code-block:: ada

    generic
       type Type1 is private;
       with function Image(Value : Type1) return String;
    package My_Client_Package is
       -- Same public API as before
    end My_Client_Package;

The syntax would be:

.. code-block:: ada

    generic
       type Type1 is private;
       with function Image(Value : Type1) return String;
    package My_Client_Package is new My_Package
       (Type1     => Type1,
        Type2     => Integer,
        Type3     => String,
        Something => Something_For_Integer_And_String,
        Image     => Image);

Here Type1, Type2, and Something are manually supplied.  Now the client
only has to supply the two parameters that are most often needed.

This cuts back on many potential maintenance hazards and supports
providing the intended API to users of a complex library.

Then implementors of My_Client_Package would simply need to do:

.. code-block:: ada

    package P is new My_Client_Package
       (Type1 => My_Type, 
        Image -> Image_For_My_Type);

and can now make the call 

.. code-block:: ada

    P.Yay;

without needing either the internal package instantiation or the 
API scaffolding.

    

Reference-level explanation
===========================

This is the technical portion of the RFC. Explain the design in sufficient
detail that:

- Deferred partial instantion of generics would otherwise follow all
  the same rules for formals as current generics.
- This could be implemented by the compiler with simple copy / paste
   mechanics.  When the user instantiates:

.. code-block:: ada

    package P is new My_Client_Package
       (Type1 => My_Type, 
        Image -> Image_For_My_Type);

  the compiler can internally replace it with 

.. code-block:: ada

    package P is new My_Package
       (Type1     => My_Type,
        Type2     => Declared_Scope.Integer,
        Type3     => Declared_Scope.String,
        Something => Declared_Scope.Something_For_Integer_And_String,
        Image     => Image_For_My_Type);


Rationale and alternatives
==========================

- Existing alternatives to this method were discussed in the Motivations
  section of this proposal.
- This proposal is designed to reduce errors due to copy/paste, 
  implementing scaffolding, and bad user construction.  Additionally,
  it helps reduce maintenance of potential "client facing" generics
  when the core generic is modified.
- The aim of this proposal is to reduce common development bugs while
  maintaining or enhancing Ada's normal readability of the code.

Drawbacks
=========

- Maybe harder to implement than I think?  
- Since the client facing generics simpley "new" the core generics, you
  do get one level of indirection of "seeing" the API.  This is the 
  same issue you see with type extension and overriding operations. 
- One still has to come up with unique names to distinguish between
  the client facing generics and the core generics, so no improvements
  in that realm.


Prior art
=========

I am not aware of any prior art for this.  

Unresolved questions
====================

- In general I think that this can be done without causing issues with
  existing Ada formal parameter rules.  I am not a compiler writer, so 
  I don't know this for sure.  Through this proposal we may be able to
  iron that out.

- I don't know if this interacts poorly with any other proposed generics
  changes disucssed in other proposals here or within the ARG.

Future possibilities
====================

I have not thought of anything further yet. Perhaps discussion will
change that.
