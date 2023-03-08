Improvements to generic instantiations
======================================

Summary
-------

This RFC proposes to introduce a series of enhancements to Ada generics,
specifically in terms of how those are instantiated, which purpose is to make
the design of high level APIs based on generics much easier than before.

Motivation
----------

The generic programming system of Ada is pretty powerful, and is essential to
Ada programming.

However, in light of other modern programming languages, it's pretty obvious
that certain features are missing from it to make it truly usable in the modern
programming world.

The general aim is to simplify the use of generics in user code, so that there
is no friction when using generic subprograms and types. While there are
improvements to generics from the formal point of view that could (and should)
be considered for Ada, this is not the topic of that meta RFC. A few key design
goals are:

1. The main purpose of those enhancements is a way to express implicit
   instantiation of generics.

2. Another key design goal is for users to be able to refer to a "unique"
   instance of a generic, by its name. For example there will be a unique
   instance of `Ada.Containers.Vectors (Positive, Positive)`, and all people
   refering to it will refer to the same instance, which solves a long standing
   problem in generics, which is the ability to structurally reference unique
   entities.

   This is akin to structural typing for types declared inside of generics, and
   is a key feature that is currently missing from Ada generics, to provide
   interoperability between separately evolving pieces of code. (TODO: Fill
   example)

3. We also want to simplify the way generic types (so, in other words, types
   that are the main point of interest of a generic package, like for example
   `Ada.Containers.Vectors.Vector`) are referred to by users, to syntactically
   acknowledge that they're the main entity of the package.

Given the following supporting generic,

```ada
--  Supporting code
generic
   type Index_Type is (<>);
   type El_Type is private;
   type Array_Type is array (Index_Type range <>) of El_Type;

   type Accum is private;
   with function Fn (Current : Accum; El : El_Type) return Accum;
function Reduce (Init : Accum; Arr : Array_Type) return Accum;
```

This would ultimately allow people to write the following example:

```ada
function Sum (X: Float_Array) return Float is
   function Red is new Reduce (Positive, Float, Float_Array, Float, "+");
begin
   return Red (0.0, X);
end Sum;
```

This way:

```ada
function Sum (X: Float_Array) return Float is (Reduce (Fn => "+") (X))
```

Also, regarding generic packages & types, we would like the following:

```ada
package Positive_Vectors
is new Ada.Containers.Vectors (Positive, Positive);

F : Positive_Vectors.Vector;
F2 : Positive_Vectors.Vector;
```

To be expressible this way:

```ada
generic type Vector is Ada.Containers.Vectors (Index_Type => Positive).Vector;

F  : Vector (Positive)
F2 : Vector (Positive)
```

### Expected high level benefits

More generally, we expect the following benefits from implementing those
improvements:

* Better code sharing/reduced code size: Due to the paradigm of explicit
  instantiations, it often happens -- because programmers cannot find duplications
  easily/because it's hard to share instances because of the structure of the
  project -- that you have several instantiations with the same parameters.

* Better modularity:
* Paradigm shift in terms of expressivity:

Explanation
-----------

We will now walk through the set of proposed features that will allow us
to write the above, starting from the current set of Ada's generic
features.

### First step: Inference of dependent types in generic instantiations

Using the feature described in [this rfc](../considered/rfc-inference-of-dependent-types.md),
we could then simplify the above code's Reduce instantiation:

```ada
function Sum (X: Float_Array) return Float is
   --  Index and element types are automatically deduced
   function Red is new Array_Reduce  (<>, <>, Float_Array, Float, "+");
begin
   return Red (0.0, X);
end Sum;
```

Here, we're allowed to not specify generic actual parameters for parameters
that can be deduced from other parameters, according to the rules described in
the RFC.

This simplifies the instantiation of the `Array_Reduce` generic function a
little, but is not a big step up from the last version. We will understand the
true edge this feature gives us in the last step. Let's go to the next
iteration

### Second step: Implicit instantiation of generics

