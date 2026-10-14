- Feature ID: component_access_modes
- Start Date: 2026-09-28
- Status: Proposed

Summary
=======

This RFC lets a register declaration say, for each of its components, **who may
read it and who may write it**, allowing the compiler to check accesses it
cannot check today and the analysis to assume what it cannot assume today.

That is the one fact today's declarations cannot carry. Ada says **where** a
hardware register lives, **how wide** an access to it is and **how its bits are
arranged**, but not who may read and who may write each of its bits. A single
32-bit word usually mixes bits the program writes and the device only samples,
bits the device sets and the program only reads, and reserved bits that must be
written back unchanged. Volatility, and the four SPARK volatility properties
that refine it, apply to a whole object and cannot say any of this.

Two aspects carry it. `Access_By` gives each component an access mode per side,
one of `None`, `Read`, `Write` and `Read_Write`, for the program and for the
environment independently. `Write_Value` follows from it: once a declaration
says the program may not write a component, it must also say what a write of
the enclosing register carries for that component.

The compiler uses the first for legality checks and the second to compose the
store; GNATprove derives the per-component `Async_Readers` and `Async_Writers`
properties from `Access_By`, so a component the device never writes becomes an
ordinary variable for proof while the device-driven component beside it, in the
same register, stays an environment input.

Motivation
==========

The information that this RFC allows us to formalize is not new: the people who
work with memory-mapped registers have been recording it for years (such as the
CMSIS-SVD and SystemRDL description formats). What is missing is a place for it
in the declaration, where the compiler can use it to check accesses and to
compose the stores the hardware expects, and the analysis can use it to reason
about one component of a register rather than about the register as a whole.

What declarations cannot say today
----------------------------------

Nothing in the declaration of a UART status register says which of its bits
the program may write, which it may read, and which it may not name at all:

```ada
type Status_Bits is record
   RX_Ready : Boolean;  --  bit 0: character available
   TX_Empty : Boolean;  --  bit 1: transmit register empty
   Busy     : Boolean;  --  bit 2: transmission in progress
   Reserved : Bits_5;   --  bits 3-7
end record
  with Volatile, Size => 8, Bit_Order => Low_Order_First,
       Async_Writers => True,   --  the device drives these bits
       Async_Readers => False;  --  and never reads them back
```

Those aspects are as much as SPARK can be told about this register today. It is
worth being exact about what they do and do not buy, because they are the
nearest thing the language already has to what this RFC proposes.

What they do not touch is legality: `Status.RX_Ready := False` compiles exactly
as before, because the four properties say what the analyzer may assume, not
what the program may do. Nor do they say that the reserved bits must be written
as zero, or that they may not be named at all. The datasheet says considerably
more than the declaration does: a record representation clause fixes where each
field sits and how wide it is and stops there.

And they are uniform. They attach to the whole object, so they can only be
right about a register every bit of which has the same properties.

Where the uniformity costs proof
--------------------------------

A control register is the complementary case, every bit of it program-owned,
and where all components have the same properties there is no gap at all. The
case for this RFC is therefore not that the model is missing but that its
granularity and its surface are not enough.

The granularity fails as soon as one register mixes ownership, and mixed
ownership is ordinary. A control register commonly carries one bit the device
drives among the fields the program owns (a start bit that the hardware clears
when the operation completes, for example).

```ada
type Control_Bits is record
   Enable    : Boolean;       --  program writes, device samples
   Prescaler : Prescale;      --  program writes, device samples
   Baud_Rate : Baud_Divisor;  --  program writes, device samples
   Start     : Boolean;       --  program sets, device clears when done
end record with Volatile, Size => 32;

Control : Control_Bits with
   Import, Volatile,
   Async_Writers => True,  --  forced only by Start
   Async_Readers => True,
   Address       => System'To_Address (16#4001_3800#);
```

`Start` is written by the device, so the object is `Async_Writers => True`. An
address names a storage element and not a bit, so there is no address to give
`Start` that is not also `Baud_Rate`'s.

This is the granularity that the object-level properties cannot reach, and it
is the one case that cannot be worked around by declaring things differently.

