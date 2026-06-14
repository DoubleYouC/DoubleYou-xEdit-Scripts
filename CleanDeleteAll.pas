{
    Clean Delete All selected REFR
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

    // comment this out if you don't want those messages
    if Signature(e) <> 'REFR' then Exit;
    SetElementEditValues(e, 'Record Header\Record Flags\Initially Disabled', '1');
    SetElementEditValues(e, 'Record Header\Record Flags\Deleted', '0');
    SetElementEditValues(e, 'Record Header\Record Flags\Is Full LOD', '0');
    if not ElementExists(e, 'XESP') then begin
        xesp := Add(e, 'XESP', True);
        xesp := ElementAssign(xesp, 0, nil, False);
    end;
    SetElementEditValues(e, 'XESP\Reference', '14');
    SetElementEditValues(e, 'XESP\Flags\Set Enable State to Opposite of Parent', '1');
    SetElementEditValues(e, 'DATA\Position\Z', '-30000');


    // processing code goes here

end;

// Called after processing
// You can remove it if script doesn't require finalization code
function Finalize: integer;
begin
    Result := 0;
end;

end.
