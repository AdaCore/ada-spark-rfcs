- Feature Name: Structural generic instantiation
- Start Date: 2023-03-03
- Status: Production

Summary
=======

This RFC proposes to allow "structural" instantiation of generics, that is to
be able to reference an implicit instance of a generic, that is denoted only by
its actual parameters, rather than by its name.

Motivation
==========

The expected benefits of this feature are:

1. Expressivity. Combined with other features that can be found in the [meta
   RFC](../meta/rfc-improved-generic-instantiations.md), we hope to make
   generic subprograms much more usable, and unblock potential use cases that
   would otherwise require language support to be expressive (Ada 2022's
   `Reduce` comes to mind).

2. Be able to refer to a "unique", structural instance of a generic. For
   example there will be a unique instance of `Ada.Containers.Vectors
   (Positive, Positive)`, and all people refering to it will refer to the same
   instance, which solves a long standing problem in generics, which is the
   ability to structurally reference unique entities.

See the high level RFC for examples.

Guide-level explanation
=======================

You can structurally refer to an implicit instantiation of a generic by naming
it. The (tentative) syntax for naming it is the following:

```ada
Ada.Unchecked_Deallocation [Integer, Integer_Access] (My_Int_Access);
```

By naming the generic, it will be implicitly instantiated, a key point being
that there is only one generic corresponding to `Ada.Unchecked_Deallocation
[Integer, Integer_Access]` at a high level, and every reference to it
references the same entity.

> *Note*
>
> It's not clear that we can actually guarantee that it will be compiled only
> once with a separate compilation model, which is why it is not mentioned
> above, but the goal is clearly to ensure that when possible, and when it's
> not, to minimize the number of instances actually generated.

This syntax does also allow naming parameters:

```ada
Ada.Unchecked_Deallocation [Object => Integer, Name => Integer_Access] (My_Int_Access);

Ada.Unchecked_Deallocation [Name => Integer_Access] (My_Int_Access);
--  NOTE: This relies on parameter inference
```

and empty parameter lists:

```ada
generic procedure Foo (A : Integer) is null;

Foo [] (12);

Ada.Unchecked_Deallocation [] (My_Int_Access);
--  NOTE: This relies on inference from name & type resolution context
```

> [!NOTE]
>
> Do we want to allow `Ada.Unchecked_Deallocation (My_Int_Access)` - so,
> without any explicit syntactic instantiation indication ? Seems nifty and
> possible, but maybe too implicit.

Any generic can be instantiated, be it a package, procedure or function:

```ada
A : Ada.Containers.Vectors [Positive, Positive].Vector;
```

This allows generalized structural typing in Ada, and fixes a long standing
problem regarding generic types and modularity:

```ada
generic
    type Element_Type is private;
package Consume_Elements is
    package Elements_Vectors is new Ada.Containers.Vectors (Positive, Element_Type);

    procedure Consume_Elements (Elements : Elements_Vectors.Vector);
end Consume_Elements;

--  In another package/library

generic
    type Element_Type is private;
package Produce_Elements is
    package Elements_Vectors is Ada.Containers.Vectors (Positive, Element_Type);

    function Produce_Elements return Elements_Vectors.Vector;
end Produce_Elements;

--  No solution to use vectors produced by Produce_Elements.Produce_Elements in
--  Consume_Elements.Consume_Elements (appart from unchecked conversion).
```

There is a convoluted solution using generic formal packages, that is far from
ideal:

```ada
generic
    type Element_Type is private;
    with package Elements_Vectors is new Ada.Containers.Vectors (Positive, Element_Type);
procedure Consume_Elements (Elements : Elements_Vectors.Vector);

--  In another package/library

generic
    type Element_Type is private;
    with package Elements_Vectors is new Ada.Containers.Vectors (Positive, Element_Type);
function Produce_Elements return Elements_Vectors.Vector;

package Positive_Vectors is new Ada.Containers.Vectors (Positive, Positive);
function Produce_Positives is new Produce_Elements (Positive, Positive_Vectors);
procedure Consume_Positives is new Consume_Elements (Positive, Positive_Vectors);

Consume_Positives (Produce_Positives);
```

This solution is far from ideal, mainly because of its verbosity. It forces
instantiators to instantiate the generic themselves even in the (probable)
majority of cases where this modularity isn't needed. The consequence is that,
in practice, most generic code in Ada is not made to be modular.

Consider the solution with structural instantiations:

```ada
generic
    type Element_Type is private;
procedure Consume_Elements (Elements : Ada.Containers.Vectors [Positive, Element_Type].Vector);

--  In another package/library

generic
    type Element_Type is private;
function Produce_Elements return Ada.Containers.Vectors [Positive, Element_Type].Vector;

Consume_Elements [Positive] (Produce_Elements [Positive]);
```

Reference-level explanation
===========================

This is clearly not complete, we expect this draft to be completed during
prototyping.

### Syntax changes

Add the following syntax rule:

```
structural_generic_instantiation_reference ::=
    name [generic_actual_part]
```

And alter the `name` rule to include `structural_generic_instantiation_reference`

### Semantic changes

* Each `structural_generic_instantiation_reference` references a structural
  generic instantiation.

* This structural generic instantiation is semantically unique, and refers to a
  unique code entity. All references refer to the same instantiation.

* As soon as there exists one reference to a given structural instantiation,
  then it will be instantiated.

* All three kinds of generics can be instantiated, be it a package, procedure
  or function. A `structural_generic_instantiation_reference` will be
  syntactically valid in any context where a name is valid, and semantically
  valid in any context where a reference to the instantiated entity (subprogram
  or package) is valid.

* For the moment, in order to be able to impose restrictions on the generic
  code that can be compilable this way, generics that are instantiable
  structurally need to be explicitly marked with the
  `Allow_Structural_Instantiation` aspect:

```ada
generic
   type T is private;
package F
    with Allow_Structural_Instantiation
is
   ...
end F;
```

* Generics annotated with the `Allow_Structural_Instantiation` aspect are
  forbidden to have:

  - Mutable global state - TODO refine
  - Non in object formals

* Additionally, instantiations of those generics can only pass static expressions
  for object formals.

* Generics annotated with the `Allow_Structural_Instantiation` are forbidden to
  have no generic formals.

* Generics annotated with the `Allow_Structural_Instantiation` cannot be
  library-level descendants of library level generic packages.

> [!NOTE]
> This restriction solely exists because GNAT already handle library level
> generic packages badly according to Steve, and we can't see compelling use
> cases.

* The instantiation denoted by a `structural_generic_instantiation_reference`
  is considered to be expansed in the topmost scope where it is legal to hoist
  it. Its accessibility level is deduced from this.

* For the moment, if there is no legal syntactic declarative region in which
  the equivalent explicit instantiation could live, then the instantiation is
  forbidden:

```ada
function Expr_Func (N : Natural) is
    (Some_Generic(N).Some_Function); -- ILLEGAL
```

> [!NOTE]
> This does not appear necessary, and is more dependent on implementation
> details than anything else in my opinion. But it might facilitate
> implementation in a first step.

Implementation guidance
=======================

## Compilation model

The main challenge is to guarantee the unicity of the emitted code, both for
code-bloat and semantic reasons.

We distinguish two cases:

1. Instantiations which can be unnested up to the library level, such as:

```ada
package P is
    T : Vectors [Positive, Positive].Vector; -- Library-level

    function Foo return Positive;
end P;

package body P is
    function Foo return Positive is
        T : Vectors [Positive, Positive].Vector -- Local, but only depends on library-level entities
    begin
        ...
    end Foo;
end P;
```

2. Instantiations which are inherently local such as

```ada
    function Foo return Positive is
        type P is new Positive;
        T : Vectors [P, P].Vector -- Local
    begin
        ...
    end Foo;
```

### Toplevel instantiations

We want to follow the C++ compilation model, where the code for a specific
generic instantiation is emitted in every compilation unit it is used, and then
de-duplicated at link time.

#### Unique symbol name for the toplevel entity

For this, the symbols emitted for a given top-level instantiation needs to be
exactly the same. We thus need to name the emitted monomorphized generic
according to a naming scheme that guarantees that a given structurally
instantiated generic always has the same name.

For top-level generics, this is luckily quite easy to guarantee: At a high
level, we want the name of the instantiated generic to be a combination of the
fully qualified name of every formal, + the qualified name of the generic.

In the case of the toplevel `Vectors [Positive, Positive].Vector` above, the
name could be something like:

`Ada_Containers_Vectors_Positive_Positive` (We don't include `Standard` because
the names are going to be pretty-long already)

> [!IMPORTANT]
> Unlike traditional explicitly instantiated Ada generics, the name **will not
> contain** the name of the containing library-level unit, by design.

#### Deduplicate multiple local instances

During compilation, we keep a set of those names, for the generics we have
already instantiated as part of the currently compiled compilation unit. If we
come across a generic twice (which is very likely), we don't emit it a second
time.

> [!NOTE]
> For symbol names internal to the instantiated generic, we presumably
> don't need to change the naming scheme.
> It's enough that the compiler is idempotent, ie that it will generate the
> same symbol names twice accross compilations, which is already the case
> AFAICT.