This one is the big step up, that will allow us to get one step closer to the
initial intent. Using implicit instantiation of generic functions [(see RFC
here (TODO))](https://TODO), we would be able to write the following:

```ada
function Sum (X: Float_Array) return Float is
begin
    return Array_Reduce (<>, <>, Float_Array, Float, 0.0, "+") (0.0, X);
end Sum;
```

The last step we would like to get rid of is the repetitive
instantiation parameters.


> **Note**
> Above we only show the syntax for functions, but packages can also be
> structurally instantiated

### Third step: inference of generic actual parameters from function call params

Using inference of actual generic actuals using call actuals
[(see RFC here (TODO))](https://TODO), we can express the above as:

```ada
function Sum (X: Float_Array) return Float is
begin
  return Array_Reduce (Fn => "+") (0.0, X);
end Sum;
```

Here, the only generic actual we have to specify is \`Fn\`, because:

-   All array type parameters are infered from the `Self` actual
    parameter. `Self` allows us to deduce the type of the `Array_Type`
    generic formal, and from this we can deduce the `Index_Type` and
    `Element_Type`.

-   The `Accum` type can be deduced either from the value of `Init`, or
    from the expected target type of the function call. In this case,
    since `0.0` is an universal real, we deduce `Accum` from the
    expected type of the function call, which is the return type of the
    `Sum` function.

> **Note**
> In terms of how implicit instantiations work, we can wonder whether each
> reference to an instantiation with the same parameters refers to **the same
> instance**, or to **a different one each time**.
>
> Following from the high level design point number 2 in the motivation, we
> clearly want each instantiation with similar structural parameters to refer to
> the same instantiation.
>
> In terms of name resolution, it means that, given two implicit instantiation
> references, they'll reference the same instantiation if their parameters are
> the same.

> **Note**
> There is a big question here in my opinion in how we refer to that feature.
> Talking about implicit instantiation is maybe not the best terminology. Some
> other ideas:
>
> * "Structural instantiations" might be better in how it coins the nature of the
>   feature.
>
> * A natural one for Ada would be "Anonymous instantiations". For me the only
>   problem with this name is the potential PTSD from coming from anonymous
>   accesses/array declarations.


### Fourth step: Generic types

With the current discussed features, the `Vector` example in the motivation
section can be expressed as:

```ada
F  : Ada.Containers.Vectors (Positive, Positive).Vector;
F2 : Ada.Containers.Vectors (Positive, Positive).Vector;
```

Which is pretty verbose. One could imagine that, in that case, the user can
just make an explicit instantiation if they need a shorter name. The problem
with that scheme is that, one of the features that we want to derive from
implicit instantiations is structural typing of generics, so **conciseness is
not the only reason to use generics**.

For that use, we propose the "generic types" feature (TODO link to RFC), that
will in effect add a new kind of generic entity to Ada. However, at least for
the moment, the way this will be done is still hugely relying on generic
packages:

```ada
generic type Vector is Ada.Containers.Vectors.Vector;
--  This declares that uses of ``Vector`` are really uses of
--  Ada.Containers.Vectors.

type Float_Vector is new Vector (Positive, Float);
--  Declare a new instantiation explicitly

Inst : Float_Vector;

F  : Vector (Positive, Positive)
F2 : Vector (Positive, Positive)
--  Refer to the structural instantiation
```


### Fifth step: Partial instantiation of generics

A feature that has often been asked in Ada is partial instantiations of
generics, in fact, it has been asked on ada-spark-rfcs by an external user
already, see https://github.com/AdaCore/ada-spark-rfcs/pull/41.

This feature has great consequences on generic's usability beyond the scope of
instantiations, but in the scope of this document, which are detailed in the
RFC itself, but in the context of instantiations, and of the example of
`Vectors`, it would allow the following:

```ada
generic type Vector is Ada.Containers.Vectors (Index_Type => Positive).Vector;

F  : Vector (Positive)
F2 : Vector (Positive)
```

Prior art
---------

Many (most) languages with generics have implicit/structural instantiations of
generics. It's on the other hand hard to find languages with explicit
instantiations like Ada. All mainstream languages today use implicit/structural
generics (Java/C++/C#/Rust/Go/etc).

Future possibilities
--------------------

An idea that was pointed out was that we might want to be able to annotate
generics to explicitly forbid structural references to instantiations, for
cases where generics have state that you might not want to implicitly share
between references. One example that comes to mind is GNAT's HTable package.


