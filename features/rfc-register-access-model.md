- Feature ID: register_access_model
- Start Date: 2026-09-09
- Status: Proposed

Summary
=======

Ada says **where** a hardware register lives, **how wide** an access to it is
and **how its bits are arranged**, but not the two things a datasheet spends
most of its words on: **who** may touch which bits, and **when**. This RFC
adds both. `Program_Access` and `Environment_Writes` state independently what
the program and what the environment may do to each component; `Write_Effect`
and `Read_Effect` say what a read or a write does to the device, where an
access is a command rather than an assignment; `Reserved` says what happens to
the bits the program never names. `Read_When` and `Write_When` give the
conditions under which an access is permitted at all, proved where the guard
is state the program owns and checked at run time where it is state the device
owns, and `X'Written` supplies one for the command registers that have no
readable state to test. The compiler uses the extra information for legality
checks and to choose legal access sequences, and GNATprove derives the
per-component volatility properties from it, so a control register the device
never writes becomes an ordinary variable for proof while the status register
beside it stays an environment input.

Motivation
==========

The first gap, about who
------------------------

```ada
Status.Overrun := False;  --  "clear the overrun flag"
```

`Overrun` is a write-one-to-clear bit, so this line does nothing to it. Worse,
it is a read-modify-write, since there is no way to write one bit of a byte:
the store hands back whatever the load returned for every other bit of the
register, and under the usual convention a one clears such a bit, so any error
flagged before the load is acknowledged and lost.

Nothing in the declaration of `Status` could have prevented it. A record
representation clause fixes where each field sits and how wide it is, and stops
there. That `RX_Ready` and `TX_Empty` are set by the device, so writing them is
meaningless; that `Overrun` is acknowledged by writing a one and not by writing
a zero; that the reserved bits must be written back unchanged rather than
zeroed by an aggregate: none of it is stated, so none of it is checked, and all
of it survives only in the comments of the datasheet.

The same gap costs proof. A control register is declared the same way, and in
SPARK it is an external state, so all four volatility properties default to
True and the analyzer must assume the environment writes it asynchronously. A
read of `Control` therefore tells us nothing, a write followed by a read cannot
be assumed to yield the value written, and this contract is neither provable
nor legal:

```ada
procedure Set_Baud (D : Baud_Divisor) with
  Post => Control.Baud_Rate = D;
```

The truth about that register is that the device never writes it, and there is
no way to say so of a component. So users either drop out of SPARK for the
whole driver, or wrap every register in hand-written shadow state with `Global`
contracts written by hand.

The second gap, about when
--------------------------

From the SVD description that ships with a widely used Cortex-M part:

```xml
<register>
  <name>PRESCALER</name>
  <description>12-bit prescaler for COUNTER frequency (32768/(PRESCALER+1)).
               Must be written when RTC is STOPed.</description>
```

"Must be written when RTC is STOPed" is a rule about when, in a machine-readable
description of the device, and nothing in the file relates it to the register
that stops the RTC. Today neither the compiler nor the prover can do anything
with it.

Close the first gap and the rules about when are still missing. A UART whose
layout and whose ownership are both machine-checked still has four sentences of
its datasheet nowhere in its declaration:

- `CR.Baud_Rate` may only be written while `CR.Enable` is False. Writing it on a
  running UART corrupts the current character.
- `CR` may not be written at all while `SR.Busy` is set.
- `DR` may only be read when `SR.RX_Ready` is set; otherwise the value is
  undefined, and on some devices reading it also clears the flag, so the poll and
  the read cannot be reordered or duplicated.
- `CR.Prescaler` must be written before `CR.Enable` is first set.

These are not exotic. They are the ordinary content of a peripheral
description, and these rules are often broken. Note that the first and the
second of them read alike but verify quite differently, since `CR.Enable` is
written by the program alone and `SR.Busy` by the device.

The facts behind the first gap are machine-readable: CMSIS-SVD carries
`access`, `readAction` and `modifiedWriteValues` on every field, and the
mapping table in the Reference section lists them against the aspects proposed
here. The facts behind the second are not, as `PRESCALER` shows, so those
annotations are decisions about the device rather than transcriptions of a
file.

The expected outcome is that a register declaration becomes a complete,
checkable model of the register: the compiler rejects the accesses that the
hardware does not support, generates only the access sequences that the
hardware tolerates, refuses an access made at a moment the device does not
allow, and GNATprove reasons about control registers as precisely as it reasons
about ordinary variables while still treating status registers as environment
inputs.

Guide-level explanation
=======================

Two views of one register
-------------------------

A memory-mapped register has two users: the program and the environment.
"Environment" means whatever else drives those bits (the device itself, a DMA
engine, an interrupt handler outside the analyzed subsystem, or foreign code in
C). The proposal is to let you describe each side separately, per component:

```ada
type Status_Register is record
   RX_Ready : Boolean := False with Program_Access => Read_Only,
                                    Environment_Writes => True;
   TX_Empty : Boolean := False with Program_Access => Read_Only,
                                    Environment_Writes => True;
   Busy     : Boolean := False with Program_Access => Read_Only,
                                    Environment_Writes => True;
   --  Overrun is write-one-to-clear: writing a one acknowledges it.
   Overrun  : Boolean with Write_Effect => (Trigger_On_One => Clear);
   Reserved : Bits_4  with Reserved => Write (0);
end record
  with Volatile, Size => 8, Bit_Order => Low_Order_First;
```

Read it as a contract between the two sides. `Program_Access` says what your
code may do; `Environment_Writes` says whether the device writes it. Both
default to the permissive value (`Read_Write` and `True`), so an existing
declaration keeps exactly its current meaning.

Those `:= False` defaults are not initializations. They are the values written
to those bits when the program writes the register, which the declaration has
to state, because the device owns those bits and the datasheet says what a
write to them must carry. Here that is zero, the usual answer for a status bit
whose writes the device ignores.

With that declaration in place:

```ada
Status.RX_Ready := False;    --  illegal: Program_Access => Read_Only
if Status.RX_Ready then ...  --  fine
Status.Overrun  := True;     --  writes a one: acknowledges it
Status.Overrun  := False;    --  illegal: provokes nothing
X := Status.Reserved;        --  illegal: reserved, so not nameable
```

The control register: telling the analyzer what the device does not do
----------------------------------------------------------------------

The complementary direction, and for SPARK the more valuable one, is to say
that the environment does not write a component:

```ada
type Control_Register is record
   Enable    : Boolean      with Environment_Writes => False;
   Prescaler : Prescale     with Environment_Writes => False;
   Baud_Rate : Baud_Divisor with Environment_Writes => False;
end record
  with Volatile, Size => 32;
```

`Environment_Writes => False` means: the device may sample these bits at any
time, but it never changes them. Nothing else writes them either. The program
is therefore the sole writer, and a read-back yields what was last written. In
SPARK terms the component has `Async_Writers => False` and
`Effective_Reads => False`, which makes the contract we wanted legal and
provable:

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
real store. Only the analysis changes, and it changes because we told the
truth about the device rather than because we hid the register from the
analyzer.