#### Linker machinery

The symbols emitted as part of the instantiated generic need to be marked as
`weak`, so that only one instance is kept at link-time.

### Local instantiations

Local instantiations by definition cannot be shared accross compilation units,
because they depend on local entities that are not globally visible. Thus, we
do not need to devise a scheme to share their code accross compilations.

We then just need a set of locally already compiled structural generics, so
that we emit each one only once.

## Shared libraries

There are some cases where the code potentially cannot be de-duplicated,
particularly where objects are linked together at run-time via dynamic linking.
In those cases, two concurrent implementations will potentially be used
concurrently in the same executable. We then need to make sure that either the
two implementations are compatible and their interaction produce consistent
results, either those use cases are forbidden.

> [!IMPORTANT]
> It looks from what is achieved in C++, that, at least on certain platforms,
> de-duplicating in every case is possible. See for example
> https://stackoverflow.com/questions/4924082/static-template-data-members-storage
>
> It means that every potential problem that Steve raised (address of
> operators, tags) could potentially be solved this way. Remains to see how
> easy it is/whether this is what we want to do.
>
> It also means that the restrictions we want to impose on global state could
> probably be relaxed if we follow this implementation model.

Examples of this problem:

### Tags

```ada
    p1.ads
    subtype S1 is Some_Generic (Integer, "+").Some_Tagged_Type;

    p2.ads
    subtype S2 is Some_Generic (Integer, "+").Some_Tagged_Type;

    p3.ads
    Flag : Boolean := S1'Tag = S2'Tag;
```

In this case we have two possible work-arounds:

* The first is to not rely on tags being exactly the same for the above to
  work: abstracting the tag and overloadng tag equality, and then generate a
  unique identifier for the tag, that is used by the equality function.

* The second is to manage to always use only one copy of the code at runtime,
  by emitting the proper code with the proper link attributes.

### Addresses for shared entities (constants, functions, etc)

```ada
     type Ref is access procedure;
     Ptr1 : Ref := Some_Generic (Integer, "+").Proc'Access;
     Ptr2 : Ref := Some_Generic (Integer, "+").Proc'Access;
     Flag : Boolean := Ptr1 = Ptr2;
```

As said above, managing to always use the same symbol, via linker attributes,
would be the only solution to guarantee that this works.

However, we consider that it's acceptable for the above to return `False` if
implementing it correctly is too complex.

Rationale and alternatives
==========================

The rationale is contained in the high level RFC on generics.

The alternative, as far as generic instantiation is concerned, is what already
implements: Nominal, explicit, non-structural generic instantiation.

Drawbacks
=========

Some users raised the question of code-bloat that would arise from the use of
this feature.

Prior art
=========

