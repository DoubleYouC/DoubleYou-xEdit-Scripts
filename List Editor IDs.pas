{
  New script template, only shows processed records
  Assigning any nonzero value to Result will terminate script
}
unit DoStuff;


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
    AddMessage(EditorID(e));
end;


// Called after processing
// You can remove it if script doesn't require finalization code
function Finalize: integer;
begin
    Result := 0;

end;

end.