When an access is a command
---------------------------

For some registers a read or a write is not an assignment at all but an
instruction to the device. Two aspects describe this:

```ada
type Interrupt_Status is record
   Pending  : Boolean with Program_Access => Read_Only,
                           Read_Effect => Clear;
   Reserved : Bits_7  with Reserved => Preserve;
end record with Volatile, Size => 8;
```

`Read_Effect` says what reading the component does to the device: `None` (the
default), or one of the four actions SVD's `readAction` distinguishes, a read
that clears the field, sets it, modifies it in some way the description does
not state, or modifies something else (`Clear`, `Set`, `Modify`, `External`).
All four make the component's `Effective_Reads` property True, so it may not
be read where a read must have no effect: not in a precondition, an invariant,
or twice in one expression. That is the existing SPARK rule for objects, here
applied to fields. A component whose read has an effect has
`Environment_Writes => True` as well, so whatever the read left behind the
device may have changed already, and that is why the four are one property to
the analyzer even though they are four different sentences in the datasheet.

`Write_Effect` says both what a write provokes and what it then does:

```ada
Overrun : Boolean with Write_Effect => (Trigger_On_One => Clear);
```

The default is `Normal`, written as a value rather than a pair, and it is
today's behavior: the value written is the value stored. Otherwise the aspect
is a trigger and an action. The trigger is `Trigger_On_One`,
`Trigger_On_Zero`, or `Trigger_On_Write`, the three ways a bit can be
provoked. The action is `Clear`, `Set`, `Toggle`, `Modify`, or `External` (the
same vocabulary as the read side, plus `Toggle`, which only a write can do,
since only a write brings an operand to say which bits to flip).

The two halves are separate because they are consulted separately. The trigger
decides the code: an assignment to such a component is a full-width store in
which every component the program did not name holds the value whose writing
provokes nothing, or, where that is not a value it has, the value it already
holds. Only the second of those needs the register loaded first.

```ada
Status.Overrun := True;  --  one store of 2#0000_1000#
```

The action decides what is known afterwards. Writing a one to `Overrun` clears
it, so under `Environment_Writes => False` the analyzer may take the bit as
zero after the assignment; here `Overrun` is a device-set flag, so it may not,
and the action is what a reader and a generator get rather than the prover. The
two actions that state no outcome, `Modify` and `External`, yield nothing
either way: `Modify` because the description does not say what the device does,
`External` because what the write provokes is somewhere else entirely, which is
the shape of a command register.

Writing `False` to `Overrun` is illegal, because on a `Trigger_On_One`
component `False` is the value whose writing provokes nothing: the store would
be a word of zeros, which reads as clearing the flag and does not touch it. So
the rules forbid assigning the provoke-nothing value wherever it is static.

Without the aspect, the assignment `Status.Overrun := False` is not merely
useless. It has to load the register, clear the bit, and store the result, since
there is no way to write one bit of a byte. So the store carries back into every
other component whatever the load returned for it, and where a write is a command
rather than an assignment, the value handed back may be the one that provokes it.
Under the usual write-one-to-clear convention, a bit reads as one while its
condition is pending, and a one is what clears it, so any error flagged before
the load is acknowledged and lost. Whether that happens depends on how each
field reads and on which value provokes its effect, which is the argument for
saying both in the declaration: nothing states them today, so nothing can check
the store.

A multi-bit field works the same way, which is the usual shape where one
register collects several interrupt sources. Give a four-bit `Sources` field
`Write_Effect => (Trigger_On_One => Clear)` and a write acknowledges the bits
it names and leaves the rest of that register alone:

```ada
Interrupts.Sources := 2#0011#;  --  acknowledges two of the four sources
```

Between them the two aspects hold everything a vendor description states about
an effect, which the mapping table below sets out value by value.

Reserved bits
-------------

Three kinds of reserved bits occur, and they need different code:

```ada
Reserved_1 : Bits_3 with Reserved => Preserve;   --  read-modify-write
Reserved_2 : Bits_4 with Reserved => Write (0);  --  always write this value
Reserved_3 : Bits_5 with Reserved;               --  never written at all
```

`Preserve` is the datasheet saying "write back the value read", so a whole-
register write has to load first and copy those bits across. `Write (E)` is
"always write this", and the value sits in the aspect rather than in a default
expression, because the program never assigns this component. The valueless
form is for the gap of a register that is never written, and says just that:
these bits have no write value. What makes such a register unwritable is
`Program_Access => Read_Only` on the type, which rule 8 requires before the
valueless form may be used at all.

None of the three may be named in program text at all: `X := Status.Reserved_1`
and `Status.Reserved_2 := 1` are both illegal, and a reserved component is not in
the aggregate's component set either. That is why this is a separate aspect from
`Program_Access` rather than two more of its values: an access mode says what
you may do with something you name, and these you do not name.

Guarding an access
------------------

`Write_When` and `Read_When` take a list of clauses, each naming a part of the
type and the condition under which that part may be accessed. `Write_When`
guards the stores, which is where most datasheet rules land, since most of them
forbid configuring a device at the wrong moment. `Read_When` guards the loads,
for the registers whose value is undefined outside a window: a data register
that holds nothing until the device says it does, an ADC result that is not the
last conversion's until the conversion is complete.

```ada
type Control_Register is record
   Enable    : Boolean      with Environment_Writes => False;
   Prescaler : Prescale     with Environment_Writes => False;
   Baud_Rate : Baud_Divisor with Environment_Writes => False;
end record
  with Volatile, Size => 32,
       Write_When => (Baud_Rate when not Enable);
```

Names in the clauses denote components of the type on which they are specified,
and conditions are ordinary Boolean expressions over those components. So a
rule between two registers of one peripheral goes on the peripheral type, where
both are components:

```ada
type UART_Peripheral is record
   CR : Control_Register;
   SR : Status_Register;
   DR : Data_Register;
end record
  with Volatile,
       Write_When => (CR when not SR.Busy),
       Read_When  => (DR when SR.RX_Ready);
```

and a rule involving another peripheral entirely (a clock gate, a power
domain) goes on the object, where any visible object may be named:

```ada
UART1 : UART_Peripheral with
   Import, Volatile,
   Address    => System'To_Address (16#4001_3800#),
   Write_When => (CR when RCC.APB2_Enable.UART1_Clock);
```

The split is deliberate: a type may be shared by four UARTs and must not
mention any one of them, while an object may say anything true of itself.

With those declarations, the mistakes become diagnostics:

```ada
UART1.CR.Baud_Rate := 9600;  --  proved, or rejected, statically
UART1.CR.Enable    := True;  --  checked against SR.Busy
X := UART1.DR;               --  requires SR.RX_Ready to have been tested
```

Conditions accumulate. A write to `UART1.CR.Baud_Rate` must satisfy both the
`CR` clause and the `Baud_Rate` clause, because both name a part containing it.

Provable, or merely checkable
-----------------------------

