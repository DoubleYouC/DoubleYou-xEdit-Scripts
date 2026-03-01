{
  New script template, only shows processed records
  Assigning any nonzero value to Result will terminate script
}
unit userscript;

// Called before processing
// You can remove it if script doesn't require initialization code
function Initialize: integer;
begin
  Result := 0;
end;

// called for every record selected in xEdit
function Process(e: IInterface): integer;

begin
  Result := 0;

  if Signature(e) <> 'CELL' then Exit;

  if GetElementEditValues(e, 'DATA - Flags\Distant LOD Only') = 0 then Exit;
  //if not ElementExists(e, 'XILW - Exterior LOD') then Exit;

  AddMessage(Name(e));


  // processing code goes here

end;

// Called after processing
// You can remove it if script doesn't require finalization code
function Finalize: integer;
begin
  Result := 0;
end;

function regexReplace(subject, regexString, replacement: string): string;
var
  regex: TPerlRegEx;
begin
  Result := '';
  regex  := TPerlRegEx.Create();
  try
    regex.RegEx := regexString;
    regex.Subject := subject;
    regex.Replacement := replacement;
    regex.ReplaceAll();
    Result := regex.Subject;
  finally
    RegEx.Free;
  end;
end;

end.
