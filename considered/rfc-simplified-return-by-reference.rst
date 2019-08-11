- Feature Name: Simplified Return by Reference Syntax
- Start Date: 2019-08-10
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Summary
=======

Provide a more simplified new user syntax for creating return types that
return by reference.

Motivation
==========

The Ada RM defines a "reference type" as "A (view of a) type with a specified 
Implicit_Dereference aspect" [1].  These types are used to more safely return
an internal component of an object (such as a container), used for iterators,
etc.  However, the syntax for such a type is not very user friendly and takes
a lot of scaffolding that doesn't actually add to reabability.  In fact, it 
can hamper readability.  New users may find it challenging to create one from
scratch withough finding and example to mimic, and even then they may not
fully understand all the implications of the implementation that they end up
mimicing.

Additionally, using a "reference type" still ends up exposing an access type
to the client code.  It is safer than a standard access type, but still not
desirable.

The idea behind this RFC PR is to suggest a simpler, more readable and
understandable syntax that leverages existing Ada idioms as implementation.

[1]: http://www.ada-auth.org/standards/rm12_w_tc1/html/RM-4-1-5.html#I2450

Guide-level explanation
=======================

In order to return a component by reference, one should use the syntax:

.. code-block:: ada

    function Reference(Source : in out Thing) return aliased Some_Type;


This will return a view of an object of Some_Type by reference, presumably from
Source (though it could come from a package level variable as well if aliased).
Note that the parameter thing may required to be aliased depending on how the
return object is referenced.

If a readonly view is desired, then the syntax can be changed to:

.. code-block:: ada

    function Reference(Source : Thing) return aliased constant Some_Type;

To actually implement this function, simply return an access type and the
compiler will convert it based on the return type specified in the 
declaration.

.. code-block:: ada

    function Reference(Source : in out Thing) return aliased Some_Type is
    begin
    
       -- Here, both Source and Something must be aliased (Source is not
       -- explicitly aliased in this example, but it may have to be if not
       -- tagged or limited).
       return Source.Something'Access;
    end Reference;

Reference-level explanation
===========================

In current Ada, to return by reference, the RM suggests something similar to

.. code-block:: ada

    type Reference_Type(Element : not null access Some_Type) is limited null record
       with Implicit_Dereference => Element;
    
    function Reference(Source : in out Thing) return Reference_Type;

This RFC does not propose a change or deprication to this but to have the
compiler automatically generate the reference type under the hood for the
programmer if they use the following syntax for that call:

.. code-block:: ada

    function Reference(Source : in out Thing) return aliased Some_Type;

All of the same rules that apply to the type with Implicit_Dereference would
apply to the type returned by the function, but it would hide the actually
access type (and thus protect the user).  One would expect the same compiler
errors, compiler warnings, and runtime exceptions that would be encountered
when using a type with Implicit_Dereference.

Implementing the function would be just as simple:

.. code-block:: ada

    function Reference(Source : in out Thing) return aliased Some_Type is
    begin
       -- Identical to return (Element => Source.Something'Access);
       return Source.Something'Access;
    end Reference;

Again, the proposal is that this can purely be implemented the way it is
in today's Ada, but with a simplified syntax that clearly indicates what
is being done.  The intent is that all the same access rules that exist in
Ada today would still apply.  This is meant to be mostly cosmetic.

For situations where a more complex return type is needed (say for handling
tampering checks in a container), an aspect could be supplied to where the
existing form could still be used as a specified implementation:

.. code-block:: ada

    -- This hides a record with a tamper check implementation
    type Reference_Type(Element : not null access Some_Type) is limited private
       with Implicit_Dereference => Element;
    
    function Reference(Source : in out Thing) return aliased Some_Thing
       with Reference_Return_Type => Reference_Type;

Note that while the reference type is declared in this example, the user
of the function still does not have access to that view of the returned object.
They still get a object that looks like a Some_Thing.  This just allows the
compiler to avoid implicitly making the reference type and will use the
user defined one.  It also prevents the user from having access to the access type.

Implementing the above function would look more like the traditional current
method:

.. code-block:: ada

    function Reference(Source : in out Thing) return aliased Some_Thing is
    begin
       return (Element => Source.Something'Access, ...Other stuff);
    end Reference;
    
NOTE:  While this proposal focuses on implementing it using the existing
Implicit_Derefernce types, if it is easier to simply use access types
under the hood, that is fine.  The intent of this RFC is to reuse existing
rules, implementations, etc. with minimal implementaiton fuss.


Rationale and alternatives
==========================

This RFC is intended to increase readability, improve conveyance of intent, 
and improve general safety of the code.  The current alternatives work, but
still expose access types.  While access types are safer in Ada than many 
other languages, they still can be abused.  

Drawbacks
=========

* It's an alternative syntax, which adds complexity to the language.
* It makes use of an existing keyword in a way that wasn't originally intended
* It might be complex for compilers to implement?
* Existing Ada standard packages like containers already have a defined API,
  so they wouldn't be able to leverage this.

Intended Benefits
=================

* Enchanced readability - Compare to an implicit dereference declaration
* More safety from access types - User has even less access to them
* Utilizing existing Ada mechanics - Implicit dereference types or access 
  types, up to implementor

Prior art
=========

This RFC was not really inspired by prior art.  Other languages like C++ and
Rust have return by reference, but they were not the basis for this RFC.

Unresolved questions
====================

- How complex it would be to implement

- How restricted will this feature need to be? 

Future possibilities
====================

Support for anonymous access types is still very perilous in current compilers,
including GNAT.  It is incredibly easy to create dangling references without 
using Unchecked_Access in the current implementations of existing compilers.
My hope is that the implementation of this feature might lead to better support 
and also hopefully expose any holes that we currently might have in the 
standard.  It would be nice to get to a point where the Ada compiler could 
even be better at finding dangling references at compile time while having 
much better usability of those references than currently available in the 
standard.