A guard falls into one of two classes, which get different treatment, and the
compiler decides which applies from the `Environment_Writes` of the components
that the condition reads. They are called Case 1 and Case 2 throughout, and
*Discharging the obligation* states each of them exactly.

**Case 1, a guard that the program owns**: every component read by the
condition has `Environment_Writes => False`, so nothing outside the program
writes them. The condition is a stable property of program state, and the
obligation is an ordinary proof obligation:

```ada
procedure Configure (D : Baud_Divisor) is
begin
   UART1.CR.Enable    := False;
   UART1.CR.Baud_Rate := D;      --  provable: Enable was just set False
   UART1.CR.Enable    := True;
end Configure;
```

Get the order wrong and GNATprove reports an unproved check, with no runtime
cost when you get it right.

**Case 2, a guard that the device owns**: some component read by the condition
has `Environment_Writes => True`, which is also what a component that says
nothing gets by default. The condition cannot be established to hold at the
access, so the obligation is weakened to one that can be discharged and is
still worth having: *the condition must be evaluated, and found True, on every
path reaching the access, with no intervening write to the guarded part.* In
other words, you must have polled.

```ada
function Get_Byte return Byte is
begin
   while not UART1.SR.RX_Ready loop      --  the poll
      null;
   end loop;
   return UART1.DR;                      --  discharged: RX_Ready was tested
end Get_Byte;

function Get_Byte_Broken return Byte is
begin
   return UART1.DR;                      --  unproved: SR.RX_Ready never read
end Get_Byte_Broken;
```

This does not eliminate the race: the device may clear `RX_Ready` between the
loop and the read, and nothing in any language can prevent that. It eliminates
forgetting to poll, which is the bug that actually happens.

Rules about an action, not a state
----------------------------------

Every condition so far reads a value. That covers most datasheet rules, because
most of them are about hardware state, and the state is readable: "not while
the busy flag is set", "only once the clock is enabled". Some rules are not,
and the reason is always the same: the thing that must have happened first
leaves nothing to read.

Command registers are the case. A trigger is write-only, so after writing it
there is no state anywhere that says so, and every rule of the form "this
register may only be written after that command has been issued" is beyond
reach. The nRF51 UART is the example: `TXD` may only be written once
`TASKS_STARTTX` has been triggered, and `TASKS_STARTTX` has no readable value at
all. The attribute `'Written` supplies what is missing, being True once `X` has
been written by the program at least once since elaboration:

```ada
   with Write_When => (TXD when TASKS_STARTTX'Written)
```

`'Written` is ghost state maintained per object by the analysis. It also makes
write-once registers expressible:

```ada
   Lock : Boolean with Write_When => not Lock'Written;
```

which is exactly SVD's `access = writeOnce`, the one entry that the mapping
table below would otherwise have to leave as a gap.

What you gain
-------------

- The compiler rejects the accesses that the hardware does not support, at the
  point of use, rather than letting the device fail silently at run time.
- Where a partial update would be wrong, the compiler says so rather than
  emitting a read-modify-write and hoping; and reserved bits get written the
  way the datasheet asks, because the type says which kind of reserved they
  are.
- The sequencing rules that a datasheet states in prose become checked
  obligations attached to the register, so they hold for every access to it
  and not only for the accesses that go through a particular subprogram.
- `svd2ada` and equivalent generators can emit the access information an SVD
  file carries, so on a device whose description populates it, the checks cost
  the user nothing; and every value the description states about an effect has
  a place in the declaration, so nothing is dropped into a comment on the way.
- GNATprove treats a control register as a variable and a status register as
  an environment input, in the same record, which is what a driver actually
  needs to be provable. Where the program is the sole writer, it also knows
  what a write with an effect left behind, since the declaration says whether
  the provoked bits end up clear, set, or flipped, and a sequencing rule over
  that same state is proved outright rather than checked.

Reference-level explanation
===========================

Aspect `Program_Access`
-----------------------

`Program_Access` may be specified on a component of a record type, on a
(sub)type, or on a stand-alone object. Its value is one of `Read_Write`
(default), `Read_Only`, or `Write_Only`. When specified on a type, it applies
to the whole object; specifying it on both a component and the component's
subtype is illegal unless the values agree.

Legality rules:

1. A name denoting an object or component whose `Program_Access` is
   `Read_Only` shall not be the target of an assignment, an `out` or `in out`
   actual, or the prefix of a name so used.
2. A name denoting an object or component whose `Program_Access` is
   `Write_Only` shall not occur in a context that reads it: it may appear only
   as the target of an assignment or as an `out` actual. A read of an object
   one of whose components is `Write_Only` is illegal for the same reason,
   even though the name of that component does not appear in it: the value
   read for those bits is whatever the hardware returns for bits the program
   is not entitled to read. The readable components are read one at a time.
3. A `Read_Only` component supplies no value to a write of the enclosing
   object, so its declaration must. In a record aggregate for such a type the
   component shall be omitted or given `<>`, and the value written is its
   default expression, or the `Default_Value` of its subtype. A write of an
   object one of whose components is `Read_Only` with neither is illegal, and
   the diagnostic should say that the datasheet's write value for that
   component belongs in its declaration. This holds of any write of the
   object: an aggregate and the whole-register store of rule 12 alike.

Aspect `Environment_Writes`
---------------------------

`Environment_Writes` may be specified in the same places. It is a Boolean,
defaulting to True, and it answers one question: does anything outside the
program write this component?

It has no effect on legality or code generation. It is consumed by SPARK, for a
component, as `Async_Writers => Environment_Writes`. The other three
properties are derived too, from the effect aspects, which the section *How the
SPARK properties are derived* sets out once those aspects have been given.

### When `Environment_Writes => False` is not safe to claim

Everything above assumes that distinct component names denote distinct
hardware state, and real peripherals may break that assumption. The nRF51
UART's `INTENSET` at `16#304#` and `INTENCLR` at `16#308#` are two registers,
at two addresses, onto one interrupt-enable state: a one written to a bit of
either enables or disables that interrupt, and reading either returns the
current state. Neither is written by the device, so
`Environment_Writes => False` is the hardware-facing truth about both, and it
is unsound: a write to `INTENCLR.CTS` changes what `INTENSET.CTS` reads, and
the analyzer has been told these are components of distinct types, so it would
conclude something false about a declaration containing no error. The remedy
is the default, at the cost of the read-back: on a SET/CLEAR pair the program
cannot prove what it has just enabled. The hazard therefore arises only where
someone overrides the default.

4. `Environment_Writes => False` on a component is erroneous unless that
   component's name is the only one through which the state it denotes can
   change. An implementation is not required to detect this and in general
   cannot. A generator working from a description that does record the relation,
   such as SystemRDL's aliasing, should not emit `False` across it.

Aspect `Reserved`
-----------------

`Reserved` marks a component that exists in the layout because the hardware has
those bits, not because the program has any use for them. It may be specified on
a component of a record type. Its value is `Write (E)` for a static expression
`E`, or `Preserve`, or it may be given with no value at all.

