- Feature ID: register_access_model
- Start Date: 2026-09-09
- Status: Proposed

Summary
=======

Ada says **where** a hardware register lives, **how wide** an access to it is
and **how its bits are arranged**, but not the three things a datasheet spends
most of its words on: **who** may touch which bits, **what** an access does to
the device, and **when** it is allowed at all. This RFC adds all three.
`Access_By` states independently what the program and what the environment may
do to each component. `Effect` covers the registers where a read or a write is
a command rather than an assignment. `Access_When` gives the conditions under
which an access is permitted, proved where the guard is state the program owns
and checked at run time where it is state the device owns. The compiler uses
the extra information for legality checks and to choose legal access sequences,
and GNATprove derives the per-component volatility properties from it, so a
control register the device never writes becomes an ordinary variable for proof
while the status register beside it stays an environment input.

Motivation
==========

The first gap, about who and what
---------------------------------

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
layout, whose ownership and whose effects are all machine-checked still has
four sentences of its datasheet nowhere in its declaration:

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
   RX_Ready : Boolean with Access_By   => (Program => Read),
                           Write_Value => False;
   TX_Empty : Boolean with Access_By   => (Program => Read),
                           Write_Value => False;
   Busy     : Boolean with Access_By   => (Program => Read),
                           Write_Value => False;
   --  Overrun is write-one-to-clear: writing a one acknowledges it.
   Overrun  : Boolean with Effect      => (Write => (Trigger_On_One => Clear));
   Reserved : Bits_4  with Access_By   => (Program => None),
                           Write_Value => 0;
end record
  with Volatile, Size => 8, Bit_Order => Low_Order_First;
```

`Access_By` is the contract between the two sides, with a part for each of
them. Each part takes an access mode, one of `None`, `Read`, `Write` and
`Read_Write`: the `Program` part says what your code may do to the component,
and the `Environment` part says what the world outside your code does to it.
Either may be omitted, and both default to `Read_Write`, the permissive value,
so an existing declaration keeps exactly its current meaning. A status flag
needs only the `Program` part, since the default already says that the device
writes it.

When a component of a register is not intended to be written by the program,
we still need a value to fill its bits, because the code writes the whole
register, and datasheets usually say what such a write must carry. That is the
purpose of `Write_Value`, which is zero here, the usual answer for a status
bit whose writes the device ignores.

With that declaration in place:

```ada
Status.RX_Ready := False;    --  illegal: Access_By => (Program => Read)
if Status.RX_Ready then ...  --  fine
Status.Overrun  := True;     --  writes a one: acknowledges it
Status.Overrun  := False;    --  illegal: provokes nothing
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
   Reserved_1 : Bits_3  with Access_By   => (Program => None),
                             Write_Value => 0;

   --  "Reserved. Software must preserve the value read."
   Reserved_2 : Bits_8  with Access_By   => (Program     => None,
                                             Environment => Write),
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
type Control_Register is record
   Enable    : Boolean      with Access_By => (Environment => Read);
   Prescaler : Prescale     with Access_By => (Environment => Read);
   Baud_Rate : Baud_Divisor with Access_By => (Environment => Read);
end record
  with Volatile, Size => 32;
```

`Environment => Read` is the datasheet's own sentence about a control field:
the device samples these bits, at any time, and never changes them. Nothing
else writes them either. The program is therefore the sole writer, and a
read-back yields what was last written. In SPARK terms the component has
`Async_Writers => False` and `Effective_Reads => False`, which makes the
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
real store. Only the analysis changes, and it changes because we told the
truth about the device rather than because we hid the register from the
analyzer.

`Read` rather than `None` is doing work in that declaration. It says that the
device does read these bits, which gives the component `Async_Readers => True`,
so a write to it is an effect on the world even though nothing in the program
reads it back, and the analysis may not treat it as dead.

When an access is a command
---------------------------

For some registers a read or a write is not an assignment at all but an
instruction to the device. `Effect` describes this, in one part per direction:

```ada
type Interrupt_Status is record
   Pending  : Boolean with Access_By => (Program => Read),
                           Effect    => (Read => Clear);
   Reserved : Bits_7  with Access_By => (Program => None);
end record
  with Volatile, Size => 8, Access_By => (Program => Read);
