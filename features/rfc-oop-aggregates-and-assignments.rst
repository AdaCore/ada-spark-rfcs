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
such level of control is unnecessary. Some language extensions may also allow
to forbid aggregates and partial update on specific types (although this
introduces complexities in generics that now need to specify whether these
restricted types are allowed or not).

Also keep in mind that Ada Flare aggregates also need to account for types that
have both public and private components.

This RFC is about tagged records (and class records even if not explicitly
mentioned). Simple records should also be studied when constructors are made
available to them.

The additional capabilities need to be optimized as much as possible by the
compiler. In particular - even if it's not a language mandate - the compiler
should replace calls to Clone by binary copies and remove calls to Adjust when
it knows there's no chance of calling an overridden subprogram.

'Clone
------

The attribute 'Clone can be defined for each tagged type. It describes how to
copy (or clone) the value of a tagged type into a other one. For example:

.. code-block:: ada

   type Root is tagged record
      A : access Integer;
   end record;

   procedure Root'Clone (Self : Root; To : in out Root);

Root'Clone is not a primitive and cannot be inherited or overridden by
derivation.  (See the "Clone and Adjust as Primitives" section below for the
reason Clone is non-primitive while Adjust is primitive.)

A derived type may provide its own Clone:

.. code-block:: ada

   type Child is new Root with record
      B : access Integer;
   end record;

   procedure Child'Clone (Self : Child; To : in out Child);

The default implementation of Clone for a constructor type calls the parent
type's Clone on the parent portion of the object, then for each component in
declaration order: if the component's type is a constructor type with a
user-defined Clone, that Clone is called; otherwise the component is copied
bit-for-bit.  Types that are not constructor types (Integer, access types, and
so on) are always copied bit-for-bit; Clone is not user-specifiable for them.
The compiler is free to optimize the entire default sequence to a single
bitwise copy whenever it can determine that no user-defined Clone is reachable.

Calls to 'Clone are statically resolved when used on definite views, and
dynamically resolved on 'Class wide type. This is arguably a departure from the
"all calls are dispatching" requirement from other aspects of the OOP design,
but is required to allow partial copies of objects which are done today in
various places in Ada.

The invariant of the target object is not checked after a call to Clone, some
parts may still be inconsistent and fixed later by Adjust.

'Adjust
-------

'Adjust is an overridable attribute called after certain operations. It is
different from the legacy Ada Adjust primitive in that it has an argument
referring to the initial value. Note that the From parameter of Adjust is
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
   begin
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

When reasoning about this interface, note that the aggregate expansion calls
the parameterless constructor on ``Tmp`` before overwriting individual fields.
If the constructor pre-allocates a resource for a field that the aggregate
then replaces, the constructor's allocation is leaked.  For types intended to
be used with aggregates, the recommended pattern is for the constructor to
leave fields that will always be supplied by the aggregate in a trivially
destructible initial state (typically null), and to pre-allocate only those
resources that the aggregate cannot supply.  The ``Child'Destructor (Tmp)``
call at the end of the expansion releases whatever state ``Tmp`` holds after
field assignment, so the final result is leak-free provided the constructor
follows this pattern.

Generally speaking, this proposal provides the tools to develop types that
remain safe and consistent, in contrast to the previous model which offered
shortcuts that undermined that goal.

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
      --    raise Constraint_Error;
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

In the expansion pseudocode throughout this section, a bare declaration
``Tmp : Child;`` denotes a compiler-introduced raw object: no implicit
constructor call is made for the declaration itself, and the object's storage
is indeterminate until the expansion's explicit constructor call initialises
it.  This exemption is necessary to avoid infinite regress: if the declaration
of a compiler temporary for an aggregate triggered the aggregate expansion
recursively, the expansion would not terminate.  The expansion always
provides an explicit constructor call immediately following such a declaration.
Similarly, in the delta aggregate expansion, the notation
``Child'Constructor (Tmp, C1)`` is the explicit copy-constructor call that
initialises ``Tmp`` from ``C1``; it does not trigger a further assignment
expansion.

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
      -- Tmp : Child;
      -- Child'Constructor (Tmp, C1);
      -- Tmp.B := new Integer;
      -- Child'Clone (Tmp, C2);
      -- Child'Adjust (C2, Tmp);
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