5. A name denoting a component with `Reserved` shall not occur in program
   text. Not as a read, not as an assignment target, and not as a component
   name in an aggregate: a reserved component is not part of the aggregate's
   component set at all.
6. `Reserved => Write (E)` means a write of the enclosing object stores `E` in
   the component.
7. `Reserved => Preserve` means a write of the enclosing object reads it first
   and copies the component's bits across. It is only permitted on a record
   type none of whose components has a `Read_Effect` other than `None`, since
   otherwise that read would itself have an effect.
8. `Reserved` with no value means the component has no write value. It is only
   permitted on a record (sub)type specified `Program_Access => Read_Only` (on
   the type, that is; rule 9 forbids the aspect on the reserved component
   itself), which is what makes the object unwritable. A write is then illegal
   by rule 1, and the diagnostic should say that giving the register a write
   value takes both dropping `Read_Only` and choosing `Write` or `Preserve`
   for the gap.
9. A component with `Reserved` shall not have a default expression, and shall
   not also specify `Program_Access`, `Write_Effect`, or `Read_Effect`: those
   describe how the program may touch a component, and this one is not
   touched.

Aspects `Read_Effect` and `Write_Effect`
----------------------------------------

Both may be specified on a component, a subtype, or a stand-alone object.

`Read_Effect` has values `None` (the default) and the four *actions* that state
an outcome for a read: `Clear`, `Set`, `Modify`, and `External`. `Clear` and
`Set` say the read leaves the component all zeros or all ones; `Modify` says the
read changes it in a way the description does not state; `External` says the
effect is on other state, as when reading a data register advances a FIFO
pointer.

`Write_Effect` has the value `Normal` (the default), or an aggregate of one
association, *trigger* `=>` *action*. The trigger is `Trigger_On_One`,
`Trigger_On_Zero`, or `Trigger_On_Write`, and the action is `Clear`, `Set`,
`Toggle`, `Modify`, or `External`, the read side's four with `Toggle` added,
which a write can do because it carries the bits to flip. Exactly one
association shall be given. A field is provoked one way and does one thing; a
field that answered a one and a zero with different effects would be storing
what was written, which is `Normal`. A `Write_Effect` other than `Normal`
requires a component of a discrete type or of a Boolean array type (anything
whose value is a bit pattern, which for a field of a register it always is).
`Read_Effect` has no such restriction, since it constrains contexts rather than
bit patterns.

For any `Read_Effect` other than `None`, the component has
`Effective_Reads => True` and is restricted to the contexts SPARK already
restricts such reads to. Nothing may be assumed about the component's value
after the read, whichever of the four it is, and nothing may be assumed about
any other location either. That is not the actions being interchangeable but a
consequence of the rule above them: a component whose read has an effect has
`Environment_Writes => True`, so the device may have overwritten whatever the
read left behind before the next read sees it. The action is recorded because a
declaration should carry what the datasheet and the vendor description say, and
because a reader of `Read_Effect => Clear` knows why the second read of a status
register comes back empty; it is not recorded because an analyzer consults it.

The trigger determines the component's *identity value*: the value whose
writing provokes nothing, which is how "leave this field alone" is spelled on
hardware where every write is a write of the whole word. A one provokes under
`Trigger_On_One`, so its identity value is 0; a zero provokes under
`Trigger_On_Zero`, so its identity value is all ones. That is why the two
determine different machine code for the same source. `Trigger_On_Write` is
provoked by any write whatever and so has no identity value at all, which is
what makes a partial update illegal.

The *provoked bits* of an assignment are the bits at which the value assigned
differs from the identity value; under `Trigger_On_Write` every bit of the
component is provoked, whatever value is assigned. The action says what becomes
of those bits, and so is the half of the aspect that the analysis rather than
the code generator consults. Which half is doing the work is worth keeping
straight: `(Trigger_On_One => Clear)` and `(Trigger_On_One => Set)` emit the
identical store and differ only in what is known afterwards, while
`(Trigger_On_One => Clear)` and `(Trigger_On_Zero => Clear)` emit different
stores and leave the same thing behind.

The action is a property of the field and not a choice at the point of use: a
field does one thing when provoked, and the program decides only whether to
provoke it, and on a multi-bit field, which bits.

For a `Write_Effect` other than `Normal`:

10. An assignment to the component is a write of the value assigned, not a
    statement about its value afterwards: the value assigned is the bit
    pattern the device receives, and what the device does with it is given by
    the action, on the provoked bits. `Clear` leaves them zero, `Set` leaves
    them one, and `Toggle` inverts them; `Modify` and `External` say nothing
    about them, the first because the description does not state what the
    device does, the second because what the write provokes is other state
    altogether. Bits that are not provoked are unchanged. That post-state is a
    fact the analysis may use only where the component also has
    `Environment_Writes => False`, since otherwise the device may change the
    component again before the next read; on a device-written flag the action
    is therefore a fact about the store's effect and not about any later read
    of it. The component shall not be passed as an `out` or `in out` actual,
    since a copy-back writes a value that the callee computed as a state,
    which rule 11 cannot check and which on a `Trigger_On_Write` component
    provokes the effect whatever it holds.
11. An assignment to such a component says "provoke the effect", and the value
    assigned says on which bits: any value other than the effect's identity
    value provokes it, on the bits where the two differ. Where the value
    assigned is static it shall therefore not be the identity value itself (0
    for `Trigger_On_One`, all ones for `Trigger_On_Zero`), since that
    assignment reads as though it changed the component and does nothing at
    all, which is the one mistake that this spelling makes easy. On a
    `Boolean` component that leaves one legal value, `True` under
    `Trigger_On_One` and `False` under `Trigger_On_Zero`, which is as it
    should be: the only thing a write to a one-bit command field can say is
    "now", and not provoking it is spelled by not assigning to it. On a wider
    component every mask but the identity is legal, so the value selects the
    bits, and all ones under `Trigger_On_One` acknowledges every source at
    once. On a `Trigger_On_Write` component nothing is forbidden, since any
    write provokes the effect. The action does not enter this rule: what
    provokes nothing is provoked by nothing whatever the effect would have
    been.
12. Where the component is not independently addressable, so that it cannot be
    written without writing the enclosing object, the assignment is
    implemented as a store of the whole object in which the component holds
    the value assigned and every other component holds its own write value:
    its identity value where it has a `Write_Effect`, the static expression of
    `Reserved => Write (E)`, the value that rule 3 requires a `Read_Only`
    component to declare, and, for `Reserved => Preserve` and for a `Normal`
    component that the assignment does not name, the value the register
    currently holds. Where some component's write value is the value it
    currently holds the store is preceded by exactly one load of the object,
    and where none is, by none. A `Write_Effect` component's bits are never
    the ones that load returned, whichever component the assignment named,
    since storing back what a load returned is what acknowledges a flag the
    program never looked at. This composition governs every write of the
    enclosing object, and not only an assignment to a component that has a
    `Write_Effect`. Where the component *is* independently addressable, none
    of this applies: the assignment is not a write of the enclosing object, so
    no other component needs a write value, a `Read_Only` sibling needs no
    default expression, and a `Trigger_On_Write` sibling does not forbid the
    partial update. That case arises on a register of byte-wide or word-wide
    fields, `Atomic_Components` being the usual way it turns up, and not on
    the bit-mixing registers this RFC is mostly about, since independent
    addressability of one-bit fields is not implementable on ordinary
    machines. In a record aggregate for the whole object a
    `Write_Effect` component may be omitted or given `<>`, in which case its
    identity value is stored; where it is given a value, that value is written
    and rule 11 does not apply, since writing every component's identity value
    is how a whole register is written without provoking anything.
