- Feature Name: OOP Aggregates and Assignments
- Start Date:
- Status: Ready for prototyping

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
that a given sequence of statements is putting an object in a consistent state
at creation time (unlike traditional constructors).

Second, Adjust performs a post-copy update to a type. This causes a double issue,
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

To solve these issues, we propose to introduce a new mechanism for assignment,
'Assign, called in place of both binary copy and post copy assignment.

Note that this change complexity is also driven from the desire to support
natively Ada constructs (aggregates, partial copies, etc) and improve
compatibility between classes and tagged types. Users can leverage default
implementation if such level of control is unnecessary. Some language extension
may also allow to forbid aggregates and partial update on specific types
(although this introduces complexities in generics that now need to specify
whether these restricted types are allowed or not).

Also keep in mind that Ada Flare aggregates also need to account for types that
have both public and private components.

This RFC cover both simple and tagged records, assumes that constructors will
be provided for simple records.

The additional capabilities need to be optimized as much as possible by the
compiler. In particular - even if it's not a language mandate - the compiler
should replace calls to Assign by binary copies when such optimization is possible.

'Assign
-------

`'Assign` is an overridable attribute called in place of copy where the object to
be assigned has to be modified (i.e. otherwise that's a copy constructor call).
It is different from the legacy Ada Adjust primitive in that it has an argument
referring to the initial value and is expected to perform the actual copy. Note
that the From parameter of `'Assign` is always typed after the root type of the
tagged record hierarchy - indeed, the source object may be higher or lower in
the derivation chain in the case of partial copy. This value is provided for
reference but is not expected to be modified.

.. code-block:: ada

   type Root is tagged record
      A : access Integer;
   end record;

   procedure Root'Assign (Self : in out Root; From : Root'Class);

   type Child is new Root with record
      B : access Integer;
   end record;

   procedure Child'Assign (Self : in out Child; From : Root'Class);

The From parameter refers to the original source object and is passed by
reference; it is not a copy and is not expected to be modified.

Invariants are checked after a call to Assign.

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

   procedure Root'Assign (Self : in out Root; From : Root'Class) is
   begin
      Free (Self.A);
      Self.A := new Integer'(From.A.all);
   end Root'Assign;

   type Child is new Root with record
      B : access Integer;
   end record;

   procedure Child'Constructor (Self : in out Child) is
   begin
      Self.B := new Integer'(0);
   end Child'Constructor;

   procedure Child'Assign (Self : in out Child; From : Root'Class)
   is
   begin
      Self'Super'Assign (From);
      Free (Self.B);

      if From not in Child'Class then
         --  This was a partial assignment, fix the A / B consistency
         Self.B.all := new Integer'(Self.A.all);
      else
         --  We have a from value, re-use it
         Self.B := new Integer'(Child (From).B.all);
      end if;
   end Child'Assign;

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

The simple copy assignment of two objects leads to a simple dispatching call
to 'Assign:

.. code-block:: ada

      R1, R2 : Root;

   begin

      R2 := R1;
      --  R2'Assign (R1); -- dispatch to Root

Partial Copy Assignments
------------------------

Assign is always dispatching, as any other primitive in Flare. So even if
the user is doing a static view conversion, we will dispatch:

.. code-block:: ada

      R1 : Root;
      C1 : Child;

   begin

      Root (C1) := R1;
      --  C1'Assign (R1); -- dispatch to Child

This is also the case where the view conversion is hidden, e.g. in calls:

.. code-block:: ada

      procedure Something (A : in out Root; B : Root) is
      begin
         A := B;
         --  A'Assign (B);  -- dispatch to whatever is the real tag of A
      end Something;

      R1 : Root;
      C1 : Child;

   begin

      Something (Root (C1), R1);

Class-Wide Assignments
----------------------

Class wide assignments lead to dispatching calls to 'Assign, ensuring
that the whole object is copied. They also require the two tags to be equal,
like today in Ada. Unless the type is mutable, in which case we need to call
a destructor / constructor sequence (see later). This is the code for immutable
class wide types:

 .. code-block:: ada

    procedure P (V : in out Root'Class; W : Root'Class) is
    begin
       V := W;
      --  if V'Tag = W'Tag then
      --    V'Assign (W); -- dispatches
      --  else
      --    raise Constraint_Error;
      --  end if;

Aggregate Assignments
---------------------

Aggregates will lead to field by field assignment of a temporary object,
followed by the same call to Assign. Aggregate objects need to
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
      -- C'Assign (Tmp);
      -- Tmp'Destructor;

Note that the compiler is free to optimize the above by directly assigning A and
B if it knows that there's no user defined constructor, destructor or assign attributes:

.. code-block:: ada

      C : Some_Other_Child_With_No_Attributes;

   begin

      C := (new Integer, new Integer);
      -- C.A := new Integer;
      -- C.B := new Integer;