Most languages with generics also have by default structural instantiation of
them. In fact it is pretty much the default paradigm for generics in most
languages (C++, C#, Java, Rust, Haskell, OCaml, etc), which makes it difficult
to identify the feature with such a specific name, because it is usually just
called "generics".

Implementation models & advice exist for similar features in
languages/implementations that monomorphize the result, as GNAT does:

* The GCC documentation has a short page describing the Borland template
  instantiation model, which is the one that was chosen in GCC too:
  https://gcc.gnu.org/onlinedocs/gcc/Template-Instantiation.html

> [!NOTE]
> It seems like [Weak symbols](https://en.wikipedia.org/wiki/Weak_symbol) is
> all that is needed in terms of linker on modern native platforms, and that
> such weak symbols will be "collapsed" at link time.
>
> [LLVM's
> documentation](https://llvm.org/doxygen/group__LLVMCCoreTypes.html#ga0e85efb9820f572c69cf98d8c8d237de)
> about link modes gives some more information about this.

* The Rust compilation model for generics [is described
  here](https://rustc-dev-guide.rust-lang.org/backend/monomorph.html), but I
  didn't see any information about the specific way generic instantiations are
  de-duplicated. A confirmation that something similar to the C++ compilation
  model is used would be good.

Issues to consider
==================

### Steve on elaboration issues

RM 3.11(13) states that the elaboration of an instantiation of a generic
unit that has a body includes a check that the body has been elaborated.
If this elaboration check fails, then Program_Error is raised.

This check is needed in order to prevent use-before-declaration
problems, either directly (i.e., during the elaboration of a package instance)
or via a call to a subprogram declared in the instance. Both scenarios are
illustrated by the following example:

```ada
    generic
    package G is
       function Foo return Integer;
    end G;

    package Inst is new G;

    Int : Integer := Inst.Foo;

    Table : Some_Array_Type (1 .. Some_Function);

    package body G is
       function Foo return Integer is
       begin
          return Table (Table'First).Some_Integer_Component;
       end Foo;
    begin
       Table (Table'First) := ... ;
    end;
```

The instantiation `package Inst is new G;` will fail the check and raise
`Program_Error`. But imagine the consequences if the language did not require
this check. First, the elaboration of the expanded body for Inst would try
to assign to a component of the object Table before the declaration of that
object has been elaborated (and, in particular, before the bounds of that
object are known). Next, the call to Inst.Foo would try to read some part of
the Table object, again before the declaration of that object has been
elaborated. So there are good reasons for this elaboration check.

Sometimes code has to be structured specifically to avoid failing this check.
For example, a package usually cannot export both a generic that has a body
and an instance of that generic. Or it may be the case that elaboration
order issues mean that a package body that wants to instantiate some generic
has to cope with the case where that instantiating package body is elaborated
before the body of the generic is elaborated. In some cases, one solution
is to move the declaration of the instantiation into the bodies of the
subprograms that need to refer to it. This defers the elaboration check for
the generic body until an instantiating subprogram is called. So instead of
version #1,

```ada
   package Pkg is
      procedure Foo;
      procedure Bar;
   end Pkg;

   with G;
   package body Pkg is
      package I is new G;
      procedure Foo is
      begin
         I.Do_Stuff;
      end;
      procedure Bar is
      begin
         I.Do_Other_Stuff;
      end;
    end Pkg;
```

we might see version #2,

```ada
   package Pkg is
      procedure Foo;
      procedure Bar;
   end Pkg;

   with G;
   package body Pkg is
      procedure Foo is
         package I is new G;
      begin
         I.Do_Stuff;
      end;
      procedure Bar is
         package I is new G;
      begin
         I.Do_Other_Stuff;
      end;
    end G;
```

Now consider this case with the added wrinkle that the instance is
implicitly declared in version #3:

```ada
   with G;
   package body Pkg is
      procedure Foo is
      begin
         G[].Do_Stuff;
      end;
      procedure Bar is
      begin
         G[].Do_Other_Stuff;
      end;
   end G;
```

If hoisting-to-get-sharing of implicit instance declarations turns this
into something equivalent to version #1, then we may have introduced an
elaboration check failure.

I'm not claiming that this is an insurmountable problem, but it is a
scenario that we need to be aware of.

> Raph: I feel like the workaround *might* be to use explicit instantiations in
> those cases ? But let's discuss during the meeting.

### Problems already discussed, and solved (in principle)

The accessibility level of an instance of a generic package can impact both
the static legality and the dynamic behavior of a program. Examples
illustrating this are provided below. This suggests that the point at which
an implicit instance is declared should be well-defined.

First, a static example:

```ada
    generic
    package G1 is
      Int : aliased Integer;
    end package;

    type Int_Ref is access all Integer;
    Ref : Int_Ref;

    package I1 is new G1;

    procedure Foo is
       package I2 is new G1;
    begin
       Ref := I1.Int'Access; -- legal
       Ref := I2.Int'Access; -- illegal
    end Foo;
```

One might argue that this is not a problem since we do not plan to allow
implicit instances of generic packages that declare variables. But the
entity declared in the generic have been a constant or even a subprogram
(with corresponding changes to the access type declaration).

Next, a dynamic example, referencing the same G1, Int_Ref, Ref, and I1
declarations:

```ada
     procedure Bar is
       package I2 is new G1;
       procedure Update_Ref (Value : access Integer) is
       begin
           Ref := Int_Ref (Value);
       end;
    begin
       Update_Ref (I1.Int'Access); -- succeeds
       Update_Ref (I2.Int'Access); -- raises Program_Error
    end;
```

Accessibility levels can also impact the results of membership tests
and the point at which finalization takes place. We presumably want all
these sorts of things to be well-defined for an implicitly declared instance.

A general approach that was discussed briefly at the meeting was to
hoist the implicit declaration of an instance to the outermost possible
scope. For example, if a formal parameter of a subprogram is an actual
parameter of an instance, then we can't hoist the implicit declaration
to some point outside of the subprogram. But what does "outermost possible"
mean in the case of renamings and subtype declarations? In a case like

```ada
    procedure Foo (N : Natural) is
       subtype S is String;
       function Eq (X, Y : S) return Boolean renames "=";
    begin
       Some_Generic (S, Eq).Some_Procedure;
    end;
```

can we hoist the implicit instance declaration outside of Foo?
What if we add a static constraint to the subtype declaration, as in
    subtype S is String (1 .. 10);
? Or a dynamic constraint, as in
    subtype S is String (1 .. N);
?

> Raph: For me we shouldn't try to be clever about those cases (so no resolving of renamings/subtypes)
> The right approach is for the compiler to show where the generic has been instantiated and why.

Is some cases, there may be no suitable declaration site and so the
implicit instance reference would presumably have to be rejected.
Consider an implicit instance with an actual parameter that is a
formal parameter of an expression function:

    function Expr_Func (N : Natural) is
       (Some_Generic(N).Some_Function);

Would we want to allow this? Note that implicitly replacing an
expression function with a "regular" function would give us a place
to declare the implicitly-declared instance, but it would also introduce
complexity (e.g., interactions with freezing).

> Raph: It's a shame that expression functions and regular functions have different semantics in that regard.
> I think this case can acceptably be flagged as illegal, at least for now, as long as we have decent
> error messages in the implementation.

> Romain: I agree that we can forbid such instantiations in those cases, although this will prevent doing some
> of the cool stuff we advertised for, like `function Sum (X: Float_Array) return Float is (Reduce (Fn => "+") (X))` :D

====

When hoisting the implicit declaration of an instance, we probaby need to be
careful not to introduce a case where the instance is elaborated before
the corresponding generic body. We don't want to introduce an
access-before-elaboration failure. Similarly, if would not be good if we have a
subprogram that is never called and it contains a reference to an implicitly
declared package instance, and if that instance gets hoisted to some point outside
of the subprogram and then the elaboration of the instance propagates an exception.

> Raph: Can you give examples ?

====

We want to allow, but not require, sharing of implicitly declared instances
that have the same actual parameters. The idea is that program legality
and behavior should be unaffected by such sharing (or its absence). That's
one reason, for example, that we want to disallow implicit instances of
generics that have variable state (or which query variable state during their
elaboration).

One case that requires some thought is tagged type declarations. Consider

```
    p1.ads
    subtype S1 is Some_Generic (Integer, "+").Some_Tagged_Type;

    p2.ads
    subtype S2 is Some_Generic (Integer, "+").Some_Tagged_Type;

    p3.ads
    Flag : Boolean := S1'Tag = S2'Tag;
```

If two tagged types have distinct tags and neither is descended from
the other, then allowing conversion between the types (implicit or
explicit) seems like it would lead to problems. So if we are going to
treat S1 and S2 as being subtypes of the same type, then the two
implicit instance references probably need to be somehow required to refer
to the same instance.

> Raph: That's a good point but yes. At the user level, we want there to be only one type.
>  In this particular case, it means that we *need* the emitted code to have only one tag
>  for this type.

> Romain: "then allowing conversion between the types (implicit or explicit) seems like it
> would lead to problems" are you thinking of problems at runtime? Because if I understand
> correctly, it couldn't cause problems at compile-time because if two instances are not
> shared it means they couldn't "see" each other in the first place. So assuming they can't
> "see" each other, maybe we can rely on the fact that the compiler will generate the same
> code for the duplicate instances in such a way that it is not possible to make a
> distinction between them at runtime? If that's not an option, does it mean that we would
> have to find a way to share the instances accross libraries?

Another somewhat similar case is access equality, as in

```
     type Ref is access procedure;
     Ptr1 : Ref := Some_Generic (Integer, "+").Proc'Access;
     Ptr2 : Ref := Some_Generic (Integer, "+").Proc'Access;
     Flag : Boolean := Ptr1 = Ptr2;
```

where Flag will probably be initialized to True if and only if instance
sharing occurs (although in this particular case, Flag might be False even
if sharing occurs because of RM 4.5.2(13)). Similar scenarios involving
an access-to-constant type are possible.

[Aside: hopefully we will not introduce any violation of the equivalence
rule for multi-identifier object declarations given in 3.3.1(7). We don't
want to treat
   X, Y : Some_Generic (Integer, "+").T;
differently than
   X : Some_Generic (Integer, "+").T;
   Y : Some_Generic (Integer, "+").T;
with respect to allowing/forbidding instance sharing]

One approach is to invent rules to eliminate optional instance sharing -
in cases where it makes a difference, sharing should be forbidden or
required. Another approach is to give up on the ideal that program
behavior should be unaffected by whether the implementation chooses to
share instances or not.

> Raph: Question: is there an ideal compilation model where we can guarantee sharing in 100% of the cases ? Under what constraints ? How would it look like ?

### Discussion during WG

* Safer to forbid interaction with nested library level generics, because GNAT already handles them pretty badly