13. Neither `Trigger_On_Write` nor `Normal` has an identity value, but they
    differ in what follows. A `Normal` component is left alone by writing back
    what it currently holds, which is the write value rule 12 gives it. A
    `Trigger_On_Write` component cannot be left alone at all, since any write
    of the object provokes its effect, so a record carrying one has no partial
    update of any of its components, and an assignment to a single component
    of it is illegal whether or not that component is the one with the
    `Write_Effect`.

    The load that rule 12 may require carries two conditions of its own, and
    where either fails the partial update is likewise illegal and the register
    must be written whole. The load shall be harmless: no component of the
    record may have a `Read_Effect` other than `None`, which is rule 7's
    condition for `Reserved => Preserve`, and holds here for the same reason.
    And it shall not be able to lose an update: a `Normal` component whose
    write value the load supplies shall have `Environment_Writes => False`,
    since otherwise the device may change it between the load and the store,
    and the store would revert that change. Where it fails, the value has to
    come from the program, and the aggregate is what makes the program state
    it.
14. Reading the component is unaffected, and governed by `Program_Access` and
    `Read_Effect` as usual.
15. The component shall not have a default expression. Rule 12 already
    determines the value stored in a component that the program did not name,
    so a default would at best restate it and at worst contradict it; and a
    default expression means "the value stored when none is given", which has
    no reading for a component whose write provokes a command rather than
    storing a value.

How the SPARK properties are derived
------------------------------------

`Async_Writers` follows `Environment_Writes` component by component, as that
aspect's own section says. The other three follow the effect aspects.

`Effective_Reads` keeps its current meaning and is derived: it is True for a
component whose `Read_Effect` is other than `None`, and False otherwise.
`Effective_Writes` likewise follows `Write_Effect`: True for a component whose
`Write_Effect` is other than `Normal`, False otherwise. Of SPARK's two
consistency requirements on these properties (RM 7.1.2(6)), one becomes a
legality rule here and one is met by construction: `Read_Effect` other than
`None` requires `Environment_Writes => True`, which a declaration can get
wrong and a compiler shall reject; `Write_Effect` other than `Normal` requires
`Async_Readers => True`.

An object still has the four properties, since existing analysis and existing
contracts are written in terms of them, and they are derived from its
components: each is True for the object if it is True for any component. So a
record with one device-written status bit is an object with
`Async_Writers => True`, as it is today. Where the object or its type also
specifies one of the four explicitly, the values shall agree, as for
`Program_Access` on a component and its subtype. The derivation applies only to
a type one of whose components specifies `Environment_Writes`, `Read_Effect` or
`Write_Effect`: on a type that specifies none of them, the four properties keep
exactly their current meaning, which is what makes an existing declaration that
sets them by hand unaffected.

The consequences for analysis are the existing ones, applied per component
rather than per object:

- A component with `Async_Writers => False` may be read in an assertion
  expression and may be assumed unchanged between two reads with no
  intervening write. It yields on read the last value written by the program
  only where its `Write_Effect` is `Normal`: where a write provokes an effect,
  what it yields is what rule 10 derives from the action, which is the value
  written for none of the five and is nothing at all for two of them.
- A component with `Async_Readers => False` may have its writes coalesced or
  eliminated by the analysis model (not by the compiler, which is still bound
  by `Volatile`), so successive writes need not be reported as effects.
- A component with `Effective_Reads => True` is restricted to the contexts
  SPARK already restricts such reads to.
- An object all of whose components have `Environment_Writes => False` and no
  effective reads or writes is not an external state, and is not required to be
  declared at library level.

`Global` and `Depends` contracts continue to name objects, not components; the
refinement of effects to components is what a component-level `Modifies`
aspect, proposed separately, already provides, and the two features compose:
`Modifies => Control.Baud_Rate` says which component this call writes, while
`Environment_Writes` says who else can.

Aspects `Read_When` and `Write_When`
------------------------------------

Both may be specified on a record type, on a component of a record type, or on
a stand-alone object. Each takes a positional list of clauses of the form

```
   name when condition
```

where `condition` is a Boolean expression. A clause with no `when` part is
illegal: an unconditional prohibition is `Program_Access`, not this.

A subprogram with `Modifies => CR.Baud_Rate` inherits the obligation of the
`Baud_Rate` clause, which is what makes these contracts compositional rather
than checked only at the leaves.

That clause form is deliberately the one that the `Modifies` aspect already
uses, where a `MODIFIES_CLAUSE` is `MODIFIED_OBJECTS { when GUARD }`, and so is
the reading of the guard. `Modifies` fixes it as evaluated once and for all at
the point where the obligation arises, with the clause enabled if the guard is
True, and these aspects mean the same thing at the access rather than at the
call. Reusing it is worth more than a saved grammar rule: it is a settled
answer to when a guard is evaluated, from a feature already in production, and
it means a reader who knows one aspect can read the other.

Name resolution:

16. Specified on a type, `name` shall denote a component of that type,
    possibly a nested one (`CR.Baud_Rate`), and `condition` shall name only
    components of that type. No object may be named, so that the type stays
    usable for several objects.
17. Specified on an object, `name` shall denote a part of that object, and
    `condition` may in addition name any object visible at the point of the
    aspect specification.
18. Specified on a component, `name` is omitted and the aspect applies to that
    component; the condition follows rule 16 for the enclosing type.

Aspects on a type and on an object of that type accumulate rather than override,
and so do clauses naming a part and clauses naming a whole containing it. The
obligation at an access is the conjunction of the conditions of every clause
whose named part overlaps the accessed part. Writing a whole peripheral,
`UART1 := (...)`, therefore has to satisfy every clause of every part, and
that conjunction is often unsatisfiable. It should be: peripherals are not
assignable objects. The diagnostic should say which clause failed rather than
listing all of them.

### Legality rules

19. A condition shall not read a component whose `Read_Effect` is other than
    `None`. Evaluating the guard would then have an effect on the device, and
    the guard is evaluated an implementation-defined number of times (including
    zero, when assertions are off). This is the rule that makes the feature safe
    to compile away.
20. A condition shall not read a component whose `Program_Access` is
    `Write_Only`, for the reason that mode already gives; a component carrying
    the `Reserved` aspect may not be named in a condition at all, by rule 5.
    `X'Written` is not a read of `X` and remains permitted on a `Write_Only`
    component. This is not a technicality: a write-only register has no
    readable value, so `'Written` is the only thing a guard can say about
    one, and without it every write-only register (every trigger, every
    command port) would be beyond the reach of this feature.
