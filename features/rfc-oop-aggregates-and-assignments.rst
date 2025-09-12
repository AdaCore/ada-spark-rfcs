- Feature Name:
- Start Date:
- RFC PR:
- RFC Issue:

Summary
=======

Motivation
==========

Issue at hand
-------------

Aggregates and assignments share a few joint issues that make it worth combining
into a single RFC. To understand, it's worth starting with the issues with the
current semantics.

First, in Ada, aggregates are a way to completely workaround calls of
initialization. To some respect, this makes sense, aggregates are ways to
replace initialization. But the consequence is that there's no way to ensure
that a given sequence of statement is putting an object in a consistent state
at creation time (unlike traditional constructors).

Second, Adjust perform a post-copy update to a type. This causes a double issue,
first in terms of performance, as assignment may not need all components to be
modified. But this also limits the control over assignment logic, as the user
has no way to know what was the initial state of the object or what object
was initially copied from.

Third, Ada allows partial assignment of objects through parent views. To
some respect, this is also an issue, as the resulting object may be inconsistent,
with only part updated, and potentially no way in Adjust to understand which
part was changed and which part was not.

A related issue is the so called "Aggregate by extension" where a root object
is copied into a child one with specific values provided by the aggregate,
again here with no control over the consistency of values (not even in Adjust
in the case of initialization).

