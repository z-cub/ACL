FreePascal 3.3.1 (trunk) compiler always recompile the cross-linked units due PPU's CRC mismatch (unit_u_interface_crc_changed).
https://gitlab.com/freepascal.org/fpc/source/-/issues/41385
I have some research for that.

---------------------------------------------------------------
For example, there are two cross-linked modules looks like that:
---------------------------------------------------------------
unit MyUnit;

interface

implementation

uses
  MyUnit.Ex;
end.


unit MyUnit.Ex;

interface

uses MyUnit;

implementation

end.

So, what's goes wrong?
1) Parses interface part of MyUnit unit and generates CRC of public api section (OK).
2) Parses the MyUnit.Ex unit that linked in implementation section of the unit (OK).
3) Generates the PPU file for MyUnit.Ex using CRC from step #1 for used unit (OK).
4) After all units of implementation section are parsed, the compiler invokes the connect_loaded_units 
   that lead to call Symtable.checkduplicate for each of loaded unit.
   Because MyUnit.Ex contains a part of original unit the checkduplicate method marks the "MyUnit" symbol as hidden (symtable.hidesym).
   Because MyUnit symbol is unit name it was defined in public api section, so changing it visibility lead to change public api CRC (FAIL).
Of course, this is a compiler issue and it needs to be solved on its side, but who will do it? 

---------------------------------------------------------------
I would like to keep units names in my project, so I get used following workaround:
I've created an empty unit in same namescope like "MyUnit.Stub" and link it to base unit:
---------------------------------------------------------------
unit MyUnit;

interface

uses
  MyUnit.Stub;

---------------------------------------------------------------
So, this early declaration forces the compiler to mark "MyUnit" symbol as hidden before the checksum of public api will be calculated.