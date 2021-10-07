- Feature Name: Deep Delta Aggregates
- Start Date: 2021-10-07
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Summary
=======

Delta aggregates should allow the update of individual subcomponents rather than only entire components

Motivation
==========

Early users of delta aggregates, and users of the former 'Update feature of SPARK
have noticed a periodic need to update an individual subcomponent (e.g. X.A.B) rather
than an entire components (e.g. X.A).  This can be accomplished by a series of
nested delta aggregates, but it seems more straightforward to support a syntax
that allows the direct update of an individual subcomponent of an enclosing object.

Guide-level explanation
=======================

Delta aggregates allow the construction of a new object of a composite type
by taking a base object, and specifying new values for some of the components.
This proposal would allow the specification of a new value for a subcomponent,
rather than an entire component, using a generalization of the current
syntax, such as:

    (X with delta A.B => 42)
   
This would be approximately equivalent to:

    (X with delta A => (X.A with delta B => 42))
   
but would presumably involve fewer copies.

More generally a delta aggregate can be seen as equivalent to the creation of a copy
of the base object, and then a sequence of assignments to some of the *components*
of the copy.  This feature generalizes that to be a sequence of assignments
to some of the *subcomponents* of the copy.

This generalization also permits a more general notation for updating
subcomponents of arrays, including multi-dimensional arrays:

    (A with delta B.C(1,2) => 5, D(3,True) => 7)

or for the case where the base object is itself an array:

    [O with delta (6).G => 11, 5 => (G => 3, H => 4), for I in 2..4 => (G => 7, H => I*2)]

including a multi-dimensional case:

    [M with delta (1, 3) => 77, (2, 5) => 88]

Reference-level explanation
===========================

The syntax for delta_aggregate (see RM 4.3.4) is revised as follows:

```
delta_aggregate ::= record_delta_aggregate | array_delta_aggregate

record_delta_aggregate ::=
  ( base_expression with delta record_subcomponent_association_list )

record_subcomponent_association_list ::=
  record_subcomponent_association {, record_subcomponent_association}

record_subcomponent_association ::=
  record_subcomponent_choice_list => expression

record_subcomponent_choice_list ::=
  record_subcomponent_choice {'|' record_subcomponent_choice}

record_subcomponent_choice ::=
    component_selector_name
  | record_subcomponent_choice (expression {, expression)
  | record_subcomponent_choice . component_selector_name
   
array_delta_aggregate ::=
    ( base_expression with delta array_subcomponent_association_list )
  | '[' base_expression with delta array_subcomponent_association_list ']'

array_subcomponent_association_list ::=
  array_subcomponent_association {, array_subcomponent_association}

array_subcomponent_association ::=
    discrete_choice_list => expression
  | iterated_component_association
  | array_subcomponent_choice_list => expression

array_subcomponent_choice_list ::=
  array_subcomponent_choice {'|' array_subcomponent_choice}

array_subcomponent_choice ::=
    ( expression {, expression} )
  | array_subcomponent_choice (expression {, expression)
  | array_subcomponent_choice . component_selector_name
```

This revised syntax is a superset of the existing delta_aggregate syntax.
It provides for multi-dimensional arrays, and for subcomponent selection,
to support updates to the components of both nested arrays and nested records.

This legality rule from RM 4.3.1(16/5):
> For a record_delta_aggregate, each component_selector_name of each component_choice_list shall denote a distinct nondiscriminant component of the type of the aggregate

is removed, and a new legality rule in RM 4.3.4 is added:
> For a record_delta_aggregate, no two record_subcomponent_choices that consist of only component_selector_names, shall be the same sequence of selector_names.

In addition, the dynamic semantics of RM 4.3.4(15/5-21/5) are changed as follows:

>For a delta_aggregate, for each discrete_choice or each subcomponent associated with each record_ or array_subcomponent_association (in the order given in the enclosing discrete_choice_list and record_ or array_subcomponent_association_list, respectively): 
> * if the associated subcomponent belongs to a variant, a check is made that the values of the governing discriminants are such that the anonymous object has this component. The exception Constraint_Error is raised if this check fails.
> * if the associated subcomponent is a subcomponent of an array, the for each represented index value (in ascending order, if the discrete_choice represents a range): 
>   * the index value is converted to the index type of the array type.
>   * a check is made that the index value belongs to the index range of the corresponding part of the anonymous object; Constraint_Error is raised if this check fails.
> * the expression of the record_ or array_subcomponent_association is evaluated, converted to the nominal subtype of the associated subcomponent, and assigned to the corresponding subcomponent of the anonymous object.

Rationale and alternatives
==========================

This is a generalization of the existing delta_aggregate syntax, and in fact unifies record and array
delta aggregates to some degree, while preserving the ability to identify array components simply by their index value if desired.
Note that there is syntactic ambiguity for single-dimensional arrays, since the choices in a discrete choice list may individually be parenthesized, as in:

    [X with delta (1)|(2)|(3) => 55]

This is a benign syntactic ambiguity, since the semantics are the same.  It would be possible to eliminate this ambiguity with a more
complex BNF, but that would probably not increase understandability.

Drawbacks
=========

This clearly adds complexity to delta aggregates, but seems like an "intuitive" extension if the programmer
makes the connection to a series of assignments to subcomponents.

Prior art
=========

Not sure what are the other languages that provide this capability, though it has been indicated
that the TLA+ "EXCEPT" operator has this feature.

Unresolved questions
====================

It has been indicated that SPARK may have some trouble with transforming this feature to Why3.

Future possibilities
====================

This could conceivably be generalized to allow operations other than assignments to be applied
to the "anonymous object" that is a copy of the base object, thereby generalizing it to work
on private types.  E.g.:

    (Empty_Stack with delta Push(5), Push(7))

being defined as equivalent to:

```
     X : Stack_Type := Empty_Stack;
   begin
     X.Push(5);
     X.Push(7);
     return X;
```

At some point it might make better sense to declare a ghost function to do this, presuming it can be inlined for proof.
