- Feature Name:
- Start Date:
- RFC PR:
- RFC Issue:

Summary
=======

Motivation
==========

Constructors have been added to tagged and class types in Flare. They also need
to be added to regular record types, as we need to promote non OOP usage when
necessary and useful. However, non-tagged types introduce a different kind of
derivation that needs to be described in its own right. Another issue relates
to by-copy vs. by-reference parameter passing: we need to ensure that
constructors (and in particular the copy constructor) are properly described
here.

This proposal also describes the behavior of 'Assign and 'Destructor, as well
as the interaction of these operations with aggregates.

A guiding principle of this proposal is that non-tagged types provide the very
same lifecycle guarantees as class types: whatever the derivation, and whatever
the notation used to create a value (constructor call, aggregate, delta
aggregate), it is not possible to obtain an object of a derived type whose
parent part has not been built by one of the constructors that the designer of
the parent type has provided. Simple derivation is not a way to opt out of the
parent's invariants.

Guide-level explanation
=======================

Constructors
------------

Constructors can be provided to non-tagged non-class types with the same
syntax as class types, by adding a constructor in their scope, e.g.:

.. code-block:: ada

   type B is record

      F : Integer;

      procedure B'Constructor (Self : in out B; V : Integer);

   end B;

Constructors can then be implemented as other scoped primitives:

.. code-block:: ada

   type body B is

      procedure B'Constructor (Self : in out B; V : Integer) is
      begin
         Self.F := V;
      end B'Constructor;

   end B;

Rules on initialization lists, component initialization, discriminant
valuation, default constructors, constructor removal and constructor calls are
all the same as for tagged constructors. In particular, a constructor of a
derived type always calls a constructor of its parent type, through the
``Super`` aspect, exactly as in the tagged case - see `Simple Derivation`_.

Assign
------

