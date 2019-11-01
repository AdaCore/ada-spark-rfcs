Feature Name: Prefixed notation (object.op()) for untagged types
- Start Date: 2019-11-01
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Summary
=======

The "object.op()" notation has become popular enough that we should
consider generalizing it to apply to untagged private types, and the
types that implement them.

Motivation
==========

The object.op() notation was introduced in Ada 2005, and it only applied
to tagged types.  The notation allows an operation of a type to be
invoked on an object of the type without having to specify the package 
where the type is declared.  This notation is familiar from many other
languages, and has become quite widely used within Ada for tagged types.
In fact, the object.op() notation is sufficiently user-friendly that some
private types are declared as **tagged** merely to ensure the availability
of this notation.  This seems like an indication that we should consider
generalizing the notation so it applies to untagged as well as tagged types.

There are both technical and methodological reasons why we are only proposing
generalizing this notation to *private* untagged types.  To avoid confusing situations 
that arise from allowing a notation on a private type but not on its full type,
we are proposing to allow the notation even when within the scope of
the full type implementing the private type, but the notation is limited
to primitive operations declared within the spec of the package where the
private type is declared.

Guide-level explanation
=======================

When operating on an untagged private type, if it has any primitive operations,
and the first parameter of an operation is of the private type (or
is an access parameter with an anonymous type that designates the private type),
you may invoke these operations using an "object.op(...)" notation, where the
parameter that would normally be the first parameter is brought out front,
and the remaining parameters (if any) appear within parentheses after the name
of the primitive operation.

This same notation is already available for tagged types.  We are proposing to
allow it for untagged private types.  It is allowed for all primitive operations
of the private type declared in the package spec where the private type
is declared, and can be used even if the caller has visibility on the full type
implementing the private type.

For example::

  generic
     type Elem_Type is private;
  package Vectors is
      type Vector is private;
      procedure Add_Element (V : in out Vector; Elem : Elem_Type);
      function Nth_Element (V : Vector; N : Positive) return Elem_Type;
      function Length (V : Vector) return Natural;
  private
      function Capacity (V : Vector) return Natural;
         --  Return number of elements that may be added without causing
         --  any new allocation of space
         
      type Vector is ... 
        with Type_Invariant => Vector.Length <= Vector.Capacity;
      ...
  end Vectors;
  
  package Int_Vecs is new Vectors(Integer);
  V : Int_Vecs.Vector;
  ...
  V.Add_Element(42);
  V.Add_Element(-33);
  pragma Assert (V.Length = 2);
  pragma Assert (V.Nth_Element(1) = 42);

Reference-level explanation
===========================

The notion of a *prefixed view of a subprogram* introduced in **RM 4.1.3 Selected_Components**
is generalized to apply to primitives of an untagged private type declared in the visible
or private part of the package.  It also applies in places where the full type is visible.
The current feature is defined in paragraph (9.2/3) of **RM 4.1.3**.  This would be adjusted a
bit to allow untagged private types as well, including when in the scope of their full
type.

In the example above, we see a use of the notation in statements and assertion pragmas outside
the package, but we also see the notation used inside the private part of the package
to define a Type_Invariant on the full type.  When the full type is visible, there
might be more overloading to deal with.  For example, if the full type is a record type,
it might have a component named Length or Capacity.  If so, as for tagged types,
the component takes precedence during overload resolution.  Similarly, if the
full type is an access-to-record type, the record type might have components
called Length or Capacity.  Again, the name resolution rules would favor the
components in such a case.

Rationale and alternatives
==========================

Object.operation notation as defined in Ada 2005 is only for tagged types.
At the time, the ARG considered generalizing it further, but chose to stick
to tagged types because those seemed the most critical.  We expressed an intent to
create another AI to extend it to more types, but ultimately never got around
to it.  Since Ada 2005 was released, we have seen growing use of object.op
notation, to the point that some private types are being made **tagged**
merely to ensure the availability of the notation.  

We considered generalizing this to all untagged types, but this seemed to open
up more possibilities for confusion.  The places where we have noticed the
demand for this has been with private types.  It is conceivable that there
is also interest in having this for visible types, or at least visible
untagged record types.  That would be a relatively simple extension, but
the whole notion of primitive operations for non-private types is
somewhat less interesting, as the operations other than operators tend
to be only loosely linked to the type.  The predefined operators themselves
are not interesting for this notation, as normal infix notation (e.g. X + Y) 
is far superior in readability to a corresponding prefix notation using a 
quoted operator symbol (e.g. X."+"(Y)).

We have been taking other steps to remove some of the distinctions between
tagged and untagged types (e.g. in the handling of "=" on untagged
record types), and this proposal is consistent with that.

Drawbacks
=========

There is some implementation effort to support the new feature, but it
is not introducing any fundamentally new kind of overload resolution, given
the existing ability to have a prefix of a selection that is
a call on an overloaded function, where one overloading might return a
tagged type, and the other might return an access-to-tagged type.

Prior art
=========

This is generalizing a feature introduced in Ada 2005, so the notion is
already pretty well established in the Ada community.  For other languages,
prefix notation is quite common.

Unresolved questions
====================

Whether to allow this for non-private untagged types is still open.  We could
see allowing it on untagged record types, since it is allowed on tagged
record types.  Extending it to all untagged types seems like it might
sink the whole idea from a complexity or confusion point of view, and 
doesn't seem to provide significant benefit.

Future possibilities
====================

Conceivably in future versions we could extend this further, to all types.
I personally wouldn't recommend it, as the whole notion of whether an
"operation" actually *belongs* to an object begins to break down for
non-private types.