The cost lands on the fields that have nothing to do with `Start`. The analyzer
must assume the environment rewrites `Baud_Rate` between any two statements, so
a read of it tells us nothing, a write followed by a read cannot be assumed to
yield the value written, and a postcondition that should be provable is neither
provable nor legal:

```ada
procedure Set_Baud (D : Baud_Divisor) with
  Post => Control.Baud_Rate = D;  --  illegal: Control has Async_Writers
```

The truth about `Baud_Rate` is that the device never writes it. It samples that
field and changes none of its bits, so a read-back yields exactly
what the program last stored. There is no way to say so of a component, only of
the whole register, so users either drop out of SPARK for the whole driver, or
wrap every register in hand-written shadow state with `Global` contracts
written by hand.

Guide-level explanation
=======================

Two views of one register
-------------------------

A memory-mapped register has two users: the program and the environment.
"Environment" means whatever else drives those bits (the device itself, a DMA
engine, an interrupt handler outside the analyzed subsystem, or foreign code in
C). The proposal is to let you describe each side separately, per component:

```ada
type Status_Bits is record
   RX_Ready : Boolean with Access_By   => (Program     => Read,
                                           Environment => Write),
                           Write_Value => False;
   TX_Empty : Boolean with Access_By   => (Program     => Read,
                                           Environment => Write),
                           Write_Value => False;
   Busy     : Boolean with Access_By   => (Program     => Read,
                                           Environment => Write),
                           Write_Value => False;
   Reserved : Bits_5  with Access_By   => (Program => None),
                           Write_Value => 0;
end record
  with Volatile, Size => 8, Bit_Order => Low_Order_First;
```

`Access_By` is the contract between the two sides, with a part for each of
them. Each part takes an access mode, one of `None`, `Read`, `Write` and
`Read_Write`: the `Program` part says what your code may do to the component,
and the `Environment` part says what the world outside your code does to it.
Either may be omitted, and both default to `Read_Write`, the permissive value,
so an existing declaration keeps exactly its current meaning.

A status flag needs both parts. `Program => Read` is the legality half: the
program may read the bit and may not assign to it. `Environment => Write` is
the half the analyzer reads: the device drives the bit, so nothing may be
carried from one read to the next.

When a component of a register is not intended to be written by the program,
we still need a value to fill its bits, because no machine stores a single bit:
the store instruction that writes any one component writes all of them, and
datasheets usually say what such a write must carry. That is the purpose of
`Write_Value`, which is zero here, the usual answer for a status bit whose
writes the device ignores.

With that declaration in place:

```ada
Status.RX_Ready := False;    --  illegal: Access_By => (Program => Read)
if Status.RX_Ready then ...  --  fine
X := Status.Reserved;        --  illegal: Program => None, so not nameable
```

The two parts vary independently, and one register commonly needs several of
the combinations:

```ada
type Timer_Control is record
   --  "The prescaler is set by software and sampled by the timer.
   --   It is never modified by hardware."
   Prescaler  : Bits_4  with Access_By => (Program     => Read_Write,
                                           Environment => Read);

   --  "Writing a one starts the counter. The bit reads back the run
   --   state, which hardware clears at top-of-count in one-shot mode."
   Running    : Boolean with Access_By => (Program     => Read_Write,
                                           Environment => Read_Write);

   --  "Reserved. Must be written as zero."
   Reserved_Low  : Bits_3  with Access_By   => (Program => None),
                                Write_Value => 0;

   --  "Reserved. Software must preserve the value read."
   Reserved_High : Bits_8  with Access_By   => (Program     => None,
                                                Environment => None),
                                Write_Value => Preserve;
end record
  with Volatile, Size => 16;
```

Each of those four annotations is one sentence of a datasheet, and each of the
four is a different pair of answers. `Prescaler` the program owns and the
device only samples; `Running` both sides write, so the program's read of it
is a read of the device's state and not a read-back of its own.

The control register: telling the analyzer what the device does not do
----------------------------------------------------------------------

The complementary direction, and for SPARK the more valuable one, is to say
what the environment does not do:

```ada
type Control_Bits is record
   Enable    : Boolean      with Access_By => (Environment => Read);
   Prescaler : Prescale     with Access_By => (Environment => Read);
   Baud_Rate : Baud_Divisor with Access_By => (Environment => Read);
   Start     : Boolean;  --  no aspect: the device clears it, as by default
end record
  with Volatile, Size => 32;
```

`Start` keeps the default, `Environment => Read_Write`, because the device does
clear it, and the other three now say that it does not touch them. The one
device-driven bit no longer costs the other three their read-back, which is the
whole of what per-component properties buy here.

`Environment => Read` is the datasheet's own sentence about a control field:
the device samples these bits, at any time, and never changes them. The program
is therefore the sole writer, and a read-back yields what was last written. In
SPARK terms the component has `Async_Writers => False`, which makes the
contract we wanted legal and provable:

```ada
procedure Set_Baud (D : Baud_Divisor) with
  Global => (In_Out => Control),
  Post   => Control.Baud_Rate = D;

procedure Set_Baud (D : Baud_Divisor) is
begin
   Control.Baud_Rate := D;
end Set_Baud;
```

The register is still `Volatile`, still `Import`ed at a hard address, and the
generated code is unchanged: every read is still a real load and every write a
real store. Only the analysis changes, and it changes because we can provide
more detailed information.

`Read` rather than `None` is doing work in that declaration. It says that the
device does read these bits, which gives the component `Async_Readers => True`,
so a write to it is an effect on the world even though nothing in the program
reads it back, and the analysis may not treat it as dead.

Reserved bits
-------------

Reserved bits are the bits that are in the layout because the hardware has
them and not because the program has any use for them, and `Program => None`
is what says so: the component may not be named at all, neither read nor
assigned nor mentioned in an aggregate. What is left to say about them is what
a write of the register carries for them, and there are three answers, which
need different code:

```ada
Reserved_1 : Bits_3 with Access_By   => (Program     => None,
                                         Environment => None),
                         Write_Value => Preserve;  --  read-modify-write
Reserved_2 : Bits_4 with Access_By   => (Program => None),
                         Write_Value => 0;         --  always write this value
Reserved_3 : Bits_5 with Access_By   => (Program => None);  --  never written
```

`Preserve` is the datasheet saying "write back the value read", so a whole-
register write has to load first and copy those bits across. That load carries
a condition of its own, given as rule 8: the component must not be written by
the environment either, or the store would revert a change the device made
between the load and the store. A value is "always write this". The absence of
`Write_Value` is for the gap of a register that is never written, and says just
that: these bits have no write value. What makes such a register unwritable is
`Program => Read` or `Program => None` on the type, which rule 6 requires
before the third form may be used at all.

What you gain
-------------

- The compiler rejects the accesses that the hardware does not support, at the
  point of use, rather than letting the device fail silently at run time.
- Reserved bits get written the way the datasheet asks, because the type says
  which kind of reserved they are, instead of every access site re-deriving it.
- GNATprove treats a program-owned component as an ordinary variable and the
  device-driven component beside it, in the same register and the same word, as
  an environment input, which is what a driver actually needs to be provable,
  and which today requires shadow state that can drift from the hardware it
  mirrors.

Reference-level explanation
===========================

Aspect `Access_By`
------------------

`Access_By` may be specified on a component of a record type, on a (sub)type,
or on a stand-alone object. Its value is an aggregate with two named parts,
`Program` and `Environment`, each of which is an *access mode*: one of `None`,
`Read`, `Write`, and `Read_Write`. Either part may be omitted, and both
default to `Read_Write`. When specified on a type, it applies to the whole
object; specifying it on both a component and the component's subtype is
illegal unless the values agree.

### The `Program` part

The `Program` part is a rule about the code: it says what your code may do to
the component, and the legality rules below are what it means. It is enforced,
in that the compiler checks every use of the component against it.

### The `Environment` part

The `Environment` part is a statement about everything else that reaches those
bits, the device itself, a DMA engine, an interrupt handler outside the
analyzed subsystem, or foreign code. It takes no access away: `Volatile` still
requires every read to be a load and every write a store, whatever is assumed
about them. It reaches the code in one place only, rule 8, where a component
the environment may write may not take its write value from a load.

What it fixes is what may be assumed about the value the component carries:

