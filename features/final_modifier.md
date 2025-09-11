# `final` modifier RFC

- Status: Planning

## Summary

The idea is to be able to annotate various entities with a `final` modifier,
that would prevent extending it further. So far, here are the identified entity
kinds that would benefit from such an annotation:

### Tagged types

Tagged types could be annotated with such a modifier, that would prevent
deriving from them outside of the package they have been defined in. This is
useful if the tagged type isn't meant to be derivated from.

> NOTE: We deliberately make this work so that you can derive from a tagged
> final type if you are in the same package. 
> 
> The rationale is that this allows for more flexibility and less boilerplate
> when you want to define a tagged type hierarchy that cannot be derived from
> outside the package (see the RFC about `Max_Size` for an example of use).
> 
> Additionally we posit that if you don't need to define a hierarchy you
> probably wouldn't use a tagged type in the first place, and that a single
> user knows what he is doing in the package of definition.

```ada
package P is
    type Root_Type is tagged final null record;
    
    type Derived_Type is new Root_Type with record
        Field : Integer;
    end record;
    --  This works because the type is derived in the same package        
end P;

package Q is
    type Der is new P.Root_Type with null record; --  ERROR
    type Der2 is new P.Derived_Type with null record; --  ERROR 
end Q;
```

> QUESTION: With regards to the `Max_Size` RFC, it appears that we could make
> tagged final hierarchies automatically bounded (e.g. not even require a
> `Max_Size` annotation. What do people think ?  On the one hand: It seems good
> for the cases where you *do* want to conflate the two.  On the other hand:
> From experience from other parts of Ada, it doesn't seem like a great idea to
> hard-link two aspects that could in theory be separate.

> NOTE: An interest about sealed tagged type hierarchies when they interact
> with pattern matching is that we can guarantee completeness of the match, and
> so the `others` branch shall not be mandatory anymore.

### Tagged primitives

In the scope of object oriented programming, another kind of entity where it
could be deemed useful to prevent derivation is primitive subprograms of tagged
types. This is a subcase of the tagged types one, and is extremely useful if:

* You have an API that exposes derivation as a means to extend it
* It also exposes tagged primitives that expose functionalities that users
  (people deriving the base class) need
* Those primitives **shouldn't** be overriden by users

```ada
```

> NOTE: Not sure that this is tremendously useful: You can already make such
> subprograms non-dispatching and non overridable by using  `'Class'`. You have
> a small convenience with this feature because the function stays a primitive,
> so you can still derive it inside the definition of your API, and it is
> visible on subclasses without having to with/use the package.

> Another argument is that in Ada, those kind of APIs where you would use
> abstract methods and final methods, and make the user derive the object, are
> often done via generic packages with subprogram params in Ada.

### Library level packages

In the same vein, it is possible to break invariants about APIs by creating a
child package for a given library level package. This allows accessing the
private part of the package amongst other things. Annotating the package with a
`final` modifier will disallow this kind of usages.

```ada
final package A is
    
end A;

package A.B is -- ERROR
end A.B;
```

### Good faith & security

It needs to be understood that those features are not meant to ensure security,
although they can be used alongside other measures in modelling a secure
system. The invariants that are described

## Motivation

There are two motivations for this feature: 

* The possibility of annotating "finalness" of different entities to provide
  better APIs that are more explicit/less easy to break.

* The possibility of having a tagged hierarchy that is "closed", so that we can
  compute a maximum static size for instances of the type at compile time (see
  https://hackmd.io/q0NXV7J8RdiambtId8CMsg).

## Guide-level explanation

### Syntax

A `final` reserved word is added to the language. It is not a keyword, so the
identifier `final` is still usable in every-other place where it is not a valid
modifier.

The grammar of subprogram declarations, tagged type declarations, and package
declarations, is annotated to accept the `final` reserved word:

```
subprogram_declaration ::= 
    [overriding_indicator | final]    
    subprogram_specification
        [aspect_specification];

record_type_definition ::= [[abstract | final] tagged] [limited] record_definition

derived_type_definition ::= 
    [abstract | final] [limited] new parent_subtype_indication
 [[and interface_list] record_extension_part]
 
library_item ::= [private] [final] library_unit_declaration
  | library_unit_body
  | [private] library_unit_renaming_declaration
```

### Static legality rules

Illegal uses of the modifier must be flagged. This includes:

* `final` on non subprogram library level entities
* `final` on any subprogram that is not a primitive of a tagged type
* `final` on non-tagged records
* ???

### Operational semantics

None, this is only legality checking, no new runtime capabilities are added.

## Alternatives

It's not necessary to introduce a new reserved word for this feature (although
it would be my personal preference). We can make a design where we use
aspects for that:

```ada

    type Root_Type is tagged null record with Final;

    package A with Final is
    end A;
```

## Prior art

- C#'s sealed:
  https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/sealed

- Java's final:
  https://docs.oracle.com/javase/specs/jls/se8/html/jls-8.html#jls-8.1.1.2
  https://docs.oracle.com/javase/specs/jls/se8/html/jls-8.html#jls-8.4.3.3