```

The `Read` part says what reading the component does to the device: `None`
(the default), or one of the four actions SVD's `readAction` distinguishes, a
read that clears the field, sets it, modifies it in some way the description
does not state, or modifies something else (`Clear`, `Set`, `Modify`,
`External`). All four make the component's `Effective_Reads` property True, so
it may not be read where a read must have no effect: not in a precondition, an
invariant, or twice in one expression. That is the existing SPARK rule for
objects, here applied to fields. A component whose read has an effect is
written by the environment as well, so whatever the read left behind the
device may have changed already, and that is why the four are one property to
the analyzer even though they are four different sentences in the datasheet.

The `Write` part says both what a write provokes and what it then does:

```ada
Overrun : Boolean with Effect => (Write => (Trigger_On_One => Clear));
```

Its default is `Normal`, written as a value rather than a pair, and it is
today's behavior: the value written is the value stored. Otherwise it is a
trigger and an action. The trigger is `Trigger_On_One`, `Trigger_On_Zero`, or
`Trigger_On_Write`, the three ways a bit can be provoked. The action is
`Clear`, `Set`, `Toggle`, `Modify`, or `External` (the same vocabulary as the
read side, plus `Toggle`, which only a write can do, since only a write brings
an operand to say which bits to flip).

The two halves are separate because they are consulted separately. The trigger
decides the code: an assignment to such a component is a full-width store in
which every component the program did not name holds the value whose writing
provokes nothing, or, where that is not a value it has, the value it already
holds. Only the second of those needs the register loaded first.

```ada
Status.Overrun := True;  --  one store of 2#0000_1000#
```

The action decides what is known afterwards. Writing a one to `Overrun` clears
it, so under `Environment => Read` the analyzer may take the bit as zero after
the assignment; here `Overrun` is a device-set flag, so it may not, and the
action is what a reader and a generator get rather than the prover. The two
actions that state no outcome, `Modify` and `External`, yield nothing either
way: `Modify` because the description does not say what the device does,
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
`Effect => (Write => (Trigger_On_One => Clear))` and a write acknowledges the
bits it names and leaves the rest of that register alone:

```ada
Interrupts.Sources := 2#0011#;  --  acknowledges two of the four sources
```

Between them the two parts hold everything a vendor description states about
an effect, which the mapping table below sets out value by value.

Reserved bits
-------------

Reserved bits are the bits that are in the layout because the hardware has
them and not because the program has any use for them, and `Program => None`
is what says so: the component may not be named at all, neither read nor
assigned nor mentioned in an aggregate. What is left to say about them is what
a write of the register carries for them, and there are three answers, which
need different code:

```ada
Reserved_1 : Bits_3 with Access_By   => (Program => None),
                         Write_Value => Preserve;  --  read-modify-write
Reserved_2 : Bits_4 with Access_By   => (Program => None),
                         Write_Value => 0;         --  always write this value
Reserved_3 : Bits_5 with Access_By   => (Program => None);  --  never written
```

`Preserve` is the datasheet saying "write back the value read", so a whole-
register write has to load first and copy those bits across. A value is
"always write this". The absence of `Write_Value` is for the gap of a register
that is never written, and says just that: these bits have no write value.
What makes such a register unwritable is `Access_By => (Program => Read)` on
the type, which rule 6 requires before the third form may be used at all, and
which is why `Interrupt_Status` above carries it.

Guarding an access
------------------

`Access_When` has two parts, `Write` and `Read`, each a list of clauses naming
a part of the type and the condition under which that part may be accessed.
The `Write` part guards the stores, which is where most datasheet rules land,
since most of them forbid configuring a device at the wrong moment. The `Read`
part guards the loads, for the registers whose value is undefined outside a
window: a data register that holds nothing until the device says it does, an
ADC result that is not the last conversion's until the conversion is complete.

Names in the clauses denote components of the type on which the aspect is
specified, and conditions are ordinary Boolean expressions over those
components. So the rules relating two registers of one peripheral go on the
peripheral type, where both are components:

```ada
type UART_Peripheral is record
   CR : Control_Register;   --  Enable, Prescaler, Baud_Rate
   SR : Status_Register;    --  RX_Ready, TX_Empty, Busy
   DR : Data_Register;
end record
  with Volatile,
       Access_When =>

         (Write => (--  "The baud divisor may only be changed while the
                    --   UART is disabled."
                    CR.Baud_Rate when not CR.Enable,

                    --  "No control field may be written while a
                    --   transmission is in progress."
                    CR           when not SR.Busy),

          Read  => (--  "DR may only be read when RX_Ready is set;
                    --   otherwise the value is undefined and the
                    --   receiver stalls."
                    DR           when SR.RX_Ready));
```

A rule about one register alone can equally sit on that register's own type,
where the names are shorter and the rule travels with the register into every
peripheral that has one:

```ada
type Control_Register is record
   Enable    : Boolean      with Access_By => (Environment => Read);
   Prescaler : Prescale     with Access_By => (Environment => Read);
   Baud_Rate : Baud_Divisor with Access_By => (Environment => Read);
end record
  with Volatile, Size => 32,
       Access_When => (Write => (Baud_Rate when not Enable));
```

and a rule involving another peripheral entirely (a clock gate, a power
domain) goes on the object, where any visible object may be named:

```ada
UART1 : UART_Peripheral with
   Import, Volatile,
   Address     => System'To_Address (16#4001_3800#),
   Access_When => (Write => (CR when RCC.APB2_Enable.UART1_Clock));
