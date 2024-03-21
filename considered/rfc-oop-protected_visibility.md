- Feature Name: oop_protected_visibility
- Start Date: 2024-03-20
- RFC PR: (leave this empty)
- RFC Issue: (leave this empty)

Summary
=======

This RFC introduces a way to obtain an intermediate level of visibility between the "public" and "private" levels, often refered to as "protected" in OOP paradigms. It is a useful level of visibility as will be argued below that is currently only possible to achieve by a perverse use of child packages in a way that forces a naming convention in a context where it doesn't make sense. The proposal is to recognize "protected" visibility as a first class citizen and liberate it from the naming constraints. While the proposal is proposed and argued in the context of OOP, it extends beyond OOP in Ada and applies to all declarations that are subject to the rules of visibility.

Motivation
==========

Many OOP paradigms define three levels of visibility associated with the members (fields and methods) of a class:

- "public" visibility should be applied to members intended to be used by client code using the class.
- "private" visibility should be applied to members intended to be used only by the implementation of the class, and never by client code.
- "protected" visibility should be applied to members intended to be used by code extending the class.

This model is valuable in the fact that it distinguishes 2 categories of code that can use a class: client code that is a mere User of the class, and extending code that defines a modified version of the class.

Ada allows developers to implement visibility in the following manner:

- Declarations in the public part of a package spec are visible to any other code. This matches the "public" visibility of popular OOP paradigms.
- Declarations in the private part of a package spec `P` are visible to the body of that spec, as well as to the specs of nested packages and non-nested child packages, *i.e.* packages with the prefix `P.` in their name.

Ada-private visibility is a mix of OOP-private and OOP-protected visibility. Indeed extending code can be written into non-nested child packages named `P.*`.

However that naming constraint is often undesirable and is an obstacle to creating libraries that extend other libraries.

Consider the following example. A library defines the following type intended for logging:

```ada
package SomeLib.Logging is
    type Logger is tagged null record;
    --  A logger that writes message to a logging stream

    procedure Log (Self : Logger; Msg : String);

private

    procedure Write_Line (Self : Logger; Line : String);
    --  primitive intended for use by the implementation, or by extending code
    procedure Write (Self : Logger; Text : String);
    --  primitive intended for use by the implementation, or by extending code

end SomeLib.Logging;
```

Now if someone wanted to extend the `Logger` type to create a logger with extended functionality, they can do it as follows:

```ada
with SomeLib.Logging;

package MyLib.TimestampedLogging is
    type TimestampedLogger is new SomeLib.Logging.Logger with null record;
    --  A logger that logs messages to a stream, prefixed with a timestamp

    overriding procedure Log (Self: TimestampedLogger; Msg : String);
end MyLib.TimestampedLogging;
```

In the implementation of the `TimestampedLogger` ideally we would like to reuse primitives of the parent type as follows:

```ada
with SomeLib.Logging;

package body MyLib.TimestampedLogging is
    overriding procedure Log (Self: TimestampedLogger; Msg : String) is
        Timestamp : String := "[Timestamp obtained somehow]";
    begin
        TimestampedLogger'Class (Self).Write (Timestamp & " "); -- error: no selector "Write" for type "TimestampedLogger'Class" defined at mylib-timestampedlogging.ads:4
        SomeLib.Logging.Logger (Self).Write_Line (Msg);         -- error: no selector "Write_Line" for type "Logger" defined at somelib-logging.ads:2
    end Log;
end MyLib.TimestampedLogging;
```

However we cannot do so because standard Ada visibility does not allow it.

It is possible to declare the extended type in a child package as follows:

```ada
--  src/mylib/somelib-logging-timestampedlogging.ads
with SomeLib.Logging;

package SomeLib.Logging.TimestampedLogging is
    type TimestampedLogger is new SomeLib.Logging.Logger with null record;
    --  A logger that logs messages to a stream, prefixed with a timestamp

    overriding procedure Log (Self: TimestampedLogger; Msg : String);
end SomeLib.Logging.TimestampedLogging;


--  src/mylib/somelib-logging-timestampedlogging.adb
package body SomeLib.Logging.TimestampedLogging is
    overriding procedure Log (Self: TimestampedLogger; Msg : String) is
        Timestamp : String := "[Timestamp obtained somehow]";
    begin
        TimestampedLogger'Class (Self).Write (Timestamp & " ");
        SomeLib.Logging.Logger (Self).Write_Line (Msg);
    end Log;
end SomeLib.Logging.TimestampedLogging;
```

But that forces a naming convention that might be undersirable. It seems inappropriate that a library called `mylib` with all provided packages named `MyLib.*` has to use the name `SomeLib.*` to provide extended functionality.

Guide-level explanation
=======================

