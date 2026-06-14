{
    Given a cell, make a SCOL of all precombinable references in it.
}
unit SCOL;

var
    joPlacedReferences, joWinningCells: TJSONObject;

function Initialize: integer;
begin
    joPlacedReferences := TJSONObject.Create;
    joWinningCells := TJSONObject.Create;
    Result := 0;
end;

function Finalize: integer;
begin
    joPlacedReferences.Free;
    joWinningCells.Free;
    Result := 0;
end;

function Process(rCell: IInterface): integer;
var
    i, j, count, xcriCount, blockidx, cx, cy: integer;
    r, mCell, cCell, rWrld, pCell: IwbElement;
    cellchild, wrldgroup: IwbGroupRecord;
    wrldEdid: string;
    position: TwbVector;
    c: TwbGridCell;
    posX, posY, posZ: double;
begin
    if Signature(rCell) <> 'CELL' then Exit;
    AddMessage('Processing: ' + Name(rCell));
    mCell := MasterOrSelf(rCell);

    // Check references for master cell
    cellchild := FindChildGroup(ChildGroup(mCell), 9, mCell); // get Temporary group of cell
    for j := Pred(ElementCount(cellchild)) downto 0 do begin
        r := ElementByIndex(cellchild, j);
        if Signature(r) <> 'REFR' then Continue;
        if not IsWinningOverride(r) then Continue;
        if not IsRefPrecombinable(r) then Continue;
        AddMessage('Precombinable reference found: ' + Name(r));
        Inc(count);
    end;
    cellchild := FindChildGroup(ChildGroup(rCell), 8, rCell); // get Persistent group of cell
    for j := Pred(ElementCount(cellchild)) downto 0 do begin
        r := ElementByIndex(cellchild, j);
        if Signature(r) <> 'REFR' then Continue;
        if not IsWinningOverride(r) then Continue;
        if not IsRefPrecombinable(r) then Continue;
        AddMessage('Precombinable reference found: ' + Name(r));
        Inc(count);
    end;


    // Check references in downstream plugins that override the cell
    for i := Pred(OverrideCount(mCell)) downto 0 do begin
        cCell := OverrideByIndex(mCell, i);
        cellchild := FindChildGroup(ChildGroup(cCell), 9, cCell); // get Temporary group of cell
        for j := Pred(ElementCount(cellchild)) downto 0 do begin
            r := ElementByIndex(cellchild, j);
            if Signature(r) <> 'REFR' then Continue;
            if not IsWinningOverride(r) then Continue;
            if not IsRefPrecombinable(r) then Continue;
            AddMessage('Precombinable reference found: ' + Name(r));
            Inc(count);
        end;
        cellchild := FindChildGroup(ChildGroup(cCell), 9, cCell); // get Persistent group of cell
        for j := Pred(ElementCount(cellchild)) downto 0 do begin
            r := ElementByIndex(cellchild, j);
            if Signature(r) <> 'REFR' then Continue;
            if not IsWinningOverride(r) then Continue;
            if not IsRefPrecombinable(r) then Continue;
            AddMessage('Precombinable reference found: ' + Name(r));
            Inc(count);
        end;
    end;

    // Check persistent worldspace cell
    // if (GetElementNativeValues(rCell, 'DATA - Flags\Is Interior Cell') <> 0) then begin
    //     rWrld := MasterOrSelf(ElementByIndex(rCell, 0));
    //     if Signature(rWrld) = 'WRLD' then begin
    //         wrldEdid := GetElementEditValues(rWrld, 'EDID');
    //         cx := GetElementNativeValues(rCell, 'XCLC\X');
    //         cy := GetElementNativeValues(rCell, 'XCLC\Y');

    //         wrldgroup := ChildGroup(rWrld);
    //         for blockidx := 0 to Pred(ElementCount(wrldgroup)) do begin
    //             pCell := ElementByIndex(wrldgroup, blockidx);
    //             if Signature(pCell) <> 'CELL' then Continue;
    //             joWinningCells.O[wrldEdid].O['PersistentWorldspaceCell'].S['RecordID'] := RecordFormIdFileId(pCell);
    //         end;
    //         if Assigned(pCell) then begin
    //             cellchild := FindChildGroup(ChildGroup(pCell), 8, pCell); // get Persistent group of cell
    //             for j := Pred(ElementCount(cellchild)) downto 0 do begin
    //                 r := ElementByIndex(cellchild, j);
    //                 if Signature(r) <> 'REFR' then Continue;
    //                 if not IsWinningOverride(r) then Continue;

    //                 posX := GetElementNativeValues(r, 'DATA\Position\X');
    //                 posY := GetElementNativeValues(r, 'DATA\Position\Y');
    //                 posZ := GetElementNativeValues(r, 'DATA\Position\Z');
    //                 position.x := posX;
    //                 position.y := posY;
    //                 position.z := posZ;
    //                 c := wbPositionToGridCell(position);

    //                 if (c.x <> cx) or (c.y <> cy) then Continue; // skip references not in current cell

    //                 if not IsRefPrecombinable(r) then Continue;
    //                 AddMessage('Precombinable reference found in persistent worldspace cell: ' + Name(r));
    //                 Inc(count);
    //             end;
    //         end;
    //     end;
    // end;

    if count > 0 then
        AddMessage('Total precombinable references found: ' + IntToStr(count));

    // Count xcri references
    xcriCount := ElementCount(ElementByPath(rCell, 'XCRI\References'));
    AddMessage('Total XCRI references found: ' + IntToStr(xcriCount));

    Result := 0;