- A mode that **excludes `Write`** says nothing outside the program changes
  those bits. The component therefore holds what the program last stored, still
  holds it at the next statement, and yields it on the next read, so a
  read-back is exact, a postcondition about the component is provable, and a
  guard over it is a matter of ordinary proof.
- A mode that **includes `Write`** says the opposite: a read yields only what
  the device presented at that instant, nothing may be carried from one read to
  the next, and the value the program stored may already be gone.
- A mode that **includes `Read`** says the bits are observed from outside.
  Their values reach the world whether or not the program ever reads them back,
  so the analysis must count a write as an effect, and may not write off as
  dead one whose value nothing in the program goes on to use.
- A mode that **excludes `Read`** says no one is looking, so the analysis need
  not report successive writes as successive effects, although the compiler
  still emits every one of them because it is `Volatile`.

`Environment => None` excludes both, and is the component that behaves, for
analysis, exactly like an ordinary variable.

*How the SPARK properties are derived* below restates these as the four
volatility properties.

### Legality rules

1. A name denoting an object or component whose `Program` mode is `Read` or
   `None` shall not be the target of an assignment, an `out` or `in out`
   actual, or the prefix of a name so used, and shall not be given a value in
   a record aggregate. Rule 5 says what is written for it instead.
2. A name denoting an object or component whose `Program` mode is `Write` or
   `None` shall not occur in a context that reads it: it may appear only as
   the target of an assignment or as an `out` actual.

   The restriction reaches the enclosing object. A read of an object one of
   whose components the program may not read is illegal too, even though that
   component's name does not appear in it, because the value read for those
   bits is whatever the hardware returns for bits the program is not entitled
   to read. Such a register is therefore read one component at a time; and
   since no machine reads fewer bits than a storage element, each of those
   reads is a separate load of the register, so reading two of its components
   is two accesses to the device where reading the whole object would have
   been one.
3. `Program => None` says more than rules 1 and 2 together: a name denoting
   such a component shall not occur in program text at all, not as a read, not
   as an assignment target, and not as a component name in an aggregate. The
   component is not part of the type's component set for that purpose, so
   `others` does not reach it either; what a write of the object carries for it
   is its `Write_Value`, and nothing the program writes can say otherwise.

   This is how the reserved bits of a register are declared, the bits that are
   in the layout because the hardware has them and not because the program has
   any use for them. The other three modes say what you may do to a component
   you name; this one says you may not name it.
4. Where the state a component denotes can also be changed through some other
   name (through aliasing), an `Environment` mode excluding `Write` on that
   component is a false statement, and a program containing one is erroneous.

Aspect `Write_Value`
--------------------

`Write_Value` gives the value that a write of the enclosing object carries for
a component that the program does not write. Its value is a static expression
of the component's subtype, or `Preserve`. It may be specified on a component
of a record type or on a (sub)type, in the latter case with the same
agree-or-illegal rule as `Access_By`, and only where the `Program` mode is
`Read` or `None`: where the program may write a component it supplies the
value itself, or rule 8's composition leaves the component alone.

5. `Write_Value` supplies what the component contributes to a write of the
   enclosing object, in the two forms the datasheets use.
   `Write_Value => E` contributes the constant `E`. `Write_Value => Preserve`
   contributes what the component already holds, so the store must be preceded
   by a load of the object.

   Either form governs every write of the object alike: an aggregate the
   program writes, and the whole-object store that rule 8 composes.

   The program never supplies the value itself. In an aggregate a
   `Program => Read` component is omitted or given `<>`, and a
   `Program => None` component is omitted, rule 3 forbidding it the `<>`; what
   is written for either is its `Write_Value`.

   Of the two forms only `Preserve` requires an access of its own, and so only
   it can be refused. The load it forces is subject to the condition
   in rule 8, and [`rfc-register-effects`](rfc-register-effects.md) adds a
   second, that no component of the register may have a read with an effect.
6. A component that the program may not write and for which no `Write_Value`
   is specified has nothing to contribute to a write of the enclosing object.
   No write of that object can be composed, so **the enclosing object cannot be
   written at all**.

   The declaration shall say so: such a component is permitted only in a
   record (sub)type whose own `Program` mode is `Read` or `None`, which is what
   makes every write of the object illegal by rule 1.

   This is the shape of a status register that the program only ever reads:
   nothing in it has a write value, and nothing needs one.