The proposal is to introduce an aspect `Private_Visibility_On` that applies to a package spec and gives it visibility over the private part of another package, *e.g.*

```ada
with SomeLib.Logging;

package MyLib.TimestampedLogging
with
    Private_Visibility_On => SomeLib.Logging
is
    type TimestampedLogger is new SomeLib.Logging.Logger with null record;
    --  A logger that logs messages to a stream, prefixed with a timestamp

    overriding procedure Log (Self: TimestampedLogger; Msg : String);
end MyLib.TimestampedLogging;
```

The resulting visibility in `MyLib.TimestampedLogging` is the same as if package `MyLib.TimestampedLogging` was a child package of `SomeLib.Logging`. As a result the following package body becomes valid:

```ada
with SomeLib.Logging;

package body MyLib.TimestampedLogging is
    overriding procedure Log (Self: TimestampedLogger; Msg : String) is
        Timestamp : String := "[Timestamp obtained somehow]";
    begin
        TimestampedLogger'Class (Self).Write (Timestamp & " ");
        SomeLib.Logging.Logger (Self).Write_Line (Msg);
    end Log;
end MyLib.TimestampedLogging;
```

Thanks to the `Private_Visibility_On` aspect, the package body has visibility over the private part of the spec of `SomeLib.Logging` and thus can access the primitives `Write` and `Write_Line`. We have thus achieved "protected" visibility in the terms used by popular OOP paradigms.

The effect of the `Private_Visibility_On` aspect is limited to the package spec where it is introduced and the corresponding package body. This means that non-nested child packages of `MyLib.TimestampedLogging` do not obtain visibility over the private part of `SomeLib.Logging`. This keeps the feature conservative in the attribution of elevated visibility and limits it to a minimum that is sufficient in practice.

Reference-level explanation
===========================

The semantics of `Private_Visibility_On` is proposed to be equivalent to the visibility given to non-nested child packages. This simplifies the definition of this semantics as well as its implementation.

Moreover the proposed semantics is to limit the elevated visibility to the package spec where it is used and the corresponding body. That also fosters simplicity and reduces impact.

Rationale and alternatives
==========================

This design was prefered because it leverages an existing possibility in the language, *i.e.* using a non-nested child package to gain visibility over the private part of a parent package, and recognizes it as a feature for achieving what is refered to as "protected" visibility in popular OOP paradigms.

Drawbacks
=========

The proposed makes it easier for any code to obtain visibility over private declarations that were not intended to be visible by the author of the package. There are two reasons why this is acceptable.

The first reason is that it was already possible to do that before this proposal by using non-nested child packages. Even when considering separate libraries, there is nothing that prevents one library from declaring a child package of another library. The only thing that this proposal is changing is to lift the naming constraint on the package that needs access to the private declarations.

The second reason is that visibility should not be a way to achieve security, *i.e.* prevent data from being accessed by unauthorized parties. Visibility is a way to convey the intent of the author in making a declaration only revelant to the implementation of a component and not to users of that component. However when other developers which to extend the implementation of that component themselves, it is justified for them to obtain visiblity over the private declarations intended for that purpose.

Prior art
=========

**TBD**

Discuss prior art, both the good and the bad, in relation to this proposal.

- For language, library, and compiler proposals: Does this feature exist in
  other programming languages and what experience have their community had?

- Papers: Are there any published papers or great posts that discuss this? If
  you have some relevant papers to refer to, this can serve as a more detailed
  theoretical background.

This section is intended to encourage you as an author to think about the
lessons from other languages, provide readers of your RFC with a fuller
picture.

If there is no prior art, that is fine - your ideas are interesting to us
whether they are brand new or if it is an adaptation from other languages.

Note that while precedent set by other languages is some motivation, it does
not on its own motivate an RFC.

Unresolved questions
====================

**TBD**

- What parts of the design do you expect to resolve through the RFC process
  before this gets merged?

- What parts of the design do you expect to resolve through the implementation
  of this feature before stabilization?

- What related issues do you consider out of scope for this RFC that could be
  addressed in the future independently of the solution that comes out of this
  RFC?

Future possibilities
====================

**TBD**

Think about what the natural extension and evolution of your proposal would
be and how it would affect the language and project as a whole in a holistic
way. Try to use this section as a tool to more fully consider all possible
interactions with the project and language in your proposal.
Also consider how the this all fits into the roadmap for the project
and of the relevant sub-team.

This is also a good place to "dump ideas", if they are out of scope for the
RFC you are writing but otherwise related.

If you have tried and cannot think of any future possibilities,
you may simply state that you cannot think of anything.

Note that having something written down in the future-possibilities section
is not a reason to accept the current or a future RFC; such notes should be
in the section on motivation or rationale in this or subsequent RFCs.
The section merely provides additional information.