To solve these issues, we propose to introduce a two step object update
mechanism through a value duplication ('Clone) and post update adjustment
('Adjust).

Note that this extra complexity is driven from the desire to support natively
Ada constructs (aggregates, partial copies, etc) and improve compatibility
between classes and tagged types. Users can leverage default implementation if
such level of control is unecessary. Some language extension may also allow
to forbid aggregates and partial update on specific types (although this
introduces complexities in generics that now need to specify wether these
restricted types are allowed or not).

Also keep in mind that Ada Flare aggregates also need to account for types that
have both public and private components.

This RFC is about tagged record (and class records even if not explicitely
mentionned). Simple records should also be studied when constructors are made
available to them.

The additional capabilities need to be optimized as much as possible by the
compiler. In particular - even if it's not a language mandate - the compiler
should replace calls to Clone by binary copies and remove calls to Adjust when
it knows there's no chance of calling an overriden subprogram.

'Clone
------

The attribute 'Clone can be defined for each tagged type. It describes how to
copy (or clone) the value of a tagged type into a other one. For example:

.. code-block:: ada

   type Root is tagged record
      A : access Integer;
   end record;

   procedure Root'Clone (Self : Root; To : in out Root);

Root'Clone is not a primitive and cannot be inherited. However, a child
class may provide its own cloning method:

.. code-block:: ada

   type Child is new Root with record
      B : access Integer;
   end record;

   procedure Child'Clone (Self : Child; To : in out Child);

The default implementation of Clone first calls the parent clone and then
calls clone operation of all the components one by one. The compiler is free to
optimize to bitwise copies if clone operations are not user-defined.

Calls to 'Clone are statically resolved when used on definite views, and
dynamically resolved on 'Class wide type. This is arguably a departure from the
"all calls are dispatching" requirement from other aspects of the OOP design,
but is required to allow partial copies of objects which are done today in
various places Ada.

The invariant of the target object is not checked after a call to Clone, some
parts may still be inconsistent and fixed later by Adjust.

'Adjust
-------

'Adjust is a overridable attribute called after certain operations. It is
different from the legacy Ada Adjust primitive in that it has an argument
refering to the initial value. Note that the From parameter of adjust is
always typed after the root type of the tagged record hierarchy - indeed, the source
object may be higher up in the derivation chain in the case of partial
copy. This value is provided for reference but is not expected to be
modified.

.. code-block:: ada

   type Root is tagged record
      A : access Integer;
   end record;

   procedure Root'Adjust (Self : in out Root; From : Root);

   type Child is new Root with record
      B : access Integer;
   end record;

   procedure Child'Adjust (Self : in out Child; From : Root);

Values of the From parameter will have been copied from Clone call prior to
calling Adjust.

Invariants are checked after a call to Adjust.

Base code for the Examples
--------------------------

To reason on the examples below, it's useful to consider a simple hierarchy
with pointers as components, where these pointers are supposed to be unique
and deallocated upon destruction. In addition, the pointed value of the child
needs to be maintained equal to the parents.

.. code-block:: ada

   type Root is tagged record
      A : access Integer;
   end record;

   procedure Root'Constructor (Self : in out Root) is
   begin
      Self.A := new Integer'(0);
   end Root'Constructor;

   procedure Root'Clone (Self : Root; To : in out Root) is
   begin
      Free (To.A);
      To.A := new Integer'(Self.A.all);
   end Root'Clone;

   procedure Root'Adjust (Self : in out Root; From : Root) is
   begin
      null;
   end Root'Adjust;

   type Child is new Root with record
      B : access Integer;
   end record;

   procedure Child'Constructor (Self : in out Child) is
   begin
      Self.B := new Integer'(0);
   end Child'Constructor;

   procedure Child'Clone (Self : Child; To : in out Child) is
   begin'
      Root (To) := Root (Self);
      Free (To.B);
      To.B := new Integer'(Self.B.all);
   end Child'Clone;

   procedure Child'Adjust (Self : in out Child; From : Root) is
   begin
      if From not in Child'Class then
         --  This was a partial assignment, fix the A / B consistency
         Self.B.all := Self.A.all;
      end if;
   end Child'Adjust;

When reasoning about this interface, it's useful to keep in mind that it has
a fundamental design flaw - it allows the user to modify the values of A and
B while possibly leaking the values. A more realistic example would make these
values private, or maybe not automatically allocate objects (but that would
prevent to showcase some aspects of the proposal later).

Generally speaking, this proposal is providing to the user the tools to develop
a type which will remain safe and consistent, to the contrary of the previous
model that offers shortcuts breaking this ability.

Simple Copy Assignments
-----------------------

The simple copy assignment of two objects leads to a sequence of calls to clone
and adjust:

.. code-block:: ada

      R1, R2 : Root;

   begin

      R2 := R1;
      --  Root'Clone (R1, R2); -- Static call
      --  Root'Adjust (R2, R1); -- Dispatching call on R2

Partial Copy Assignments
------------------------

Ada dynamically checks for tags compatibility in the context of two 'Class
types, which can only be assigned if they are of the same type. However, if the
views are definite, the assignment is partial. For example:

.. code-block:: ada

      R1 : Root;
      C1 : Child;

   begin

      Root (C1) := R1;
      --  Root'Clone (R1, C1);
      --  Child'Adjust (C1, R1);

In this case, the sequence is exactly the same as before. A similar
thing can be observed in parameters:

.. code-block:: ada

      procedure Something (A, B : Root) is
      begin
         A := B;
         --  Root'Clone (B, A);
         --  Root'Adjust (A, B);
      end Something;

      R1 : Root;
      C1 : Child;

   begin

      Something (C1, R1);

In this version of Ada, calls to primitive always dispatch. So the call to
Root'Adjust does dispatch to Child'Adjust.

Note also that while Adjust dispatches, Clone is a static call, in order to
respect the user choice to assign only the components of the view. For example:

.. code-block:: ada

      C1 : Child;
      C2 : Child;

   begin

      Root (C1) := Root (C2);
      --  Root'Clone (C2, C1); -- this is static, only copy Root fields
      --  Root'Adjust (C1, C2); -- this dispatches

Class-Wide Assignments
----------------------

Class wide assignments lead to dispatching calls to 'Clone and 'Adjust, ensuring
that the whole object is copied. They also require the two tags to be equals,
like today in Ada. Specifically:

.. code-block:: ada

   procedure P (V, W : R'Class) is
   begin
      V := W;
      --  if V'Tag = W'Tag then
      --    Root'Clone (W, V); -- this dispatches
      --    Root'Adjust (V, W); -- this dispatches
      --  else
      --    raise <the appropriate exception>;
      --  end if;

Aggregate Assignments
---------------------

Aggregates will lead to field by field assignment of a temporary object,
followed by the same sequence of Clone and Adjust. Aggregate objects need to
have a default constructor as this is what's going to be used to create the
temporary object initially:

.. code-block:: ada

      C : Child;

   begin

      C := (new Integer, new Integer);
      -- Tmp : Child;
      -- Child'Constructor (Tmp);
      -- Tmp.A := new Integer;
      -- Tmp.B := new Integer;
      -- Child'Clone (Tmp, C);
      -- Child'Adjust (C, Tmp);
      -- Child'Destructor (Tmp);

Note that the compiler is free to optimize the above by directly assigning A and
B if it knows that there's no clone and adjust user attributes:

.. code-block:: ada

      C : Some_Other_Child_With_No_Attributes;

   begin

      C := (new Integer, new Integer);
      -- C.A := new Integer;
      -- C.B := new Integer;

The above works the same in the case of a by extension aggregate if the parent
type is directly referred to. Values taken from the parent object are those
resulting of the constructor call:

.. code-block:: ada

      C : Child;

   begin

      C := (Root with new Integer);
      -- Tmp : Child;
      -- Child'Constructor (Tmp);
      -- Tmp.B := new Integer;
      -- Child'Clone (Tmp, C);
      -- Child'Adjust (C, Tmp);
      -- Child'Destructor (Tmp);

A few notes on the above sequences:

- The call to Clone is important, as it allows to clean the target object if
  necessary prior to copy.
- Before cloning Tmp we are cloning an object, we need to ensure its own
  internal consistency and lifecycle, hence the need to call its constructor and
  destructor.
- Usage of aggregate in conjunction with types that provide constructors,
  destructor, adjust and clone attributes is somewhat heavy, as the aggregate
  needs to be fully initialized before cloned, then reclaimed. It's important
  to have self consistency here. However, developer may prefer to reserve
  aggregate notation for types that do not require these constructs, and
  the compiler should optimize the sequencing in these cases.

Aggregate Assignments with Extension Copies
-------------------------------------------

Aggregate by extension that are extending a value as opposed to a default value
require an initial cloning of said value, e.g.:

.. code-block:: ada

      R : Root;
      C : Child;

   begin

      C := (R with new Integer);
      -- Tmp : Child;
      -- Child'Constructor (Tmp);
      -- Root'Clone (R, Tmp);
      -- Tmp.B := new Integer;
      -- Child'Clone (Tmp, C);
      -- Child'Adjust (C, Tmp);
      -- Child'Destructor (Tmp);

Delta Aggregates
----------------

Delta aggregates create their initial value from a by-copy constructor:

.. code-block:: ada

      C1 : Child;
      C2 : Child;

   begin

      C2 := (C1 with delta B => new Integer);
      -- Tmp : Child := C1;
      -- Child'Constructor (Tmp, C1);
      -- Tmp.B := new Integer;
      -- Child'Clone (Tmp, C);
      -- Child'Adjust (C, Tmp);
      -- Child'Destructor (Tmp);

Aggregates with Private Parts or Default Values
-----------------------------------------------

Aggregates may be provided with default values through the `=> <>` notation. In
that case, the value taken is the one set after call to the parameterless
constructor, e.g.:

.. code-block:: ada

      C : Child;

   begin

      C := (A => new Integer, others => <>);
      -- Tmp : Child;
      -- Child'Constructor (Tmp);
      -- Tmp.A := new Integer;
      -- Child'Clone (Tmp, C);
      -- Child'Adjust (C, Tmp);
      -- Child'Destructor (Tmp);

A new syntax in Flare allows types to have both public and private components,
if a user does not have visibility over all the components of a type, he
needs to specify in the aggregate that these non visible values are not
specified with a "private" part at the end of the aggregate, e.g.:

.. code-block:: ada

   package P is
      type Root is tagged record
         A, B : Integer;
      end record with private;

      R : Root := (1, 2, private);
   private
      type Root is tagged record
         C, D : Integer;
      end record;
   end P;

The behavior of a private part is the same as the one of default values. The
presence of this private word is mandatory if the user doesn't have full
visibility of the components of a type, forbidden otherwise. This is different
from the "others => <>" notation which expresses the desire to not value other
otherwise visible components.

Self Assignment
---------------

Detection against self assignment is now mandatory, to avoid users to manually
verify it and possibly making mistakes. The compiler is able to optimize self
assignment checks when it is statically known that the two objects are different
(for example, two local variables without address clauses). So the expansion
provided so far is conceptually a shortcut to:

.. code-block:: ada

      R1 : Root;
      R2 : Root;
   begin
      R1 := R2;
      --  if R1'Address /= R2'Address then
      --    Root'Clone (R2, R1);
      --    Root'Adjust (R1, R2);
      --  end if;
      --
      R1 := R1;
      --  if R1'Address /= R1'Address then
      --    Root'Clone (R1, R1);
      --    Root'Adjust (R1, R1);
      --  end if;

Note that this check was already an implementation permission in former versions
of Ada.

Aggregates and Initialization
-----------------------------

In the context of an initialization, aggregates, we're going first to create
a temporary object for the aggregate, and then use copy constructor to pass
its value to the final object:

.. code-block:: ada

   C : Child := (new Integer, new Integer);
   --  Tmp : Child;
   --  Child'Constructor (Tmp);
   --  Tmp.A := new Integer;
   --  Tmp.B := new Integer;
   --  Child'Constructor (C, Tmp);
   --  Child'Destructor (Tmp);

Note that we're using a copy constructor here instead of the Clone / Adjust
sequence as there's no initial object to modify here.

Partial Copy and Initialization
-------------------------------

Partial copy in the context of a copy constructor is following the same pattern
as other copy constructor calls, e.g.:


.. code-block:: ada

   C : Child;
   R : Root := Root (Child);
   --  Root'Constructor (R, Root (Child));

In the context of an aggregate by extension that contains a copy, a call to
Clone is necessary, simlar to assignment of the same form:

.. code-block:: ada

   R : Root;
   C : Child := (R with B => new Integer);
   --  Tmp : Child;
   --  Child'Constructor (Tmp);
   --  Root'Clone (R, Tmp);
   --  Tmp.B := new Integer;
   --  Child'Constructor (C, Tmp);
   --  Child'Destructor (Tmp);

Aggregate Aspect
----------------

The presence of constructors, destructors, clone and adjust attributes may
significantly increase the complexity and footprint of assignment and aggregate
usage. The compile may optimize these sequences if it has enough information,
although it's not always clear if it can.

It is possible to specify that a type hierarchy cannot provide any of these
attributes, and therefore instruct the compiler to generate much simpler code.
This can be done through the Aggregate_Type aspect:

.. code-block:: ada

   type Root is tagged record
      A : access Integer;
   end record with Aggregate_Type;

This aspect must be positionned on the root of a tagged type hierarchy.
It forbids the introduction of user defined constructors, destructor, clone and
adjust attributes in derivations. All record components of such types must
also be Aggregate_Type types.

Aggregate_Type types cannot be provided to generic tagged formal parameters, as
the generic instance may extend the type and mistakenly add these attributes
not knowing there are forbidden. However, a generic formal parameter may allow
such types by adding the Aggregate_Type aspect in its definition:

.. code-block:: ada

   generic
      type Root is tagged private with Type_Aggregate;
   package P

      type Child is new Root with null record;

      procedure Child'Constructor (Self : Child); -- Illegal

If the compiler is using a generic expansion model, it is free to optimize code
if the actual is indeed a Type_Aggregate type, and generate the full sequences
in other cases.

Controlled Types
----------------

Controlled types, which includes types derived from Ada.Finalization and types
that are using the Finalizable aspect, are incompatible with constructors,
destructors as well as clone and adjust attributes.

Reference-level explanation
===========================

TBD

Rationale and alternatives
==========================

The current Ada Finalize / Adjust sequence could be an alternative. However, it
doesn't provide sufficient ability to control consistency of the objects. It
forces the target object to be finalized, it never allows to look at both the
source and target value in the same sequence of statement (finalize on the
previous value, adjust on the new value) and it doesn't allow to control
what is copied. On top of that, when doing assignment on partial objects,
Finalize and Adjust are never dispatched to the real value, leaving potential
inconsistencies.

Another approach would have been to introduce some kind of a new assignment
overload similar to C++, for example:


.. code-block:: ada

   type Root is tagged record
      A : access Integer;
   end record;

   procedure ":=" (Self : in out Root; From : in out Root);

   type Child is new Root with record
      B : access Integer;
   end record;

   procedure ":=" (Self : in out Child; From : in out Child);

However, this still doesn't allow control over partial assignment. There's no
simple way to write:

.. code-block:: ada

      C1 : Child;
      C2 : Child;
   begin
      Root (C1) := Root (C2);

And ensure that indeed Root is copied (you'd want to call := on Root) but that
the actual object Child maintains consistency (you'd want to call := on Child).

We looked at various ways to remove the need of temporaries, for example by
introducing special constructors taking aggregate values as paramters. However,
this quickly leads to the need of creating a lot of extra attributes for all
situations. In light of the added complexity, and the fact that we can
provide means to achieve desired optimization when needed, it didn't look like
the right trade-off.

Drawbacks
=========

Prior art
=========

Unresolved questions
====================

Future possibilities
====================

The introduction of borrow-checker capabililites as well as move semantics could
allow to optimize more cases. The various temporaries introduced in the
expansion are short lived and could be moved instead of copied, saving one
copy and one destructor operation.