21. `Read_When` on a component whose `Program_Access` is `Write_Only`, and
    `Write_When` on a component whose `Program_Access` is `Read_Only`, are
    illegal: there is no access to guard.
22. A condition may read a component whose `Async_Writers` is True,
    notwithstanding SPARK RM 7.1.3(9).

SPARK bars a read of an effectively volatile object from an assertion
expression because 1) an assertion must be free of effects, and 2) it must not
change value under its own evaluation. The first property is the one that rule
19 covers. The second is removed in this context, as the basis of the two
tiers below: where the property still holds, the guard is a normal proof
obligation; where it does not, the obligation is explicitly weakened. So the
restriction is less relaxed than replaced by a rule that says what to do when
it is violated. The relaxation is needed for a guard the device writes, and
for nothing else.

That last claim is measurable, since rule 22 is the one place this RFC touches
an existing SPARK rule. Reduced to its smallest form, a precondition over a
device-written register is rejected:

```ada
Status : Integer with
  Volatile, Async_Readers, Async_Writers, Import,
  Address => System'To_Address (16#4000_0000#);

procedure Use_It with
  Global => (Input => Status),
  Pre    => Status /= 0;
```

```
error: volatile object or volatile function call in interfering context is not
       allowed in SPARK (SPARK RM 7.1.3(9)) [E0004]
```

Turn off `Async_Writers` alone, keeping `Async_Readers` so that the object is
still effectively volatile, and the same precondition is legal.

So 7.1.3(9) keys on whether the read interferes and not on effective volatility
in general, which is why Case 1 needs no relaxation at all and rule 22 reaches
only Case 2.

### Discharging the obligation

Let *G* be the set of components read by a clause's condition.

**Case 1: every component of *G* has `Environment_Writes => False`.** The
condition is a function of program state alone. The obligation is that the
condition holds immediately before the access, and it is a proof obligation in
the ordinary sense, discharged by GNATprove using the same reasoning it
applies to non-volatile state. `Async_Writers` being False for every component
of *G* is precisely what licenses treating a read of the register as yielding
the last value that the program wrote, which is what makes this work, and that
license comes from `Environment_Writes`, not from the guard.

**Case 2: some component of *G* has `Environment_Writes => True`, whether
specified or left to the default.** The condition cannot be shown to hold at
the access. The obligation is instead: on every path reaching the access, there
is an evaluation of the condition that yielded True, and between that
evaluation and the access there is no write to the guarded part and no write by
the program to any component of *G*.

This is a dataflow property, not a value property, and it is decidable by the
same machinery that proves initialization. It is strictly weaker than Case 1:
it establishes that the program consulted the device before acting, and nothing
about what the device did next.

**Run-time semantics.** Under an assertion policy that enables them, the
condition is evaluated immediately before the access, and `Assertion_Error` is
raised if it is False, in both cases. This is the useful behavior during
bring-up, and it is why rule 19 matters: a guard with a read effect would make
enabling assertions change the device's behavior.

When assertions are off, no code is generated for either case, exactly as for a
precondition.

Attribute `'Written`
--------------------

For a part `X` of a volatile object, `X'Written` is a Boolean-valued ghost
attribute, False after elaboration and True once the program has performed a
write of `X` or of any part containing `X`. It is maintained by the analysis and
by the runtime assertion machinery only; no code is generated for it when
assertions are off, and it is not addressable.

`'Written` is permitted in a `Read_When` or `Write_When` condition and in
assertion expressions, and nowhere else. Whether it should also be permitted in
a `Global` or `Depends` contract turns on what kind of state it is, which this
RFC does not settle, so it is left out for now rather than ruled out: a
restriction can be lifted later without invalidating any code that was written
under it, and a permission cannot be withdrawn on the same terms.

The negative form is the useful one. `Write_When => (X when X'Written)` can
never be satisfied, since the write that would make the attribute True is the
write the clause forbids, and it deserves the warning that any statically
False condition does.

`'Written` inherits the aliasing hazard of rule 4. Where two addresses reach
one piece of state, a write through one leaves `'Written` False for the other,
so a write-once register with a second address appears unwritten through that
view. Rule 4 handles the analogous case for `Environment_Writes` by forbidding
the annotation rather than by declaring alias groups, and a `'Written` clause
naming a component reachable by another name is erroneous on the same terms.

A subprogram whose body writes `X` therefore establishes `X'Written`, which
propagates through contracts as an ordinary postcondition would. Whether it
should be *expressible* in a postcondition is left open below.

The mapping from vendor descriptions
------------------------------------

A generator should have somewhere to put every field-level fact that a
CMSIS-SVD description gives it, even where several facts land in one place. The
correspondence:

| SVD attribute and value | Ada |
| ----------------------- | --- |
| `access` = `read-only` | `Program_Access => Read_Only` |
| `access` = `write-only` | `Program_Access => Write_Only` |
| `access` = `read-write` | `Program_Access => Read_Write` |
| `access` = `writeOnce`, `read-writeOnce` | `Write_When => not X'Written` |
| `readAction` = `clear` / `set` / `modify` / `modifyExternal` | `Read_Effect => Clear / Set / Modify / External` |
| `modifiedWriteValues` = `oneToClear` / `oneToSet` / `oneToToggle` | `Write_Effect => (Trigger_On_One => Clear / Set / Toggle)` |
| `modifiedWriteValues` = `zeroToClear` / `zeroToSet` / `zeroToToggle` | `Write_Effect => (Trigger_On_Zero => Clear / Set / Toggle)` |
| `modifiedWriteValues` = `clear` / `set` | `Write_Effect => (Trigger_On_Write => Clear / Set)` |
| `modifiedWriteValues` = `modify` | `Write_Effect => Normal` (the default) |
| `enumeratedValues` with `usage` = `write` | `Write_Effect`, by the reduction below |
| `alternateRegister` | an overlay, and rule 4 on both views |
| *no SVD equivalent* | `Environment_Writes` |
| `resetValue`, for a gap between declared fields | `Reserved => Write (…)` |
| *no SVD equivalent* | `Reserved => Preserve` |

Every value that a description can state about an effect has a place of its
own, which is the point of the trigger-and-action pair: a description says
what provokes an effect and what the effect is, and so does the declaration,
so a generator has nothing left over to put in a comment and nothing to
decide. The grid is larger than the formats populate, fifteen pairs against
SVD's eight and SystemRDL's nine, because the trigger and the action are
independent facts and closing the grid costs less than enumerating the
combinations hardware happens to ship. `Modify` and `External` are the two
that no format spells for writes in those words; they are what SystemRDL's
`wuser` and `ruser` escape hatches become, and what a command register whose
write does something the datasheet describes in prose gets.

Four rows deserve comment, and the reserved bits deserve a word after them.