The above works the same in the case of a by extension aggregate if the parent
type is directly referred to. Values taken from the parent object are those
resulting from the constructor call:

.. code-block:: ada

      C : Child;

   begin

      C := (Root with new Integer);
      -- Tmp : Child;
      -- Child'Constructor (Tmp);
      -- Tmp.B := new Integer;
      -- C'Assign (Tmp);
      -- Tmp'Destructor;

A few notes on the above sequences:

- Tmp is itself a full object that we then assign, so we need to ensure its own
  internal consistency and lifecycle, hence the need to call its constructor and
  destructor.
- Usage of aggregate in conjunction with types that provide constructors,
  destructors and assign attributes is somewhat heavy, as the aggregate
  needs to be fully initialized before assigned, then reclaimed. It's important
  to have self consistency here. However, developers may prefer to reserve
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
require an initial assignment of said value, e.g.:

.. code-block:: ada

      R : Root;
      C : Child;

   begin

      C := (R with new Integer);
      -- Tmp : Child;
      -- Child'Constructor (Tmp);
      -- Tmp'Assign (R);
      -- Tmp.B := new Integer;
      -- C'Assign (Tmp);
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
      -- C2'Assign (Tmp);
      -- Tmp'Destructor;

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
      -- C'Assign (Tmp);
      -- Tmp'Destructor;

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

Detection against self assignment is now mandatory, to avoid having users manually
verify it and possibly make mistakes. The compiler is able to optimize self
assignment checks when it is statically known that the two objects are different
(for example, two local variables without address clauses). So the expansion
provided so far is conceptually a shortcut to:

.. code-block:: ada

      R1 : Root;
      R2 : Root;
   begin
      R1 := R2;
      --  if R1'Address /= R2'Address then
      --    R1'Assign (R2);
      --  end if;
      --
      R1 := R1;
      --  if R1'Address /= R1'Address then
      --    R1'Assign (R1);
      --  end if;

Note that this check was already an implementation permission in former versions
of Ada.

Aggregates and Initialization
-----------------------------

In the context of an initialization aggregate, we first create
a temporary object for the aggregate, and then use a copy constructor to pass
its value to the final object:

.. code-block:: ada

   C : Child := (new Integer, new Integer);
   --  Tmp : Child;
   --  Child'Constructor (Tmp);
   --  Tmp.A := new Integer;
   --  Tmp.B := new Integer;
   --  Child'Constructor (C, Tmp);
   --  Tmp'Destructor;

Note that we're using a copy constructor here instead of the Assign
operation as there's no initial object to modify here.  The copy constructor's
profile (its two-parameter form) is specified in the Constructors RFC.  Unlike
Assign, whose ``From`` parameter is typed as the root of the hierarchy, the
copy constructor's ``From`` parameter is typed as the specific type being
constructed, since no partial copy is involved.

Partial Copy and Initialization
-------------------------------

Partial copy in the context of a copy constructor is following the same pattern
as other copy constructor calls, e.g.:


.. code-block:: ada

   C : Child;
   R : Root := Root (C);
   --  Root'Constructor (R, Root (C));

In the context of an aggregate by extension that contains a copy, a call to
Assign is necessary, similar to assignment of the same form:

.. code-block:: ada

   R : Root;
   C : Child := (R with B => new Integer);
   --  Tmp : Child;
   --  Child'Constructor (Tmp);
   --  Tmp'Assign (R);
   --  Tmp.B := new Integer;
   --  Child'Constructor (C, Tmp);
   --  Tmp'Destructor;

Aggregate Aspect
----------------

The presence of constructors, destructors and assign attributes may
significantly increase the complexity and footprint of assignment and aggregate
usage. The compiler may optimize these sequences if it has enough information,
although it's not always clear if it can.

It is possible to specify that a type hierarchy cannot provide any of these
attributes, and therefore instruct the compiler to generate much simpler code.
This can be done through the Aggregate_Type aspect:

.. code-block:: ada

   type Root is tagged record
      A : access Integer;
   end record with Aggregate_Type;

This aspect must be positioned on the root of a tagged type hierarchy.
It forbids the introduction of user defined constructors, destructors and
assign attributes in derivations. All record components of such types must
also be Aggregate_Type types.

Aggregate_Type types cannot be provided to generic tagged formal parameters, as
the generic instance may extend the type and mistakenly add these attributes
not knowing they are forbidden. However, a generic formal parameter may allow
such types by adding the Aggregate_Type aspect in its definition:

.. code-block:: ada

   generic
      type Root is tagged private with Aggregate_Type;
   package P is

      type Child is new Root with null record;

      procedure Child'Constructor (Self : Child); -- Illegal

   end P;

If the compiler is using a generic expansion model, it is free to optimize code
if the actual is indeed an Aggregate_Type type, and generate the full sequences
in other cases.

