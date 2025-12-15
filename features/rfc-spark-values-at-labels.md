Feature Name: value_at_labels

Start Date: 2025-10-30

Status: Ready for implementation

Summary
=======

This RFC introduces a new attribute, called ``At`` that can be applied to
an expression to refer to a copy of its value saved at a preceding label.
This attribute can be thought as a generalization of the ``Old`` and
``Loop_Entry`` attributes.

Motivation
==========

Complex proof in GNATprove can require writing intermediate assertions to
guide proof, relating values of the program state between multiple steps.
Currently, the only way to state anything about these values is to manually
save the required values in ghost constant declarations. The ``At``
attribute is intended to provide concise syntactic sugar to automate that
process. The user would only need to add a label at the preceding control
flow point, rather than full ghost constant declarations for everything that
need to be saved.


Guide-level explanation
=======================

The ``'At`` attribute takes a label as argument, and can be used on
arbitrary expressions to denote a constant declared at that label,
and initialized with that expression. A program using the ``'At``
attribute is equivalent to a program declaring the constant explicitly
at that label. As an example, the following code:

```ada
X := 1;
<<My_Label>>
X := 2;
pragma Assert ((X-1)'At (My_Label) = 0);
```

is equivalent to

```ada
X := 1;
declare
   Compiler_Generated_Unique_Name : constant Integer := (X-1);
begin
   X := 2;
   pragma Assert (Compiler_Generated_Unique_Name = 0);
end;
```

That equivalence implies that it is not allowed to refer to the value of
a constant at a non-visible (or following) label. The equivalence also
means that the scope of the constant is the surrounding sequence of
statements of the label. In particular, associated finalization will
occur at the end of the sequence, rather than immediately after the
reference.


Reference-level explanation
===========================

The attribute ``'At`` can be applied to any subexpression, and takes
a ``statement_identifier`` as parameter. That ``statement_identifier``
shall refer to a visible ``statement_identifier``. The innermost sequence
of statements enclosing the ``statement_identifier`` shall also enclose
the ``'At`` attribute. Furthermore, if the ``'At`` attribute is enclosed by
an accept_statement or a body, then the ``statement_identifier`` shall not
be outside this enclosing construct. The preceding are the same rules as for
``goto`` statements; in addition, within the innermost sequence of statement
enclosing both, the ``'At`` attribute shall occur in a statement occurring
after the ``statement_identifier`` it references.

For any given sequence of statement immediately enclosing two ``statement_identifier``s
``L1`` and ``L2``, such that ``L1`` precedes ``L2``, if there is a ``goto`` statement
targeting ``L2`` within a statement preceding ``L1`` in the sequence, then no ``'At``
attribute shall reference ``L1``.

The attribute ``'At`` denotes a constant that is implicitly declared at
the label, following the same rules as local declarations without blocks.
The declaration of the constant is the same as what would be declared for
an unconditionally evaluated ``'Old`` attribute (ARM 26.*/4). In particular,
for tagged types, the constant renames a class-wide temporary in order to
preserve the tag.

The prefix of an ``'At`` attribute reference shall only reference entities
visible at the location of the referenced ``statement_identifier``, or declared
within the prefix itself. It shall not contains a ``'Loop_Entry`` reference
without an explicit loop name. If the prefix of an ``'At`` attribute reference contains
another ``'At`` attribute reference, or a ``'Loop_Entry`` reference (with an explicit
loop name) the inner reference shall be legal at the location of the
``statement_identifier`` referenced by the outer attribute. Similarly, if the
prefix of an ``'Loop_Entry`` attribute reference contains a ``'At`` attribute reference,
the ``'At`` reference shall be legal at the location immediately before the referenced
loop.
(Explanation: the reference should be legal and keep the same meaning when the expression
  of the surrounding reference is moved to the implicit declaration point).

The prefix of an ``'At`` attribute reference which is potentially unevaluated
within the outermost enclosing expression shall statically name an entity,
unless the pragma Unevaluated_Use_Of_Old is set to a value that would relax
the matching restriction for attributes ``'Old``/``'Loop_Entry``.
