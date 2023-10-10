- Feature Name: anonymous subprograms
- Start Date: 2023-02-13 

Summary
=======

Add an anonymous subprogram expression to the Ada language, similar to the
common concept of `anonymous function
<https://en.wikipedia.org/wiki/Anonymous_function>`__.

This would allow passing subprograms to other subprograms, or to generic
instantiations, without having to declare them and give them a name first.

This RFC is a placeholder to track the work of implementing this at Adacore,
since all the work has already been done by Tucker as part of an ARG AI here:

http://www.ada-auth.org/cgi-bin/cvsweb.cgi/ai12s/ai12-0190-1.txt?rev=1.13