The `writeOnce` row is the one that the second half of this RFC supplies, and
`access` is the only place SVD says anything about *when* at all. A field that
may be written once and no more is a rule about the second write rather than
about the first, which is why no ownership aspect can carry it and why the
mapping table would otherwise have to record a gap there.
`Write_When => not X'Written` states it in one clause, on the field, and a
generator can emit it; `read-writeOnce` is the same clause on a field that
stays readable afterwards.

The `enumeratedValues` row carries most of the real data. A field may have two
`enumeratedValues` blocks, one with `<usage>read</usage>` and one with
`<usage>write</usage>`, and that, rather than `modifiedWriteValues`, is where
a write side effect is often stated: a read enumeration naming the states the
field reports, beside a write enumeration whose single literal is the value
that triggers the effect. The reduction is therefore easy, a write enumeration
whose literals are all 1 giving `Trigger_On_One` and all 0 giving
`Trigger_On_Zero`, with the action taken from that literal's name where it
says one (`Clear`, `Set`, `Toggle`) and `Modify` where it does not; and the
point of performing it is that the *read* enumeration survives as the field's
type.

`alternateRegister` needs no aspect, since Ada already has the construct: it
names a second register at the *same* offset with a different layout, which is
two objects at one `Address`, each carrying its own aspects. What it does need
is rule 4, on both of them. The same state is reachable through two names, so
neither view may claim `Environment_Writes => False`, and here a generator can
see that, since the two addresses are equal in the description it is reading.

Rule 4's own case is the converse, several addresses onto one piece of state,
and for that SVD records nothing at all: `INTENSET` at `16#304#` and `INTENCLR`
at `16#308#` appear as two unrelated registers. A generator cannot tell where
the rule applies, which is a reason for it to forbid rather than to require the
annotation.

`Environment_Writes` cannot be filled in from an SVD file, because SVD has no
notion of the hardware's own access, only the program's. Either value can be
inferred where `access` is decisive: a field that the program may only read
must be written by something else, giving `Environment_Writes => True`, and a
field that the program may only write is presumably read by the device rather
than written by it, giving `False`. The case that cannot be inferred is
`access = read-write`, which covers both a control register that the device
never writes and a register with mixed ownership, and that is exactly the case
where the SPARK gain is largest. So the most valuable annotation in this RFC
is the one a generator cannot supply, which is an argument for it being an
aspect in the language that a user can write and a reviewer can check, rather
than generated output. SystemRDL, which does have `hw`, can supply it.

Reserved bits are absent from SVD entirely: every `Reserved_x_y` component in
a generated map is the generator synthesizing a name for a gap between
declared fields and taking its value from the register's `resetValue`. So the
two halves of reserved-bit handling have different provenance, which is the
second reason to separate them from `Program_Access`. `Reserved => Write (E)`
is derivable, since the generator already computes `E`; `Reserved => Preserve`
is not and cannot be, because nothing in SVD distinguishes "write back what
you read" from "write the reset value", a decision that a human makes per
register, from the datasheet text.

Rationale and alternatives
==========================

The information is real, and it is already written down. An SVD file says of
every field who may read it, who may write it, and what an access does to the
device; a datasheet says when the access is allowed. Ada has nowhere to put any
of it, so it survives as comments. Putting it in the declaration pays twice: the
compiler generates the access the hardware wants and rejects the ones it does
not support, and GNATprove reasons about a control register as precisely as
about an ordinary variable, instead of assuming the device rewrites it between
any two statements.

The alternative that needs no language change is a setter/getter API: hide the
register in a body and expose an accessor per field, carrying contracts. It is
what careful drivers already do, and it is cumbersome, one subprogram per field
for a peripheral with fifty of them, but the verbosity is not the objection. The
accessors do not replace the annotated declarations, they sit on top of them,
so the map is still there, in the body, minus every aspect. And two things no
accessor recovers at any price: a provable read-back on a register the device
never writes, for which it needs shadow state that can drift from the register
it mirrors, and any contract at all on a guard the device controls, since an
assertion expression may not read an effectively volatile object.

The neighboring answers fail for related reasons. Generated wrapper types, as
the Rust ecosystem produces, cost the record representation clause, which is the
part of Ada that makes register maps worth writing in the first place. Typestate,
which embedded Rust uses to make "configure before enable" a type error,
dissolves the declaration into a family of types and still cannot track a flag
that the device changes. And doing it in the build system, by teaching `svd2ada`
to emit a side file the prover reads, leaves hand-written maps and undescribed
devices unserved, and makes correctness depend on a generator staying in sync
with a hand-edited spec.

The smallest alternative is inside the language rather than outside it: allow
`Async_Writers` and friends on components and stop there. That delivers the
proof benefit with no new concepts and is a reasonable fallback, so the case
for going further is not that it buys more but that it is harder to get wrong.
The four properties are stated from the analyzer's point of view and are
notoriously easy to invert, since `Async_Readers` on a control register is a
property of the device's reads and not of the program's, whereas
`Environment_Writes => False` says something about the device that a datasheet
either supports or does not. The model underneath is the same either way, so
this is a question of surface, and the surface is where these mistakes get
made.

Drawbacks
=========

This adds seven aspects, one attribute and fifteen enumeration literals to a
part of the language that is already dense: a fully annotated register
declaration is more verbose, and the interaction surface with `Volatile`,
`Atomic`, `Full_Access_Only`, `Bit_Order`, and `Scalar_Storage_Order` is
non-trivial even though no aspect here changes representation.

Most of the effect vocabulary is not consulted by the compiler, and the part
the prover consults is narrow. The trigger decides a store and the action
decides a post-state, but the post-state is usable only under
`Environment_Writes => False`, and the fields that carry a write effect are
mostly device-written flags, where it is not. On the read side no action is
consulted at all: all four give `Effective_Reads => True` and nothing else.

`'Written` adds per-object ghost state to the analysis for the benefit of a
comparatively rare register kind. It also raises the questions of whether it may
appear in postconditions, how it interacts with `Global`, and what it means for
an object whose elaboration writes it.

The syntax is another clause-list aspect in a language that is accumulating
them, and a peripheral with a dozen rules acquires a dozen-clause aspect on its
type, which is not obviously more readable than a dozen comments. The
counter-argument is that it is checked, but the readability cost is real.

Compatibility
=============

The proposal is backward compatible because all five component aspects default
to the value that reproduces current behavior: `Program_Access => Read_Write`,
`Environment_Writes => True`, `Write_Effect => Normal`, `Read_Effect => None`,
and no `Reserved`. `Read_When` and `Write_When` are additions with no default
behavior at all: an object carrying neither is unconstrained, as today. An
existing register declaration is unchanged in legality, representation, and
generated code, and existing SPARK code sees the same four volatility
properties it sees today. No existing program becomes illegal, and no existing
proof result changes.

Rule 22's relaxation applies only inside a `Read_When` or `Write_When`
condition, so it cannot affect the legality of any existing assertion
expression.

The added legality rules only constrain programs that opt in by writing the
aspects, and the runtime checks follow the assertion policy, so a program that
adopts the aspects and builds without assertions generates identical code to one
that does not. This makes incremental adoption per peripheral practical, which
matters: these annotations will be added to existing register maps one datasheet
chapter at a time.