```

The split is deliberate: a type may be shared by four UARTs and must not
mention any one of them, while an object may say anything true of itself.

With those declarations, the mistakes become diagnostics:

```ada
UART1.CR.Baud_Rate := 9600;  --  proved, or rejected, statically
UART1.CR.Enable    := True;  --  checked against SR.Busy
X := UART1.DR;               --  requires SR.RX_Ready to have been tested
```

Conditions accumulate, across the parts of an object and across the type and
the object alike. A write to `UART1.CR.Baud_Rate` must satisfy the
`CR.Baud_Rate` clause and the `CR` clause both, because both name a part
containing it, and the clause on `Control_Register` too where the register
type carries one.

Provable, or merely checkable
-----------------------------

A guard falls into one of two classes, which get different treatment, and the
compiler decides which applies from the `Environment` mode of the components
that the condition reads. They are called Case 1 and Case 2 throughout, and
*Discharging the obligation* states each of them exactly.

**Case 1, a guard that the program owns**: the components read by the
condition are not written by the environment, so nothing outside the program
changes them.
The condition is a stable property of program state, and the obligation is an
ordinary proof obligation:

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
has an `Environment` mode that includes `Write`, which is also what a component
that says nothing gets by default. The condition cannot be established to hold
at the access, so the obligation is weakened to one that can be discharged and
is still worth having: *the condition must be evaluated, and found True, on
every path reaching the access, with no intervening write to the guarded part.*
In other words, you must have polled.

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
   with Access_When => (Write => (TXD when TASKS_STARTTX'Written))
```

`'Written` is ghost state maintained per object by the analysis. It also makes
write-once registers expressible:

```ada
   Lock : Boolean with Access_When => (Write => not Lock'Written);
```

where the clause is a bare condition because there is no part of `Lock` to
name. That is exactly SVD's `access = writeOnce`, the one entry that the
mapping table below would otherwise have to leave as a gap.

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

Aspect `Access_By`
------------------

`Access_By` may be specified on a component of a record type, on a (sub)type,
or on a stand-alone object. Its value is an aggregate with two named parts,
`Program` and `Environment`, each of which is an *access mode*: one of `None`,
`Read`, `Write`, and `Read_Write`. Either part may be omitted, and both
default to `Read_Write`. When specified on a type, it applies to the whole
object; specifying it on both a component and the component's subtype is
illegal unless the values agree.

The `Program` part is a rule about the program text, and the legality rules
below are what it means. The `Environment` part is a statement about
everything else that reaches those bits, the device itself, a DMA engine, an
interrupt handler outside the analyzed subsystem, or foreign code, and it has
no effect on legality or on code generation: it is what the SPARK properties
are derived from, in *How the SPARK properties are derived* below.

Legality rules:

1. A name denoting an object or component whose `Program` mode is `Read` or
   `None` shall not be the target of an assignment, an `out` or `in out`
   actual, or the prefix of a name so used.
2. A name denoting an object or component whose `Program` mode is `Write` or
   `None` shall not occur in a context that reads it: it may appear only as
   the target of an assignment or as an `out` actual. A read of an object one
   of whose components the program may not read is illegal for the same
   reason, even though the name of that component does not appear in it: the
   value read for those bits is whatever the hardware returns for bits the
   program is not entitled to read. The readable components are read one at a
   time.
3. `Program => None` says more than rules 1 and 2 together. A name denoting
   such a component shall not occur in program text at all: not as a read, not
   as an assignment target, and not as a component name in an aggregate, of
   whose component set it is not part. This is how the reserved bits of a
   register are declared, the bits that are in the layout because the hardware
   has them and not because the program has any use for them, and the
   distinction the mode draws is between what you may do to a component you
   name and one you may not name.
4. An `Environment` mode that does not include `Write` is erroneous unless
   that component's name is the only one through which the state it denotes
   can change. An implementation is not required to detect this and in general
   cannot. A generator working from a description that does record the
   relation, such as SystemRDL's aliasing, should not claim it across such a
   relation.

### When claiming that the environment does not write is not safe

Everything above assumes that distinct component names denote distinct
hardware state, and real peripherals may break that assumption. The nRF51
UART's `INTENSET` at `16#304#` and `INTENCLR` at `16#308#` are two registers,
at two addresses, onto one interrupt-enable state: a one written to a bit of
either enables or disables that interrupt, and reading either returns the
current state. Neither is written by the device, so `Environment => Read` is
the hardware-facing truth about both, and it is unsound: a write to
`INTENCLR.CTS` changes what `INTENSET.CTS` reads, and the analyzer has been
told these are components of distinct types, so it would conclude something
false about a declaration containing no error. The remedy is the default, at
the cost of the read-back: on a SET/CLEAR pair the program cannot prove what
it has just enabled. The hazard therefore arises only where someone overrides
the default, which is what rule 4 is about.

Aspect `Write_Value`
--------------------