7. A component that specifies `Write_Value` shall not have a default
   expression, and neither shall a component whose `Program` mode is `None`.
   The write value belongs in an aspect rather than in a default expression
   because a default expression is the value stored when the program gives
   none, and the program never names this component to give one.

Composing the store
-------------------

8. Assigning to a component that cannot be written without writing the
   enclosing object, which on ordinary machines is any component narrower than
   a storage element, is a store of the whole object. The assignment must
   therefore supply a value for every other component as well, and this is the
   case `Write_Value` exists for: a sibling the program may *not* write (a
   status flag, a reserved field) receives the value the datasheet requires
   instead of whatever a load happened to return for it.

   Each component of the store takes:

   - the value assigned, for the component the assignment names;
   - its `Write_Value`, for a component whose `Program` mode is `Read` or
     `None`;
   - the value the object currently holds, for `Write_Value => Preserve`, and
     for a component the program may write that the assignment does not name.

   Only the last of the three needs the previous value, so the store is
   preceded by exactly one load of the object where some component takes it and
   by none otherwise. This composition governs every write of the enclosing
   object, and not only an assignment to a single component.

   The load carries a condition: it shall not be able to lose an update, so
   every component whose write value the load supplies shall have an
   `Environment` mode that excludes `Write`, since otherwise the device may
   change it between the load and the store, and the store would revert that
   change. Where the condition fails the partial update is illegal and the
   register must be written whole, which puts the read-modify-write in the
   source, where a reviewer can see it, rather than in the code generator.
   Written whole is an aggregate naming every component the program may write
   and giving each the bit pattern the device is to receive, the compiler
   supplying the rest from their `Write_Value` aspects: a `Program => Read`
   component is omitted or given `<>`, and a `Program => None` component is no
   more named there than anywhere else.

How the SPARK properties are derived
------------------------------------

Two of the four properties follow the two parts of `Access_By`:

- `Async_Writers` is True for a component whose `Environment` mode includes
  `Write`, and False otherwise.
- `Async_Readers` is True for a component whose `Environment` mode includes
  `Read`, and False otherwise.

`Effective_Reads` and `Effective_Writes` keep exactly their current meaning and
their current object granularity. They describe what an access *does* rather
than who may make it.

None of the four is specifiable on a component. A component acquires them by
derivation from `Access_By` and in no other way; the existing freedom to state
them by hand stays where it is today, on an object or a type.

An object has the four properties, and the two derived ones are derived from
its components: each is True for the object if it is True for any component.
Where the object or its type also specifies one of the four explicitly, the
values shall agree.

The consequences for analysis are the existing ones, applied per component
rather than per object:

- A component with `Async_Writers => False` may be read in an assertion
  expression, may be assumed unchanged between two reads with no intervening
  write, and yields on read the last value written by the program.
- A component with `Async_Readers => False` may have its writes coalesced or
  eliminated by the analysis model (not by the compiler, which is still bound
  by `Volatile`), so successive writes need not be reported as effects.
- An object all of whose components have `Environment => None` is not an
  external state, and is not required to be declared at library level.

The mapping from vendor descriptions
------------------------------------

The rows of the CMSIS-SVD correspondence that this RFC is responsible for:

| SVD attribute and value | Ada |
| ----------------------- | --- |
| `access` = `read-only` | `Access_By => (Program => Read)` |
| `access` = `write-only` | `Access_By => (Program => Write)` |
| `access` = `read-write` | `Access_By => (Program => Read_Write)` |
| `alternateRegister` | an overlay, and rule 4 on both views |
| `resetValue`, for a gap between declared fields | `Access_By => (Program => None)` with `Write_Value => …` |
| *no SVD equivalent* | `Access_By`'s `Environment` part |
| *no SVD equivalent* | `Write_Value => Preserve` |

`alternateRegister` needs no aspect, since Ada already has the construct: it
names a second register at the *same* offset with a different layout, which is
two objects at one `Address`, each carrying its own aspects. What it does need
is rule 4, on both of them. The same state is reachable through two names, so
neither view may claim that the environment does not write, and here a
generator can see that, since the two addresses are equal in the description it
is reading.