The aspects are the whole point of the feature, so once it is prototyped it
belongs in the default feature set rather than permanently behind a switch:
nothing is imposed on code that does not write them, and a switch would only
keep the checks away from the users who would benefit. During prototyping it
belongs in the `Experimental` set under `-gnatX0`, as the process requires.
A generator is the one case wanting a switch of its own, since `svd2ada`
emitting these aspects makes code that previously compiled illegal, correctly
so but all at once; generators should gate the emission for at least one
release.

Open questions
==============

On who may touch which bits:

- Whether `Read_Effect`'s four actions earn their place, given that all four
  give `Effective_Reads => True` and nothing else. The alternative is a
  per-component `Effective_Reads => True` Boolean, which is smaller and
  matches SPARK's existing name. What the enumeration keeps is the vendor
  description's own distinction, a form symmetric with `Write_Effect`'s
  action.
- Interaction with `Relaxed_Initialization` and with `Modifies`, which both
  reason about parts of an object and will need rules for parts the program
  may not read.
- Whether `Volatile_Function` should follow the per-component properties
  rather than the object's. SPARK forbids a nonvolatile function from having a
  volatile input (RM 7.1.3(7)) and treats a call to a `Volatile_Function` as
  interfering, both at object granularity, so a function that reads one
  program-owned field of a peripheral is a volatile function because some
  other field of the same record is device-written, and a function as ordinary
  as `Is_Enabled` cannot be written as an ordinary one. `Environment_Writes`
  is what would say which reads actually interfere, since a function over
  components with `Async_Writers => False` and `Effective_Reads => False` does
  not.

On when they may touch it:

- Whether `'Written` should be expressible in postconditions, and in `Global`
  and `Depends`. Expressing it in a postcondition would make initialization
  ordering compositional across subprograms; naming it in `Global` or
  `Depends` would say where the analysis carries it. All three turn on the
  same undecided point, what kind of state the attribute is, which is why the
  reference section leaves all three out for the time being.
- Whether `'Written` should have a companion `'Read`, for the rules whose
  establishing action is a read. Once the program has read the GIC's interrupt
  acknowledge register it may write the corresponding end-of-interrupt
  register, and not before, which is `Write_When => (EOIR when IAR'Read)`.
  Reading `IAR` acknowledges the interrupt, so it has a `Read_Effect` and rule
  19 bars naming it in a condition at all; `'Read` would be on the read side
  what `'Written` already is on the write side under rule 20, the only thing a
  guard can say about a register whose value a condition may not touch.
- Whether conditions should be allowed to call functions, which is how a
  non-trivial guard would want to be written, and which needs exactly the
  notion of a non-interfering read of volatile state that the
  `Volatile_Function` question above asks for.

Prior art
=========

Register description languages
------------------------------

SVD, the format Cortex-M vendor ships, carries `access`, `readAction`, and
`modifiedWriteValues` on registers and on fields; the mapping table above
lists their values against the aspects proposed here. `access = writeOnce`
and `read-writeOnce` are the only sequencing information the format carries,
and `Write_When => not X'Written` is what makes them expressible, so a
generator can emit them.

SystemRDL is the closest match to the design proposed here. It describes each
field with two independent access properties, `sw` and `hw`, precisely the
two-sided model of `Program_Access` and `Environment_Writes`. On top of that
it has `onread` (`rclr`, `rset`, `ruser`) and `onwrite` (`woclr`, `woset`,
`wot`, `wzc`, `wzs`, `wzt`, `wclr`, `wset`, `wuser`) side-effect modifiers,
which `Read_Effect` and `Write_Effect` render one for one. It also has
`swwe`/`swwel` software-write-enable properties, active high and active low,
which gate a field's writability on another field or signal and are a
`Write_When` clause restricted to a single reference.

That the language designed specifically to describe registers arrived
independently at a two-sided per-field access model is a good indication of
its value. Ada, uniquely well placed to consume such descriptions, could benefit
from it.

Rust and typestate
------------------

The embedded Rust ecosystem encodes ordering rules in the type system: peripheral
configuration is a builder that yields an enabled peripheral, and pin modes are
type parameters, so "configure before enable" is a compile error at zero cost.

Ada and SPARK
-------------

The four volatility properties (SPARK RM 7.1.2) are the foundation this proposal
reuses; `No_Caching` established the pattern of adding a property that narrows
what volatility implies for analysis, which is what `Environment_Writes => False`
does per component. `Volatile_Components` and `Atomic_Components` show the
language has already accepted that volatility can need component granularity,
though only for array elements and only as an all-or-nothing property.

Unresolved questions
====================

To resolve during the RFC process. Whether Case 2's obligation is the right
one, or whether the second half should be narrowed to Case 1 and device-flag
rules left to run-time checks, Case 2 being a guard the device writes and Case
1 a guard the program writes, both defined under *Discharging the obligation*;
whether rule 22's relaxation is sound; and whether `'Written` belongs here at
all or is a separable feature.

Whether `Read_Effect`'s four actions earn their place beside a Boolean decides
how much vocabulary the language takes on, and what kind of state `'Written` is
decides whether it may appear in postconditions, in `Global` and in `Depends`.
Whether `Volatile_Function` should follow the per-component properties is a
question about this RFC's scope rather than its content, since the change is
not proposed here; but if the answer is that it belongs here, it belongs before
acceptance and not after, because it would widen what the derived properties
are for.

To resolve during implementation. The precise SPARK rules for components the
program may not read, which is the interaction with `Modifies` and
`Relaxed_Initialization` listed above; whether GNATprove needs any change to
its external-state model beyond attaching the four properties to components,
or whether the existing object-level model must be generalized first; the
dataflow analysis for Case 2, and whether GNATprove's existing initialization
machinery can be reused for it.

Out of scope. Timing, since Ada has no notion of elapsed time in a contract and
inventing one for "wait two peripheral clock cycles after enabling" is not
proportionate. Unlock sequences, "write 0xCAFE to `KEYR`, then 0x1234, then the
register is writable for 16 cycles", which are a small state machine with a
timeout: `'Written` is a single monotonic bit and cannot count, order, or
remember values, so what it could express of one is worse than a comment, and
registers like this want a hand-written abstraction with its own invariant. And
any attempt to make Case 2 race-free.

Future possibilities
====================

Improve `svd2ada` to support all these extensions. Most of the ownership half
is a transcription an SVD file already licenses, so a device whose description
populates `access`, `readAction` and `modifiedWriteValues` would arrive
annotated at no cost to the user, and `writeOnce` would arrive as
`Write_When => not X'Written`, which is the whole of the sequencing
information a vendor file carries. The emission should sit behind a switch for
at least one release, since a generated map that suddenly rejects the driver
on top of it is not a welcome upgrade. A second input format would go further:
SystemRDL has `hw`, which is `Environment_Writes`, and that is the one
annotation with the largest proof value and no SVD equivalent, so a generator
reading SystemRDL could supply what a generator reading SVD must leave to the
user.