`Write_Value` gives the value that a write of the enclosing object carries for
a component that the program does not write. Its value is a static expression
of the component's subtype, or `Preserve`. It may be specified on a component
of a record type or on a (sub)type, in the latter case with the same
agree-or-illegal rule as `Access_By`, and only where the `Program` mode is
`Read` or `None`: where the program may write a component it supplies the
value itself, or rule 10's composition leaves the component alone.

5. `Write_Value => E` means a write of the enclosing object stores `E` in the
   component, and `Write_Value => Preserve` means such a write reads the object
   first and copies the component's bits across. `Preserve` is only permitted
   on a record type none of whose components has a `Read` effect other than
   `None`, since otherwise that read would itself have an effect on the device.
   In a record aggregate for the type the component shall be omitted or given
   `<>`, and what is written for it either way is its `Write_Value`. Both forms
   govern every write of the object: an aggregate and the whole-register store
   of rule 10 alike.
6. A component that the program may not write and that has no `Write_Value`
   has no write value, and the enclosing object is therefore unwritable. Such
   a component is only permitted in a record (sub)type whose own `Program`
   mode is `Read` or `None`, which is what makes every write of the object
   illegal by rule 1, and the diagnostic for such a write should say that
   giving the register a write value takes both widening the type's `Program`
   mode and choosing a `Write_Value` for that component. This is the shape of
   a status register that the program only ever reads: nothing in it has a
   write value, and nothing needs one.
7. A component that specifies `Write_Value` shall not have a default
   expression, and neither shall a component whose `Program` mode is `None`,
   which shall not specify `Effect` either: an effect describes what happens
   when the program touches a component, and this one it does not touch. The
   write value belongs in an aspect rather than in a default expression
   because a default expression is the value stored when the program gives
   none, and the program never names this component to give one.

Aspect `Effect`
---------------

`Effect` says what an access does to the device where it is a command rather
than an assignment. It may be specified on a component, a (sub)type, or a
stand-alone object. Its value is an aggregate with two named parts, `Read` and
`Write`, either of which may be omitted.

The `Read` part is `None` (the default) or one of the four *actions* that
state an outcome for a read: `Clear`, `Set`, `Modify`, and `External`. `Clear`
and `Set` say the read leaves the component all zeros or all ones; `Modify`
says the read changes it in a way the description does not state; `External`
says the effect is on other state, as when reading a data register advances a
FIFO pointer.

The `Write` part is `Normal` (the default), or an aggregate of one
association, *trigger* `=>` *action*. The trigger is `Trigger_On_One`,
`Trigger_On_Zero`, or `Trigger_On_Write`, and the action is `Clear`, `Set`,
`Toggle`, `Modify`, or `External`, the read side's four with `Toggle` added,
which a write can do because it carries the bits to flip. Exactly one
association shall be given. A field is provoked one way and does one thing; a
field that answered a one and a zero with different effects would be storing
what was written, which is `Normal`. A `Write` part other than `Normal`
requires a component of a discrete type or of a Boolean array type (anything
whose value is a bit pattern, which for a field of a register it always is).
The `Read` part has no such restriction, since it constrains contexts rather
than bit patterns.

The two parts are unequal in shape, and the asymmetry is the hardware's: a
read carries no operand, so it has nothing to be provoked by and names an
action alone, while a write names both what provokes it and what follows. They
are one aspect nonetheless, because they answer one question of the two
directions of an access, and because the registers where either matters are
largely the registers where both do.

For a `Read` part other than `None`, the component has
`Effective_Reads => True` and is restricted to the contexts SPARK already
restricts such reads to. Nothing may be assumed about the component's value
after the read, whichever of the four it is, and nothing may be assumed about
any other location either. That is not the actions being interchangeable but a
consequence of a rule stated below: a component whose read has an effect has
an `Environment` mode that includes `Write`, so the device may have
overwritten whatever the read left behind before the next read sees it. The
action is recorded because a declaration should carry what the datasheet and
the vendor description say, and because a reader of `Effect => (Read => Clear)`
knows why the second read of a status register comes back empty; it is not
recorded because an analyzer consults it.

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
of those bits, and so is the half of the part that the analysis rather than
the code generator consults. Which half is doing the work is worth keeping
straight: `(Trigger_On_One => Clear)` and `(Trigger_On_One => Set)` emit the
identical store and differ only in what is known afterwards, while
`(Trigger_On_One => Clear)` and `(Trigger_On_Zero => Clear)` emit different
stores and leave the same thing behind.

The action is a property of the field and not a choice at the point of use: a
field does one thing when provoked, and the program decides only whether to
provoke it, and on a multi-bit field, which bits.

For a `Write` part other than `Normal`:

8.  An assignment to the component is a write of the value assigned, not a
    statement about its value afterwards: the value assigned is the bit
    pattern the device receives, and what the device does with it is given by
    the action, on the provoked bits. `Clear` leaves them zero, `Set` leaves
    them one, and `Toggle` inverts them; `Modify` and `External` say nothing
    about them, the first because the description does not state what the
    device does, the second because what the write provokes is other state
    altogether. Bits that are not provoked are unchanged. That post-state is a
    fact the analysis may use only where the component's `Environment` mode
    also excludes `Write`, since otherwise the device may change the component
    again before the next read; on a device-written flag the action is
    therefore a fact about the store's effect and not about any later read of
    it. The component shall not be passed as an `out` or `in out` actual,
    since a copy-back writes a value that the callee computed as a state,
    which rule 9 cannot check and which on a `Trigger_On_Write` component
    provokes the effect whatever it holds.
