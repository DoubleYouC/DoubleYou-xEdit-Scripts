{
  New script template, only shows processed records
  Assigning any nonzero value to Result will terminate script
}
unit RaiseZ;

const
    raiseAmount = 325; // Set to how much you want to raise the Z position


// Called before processing
// You can remove it if script doesn't require initialization code
function Initialize: integer;
begin
    Result := 0;

end;

// called for every record selected in xEdit
function Process(e: IInterface): integer;
var
    pZ: double;
begin
    Result := 0;
    if Signature(e) <> 'REFR' then Exit;
    pZ := GetElementNativeValues(e, 'DATA\Position\Z');
    SetElementEditValues(e, 'DATA\Position\Z', FloatToStr(pZ + raiseAmount));
end;


// Called after processing
// You can remove it if script doesn't require finalization code
function Finalize: integer;
begin
    Result := 0;

end;

end.