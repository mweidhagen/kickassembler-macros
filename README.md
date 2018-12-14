# kickassembler-macros
Collection of Kick Assembler macros

Currently only one macro is included. It makes it possible to
include any Commodore BASIC V2 program in your assembler source.

## Usage
Import the file basicmacro.asm into the assembler source file with the .import command

The macro name is BasicProgram and it takes one argument which is a list of
strings, where each string is one line of BASIC code:

```
BasicProgram(List().add(
    @"10 PRINT \"HELLO WORLD\"",
     "20 GOTO 10"
))
```

This macro places the tokenized BASIC program at the default BASIC start
address which is $0801. If you use this macro as a replacemant for the
built-in Kick Assembler startup macro (BasicUpstart2) then beware that you
will have to put this Macro below the main program start label in order 
for Kick Assembler to resolve the label value first:

```
        *=$0900
start:  jmp *

    BasicProgram(List().add(
        "4711 SYS" + toIntString(start) + " : REM CODED BY MW 2018"
    ))
```