'Assign is provided for record types similar to tagged types. It is called
in place of copy where the object to be assigned has to be modified (i.e.,
otherwise that's a copy constructor call), and is expected to perform the
actual copy. The From parameter refers to the original source object, is
passed by reference, and is not expected to be modified. As for tagged
types, From is typed after the root type of the derivation chain, so that
conversions can be handled. However, as calls are static, the compiler is
expected to optimize the calls when necessary, in particular replacing them
by binary copies when possible. E.g.:

.. code-block:: ada

   type Root is record
      procedure Root'Assign (Self : in out Root; From : Root);
   end Root;

   type Child is new Root with record
      procedure Child'Assign (Self : in out Child; From : Root);
   end Child;

   V : Root;
   W : Child;

   W := Child (V); -- calls Assign on Child, statically resolved.

Unlike constructors and destructors, 'Assign is not implicitly chained to the
parent's one: it is a whole-object operation, and the derived type may need to
reorganize the target as a whole. However, an 'Assign declared on a derived
type is responsible for the parent part as well, and in the general case it
cannot copy it itself (the parent's state may be private, or may need
allocations of its own). It therefore delegates that part through 'Super,
which provides the static view of the object typed after the parent:

.. code-block:: ada

   type body Child is

      procedure Child'Assign (Self : in out Child; From : Root) is
      begin
         Self'Super'Assign (From); -- copy the Root part the way Root wants it
         --  then whatever this type needs to re-establish
      end Child'Assign;

   end Child;

Note that, as for all non-tagged operations, this call is static: there is no
dispatching involved, and the compiler is expected to inline or to replace the
whole sequence by a binary copy when it can establish that this is equivalent.

Assign and Mutable Discriminants
--------------------------------

There is one case where an assignment does not lead to a call to 'Assign:
mutable objects, i.e. objects whose discriminants have default values and
may change through assignment. When the source and the target of an
assignment have different discriminant values, the target cannot be
modified in place by 'Assign: it first needs to be destroyed, then
re-created with the new constraints. The compiler inserts a check on the
discriminants and expands the assignment into a call to 'Destructor
followed by a call to the by-copy constructor when they differ. E.g.:

.. code-block:: ada

   type Rec (V : Boolean := False) is record

      case V is
         when True =>
            A : Integer;

         when False =>
            B : Float;
      end case;

      procedure Rec'Constructor (Self : in out Rec; From : Rec);
      procedure Rec'Destructor (Self : in out Rec);
      procedure Rec'Assign (Self : in out Rec; From : Rec);

   end Rec;

   R1 : Rec := Rec'(V => True, A => 1);
   R2 : Rec := Rec'(V => False, B => 1.0);

begin

   R1 := R2;
   --  if R1.V /= R2.V then
   --     R1'Destructor;
   --     Rec'Constructor (R1, R2);
   --  else
   --     R1'Assign (R2);
   --  end if;

As a consequence, a mutable type that does not provide a by-copy
constructor cannot be assigned.

Note that this issue is specific to non-tagged types: class records with
defaulted discriminants do not exist, so the discriminants of a class
object can never change through an assignment.

Destructors
-----------

Destructors can be provided to non-tagged non-class types with the same
syntax as class types, e.g.:

.. code-block:: ada

   type B is record

      F : access Integer;

      procedure B'Destructor (Self : in out B);

   end B;

As for tagged types, the destructor is called when the object reaches the
end of its lifetime. It may also be called as part of an assignment that
changes the constraints of a mutable object, prior to the by-copy
construction of the new value, as described in the OOP aggregates and
assignments RFC. As for other non-tagged operations, calls are static and
the compiler is expected to optimize them when possible.

On simple derivation, the destructor is inherited by the derived type, which
may declare its own. Consistent with constructors, and identically to the
tagged case, the parent destructor is not bypassed: it is implicitly called
after the destructor of the derived type has completed. The destruction
sequence of a derived object is therefore:

- the destructor of the derived type, if any,
- the destructors of the components, in reverse order of construction,
- the destruction sequence of the parent type.

There is no notation to skip the parent destructor: just as a derived
constructor cannot create an object without the parent constructing its own
state, a derived destructor cannot leave the parent's state unreclaimed. E.g.:

.. code-block:: ada

   type Root is record

      A : access Integer;

      procedure Root'Constructor (Self : in out Root);
      procedure Root'Destructor (Self : in out Root);

   end Root;

   type Child is new Root with record
      procedure Child'Destructor (Self : in out Child);
   end Child;

   type body Child is

      procedure Child'Destructor (Self : in out Child) is
      begin
         --  Only deals with what this type is responsible for. Root'Destructor
         --  is called afterwards, implicitly, and frees Self.A.
         Log ("destroying a Child");
      end Child'Destructor;

   end Child;

Simple Derivation
-----------------

When performing simple derivation, derived types "inherit" all constructors of
the parent type. They may add their own, and remove inherited ones by declaring
them ``is abstract``.

Crucially, a constructor of a derived type does **not** replace the parent's
construction: the same rules as tagged derivation apply. Every constructor of a
derived type calls a constructor of its parent type. That call is:

- by default, the parameterless constructor of the parent type,
- or the parent constructor designated by the ``Super`` aspect,
- or, for a by-copy constructor with no explicit ``Super`` aspect, the by-copy
  constructor of the parent type applied to the parent view of the source.

If the parent type has no parameterless constructor, then a ``Super`` aspect is
mandatory on every constructor of the derived type; omitting it is a
compilation error. There is no notation allowing the derived type to construct
its parent part by itself: the guarantee that the designer of the parent type
retains control over the initial state of every object of the derivation chain
is identical to the one provided by class types.

Since simple derivation can neither add components nor add discriminants, a
derived constructor has nothing of its own to valuate: its initialization list
is necessarily empty, and all component and discriminant valuation happens in
the parent constructor selected by ``Super``. The body of the derived
constructor may then further modify the (inherited) components, as it operates
on an object that is already initialized.

For example:

.. code-block:: ada

   type Root is record

      F : Integer;

      procedure Root'Constructor (Self : in out Root; V : Integer);
      procedure Root'Constructor (Self : in out Root; V : String);

   end Root;

   type Child is new Root with record
      --  This cannot add components, only primitives and constructors / destructors

      procedure Child'Constructor (Self : in out Child; V : Integer) is abstract; -- removing constructor
      procedure Child'Constructor (Self : in out Child; V : Float);
   end Child;

   type body Child is

      procedure Child'Constructor (Self : in out Child; V : Float)
         with Super => (Integer (V))
         --  Mandatory here: Root has no parameterless constructor. This
         --  selects Root'Constructor (Self : in out Root; V : Integer).
      is
      begin
         --  At this point, the Root part is fully constructed, so Self.F has
         --  the value that Root'Constructor gave it, and can be refined.
         Self.F := Self.F + 1;
      end Child'Constructor;

   end Child;

The following calls are then obtained, all of them going through one of the
constructors declared by Root:

.. code-block:: ada

   R1 : Root := Root'Make (1);     -- legal, Root'Constructor (R1, 1)
   R2 : Root := Root'Make ("1");   -- legal, Root'Constructor (R2, "1")

   C1 : Child := Child'Make (1.0);
   --  legal:
   --    Root'Constructor (Root (C1), 1);  --  from the Super aspect
   --    Child'Constructor (C1, 1.0);      --  the body above

   C2 : Child := Child'Make (1);   -- illegal, removed from Child's view

   C3 : Child := Child'Make ("1");
   --  legal, inherited constructor:
   --    Root'Constructor (Root (C3), "1");

   C4 : Child;                     -- illegal, no parameterless constructor

Note that removing a constructor with ``is abstract`` only removes it from the
'Make of the derived type. It does not remove it from the parent type, so it
remains available to the ``Super`` aspect of a constructor of the derived type -
a removal is a restriction on the users of the derived type, not a way of
disabling part of the parent's construction. For instance, Child above could
still have been written:

.. code-block:: ada

   procedure Child'Constructor (Self : in out Child; V : Float)
      with Super => (Integer (V)) -- still legal, even though Child'Make (1) is not
   is
   begin
      null;
   end Child'Constructor;

The same reasoning applies to the by-copy constructor, whose implicit version
on the derived type calls the by-copy constructor of the parent type, then
copies nothing else (there is nothing else to copy on simple derivation). A
derived type that declares its own by-copy constructor selects the parent's one
in the usual way:

.. code-block:: ada

   type Child is new Root with record
      procedure Child'Constructor (Self : in out Child; From : Child);
   end Child;

   type body Child is

      procedure Child'Constructor (Self : in out Child; From : Child)
         with Super => (Root (From)) -- the parent by-copy constructor
      is
      begin
         null;
      end Child'Constructor;

   end Child;

Aggregates
----------

Aggregates on non-tagged types behave exactly as described in the OOP
aggregates and assignments RFC for tagged types: an aggregate is not a way to
build an object behind the back of its constructors. It is a constructor call
followed by modifications of the resulting object. The type must therefore
provide a parameterless constructor visible at the point of the aggregate, and
the aggregate is equivalent to 'Make followed by component updates.

In an assignment context, the aggregate builds a temporary, which is then
assigned to the target with 'Assign, and finally destroyed:

.. code-block:: ada

   type Rec is record

      A, B : access Integer;

      procedure Rec'Constructor (Self : in out Rec);
      procedure Rec'Destructor (Self : in out Rec);
      procedure Rec'Assign (Self : in out Rec; From : Rec);

   end Rec;

   R : Rec;

begin

   R := (new Integer, new Integer);
   --  Tmp : Rec := Rec'Make;   --  the parameterless constructor runs first
   --  Tmp.A := new Integer;
   --  Tmp.B := new Integer;
   --  Rec'Assign (R, Tmp);
   --  Rec'Destructor (Tmp);

In an initialization context, there is no target to modify, so the by-copy
constructor is used instead of 'Assign:

.. code-block:: ada

   R : Rec := (new Integer, new Integer);
   --  Tmp : Rec := Rec'Make;
   --  Tmp.A := new Integer;
   --  Tmp.B := new Integer;
   --  Rec'Constructor (R, Tmp);  --  by-copy constructor
   --  Rec'Destructor (Tmp);

Components left to their default value with the ``=> <>`` notation simply keep
the value given by the constructor, which is another way of seeing that the
constructor is what establishes the initial state:

.. code-block:: ada

   R := (A => new Integer, others => <>);
   --  Tmp : Rec := Rec'Make;
   --  Tmp.A := new Integer;   --  Tmp.B keeps what Rec'Constructor set
   --  Rec'Assign (R, Tmp);
   --  Rec'Destructor (Tmp);

A delta aggregate starts from a copy of its source, hence from the by-copy
constructor:

.. code-block:: ada

   R2 := (R1 with delta B => new Integer);
   --  Tmp : Rec := Rec'Make (R1);  --  by-copy constructor
   --  Tmp.B := new Integer;
   --  Rec'Assign (R2, Tmp);
   --  Rec'Destructor (Tmp);

On a derived type, the constructor called to build the temporary is the
parameterless constructor of the derived type, which - as described in
`Simple Derivation`_ - starts by calling a constructor of the parent type.
Consequently, an aggregate of a derived type cannot bypass the parent
constructors either:

.. code-block:: ada

   type Child is new Rec with record
      procedure Child'Constructor (Self : in out Child);
   end Child;

   C : Child;

begin

   C := (new Integer, new Integer);
   --  Tmp : Child := Child'Make;
   --    -- which is: Rec'Constructor (Rec (Tmp)); Child'Constructor (Tmp);
   --  Tmp.A := new Integer;
   --  Tmp.B := new Integer;
   --  Child'Assign (C, Tmp);
   --  Child'Destructor (Tmp); -- then, implicitly, Rec'Destructor

As a consequence, a type that has constructors but no parameterless one cannot
be built by an aggregate. As for tagged types, the compiler is free to optimize
these sequences, and in particular to assign the components directly when the
type provides no user-defined constructor, destructor or 'Assign:

.. code-block:: ada

   type Plain is record
      A, B : access Integer;
   end record;

   P : Plain;

begin

   P := (new Integer, new Integer);
   --  P.A := new Integer;
   --  P.B := new Integer;

Component Sections and Scoped Primitives
----------------------------------------

The component modifications introduced for class records are equally available
to simple records. Namely, a record type may have components both in the public
and in the private view of its package (the ``with private`` notation), and it
may also split its components between a type-public and a type-private section
within the record itself, the way a protected type does:

.. code-block:: ada

   package P is

      type R is record
         Pub : Integer;
      private
         Pub_Hidden : Integer;
      end record
      with private; -- there are more components in the private view

   private

      type R is record
         Priv : Integer;
      private
         Priv_Hidden : Integer;
      end record;

   end P;

The visibility rules are the ones described in the corresponding RFCs, and are
not changed by the presence of constructors, destructors or 'Assign. Note that
these sections are one of the main reasons why the lifecycle rules above have
to be enforced: a derived type has no way of building or reclaiming components
it cannot even see.

Similarly, primitives may be scoped, i.e. declared within the scope of the
record type and implemented in its ``type body``, and constructors,
destructors and 'Assign are declared this way in all the examples of this
document:

.. code-block:: ada

   package P is

      type R is record
         F : Integer;

         procedure Prim (Self : in out R; V : Integer);

         procedure R'Constructor (Self : in out R; V : Integer);
      end R;

      procedure Also_A_Prim (Self : in out R; V : Integer);
      --  legal on a simple record, and still a primitive of R

   end P;

However, unlike for class records, we are not suggesting here that primitives
have to be declared within the scope of the record. A simple record may declare
primitives outside of that scope - in particular in the public part of the
package, as ``Also_A_Prim`` above - and such subprograms remain primitives of
the type. In the same vein, the other rules that class records imply are not
enforced on simple records: notably, primitives are not required to follow the
rules of First_Controlling_Parameter. Simple records remain regular Ada record
types, to which the lifecycle operations described in this document are added.

Parameter Passing
-----------------

Parameters can be passed by reference or by copy as long as the record type
does not provide any by-copy constructor. If a by-copy constructor is provided,
then the compiler must pass any object as a reference, similar to tagged or
limited types. E.g.:

.. code-block:: ada

   type A is record

      F : Integer;

      procedure A'Constructor (Self : in out A);
   end A;

   type B is record
      procedure B'Constructor (Self : in out B; From : B);
   end B;

   procedure P1 (V : in out A); -- V may be passed by copy or reference
   procedure P2 (V : in out B); -- V has to be passed by reference

Reference-level explanation
===========================

Rationale and alternatives
==========================

Why enforce the parent construction on simple derivation?
---------------------------------------------------------

One could argue that, since simple derivation cannot add components, an
operation declared on the derived type "can do the whole job" and could
therefore replace the parent's one. This is not true for the purpose that
matters: the components of the parent may well be private, and even when they
are visible, the way the parent establishes and reclaims its state
(allocations, registration in an external structure, invariants between
components) is the parent's business.
Allowing a derived type to construct its parent part directly would make simple
derivation a supported way of bypassing the constructors that the designer of
the base type has provided, i.e. exactly the hole that constructors are meant
to close, and one that would be reachable simply by deriving a type.

We therefore align non-tagged derivation with class derivation: the parent
constructor is always called (implicitly, or as designated by ``Super``), and
the parent destructor is always called. The only difference remaining is the
absence of dispatching: all these calls are statically resolved, which is
precisely the reason to use a non-tagged type in the first place.

Why record in addition to tagged/class records?
-----------------------------------------------

Support for regular records in addition to class and tagged records adds some
level of complexity in the language that in some respects could be avoided.
However, these types are much more effective at run-time as they don't require
dispatching, and the compiler may be able to optimize calls more effectively.
They should be favored whenever inheritance is not necessary, and they are as
flexible as tagged/class types for most lifetime operations.

Drawbacks
=========

Prior art
=========

Unresolved questions
====================

Future possibilities
====================