Controlled Types
----------------

Controlled types, which include types derived from Ada.Finalization and types
that are using the Finalizable aspect, are incompatible with constructors,
destructors as well as assign attributes. Note that controlled type are
deprecated in pedantic Flare.

Raw Assign, Mutable Variadic and Class Wide Types
-------------------------------------------------

There are cases where types can "mutate" - that is to say have different
source and destination constraints or different tag. In these cases,
conceptually, the old object needs to be completely finalized, then the new one
is created through a by-copy constructor. The compiler adds a test on
constraints and will run the destruct then construct by copy sequence if they
differ. Incidentally, mutable types that don't have a by-copy constructor can't
be assigned.

For example, for a simple type:

.. code-block:: ada

      type Rec (V : Boolean := False) is record
         case V is
            when True =>
               A : Integer;

            when False =>
               B : Float;
         end case;
      end record;

      Rec1 : Rec := Rec'(True, 1);
      Rec2 : Rec := Rec'(False, 1);
   begin
      Rec1 := Rec2;    -- (1) Mutating object
      --  if Rec1.V /= Rec2.V then
      --     Rec1'Destructor;
      --     Rec'Constructor (Rec2);
      --  else
      --     Rec1'Assign (Rec2);
      --  end if;

Note that for tagged types, we need some kind of a dispatching creation of
object to be able to run the copy, which is provided by a compiler generated
primitive.

.. code-block:: ada

      type Rec (V : Boolean := False) is record
         case V is
            when True =>
               A : Integer;

            when False =>
               B : Float;
         end case;
      end record;

      type Root is tagged record
         A : Integer;
      end record with Size'Class => 64 * 4;

      type Child is new Root with record
         B : Integer;
      end record;

      C1 : Root'Class := Root'(others => <>);
      C2 : Root'Class := Child'(others => <>);
   begin
      C1 := Root (C2); -- (2) No mutation (C1 is still Root) - calls Assign

      C1 := C2;        -- (3) Mutating object
      --  if C1'Tag /= C2'Tag then
      --    C1'Destructor;
      --    C2.Dispatching_Copy (Rec1);
      --  else
      --    C1'Assign (C2);

Dispatching_Copy (or any compiler internal) conceptually looks like:

.. code-block:: ada

   procedure Dispatching_Copy (Source : Child; Destination : Root'Class) is
   begin
      Child'Constructor (Destination, Source);
      --  This statement isn't completely Flare and needs to be generated by the
      --  compiler, as it should call the whole construction sequence
   end Dispatching_Copy;

Reference-level explanation
===========================

TBD

Rationale and alternatives
==========================

To fully appreciate the needs / usefulness of such construction, one
can consider the following hierarchy:

.. code-block:: ada

   type List is tagged record
      Start_Node, End_Node : access Node;
   end record;

   procedure List'Assign (Self : in out List; From : List'Class);

   type List_With_Stats is new List with record
      Number_Of_Element : Integer := 0;
      Middle_Element : access Node;
   end record;

   procedure List_With_Stats'Assign (Self : in out List_With_Stats; From : List'Class);

   procedure List'Assign (Self : in out List; From : List'Class) is
   begin
      Self.Start_Node := Duplicate (From.Start);
      Self.End_Node := Get_Last (Self.Start_Node);
   end List'Assign;

   procedure List_With_Stats'Assign (Self : in out List_With_Stats; From : List'Class) is
   begin
      Self'Super'Assign (From);

      if From not in List_With_Stats'Class then
         Self.Number_Of_Element := Compute_Number_Of_Element (Self.Start_Node);
      end if;

      Self.Middle_Element := Get_Middle_Element (Self.Start_Node, Self.Number_Of_Element);
   end List_With_Stats'Assign;

Note that the above structure doesn't need to do any shallow copy of Start_Node
and End_Node, only needs to compute number of elements in the partial assign
case, and always requires to re-compute middle element for consistency.

The Assign mechanism's central efficiency advantage over Ada's existing
Finalize / Adjust is that Assign receives both the source object and the
pre-existing target simultaneously.  This allows an Assign implementation to
inspect the target's current state and reuse resources rather than discarding
them: for example, if the target already holds an allocated buffer of the right
size, Assign can overwrite it in place rather than freeing and reallocating.  The
Ada Finalize / Adjust model makes this impossible, because Finalize discards the
target's state before the source is consulted.

Note that the Assign implementations in this document use unconditional
Free / allocate for conciseness.  A production Assign would typically branch on
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


Drawbacks
=========

Prior art
=========

Unresolved questions
====================

Future possibilities
====================

The introduction of borrow-checker capabilities as well as move semantics could
allow to optimize more cases. The various temporaries introduced in the
expansion are short lived and could be moved instead of copied, saving one
copy and one destructor operation.
