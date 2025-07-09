{
  Make SCOL from STAT references
}
unit MakeSCOL;

const
    signatures = 'STAT';

var
    joSCOL: TJsonObject;
    orX, orY, orZ: Double;
    TargetFile, OffsetFile: IInterface;
    offsetReferenceInt: integer;
    offsetReferenceStr, sOffsetMasterName, sTargetFileName, sSCOLEditorId: string;

function Initialize: integer;
var
    offsetRef, f: IInterface;
    i: integer;
begin
    if not InputQuery('Enter', 'Enter the offset reference formid. Format should be 1C9A49', offsetReferenceStr) then begin
        AddMessage('Operation cancelled.');
        Result := 2;
        Exit;
    end;
    AddMessage('Offset Reference: ' + offsetReferenceStr);
    offsetReferenceInt := StrToInt('$' + offsetReferenceStr);

    if not InputQuery('Enter', 'Enter the offset reference file name. Format should be Fallout4.esm', sOffsetMasterName) then begin
        AddMessage('Operation cancelled.');
        Result := 2;
        Exit;
    end else AddMessage('Offset Reference File: ' + sOffsetMasterName);

    if not InputQuery('Enter', 'Enter the Target File.', sTargetFileName) then begin
        AddMessage('Operation cancelled.');
        Result := 2;
        Exit;
    end else AddMessage('Target File: ' + sTargetFileName);

    if not InputQuery('Enter', 'Enter the Editor ID you want for your new SCOL.', sSCOLEditorId) then begin
        AddMessage('Operation cancelled.');
        Result := 2;
        Exit;
    end else AddMessage('Editor ID: ' + sSCOLEditorId);

    for i := 0 to Pred(FileCount) do begin
        f := GetFileName(FileByIndex(i));
        if SameText(f, sOffsetMasterName) then
            OffsetFile := FileByIndex(i)
        else if SameText(f, sTargetFileName) then
            TargetFile := FileByIndex(i);
    end;

    offsetRef := RecordByFormID(OffsetFile, offsetReferenceInt, False);
    orX := GetElementNativeValues(offsetRef, 'DATA\Position\X');
    orY := GetElementNativeValues(offsetRef, 'DATA\Position\Y');
    orZ := GetElementNativeValues(offsetRef, 'DATA\Position\Z');

    joSCOL := TJsonObject.Create;
    Result := 0;
end;

// called for every record selected in xEdit
function Process(e: IInterface): integer;
var
    base: IInterface;
    pX, pY, pZ, rX, rY, rZ, scale: string;
begin
    Result := 0;

    if Signature(e) <> 'REFR' then Exit;
    if GetIsDeleted(e) then Exit;
    if GetIsCleanDeleted(e) then Exit;

    base := LinksTo(ElementBySignature(e, 'NAME'));
    if not Assigned(base) then begin
        AddMessage('No base record found for ' + Name(e));
        Exit;
    end;

    if Pos(Signature(base), signatures) = 0 then begin
        AddMessage('Base record ' + Name(base) + ' is not a valid type: ' + Signature(base));
        Exit;
    end;
    pX := FloatToStr(GetElementNativeValues(e, 'DATA\Position\X') - orX);
    pY := FloatToStr(GetElementNativeValues(e, 'DATA\Position\Y') - orY);
    pZ := FloatToStr(GetElementNativeValues(e, 'DATA\Position\Z') - orZ);
    rX := GetElementEditValues(e, 'DATA\Rotation\X');
    rY := GetElementEditValues(e, 'DATA\Rotation\Y');
    rZ := GetElementEditValues(e, 'DATA\Rotation\Z');
    if ElementExists(e, 'XSCL') then
        scale := GetElementEditValues(e, 'XSCL')
    else
        scale := '1.0';
    joSCOL.O[ShortName(base)].A['Placements'].Add(pX + ',' + pY + ',' + pZ + ',' + rX + ',' + rY + ',' + rZ + ',' + scale);

end;

function GetIsCleanDeleted(r: IInterface): Boolean;
{
    Checks to see if a reference has an XESP set to opposite of the PlayerRef
}
begin
    Result := False;
    if not ElementExists(r, 'XESP') then Exit;
    if not GetElementEditValues(r, 'XESP\Flags\Set Enable State to Opposite of Parent') = '1' then Exit;
    if GetElementEditValues(r, 'XESP\Reference') <> 'PlayerRef [PLYR:00000014]' then Exit;
    Result := True;
end;

function Finalize: integer;
var
    a, c, n, DelimPos, t: integer;
    placementValue, Token, key: string;
    scolGroup, scol, parts, part, onam, placement, placements: IInterface;
begin
    //Add SCOL group to TargetFile
    if HasGroup(TargetFile, 'SCOL') then
        scolGroup := GroupBySignature(TargetFile, 'SCOL')
    else scolGroup := Add(TargetFile, 'SCOL', True);
    if not Assigned(scolGroup) then begin
        AddMessage('Failed to create SCOL group in ' + Name(TargetFile));
        Exit;
    end;

    //Add SCOL record to SCOL group
    scol := Add(scolGroup, 'SCOL', True);
    SetEditorID(scol, sSCOLEditorId);

    //Add Parts
    parts := Add(scol, 'Parts', True);
    part := ElementbyIndex(parts, 0);
    onam := ElementByPath(part, 'ONAM');
    SetEditValue(onam, 'StaticCollectionPivotDummy [STAT:00035812]');

    t := 0;
    for c := 0 to Pred(joSCOL.Count) do begin
        key := joSCOL.Names[c];
        AddMessage(key);

        // Add ONAM for each key (base STAT)
        part := Add(parts, 'Part', True);
        onam := ElementByPath(part, 'ONAM');
        SetEditValue(onam, key);

        placements := Add(part, 'DATA', True);
        for a := 0 to Pred(joSCOL.O[key].A['Placements'].Count) do begin
            t := t + 1;
            placement := Add(placements, 'Placement', True);
            // Add Placement for each placement in the key
            placementValue := joSCOL.O[key].A['Placements'].S[a];
            AddMessage(#9 + 'Placement: ' + placementValue);
            n := 0;
            while placementValue <> '' do begin
                DelimPos := Pos(',', placementValue);
                if DelimPos > 0 then begin
                    Token := Copy(placementValue, 1, DelimPos - 1);
                    Delete(placementValue, 1, DelimPos);
                end
                else begin
                    Token := placementValue;
                    placementValue := '';
                end;
                n := n + 1;

                Case n of
                    1 : SetElementEditValues(placement, 'Position\X', Token);
                    2 : SetElementEditValues(placement, 'Position\Y', Token);
                    3 : SetElementEditValues(placement, 'Position\Z', Token);
                    4 : SetElementEditValues(placement, 'Rotation\X', Token);
                    5 : SetElementEditValues(placement, 'Rotation\Y', Token);
                    6 : SetElementEditValues(placement, 'Rotation\Z', Token);
                    7 : SetElementEditValues(placement, 'Scale', Token);
                end;
            end;
        end;
    end;
    AddMessage('Total placements: ' + IntToStr(t));
    joSCOL.Free;
    Result := 0;
end;

end.