The `Environment` part cannot be filled in from an SVD file, because SVD has
no notion of the hardware's own access, only the program's. It can be inferred
where `access` is decisive: a field that the program may only read must be
written by something else, giving `Environment => Read_Write`, and a field
that the program may only write is presumably read by the device rather than
written by it, giving `Environment => Read`. The case that cannot be inferred
is `access = read-write`, which covers both a control register that the device
never writes and a register with mixed ownership, and that is exactly the case
where the SPARK gain is largest. So the most valuable annotation in this RFC
is the one a generator cannot supply, which is an argument for it being an
aspect in the language that a user can write and a reviewer can check, rather
than generated output. SystemRDL, which does have `hw`, can supply it.

Reserved bits are absent from SVD entirely: every `Reserved_x_y` component in
a generated map is the generator synthesizing a name for a gap between
declared fields and taking its value from the register's `resetValue`. So the
two halves of reserved-bit handling have different provenance, and that is why
the write value is an aspect of its own rather than a mode of `Access_By`.
`Write_Value => E` is derivable, since the generator already computes `E`;
`Write_Value => Preserve` is not and cannot be, because nothing in SVD
distinguishes "write back what you read" from "write the reset value", a
decision that a human makes per register, from the datasheet text.

Rationale and alternatives
==========================

The information already exists in SVD files, which say of every field what the
program may do to it. Ada has nowhere to put even that much. Putting it in
the declaration pays twice: the compiler rejects the accesses the hardware does
not support, and GNATprove reasons about a control register as precisely as
about an ordinary variable, instead of assuming the device rewrites it between
any two statements.

The alternative that needs no language change is a setter/getter API: hide the
register in a body and expose an accessor per field, carrying contracts. It is
cumbersome and verbose.

Generated wrapper types, as the Rust ecosystem produces, cost the record
representation clause, which is the part of Ada that makes register maps worth
writing in the first place. And doing it in the build system, by teaching
`svd2ada` to emit a side file the prover reads, leaves hand-written maps and
undescribed devices unserved, and makes correctness depend on a generator
staying in sync with a hand-edited spec.

The smallest alternative is inside the language: allow
`Async_Writers` and friends on components and stop there. It is worth being
exact about how much of this RFC that would replace.

It replaces the `Environment` part, and nothing else. The two map onto each
other one for one.

It replaces no part of the rest. The four properties are analysis properties,
not legality rules: none of them makes an assignment to a device-owned flag
illegal, none makes a reserved bit unnameable, and none says what a write of
the register carries for a component the program does not write. The `Program`
part of `Access_By` and the whole of `Write_Value` therefore have no counterpart
in the fallback at all.

Drawbacks
=========

This adds two aspects, one of them a composite, and seven names to a part of
the language that is already dense: a fully annotated register declaration is
more verbose, and the interaction surface with `Volatile`, `Atomic`,
`Full_Access_Only`, `Bit_Order`, and `Scalar_Storage_Order` is non-trivial even
though neither aspect changes representation.

Rule 2 makes a record one of whose components the program may not read
unreadable as a whole, so it is read component by component. That is the right
rule, and it costs: each of those reads is a separate load of the register, so
a declaration that adds one write-only field turns a single access into as many
as the code names fields. An ordinary-looking record type behaves unlike one,
and not only in the source.

Rule 6 lets a register become unwritable by omission: leave the `Write_Value`
off one status flag and no write of the enclosing object is legal anywhere.

Compatibility
=============

The proposal is backward compatible because every part of `Access_By` defaults
to the value that reproduces current behavior,
`Access_By => (Program => Read_Write, Environment => Read_Write)`, and because
a component with no `Write_Value` is one whose write value the program
supplies, as today. An existing register declaration is unchanged in legality,
representation, and generated code, and existing SPARK code sees the same four
volatility properties it sees today. No existing program becomes illegal, and
no existing proof result changes.

The added legality rules only constrain programs that opt in by writing the
aspects, which makes incremental adoption per peripheral practical. This
matters: these annotations will be added to existing register maps one
datasheet chapter at a time.