9.  An assignment to such a component says "provoke the effect", and the value
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
10. Where the component is not independently addressable, so that it cannot be
    written without writing the enclosing object, the assignment is
    implemented as a store of the whole object in which the component holds
    the value assigned and every other component holds its own write value:
    its identity value where it has a `Write` effect, its `Write_Value` where
    it has one, and, for `Write_Value => Preserve` and for a `Normal`
    component that the assignment does not name, the value the register
    currently holds. Where some component's write value is the value it
    currently holds the store is preceded by exactly one load of the object,
    and where none is, by none. A component with a `Write` effect never takes
    the bits that load returned, whichever component the assignment named,
    since storing back what a load returned is what acknowledges a flag the
    program never looked at. This composition governs every write of the
    enclosing object, and not only an assignment to a component that has a
    `Write` effect. Where the component *is* independently addressable, none
    of this applies: the assignment is not a write of the enclosing object, so
    no other component needs a write value, a sibling the program may not
    write needs no `Write_Value`, and a `Trigger_On_Write` sibling does not
    forbid the partial update. That case arises on a register of byte-wide or
    word-wide fields, `Atomic_Components` being the usual way it turns up, and
    not on the bit-mixing registers this RFC is mostly about, since
    independent addressability of one-bit fields is not implementable on
    ordinary machines. In a record aggregate for the whole object a component
    with a `Write` effect may be omitted or given `<>`, in which case its
    identity value is stored; where it is given a value, that value is written
    and rule 9 does not apply, since writing every component's identity value
    is how a whole register is written without provoking anything.
11. Neither `Trigger_On_Write` nor `Normal` has an identity value, but they
    differ in what follows. A `Normal` component is left alone by writing back
    what it currently holds, which is the write value rule 10 gives it. A
    `Trigger_On_Write` component cannot be left alone at all, since any write
    of the object provokes its effect, so a record carrying one has no partial
    update of any of its components, and an assignment to a single component
    of it is illegal whether or not that component is the one with the effect.

    The load that rule 10 may require carries two conditions of its own, and
    where either fails the partial update is likewise illegal and the register
    must be written whole. The load shall be harmless: no component of the
    record may have a `Read` effect other than `None`, which is rule 5's
    condition for `Write_Value => Preserve`, and holds here for the same
    reason. And it shall not be able to lose an update: a `Normal` component
    whose write value the load supplies shall have an `Environment` mode that
    excludes `Write`, since otherwise the device may change it between the
    load and the store, and the store would revert that change. Where it
    fails, the value has to come from the program, and the aggregate is what
    makes the program state it.
12. Reading the component is unaffected, and governed by the `Program` mode
    and the `Read` part of `Effect` as usual.
13. The component shall not have a default expression. Rule 10 already
    determines the value stored in a component that the program did not name,
    so a default would at best restate it and at worst contradict it; and a
    default expression means "the value stored when none is given", which has
    no reading for a component whose write provokes a command rather than
    storing a value.

How the SPARK properties are derived
------------------------------------

The four properties follow the two component aspects, one property from each
part of each:

- `Async_Writers` is True for a component whose `Environment` mode includes
  `Write`, and False otherwise.
- `Async_Readers` is True for a component whose `Environment` mode includes
  `Read`, and False otherwise.
- `Effective_Reads` keeps its current meaning and is True for a component
  whose `Read` effect is other than `None`, False otherwise.
- `Effective_Writes` is True for a component whose `Write` effect is other
  than `Normal`, False otherwise.

That `Async_Readers` has a source of its own is what the two-sided access mode
adds outright. A control register the device samples has
`Async_Readers => True` because the declaration says the device reads it, and
not as a side effect of some write effect it does not have, so a write to it
is an effect on the world even where the program never reads it back;
`Environment => None` is the component that nothing outside the program
touches at all, and it is what takes an object out of external state.

SPARK's two consistency requirements on these properties (RM 7.1.2(6)) then
become two legality rules of one shape, one per direction: a `Read` effect
other than `None` requires an `Environment` mode that includes `Write`, since
something else must be putting values into a component whose reading consumes
them, and a `Write` effect other than `Normal` requires an `Environment` mode
that includes `Read`, since a write that provokes something is a write the
device reads. A declaration can get either wrong, and a compiler shall reject
both.

