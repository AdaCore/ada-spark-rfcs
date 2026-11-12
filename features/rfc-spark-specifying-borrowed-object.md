- Feature ID: spark-specifying-borrowed-object
- Start Date: 2026-11-12
- Status: Design

Summary
=======

In SPARK, traversal functions always borrow/observe their first parameter. We want the capability to override that default. We propose to annotate traversal functions with an aspect specifying the borrowed/observed objects instead. The aspect would mention one or several parameters, global objects, or state abstractions. For the aspect name, we propose re-using the existing SPARK aspect `Part_Of`. It is currently used to indicate that a state declared in a private part of a package is a constituent of a named abstract state. Similarly, traversal functions returns access to constituents of the borrowed/observed objects.

```ada
G : aliased Integer;
function Access_G return not null access Integer with
  Part_Of => G;

package Pointers with Abstract_State => Memory is
  ...
  function Reference (P : Pointer) return access Integer with
    Part_Of => (Memory, P);  --  Borrows both P and Memory
  ...
end Pointers;

function Access_X (X : aliased Integer) return not null access Integer with
  Part_Of => X;  --  This is the default
```

Motivation
==========

This feature would be very useful for SPARK pointer support. In particular, we are
currently unable to write a full sound pointer library for reference counting. This
is because a function returning a direct access to the underlying element would need
to borrow both the underlying memory and the pointer (see `Pointers` package above).
The memory must be borrowed so that no alias can be modified during the borrow.
The reference-counted pointer must be borrowed as well, to make sure it does not
go out of scope during the borrow, which would potentially
cause reclamation of the borrowed memory location.


Guide-level explanation
=======================

The proposal allows a traversal function to return a part of any of the objects
listed in the `Part_Of` aspect.

```ada
Z : aliased Integer;
function Traverse (X : aliased Integer; Y : aliased Integer; Flag : Integer) return access Integer
  with Part_Of => (X,Y,Z);
function Traverse (X : aliased Integer; Y : aliased Integer; Flag : Integer) return access Integer is
begin
  case Flag is
    when 0 =>
      return X'Access;
    when 1 =>
      return Y'Access;
    when others =>
      return Z'Access;
end Traverse;
```

Consequently, observing/borrowing through such traversal function observe/borrow all parts simultaneously.

```ada
Z := 3;
declare
  A : aliased Integer := 1;
  B : aliased Integer := 2;
  C : access Integer := Traverse (A, B, Random);
begin
  A := 1; -- ERROR: A borrowed by C
  B := 2; -- ERROR: B borrowed by C
  Z := 3; -- ERROR: Z borrowed by C
  C.all := 4; -- OK,
end;
```




Reference-level explanation
===========================

The `Part_Of` aspect may be applied to functions. In that case, it takes a list
of entity names as parameters.

```bnf
part_of_list ::= entity_name | (entity_name{, entity_name})
```

All names in the list must denote either formals of the function, visible objects,
or visible abstract states. No syntax is provided for an empty list.
[Rationale: This is not expected to be useful. The only correct return
  value for a traversal function borrowing nothing is null.
  Observing traversal function may return references to constant state
  hidden from SPARK, which can be worked around by making some state explicit]

Several SPARK concepts are pluralized. The concept of 'root object'
for names is replaced by that of 'root objects', that of 'known extracted path' for names
is replaced by 'known extracted paths', and that of 'traversed parameter' for traversal
function is replaced by 'traversed objects'. The singular variants may
still be used when there is a unique element, for example the root object of a path.

The corresponding RM rules are amended as follow [mostly pluralization]:

- 3.3.1 Object Declarations (1):
The borrowed name of the expression of an object declaration defining a borrowing operation shall not have a variable input, ~~except for a single occurrence of the root object~~ **except for occurrences of the root objects of the expression**; [...].