The ``with private`` record syntax (see the OOP Fields RFC) allows a type to
declare some components in its public view and additional components visible
only in its private view.  When writing an aggregate for such a type without
full visibility of all components, the caller must include the keyword
``private`` as the final item in the aggregate to indicate that the hidden
components are not being given explicit values, e.g.:

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

For constructor types, the private components are left in whatever state the
parameterless constructor has established.  For non-constructor types, every
private component must have a default expression; an aggregate with ``private``
is otherwise illegal.

The keyword ``private`` in aggregate position is contextual: it is treated as a
keyword only when it is the final element of an aggregate expression.  Its
presence is mandatory when the aggregate type has components not visible at the
point of the aggregate; it is a compile-time error when full visibility is
available.  This is distinct from ``others => <>``, which requests default
values for otherwise-visible components; ``private`` stands for components that
are entirely outside the caller's view.

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
sequence as there's no initial object to modify here.  The copy constructor's
profile (its two-parameter form) is specified in the Constructors RFC.  Unlike
Adjust, whose ``From`` parameter is typed as the root of the hierarchy, the
copy constructor's ``From`` parameter is typed as the specific type being
constructed, since no partial copy is involved.  When called for aggregate
initialization, ``Self`` is in default-constructed state: the parameterless
constructor has already been run on it before the copy constructor is invoked.

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

Clone and Adjust as Primitives
-------------------------------

Clone is statically dispatched: each call selects the Clone of the static
(view) type, not the tag.  This is intentional and is what allows partial
copies to copy only the components of the view the caller names.  Because Clone
must be statically selected, it is a non-primitive operation.

Adjust is dynamically dispatched: it is called with the actual tag of the
object being updated, so that the object can restore its own invariants
regardless of which partial view was cloned.  Because Adjust must dispatch on
the tag, it is a primitive operation and follows the rules of
First_Controlling_Parameter (its first parameter is ``Self : in out T``).

This combination -- static Clone, dispatching Adjust -- means a partial copy
such as ``Root (C) := R`` will clone only the Root fields but will give Child's
Adjust full visibility of the result, allowing Child to fix any
inconsistencies introduced by the partial clone.

Discriminant Handling
---------------------

The Clone and Adjust mechanism interacts with discriminants in two ways.

If the target of a Clone call is constrained (``To'Constrained`` is ``True``),
the compiler inserts a runtime check that ``Self`` and ``To`` have identical
discriminant values before invoking Clone; if they differ, ``Constraint_Error``
is raised.  This check cannot in general be resolved at compile time: a
parameter whose subtype is an unconstrained-but-definite discriminated type may
refer at runtime to either a constrained or an unconstrained object, so the
check is guarded by ``To'Constrained``.

If the target is unconstrained, a strategy of reshaping the target before
cloning would silently discard its existing state, destroying Clone's efficiency
advantage.  To avoid this situation, constructor types are prohibited from
declaring default discriminant values.  This ensures that every object of a
constructor type is effectively constrained from creation, so the
unconstrained-target case never arises.

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
      type Root is tagged private with Aggregate_Type;
   package P

      type Child is new Root with null record;

      procedure Child'Constructor (Self : Child); -- Illegal

If the compiler is using a generic expansion model, it is free to optimize code
if the actual is indeed an Aggregate_Type type, and generate the full sequences
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

The Clone / Adjust mechanism's central efficiency advantage over Ada's existing
Finalize / Adjust is that Clone receives both the source object and the
pre-existing target simultaneously.  This allows a Clone implementation to
inspect the target's current state and reuse resources rather than discarding
them: for example, if the target already holds an allocated buffer of the right
size, Clone can overwrite it in place rather than freeing and reallocating.  The
Ada Finalize / Adjust model makes this impossible, because Finalize discards the
target's state before the source is consulted.

Note that the Clone implementations in this document use unconditional
Free / allocate for conciseness.  A production Clone would typically branch on
whether existing allocations can be reused, which is the intended use of the
pattern.

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