An object still has the four properties, since existing analysis and existing
contracts are written in terms of them, and they are derived from its
components: each is True for the object if it is True for any component. So a
record with one device-written status bit is an object with
`Async_Writers => True`, as it is today. Where the object or its type also
specifies one of the four explicitly, the values shall agree, as for
`Access_By` on a component and its subtype. The derivation applies only to a
type one of whose components specifies `Access_By` or `Effect`: on a type that
specifies neither, the four properties keep exactly their current meaning,
which is what makes an existing declaration that sets them by hand unaffected.

The consequences for analysis are the existing ones, applied per component
rather than per object:

- A component with `Async_Writers => False` may be read in an assertion
  expression and may be assumed unchanged between two reads with no
  intervening write. It yields on read the last value written by the program
  only where its `Write` effect is `Normal`: where a write provokes an effect,
  what it yields is what rule 8 derives from the action, which is the value
  written for none of the five and is nothing at all for two of them.
- A component with `Async_Readers => False` may have its writes coalesced or
  eliminated by the analysis model (not by the compiler, which is still bound
  by `Volatile`), so successive writes need not be reported as effects.
- A component with `Effective_Reads => True` is restricted to the contexts
  SPARK already restricts such reads to.
- An object all of whose components have `Environment => None` and no effects
  is not an external state, and is not required to be declared at library
  level.

`Global` and `Depends` contracts continue to name objects, not components; the
refinement of effects to components is what a component-level `Modifies`
aspect, proposed separately, already provides, and the two features compose:
`Modifies => Control.Baud_Rate` says which component this call writes, while
`Access_By` says who else can.

Aspect `Access_When`
--------------------

`Access_When` may be specified on a record type, on a component of a record
type, or on a stand-alone object. Its value is an aggregate with two named
parts, `Read` and `Write`, either of which may be omitted, though at least one
shall be given. The `Write` part guards the stores and the `Read` part guards
the loads.

Specified on a type or on an object, each part is a positional list of clauses
of the form

```
   name when condition
```

where `condition` is a Boolean expression. Specified on a component, each part
is a condition alone, the component being the part accessed; a part specified
on an object may take that form too, and then guards the whole object. A clause
with no `when` part is illegal, and so is a condition of `True`: an
unconditional permission is the absence of the part, and an unconditional
prohibition is a `Program` mode, not this.

A subprogram with `Modifies => CR.Baud_Rate` inherits the obligation of the
`Baud_Rate` clause, which is what makes these contracts compositional rather
than checked only at the leaves.

That clause form is deliberately the one that the `Modifies` aspect already
uses, where a `MODIFIES_CLAUSE` is `MODIFIED_OBJECTS { when GUARD }`, and so is
the reading of the guard. `Modifies` fixes it as evaluated once and for all at
the point where the obligation arises, with the clause enabled if the guard is
True, and `Access_When` means the same thing at the access rather than at the
call. Reusing it is worth more than a saved grammar rule: it is a settled
answer to when a guard is evaluated, from a feature already in production, and
it means a reader who knows one aspect can read the other.

Name resolution:

14. Specified on a type, `name` shall denote a component of that type,
    possibly a nested one (`CR.Baud_Rate`), and `condition` shall name only
    components of that type. No object may be named, so that the type stays
    usable for several objects.
15. Specified on an object, `name` shall denote a part of that object, and
    `condition` may in addition name any object visible at the point of the
    aspect specification.
16. Specified on a component, no `name` appears and the guarded part is that
    component; the condition follows rule 14 for the enclosing type. A part
    specified on an object may likewise omit the name, and then guards the
    whole object, which is how a register with no components states a rule
    about itself.

Aspects on a type and on an object of that type accumulate rather than override,
and so do clauses naming a part and clauses naming a whole containing it. The
obligation at an access is the conjunction of the conditions of every clause
whose named part overlaps the accessed part. Writing a whole peripheral,
`UART1 := (...)`, therefore has to satisfy every clause of every part, and
that conjunction is often unsatisfiable. It should be: peripherals are not
assignable objects. The diagnostic should say which clause failed rather than
listing all of them.

### Legality rules

17. A condition shall not read a component whose `Read` effect is other than
    `None`. Evaluating the guard would then have an effect on the device, and
    the guard is evaluated an implementation-defined number of times (including
    zero, when assertions are off). This is the rule that makes the feature safe
    to compile away.
18. A condition shall not read a component that the program may not read, for
    the reason that mode already gives; a component whose `Program` mode is
    `None` may not be named in a condition at all, by rule 3. `X'Written` is
    not a read of `X` and remains permitted on a component the program may
    only write. This is not a technicality: a write-only register has no
    readable value, so `'Written` is the only thing a guard can say about
    one, and without it every write-only register (every trigger, every
    command port) would be beyond the reach of this feature.
19. A `Read` clause naming a part the program may not read, and a `Write`
    clause naming a part the program may not write, are illegal: there is no
    access to guard.
20. A condition may read a component whose `Async_Writers` is True,
    notwithstanding SPARK RM 7.1.3(9).

