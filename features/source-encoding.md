- Feature ID: source-encoding
- Start Date: 2026-03-05
- Status: Proposed

Summary
=======

The goal is to ensure that a given source is always interpreted the same way and
follows modern languages practices regarding source and identifier encoding.

Motivation
==========

Currently Ada/Spark is using by default latin-1. Compiler switches are required (-W8 in GNAT)
to change the encoding used. Mixing of library using distinct encoding can be complicated
as the switch are applied at unit level and not source level.

All modern languages are now enforcing UTF-8 for source encoding.


Guide-level explanation
=======================

Ada/Spark source code should be a valid UTF-8 sequence and identifiers should follow
Unicode® Standard Annex # 31 using the default profile.

Reference-level explanation
===========================

- Ada/Spark sources MUST be encoded in UTF-8.
- If the first character in the sequence is U+FEFF (BOM), it is removed.
- Idenfiers MUST follow the Unicode® Standard Annex # 31 and follow the following profile:

  - Start: XID_Start
  - Continue: XID_Continue
  - Medial: empty

- Other restrictions coming from the Ada standard should be preserved:

    - Forbids two consecutive Pc characters and trailing Pc
      characters in identifiers.
    - Requires that identifiers are already valid NFKC characters when considered
      individually. For example you cannot use: ﬁ (ligature),
      ① (NFKC representation is 1), Ⅳ (roman numeral), ...
    - Two identifiers are considered equal if their NFKC_Casefold forms are equal.
    - NFKC_Casefold form of an identifier must not be equal to that of a reserved keyword.

Rationale and alternatives
==========================

- The world is using UTF-8
- The current Ada/Spark community is using now UTF-8 by default (enforced by Alire)
- Not doing that is creating incompatibilities between projects

Drawbacks
=========

- Sources will need to be converted from original encoding to UTF-8. Even if the transformation
  is automatic and easy to perform, there might be surprise with string literal there were already
  encoded in UTF-8 rather than Latin-1.

Compatibility
=============

Though the change is backward incompatible, most of the time the switch to UTF-8 can be automated.

Note also that current mention of encoding in Ada 2022 mention the ISO standard ISO/IEC 10646:2020
rather than Unicode. It's probably better to reference the Unicode standard which is easier to access
than its ISO equivalent.

**Comparison with Ada 2022 identifier rules (RM 2.3)**

The rules are compatible with Ada 2022 rules when source encoding is UTF-8

Future possibilities
====================

Handling of string literals could be handled using the UTF-8 input rather than forcing a conversation
to Wide_Wide_Strings.