end;

function IsRefPrecombinable(r: IwbMainRecord): boolean;
var
    base: IwbMainRecord;
    lref: IwbElement;
    bPrecombinableBase: boolean;
begin
    Result := False;
    bPrecombinableBase := False;
    if GetIsDeleted(r) then Exit;
    if GetIsInitiallyDisabled(r) then Exit;
    base := WinningOverride(BaseRecord(r));
    if Signature(base) = 'SCOL' then begin
        bPrecombinableBase := True;
    end;
    if Signature(base) = 'STAT' then begin
        if (GetElementNativeValues(base, 'Record Header\Record Flags\Is Marker') <> 0) then Exit; // Skip markers
        if ElementExists(base, 'FTYP') then Exit;
        bPrecombinableBase := True;
    end;
    if not bPrecombinableBase then Exit;
    if ElementExists(r, 'XESP') then Exit;  //Skip enable parented reference
    if ElementExists(r, 'XATR') then Exit;  //Skip attached reference
    if ElementExists(r, 'XEMI') then Exit;  //Skip external emittance
    if ElementExists(r, 'XLRT') then Exit;  //Skip location reference type
    if ElementExists(r, 'Linked References') then begin
        lref := ElementByPath(r, 'Linked References\XLKR - Linked Reference');
        if not Assigned(lref) then Exit;  // skip null linked reference
        if (ElementCount(lref) <> 2) then Exit;
        if (GetLoadOrderFormID(LinksTo(ElementByIndex(lref, 0))) <> $00195411) then Exit;   // MultiRefLOD is precombinable
    end;
    Result := True;
end;

function RecordFormIdFileId(e: IwbElement): string;
{
    Returns the record ID of an element.
}
begin
    e := MasterOrSelf(e);
    Result := IntToHex(FormID(e), 8) + ':' + GetFileName(GetFile(e));
end;

function GetRecordFromFormIdFileId(recordId: string): IwbElement;
{
    Returns the record from the given formid:filename.
}
var
    colonPos, recordFormId: integer;
    f: IwbFile;
begin
    colonPos := Pos(':', recordId);
    recordFormId := StrToInt('$' + Copy(recordId, 1, Pred(colonPos)));
    f := FileByName(Copy(recordId, Succ(colonPos), Length(recordId)));
    Result := RecordByFormID(f, recordFormId, False);
end;

end.