- 3.10 Access types
  * The first parameter of the function is called ~~the traversed parameter~~ **the traversed object. If the aspect `Part_Of` is specified for the function, the traversed objects are instead these listed in the aspect.**
  * The root object**s** of a name that denotes an object ~~is~~ **are** defined as follows:
  * If the name is a `component_selection`, an `indexed_component`, a `slice`, or a `dereference` (implicit or explicit) then ~~it is the root object~~ **they are the root objects** of the prefix of the name;
  * if the name denotes a call on a traversal function, then ~~it is the root object~~ **they are given by the reunion of the root objects** of the name**s** denoting the actual ~~traversed parameter~~ **parameters which are traversed objects**, together with the non-parameter traversed objects of the function**
  * if the name denotes an object renaming, the root ~~object is the root object~~ **objects are the root objects** of the renamed name
  * if the name is a `qualified_expression` or a type conversion, the root ~~object is the root object~~ **objects are the root objects** of the operand of the name;
  * If the root object**s** of a name ~~is a stand-alone object or a formal parameter~~ **are all stand-alone objects or formal parameters**, then the known extracted paths of that name is either: [...]
  * **Otherwise,** the path**s** extracted from the ~~first parameter~~ **traversed parameters (parameters which are traversed objects)** to the innermost traversal function call**s** within the name ~~otherwise~~ **, together with the non-parameter traversed objects of these calls**
  * [Redundant: The root**s** of the known extracted path**s** of a name ~~is~~ **are** always the root object**s** of the name.]
  * A markable expression is either a name whose root ~~object is a~~ **are all** stand-alone object**s** or ~~a~~ formal parameter**s** or ~~a~~ reference**s** to the `Access` attribute whose ~~prefix is a name~~ **prefixes are names** whose root ~~object is a~~ **objects are** stand-alone object**s** or ~~a~~ formal parameter**s**.
  * By extension, the root object**s** and known extracted path**s** of a markable expression are defined as the root object**s** and known extracted path**s** of the prefix for a reference to the Access attribute and of the name otherwise.
  * The following operations observe ~~a~~ path**s** and identify a corresponding observer:
  * An assignment operation that is used to initialize an access object, [...].
    The known extracted path**s** of the source of the assignment ~~is~~ **are** observed by the assignment.
  * Inside the body of a borrowing traversal function, [...] is a markable expression whose root object**s** ~~is~~ **are** either ~~the~~ traversed ~~parameter~~ **objects** for the traversal function or another object of an access-to-variable type initialized as an observer. The known extracted path*s* of the source of the assignment is observed by the assignment.
  * The following operations borrow ~~a~~ path**s** and identify a corresponding borrower:
  * An assignment operation that is used to initialize an access object, [...].
    The known extracted path**s** of the source of the assignment ~~is~~ **are**
    borrowed by the assignment.
  * A name which is used as an actual parameter of an anonymous access-to-object type shall either be syntactically null, or shall have ~~a~~ root object**s** which ~~is~~ **are all** either ~~a~~  stand-alone object**s** or ~~a~~ formal parameter**s**.
  * A return statement that applies to a traversal function [...], shall return either the literal null or a markable expression whose root object**s** ~~is a~~ **are** direct or indirect observer**s** (respectively, borrower**s**) of the traversed ~~parameter~~ **objects**. [Redundant: Roughly speaking, a traversal function always yields either null or a result which is reachable from the traversed ~~parameter~~ **objects**.]
  * For an assignment statement where [...], the source shall be a markable expression whose **only** root object is the target object itself. [...] the known extracted path**s** of the source shall be observable for the target object; [...].
  * At the point of a read of an object, [...], then its known extracted path**s** shall be observable.
  * For a borrowing operation, the borrowed path**s** shall be unrestricted.

Rationale and alternatives
==========================

We could use the ownership model planned for Flare instead of improving the existing one.
However, this improvement is important for the current pointer support in SPARK, which will
remain in use even if another ownership system is added to Ada. The capability added here
is likely to be present in an Ada ownership model as well, so the underlying support
would be useful regardless.

Drawbacks
=========

Compatibility
=============

This is fully backward compatible.

Open questions
==============

None.

Prior art
=========

Unresolved questions
====================

TBD

Future possibilities
====================

The proposal limits `Part_Of` specification to traversed objects. We could consider
extending the annotation to paths.