Annotating a register that already has users is not a neutral act, however.
Code that compiled before may not afterwards, and correctly so, since that is
the point: a driver that assigns to a bit the datasheet calls read-only becomes
illegal the moment the declaration says the bit is read-only, and what the
compiler has found is a defect that was always there.

Open questions
==============

- Whether rule 2 should forbid the whole-object read at all, or only the use of
  the components the program may not read. The load happens either way: reading
  one component of a register loads the register, so the device sees the same
  access whether or not the whole object is named, and the rule protects the
  *value* rather than the hardware. What it costs is real, since a register with
  one write-only field is read one component at a time, at one load each. A
  relaxation would let the object be read whole and treat those components as
  not initialized, leaving SPARK's existing machinery to reject any use of
  them, which would also be the cheaper answer once a register has a read with
  an effect.
- Interaction with `Relaxed_Initialization` and with `Modifies`, which both
  reason about parts of an object and will need rules for parts the program
  may not read. The relaxation above would be stated in exactly those terms.
- Whether `Volatile_Function` should follow the per-component properties
  rather than the object's. SPARK forbids a nonvolatile function from having a
  volatile input (RM 7.1.3(7)) and treats a call to a `Volatile_Function` as
  interfering, both at object granularity, so a function that reads one
  program-owned field of a peripheral is a volatile function because some
  other field of the same record is device-written, and a function as ordinary
  as `Is_Enabled` cannot be written as an ordinary one. The `Environment` mode
  is what would say which reads actually interfere, since a function over
  components with `Async_Writers => False` does not.
- Whether `Write_Value` should be permitted on a component the program *may*
  write, as the value a whole-object write carries when an aggregate omits it.
  Rule 8 currently gives such a component the value it already holds, which
  costs a load; a declared write value would not.

Prior art
=========

Register description languages
------------------------------

SVD, the format every Cortex-M vendor ships, carries `access` on registers and
on fields; the mapping table above lists its values against `Access_By`'s
`Program` part. It has nothing corresponding to the `Environment` part.

SystemRDL is the closest match to the design proposed here. It describes each
field with two independent access properties, `sw` and `hw`, which are exactly
the `Program` and `Environment` parts of `Access_By`, down to their taking the
same range of access modes: it is the pair, and not either property alone, that
determines what code is correct. That the language designed specifically to
describe registers arrived independently at a two-sided per-field access model
is a good indication of its value. Ada, uniquely well placed to consume such
descriptions, could benefit from it.

Ada and SPARK
-------------

The four volatility properties (SPARK RM 7.1.2) are the foundation this proposal
reuses; `No_Caching` established the pattern of adding a property that narrows
what volatility implies for analysis, which is what an `Environment` mode
without `Write` does per component. `Volatile_Components` and
`Atomic_Components` show that the language has already accepted that volatility
can need component granularity, though only for array elements and only as an
all-or-nothing property.

Unresolved questions
====================

To resolve during the RFC process. Whether the access-mode enumeration is the
right surface for the `Environment` part, or whether the per-component
volatility properties should simply be spelled with their SPARK names, which is
the fallback the Rationale section weighs.

To resolve during implementation. The precise SPARK rules for components the
program may not read, which is the interaction with `Modifies` and
`Relaxed_Initialization` listed above; and whether GNATprove needs any change
to its external-state model beyond attaching the two derived properties to
components, or whether the existing object-level model must be generalized
first.

Out of scope for this RFC. What an access does to the device, and when an
access is allowed.

Future possibilities
====================

Improve `svd2ada` to emit `Access_By`'s `Program` part from `access`, and the
`Write_Value` of a synthesized reserved component from `resetValue`, so a
device whose description populates them arrives annotated at no cost to the
user. The emission should sit behind a switch for at least one release, since
a generated map that suddenly rejects the driver on top of it is not a welcome
upgrade.

A second input format would go further: SystemRDL has `hw`, which is the
`Environment` part of `Access_By`, and that is the one annotation with the
largest proof value and no SVD equivalent, so a generator reading SystemRDL
could supply what a generator reading SVD must leave to the user.
