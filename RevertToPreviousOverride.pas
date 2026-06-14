{
    RevertAllToPreviousOverride
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
var
    xesp: IwbElement;
begin
    Result := 0;

    ElementAssign(e, 0, ReturnPreviousOverride(e), False);

end;

// Called after processing
// You can remove it if script doesn't require finalization code
function Finalize: integer;
begin
    Result := 0;
end;

function ReturnPreviousOverride(e: IwbElement): IwbElement;
var
    master: IwbElement;
begin
    master := MasterOrSelf(e);
    Result := OverrideByIndex(master, Pred(OverrideCount(master)));
end;

end.