SPARK bars a read of an effectively volatile object from an assertion
expression because 1) an assertion must be free of effects, and 2) it must not
change value under its own evaluation. The first property is the one that rule
17 covers. The second is removed in this context, as the basis of the two
tiers below: where the property still holds, the guard is a normal proof
obligation; where it does not, the obligation is explicitly weakened. So the
restriction is less relaxed than replaced by a rule that says what to do when
it is violated. The relaxation is needed for a guard the device writes, and
for nothing else.

That last claim is measurable, since rule 20 is the one place this RFC touches
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
in general, which is why Case 1 needs no relaxation at all and rule 20 reaches
only Case 2.

### Discharging the obligation

Let *G* be the set of components read by a clause's condition.

**Case 1: no component of *G* is written by the environment**, each having an
`Environment` mode of `Read` or `None`. The
condition is a function of program state alone. The obligation is that the
condition holds immediately before the access, and it is a proof obligation in
the ordinary sense, discharged by GNATprove using the same reasoning it
applies to non-volatile state. `Async_Writers` being False for every component
of *G* is precisely what licenses treating a read of the register as yielding
the last value that the program wrote, which is what makes this work, and that
license comes from `Access_By`, not from the guard.

**Case 2: some component of *G* has an `Environment` mode that includes
`Write`, whether specified or left to the default.** The condition cannot be
shown to hold at the access. The obligation is instead: on every path reaching
the access, there is an evaluation of the condition that yielded True, and
between that evaluation and the access there is no write to the guarded part
and no write by the program to any component of *G*.

This is a dataflow property, not a value property, and it is decidable by the
same machinery that proves initialization. It is strictly weaker than Case 1:
it establishes that the program consulted the device before acting, and nothing
about what the device did next.

**Run-time semantics.** Under an assertion policy that enables them, the
condition is evaluated immediately before the access, and `Assertion_Error` is
raised if it is False, in both cases. This is the useful behavior during
bring-up, and it is why rule 17 matters: a guard with a read effect would make
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

`'Written` is permitted in an `Access_When` condition and in
assertion expressions, and nowhere else. Whether it should also be permitted in
a `Global` or `Depends` contract turns on what kind of state it is, which this
RFC does not settle, so it is left out for now rather than ruled out: a
restriction can be lifted later without invalidating any code that was written
under it, and a permission cannot be withdrawn on the same terms.

The negative form is the useful one. A clause
`Access_When => (Write => (X when X'Written))` can never be satisfied, since
the write that would make the attribute True is the write the clause forbids,
and it deserves the warning that any statically False condition does.

`'Written` inherits the aliasing hazard of rule 4. Where two addresses reach
one piece of state, a write through one leaves `'Written` False for the other,
so a write-once register with a second address appears unwritten through that
view. Rule 4 handles the analogous case for the `Environment` mode by forbidding
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
| `access` = `read-only` | `Access_By => (Program => Read)` |
| `access` = `write-only` | `Access_By => (Program => Write)` |
| `access` = `read-write` | `Access_By => (Program => Read_Write)` |
| `access` = `writeOnce`, `read-writeOnce` | `Access_When => (Write => not X'Written)` |
| `readAction` = `clear` / `set` / `modify` / `modifyExternal` | `Effect => (Read => Clear / Set / Modify / External)` |
| `modifiedWriteValues` = `oneToClear` / `oneToSet` / `oneToToggle` | `Effect => (Write => (Trigger_On_One => Clear / Set / Toggle))` |
| `modifiedWriteValues` = `zeroToClear` / `zeroToSet` / `zeroToToggle` | `Effect => (Write => (Trigger_On_Zero => Clear / Set / Toggle))` |
| `modifiedWriteValues` = `clear` / `set` | `Effect => (Write => (Trigger_On_Write => Clear / Set))` |
| `modifiedWriteValues` = `modify` | `Effect => (Write => Normal)` (the default) |
| `enumeratedValues` with `usage` = `write` | the `Write` part of `Effect`, by the reduction below |
| `alternateRegister` | an overlay, and rule 4 on both views |
| *no SVD equivalent* | `Access_By`'s `Environment` part |
| `resetValue`, for a gap between declared fields | `Access_By => (Program => None)` with `Write_Value => …` |
| *no SVD equivalent* | `Write_Value => Preserve` |

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
`Access_When => (Write => not X'Written)` states it in one clause, on the
field, and a generator can emit it; `read-writeOnce` is the same clause on a
field that stays readable afterwards.

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
neither view may claim that the environment does not write, and here a
generator can see that, since the two addresses are equal in the description it
is reading.

Rule 4's own case is the converse, several addresses onto one piece of state,
and for that SVD records nothing at all: `INTENSET` at `16#304#` and `INTENCLR`
at `16#308#` appear as two unrelated registers. A generator cannot tell where
the rule applies, which is a reason for it to forbid rather than to require the
annotation.

