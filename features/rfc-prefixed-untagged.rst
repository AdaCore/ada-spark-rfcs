Feature Name: Prefixed notation (object.op()) for untagged types

- Start Date: 2019-11-01
- Status: Production

Summary
=======

The "object.op()" notation has become popular enough that we should
consider generalizing it to apply to all types.

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

Due to both technical and methodological reasons we originally considered proposing
generalizing this notation only to *private* untagged types.  However, the general
consensus seems to be that it would be simpler to allow it for any type, and
presume we can solve the technical problems without introducing too much
upward incompatibility.

Guide-level explanation
=======================

When operating on an untagged type, if it has any primitive operations,
and the first parameter of an operation is of the type (or
is an access parameter with an anonymous type that designates the type),
you may invoke these operations using an "object.op(...)" notation, where the
parameter that would normally be the first parameter is brought out front,
and the remaining parameters (if any) appear within parentheses after the name
of the primitive operation.

This same notation is already available for tagged types.  We are proposing to
allow it for untagged types.  It would be allowed for all primitive operations
of the type independent of whether they were originally declared in a package spec or
its private part, or were inherited and/or overridden as part of a derived type declaration
occuring anywhere, so long as the first
parameter is of the type, or an access parameter designating the type.

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
is generalized to apply to primitives of an untagged type.
The current feature is defined in paragraph (9.2/3) of **RM 4.1.3**.  This would be adjusted a
bit to allow untagged types as well.

In the example above, we see a use of the notation in statements and assertion pragmas outside
the package, but we also see the notation used inside the private part of the package
to define a Type_Invariant on the full type.  When the type is not a private type,
or in places where the full type is visible, there
might be more overloading to deal with.  For example, if the (full) type is a record type,
it might have a component named Length or Capacity.  If so, as for tagged types,
the component takes precedence during overload resolution.  Similarly, if the
(full) type is an access-to-record type, the record type might have components
called Length or Capacity.  Again, the name resolution rules would favor the
components in such a case.

Here is possible revised wording for **RM 4.1.3(9.1/2-9.2/5)**:

Given a specific type T, a view of a primitive subprogram of T whose first formal parameter is of type T or is an access parameter whose designated type is T,
or, if T is tagged, a view of a subprogram whose first formal parameter is of a class-wide type or is an access parameter whose designated type is class-wide:

The prefix (after any implicit dereference) shall resolve to denote an object or value of type T or class-wide type T'Class. The selector_name shall resolve to denote a view of a subprogram declared immediately within the declarative region in which an ancestor of the type T (including T itself) is declared. The first formal parameter of the subprogram shall be of type T, or a class-wide type that covers T, or an access parameter designating one of these types. The designator of the subprogram shall not be the same as that of a component of the type visible at the point of the selected_component. Furthermore, if T is an access-to-object type, the designator of the subprogram shall not be the same as that of a visible component of the type designated by T. The subprogram shall not be an implicitly declared primitive operation of type T that overrides an inherited subprogram implemented by an entry or protected subprogram visible at the point of the selected_component. The selected_component denotes a view of this subprogram that omits the first formal parameter. This view is called a prefixed view of the subprogram, and the prefix of the selected_component (after any implicit dereference) is called the prefix of the prefixed view.

Rationale and alternatives
==========================

Object.operation notation as defined in Ada 2005 is only for tagged types.
At the time, the ARG considered generalizing it further, but chose to stick
to tagged types because those seemed the most critical.  We expressed an intent to
create another AI to extend it to more types, but ultimately never got around
to it.  Since Ada 2005 was released, we have seen growing use of object.op
notation, to the point that some types are being declared **tagged**
merely to ensure the availability of the notation.  

Our original reason for limiting this to *private* types
was that we had noticed more demand for this feature there,
and because for private types, the notion of *primitive*
operations is more important.
But we concluded that since we needed to support it on the
full type of a private type, we might as well support it for
all types. 

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

Whether to restrict this to only private untagged types is still debatable,
but lacking any strong argument to restrict it, we have chosen to
allow any type, at least for initial prototyping.

Future possibilities
====================

Conceivably in future versions we could extend this further, to all subprograms,
even those that are not primitive.  However, this might make it even harder
to figure out what subprogram is being invoked.  For primitive operations,
there is no real doubt.