The `Environment` part cannot be filled in from an SVD file, because SVD has
no notion of the hardware's own access, only the program's. It can be inferred
where `access` is decisive: a field that the program may only read must be
written by something else, giving `Environment => Read_Write`, and a field
that the program may only write is presumably read by the device rather than
written by it, giving `Environment => Read`. The case that cannot be inferred
is
`access = read-write`, which covers both a control register that the device
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
`Environment => Read` says something about the device that a datasheet either
supports or does not. The model underneath is the same either way, so this is
a question of surface, and the surface is where these mistakes get made.

Drawbacks
=========

This adds four aspects (three of them composites), one attribute and fifteen
names to a part of the language that is already dense: a fully annotated
register declaration is more verbose, and the interaction surface with
`Volatile`, `Atomic`, `Full_Access_Only`, `Bit_Order`, and
`Scalar_Storage_Order` is non-trivial even though no aspect here changes
representation.

Most of the effect vocabulary is not consulted by the compiler, and the part
the prover consults is narrow. The trigger decides a store and the action
decides a post-state, but the post-state is usable only where the environment
does not write the component, which is not the case on the device-written flags
that most write effects sit on. On the read side no action is
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

The proposal is backward compatible because every part of the two component
aspects defaults to the value that reproduces current behavior,
`Access_By => (Program => Read_Write, Environment => Read_Write)` and
`Effect => (Read => None, Write => Normal)`, and because a component with no
`Write_Value` is one whose write value the program supplies, as today.
`Access_When` is an addition with no default behavior at all: an object
without it is unconstrained, as today. An existing register declaration is
unchanged in legality, representation, and generated code, and existing SPARK
code sees the same four volatility properties it sees today. No existing
program becomes illegal, and no existing proof result changes.

Rule 20's relaxation applies only inside an `Access_When` condition, so it
cannot affect the legality of any existing assertion expression.

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

- Whether the four actions of `Effect`'s `Read` part earn their place, given
  that all four give `Effective_Reads => True` and nothing else. The
  alternative is a per-component `Effective_Reads => True` Boolean, which is
  smaller and matches SPARK's existing name. What the enumeration keeps is the
  vendor description's own distinction, and a vocabulary shared with the
  action of the `Write` part.
- Interaction with `Relaxed_Initialization` and with `Modifies`, which both
  reason about parts of an object and will need rules for parts the program
  may not read.
- Whether `Volatile_Function` should follow the per-component properties
  rather than the object's. SPARK forbids a nonvolatile function from having a
  volatile input (RM 7.1.3(7)) and treats a call to a `Volatile_Function` as
  interfering, both at object granularity, so a function that reads one
  program-owned field of a peripheral is a volatile function because some
  other field of the same record is device-written, and a function as ordinary
  as `Is_Enabled` cannot be written as an ordinary one. The `Environment` mode
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
  register, and not before, which is
  `Access_When => (Write => (EOIR when IAR'Read))`. Reading `IAR` acknowledges
  the interrupt, so it has a `Read` effect and rule 17 bars naming it in a
  condition at all; `'Read` would be on the read side what `'Written` already
  is on the write side under rule 18, the only thing a guard can say about a
  register whose value a condition may not touch.
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
and `Access_When => (Write => not X'Written)` is what makes them expressible,
so a generator can emit them.

SystemRDL is the closest match to the design proposed here. It describes each
field with two independent access properties, `sw` and `hw`, which are exactly
the `Program` and `Environment` parts of `Access_By`. On top of that it has
`onread` (`rclr`, `rset`, `ruser`) and `onwrite` (`woclr`, `woset`, `wot`,
`wzc`, `wzs`, `wzt`, `wclr`, `wset`, `wuser`) side-effect modifiers, which the
two parts of `Effect` render one for one. It also has `swwe`/`swwel`
software-write-enable properties, active high and active low, which gate a
field's writability on another field or signal and are an `Access_When` `Write`
clause restricted to a single reference.

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
what volatility implies for analysis, which is what an `Environment` mode
without `Write` does per component. `Volatile_Components` and
`Atomic_Components` show that the language has already accepted that volatility
can need component granularity, though only for array elements and only as an
all-or-nothing property.

Unresolved questions
====================

To resolve during the RFC process. Whether Case 2's obligation is the right
one, or whether the second half should be narrowed to Case 1 and device-flag
rules left to run-time checks, Case 2 being a guard the device writes and Case
1 a guard the program writes, both defined under *Discharging the obligation*;
whether rule 20's relaxation is sound; and whether `'Written` belongs here at
all or is a separable feature.

Whether the four read actions earn their place beside a Boolean decides
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
`Access_When => (Write => not X'Written)`, which is the whole of the
sequencing information a vendor file carries. The emission should sit behind a
switch for at least one release, since a generated map that suddenly rejects
the driver on top of it is not a welcome upgrade. A second input format would
go further: SystemRDL has `hw`, which is the `Environment` part of `Access_By`,
and that is the one annotation with the largest proof value and no SVD
equivalent, so a generator reading SystemRDL could supply what a generator
reading SVD must leave to the user.
