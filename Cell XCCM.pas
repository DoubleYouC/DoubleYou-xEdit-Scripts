{
  New script template, only shows processed records
  Assigning any nonzero value to Result will terminate script
}
unit xccm;

var
    joWinningCells, joInteriors: TJsonObject;
    xtelRefs: TList;
    slCellsWithSky: TStringList;

// Called before processing
// You can remove it if script doesn't require initialization code
function Initialize: integer;
begin
    joWinningCells := TJsonObject.Create;
    joInteriors := TJsonObject.Create;
    xtelRefs := TList.Create;
    slCellsWithSky := TStringList.Create;

    CollectRecords;
    ProcessXTELRefs;
    ProcessInteriors;
    Result := 0;
end;

// Called after processing
// You can remove it if script doesn't require finalization code
function Finalize: integer;
begin
    joWinningCells.Free;
    joInteriors.Free;
    xtelRefs.Free;
    slCellsWithSky.Free;
    Result := 0;
end;

procedure CollectRecords;
{
    Collect records;
}
var
    i, j, k, count, blockidx, subblockidx, cellidx: integer;
    recordid, wrldEdid, cellX, cellY: string;
    f: IwbFile;
    g, wrldgroup, refs: IwbGroupRecord;
    rWrld, block, subblock, rCell, ref: IwbElement;
begin
    count := 0;
    for i := 0 to Pred(FileCount) do begin
        f := FileByIndex(i);

        g := GroupBySignature(f, 'CELL');
        for j := 0 to Pred(ElementCount(g)) do begin
            block := ElementByIndex(g, j);
            for subblockidx := 0 to Pred(ElementCount(block)) do begin
                subblock := ElementByIndex(block, subblockidx);
                for cellidx := 0 to Pred(ElementCount(subblock)) do begin
                    rCell := ElementByIndex(subblock, cellidx);

                    if not IsWinningOverride(rCell) then continue;

                    if (Signature(rCell) <> 'CELL') then continue;
                    if (GetElementNativeValues(rCell, 'DATA - Flags\Show Sky') = 0) then continue;
                    Inc(count);
                    slCellsWithSky.Add(RecordFormIdFileId(rCell));
                end;
            end;
        end;


        g := GroupBySignature(f, 'WRLD');
        for j := 0 to Pred(ElementCount(g)) do begin
            rWrld := ElementByIndex(g, j);
            recordid := RecordFormIdFileId(rWrld);

            wrldEdid := GetElementEditValues(rWrld, 'EDID');
            joWinningCells.O[wrldEdid].S['RecordID'] := RecordFormIdFileId(rWrld);

            wrldgroup := ChildGroup(rWrld);
            for blockidx := 0 to Pred(ElementCount(wrldgroup)) do begin
                block := ElementByIndex(wrldgroup, blockidx);
                if Signature(block) = 'CELL' then begin
                    //Found persistent worldspace cell
                    rCell := block;
                    joWinningCells.O[wrldEdid].O['PersistentWorldspaceCell'].S['RecordID'] := RecordFormIdFileId(rCell);
                    refs := FindChildGroup(ChildGroup(rCell), 8, rCell);
                    for k := 0 to Pred(ElementCount(refs)) do begin
                        ref := ElementByIndex(refs, k);
                        if ElementExists(ref, 'XTEL') then begin
                            xtelRefs.Add(ref);
                            //AddMessage('Found XTEL reference: ' + Name(ref));
                        end;
                    end;
                end;
                for subblockidx := 0 to Pred(ElementCount(block)) do begin
                    subblock := ElementByIndex(block, subblockidx);
                    for cellidx := 0 to Pred(ElementCount(subblock)) do begin
                        rCell := ElementByIndex(subblock, cellidx);
                        if (Signature(rCell) <> 'CELL') then continue;
                        if not GetIsPersistent(rCell) then begin
                            cellX := GetElementNativeValues(rCell, 'XCLC\X');
                            cellY := GetElementNativeValues(rCell, 'XCLC\Y');
                            //AddMessage('Found cell: ' + Name(rCell) + ' at ' + cellX + ',' + cellY);
                            joWinningCells.O[wrldEdid].O[cellX].O[cellY].S['RecordID'] := RecordFormIdFileId(rCell);
                        end;
                        //if count > 10 then break;
                    end;
                    //if count > 10 then break;
                end;
                //if count > 10 then break;
            end;
            //if count > 10 then break;
        end;
    end;
    AddMessage('Found ' + IntToStr(count) + ' interior cells with Show Sky flag set.');
end;

procedure ProcessXTELRefs;
{
    Process collected XTEL references;
}
var
    i, count, withSky: integer;
    wrldEdid, cellRecordId: string;
    ref: IwbElement;
    position: TwbVector;
    c: TwbGridCell;
    weatherRegionOriginal, weatherRegion, xtelLinkedRef, rCell: IwbElement;
begin
    for i := 0 to Pred(xtelRefs.Count) do begin
        ref := ObjectToElement(xtelRefs[i]);


        xtelLinkedRef := WinningOverride(LinksTo(ElementByPath(ref, 'XTEL\Door')));
        if not Assigned(xtelLinkedRef) then continue;
        rCell := WinningOverride(LinksTo(ElementByIndex(xtelLinkedRef, 0)));
        if not Assigned(rCell) then continue;
        if Signature(rCell) <> 'CELL' then continue;
        if (GetElementNativeValues(rCell, 'DATA - Flags\Is Interior Cell') = 0) then continue;
        if (GetElementNativeValues(rCell, 'DATA - Flags\Show Sky') = 0) then continue;

        //AddMessage('Processing XTEL reference: ' + Name(ref));
        if ElementExists(rCell, 'XCCM') then begin
            weatherRegionOriginal := LinksTo(ElementByPath(rCell, 'XCCM'));
            //AddMessage('Found XCCM weather region: ' + Name(weatherRegionOriginal));
        end;

        position.X := GetElementNativeValues(ref, 'DATA\Position\X');
        position.Y := GetElementNativeValues(ref, 'DATA\Position\Y');
        position.Z := GetElementNativeValues(ref, 'DATA\Position\Z');
        wrldEdid := GetElementEditValues(LinksTo(ElementbyIndex(LinksTo(ElementByIndex(ref, 0)), 0)), 'EDID');
        //AddMessage('XTEL reference is in world: ' + wrldEdid);

        c := wbPositionToGridCell(position);
        cellRecordId := joWinningCells.O[wrldEdid].O[c.X].O[c.Y].S['RecordID'];
        //AddMessage('XTEL reference is in cell: ' + Name(GetRecordFromFormIdFileId(cellRecordId)));
        weatherRegion := FindWeatherRegionForWorldspaceCell(wrldEdid, cellRecordId);
        // if Assigned(weatherRegion) then begin
        //     //AddMessage('Found weather region: ' + Name(weatherRegion));
        // end;
        //else AddMessage('No weather region found for cell.');
        if Assigned(weatherRegionOriginal) then
            joInteriors.O[RecordFormIdFileId(rCell)].S['OriginalWeatherRegion'] := RecordFormIdFileId(weatherRegionOriginal)
        else
            joInteriors.O[RecordFormIdFileId(rCell)].S['OriginalWeatherRegion'] := 'NONE';
        if Assigned(weatherRegion) then
            joInteriors.O[RecordFormIdFileId(rCell)].O['CorrectedWeatherRegions'].I[RecordFormIdFileId(weatherRegion)] := joInteriors.O[RecordFormIdFileId(rCell)].O['CorrectedWeatherRegions'].I[RecordFormIdFileId(weatherRegion)] + 1;
        joInteriors.O[RecordFormIdFileId(rCell)].A['XTELReferences'].Add(RecordFormIdFileId(ref));
        joInteriors.O[RecordFormIdFileId(rCell)].A['XTELReferenceCells'].Add(cellRecordId);
        // if RecordFormIdFileId(weatherRegionOriginal) <> RecordFormIdFileId(weatherRegion) then begin
        //     if Assigned(weatherRegion) then begin
        //         // AddMessage('Cell: ' + Name(rCell));
        //         // if Assigned(weatherRegionOriginal) then AddMessage(#9 + 'Original weather region: ' + Name(weatherRegionOriginal))
        //         // else AddMessage('Original weather region: NONE');
        //         // AddMessage(#9 + 'Corrected weather region: ' + Name(weatherRegion));
        //         // AddMessage(#9#9 + 'XTEL reference: ' + Name(ref));
        //         // AddMessage(#9#9 + 'XTEL reference is in cell: ' + Name(GetRecordFromFormIdFileId(cellRecordId)));
        //         joInteriors.O[RecordFormIdFileId(rCell)].S['OriginalWeatherRegion'] := RecordFormIdFileId(weatherRegionOriginal);
        //         joInteriors.O[RecordFormIdFileId(rCell)].A['CorrectedWeatherRegions'].Add(RecordFormIdFileId(weatherRegion));
        //         joInteriors.O[RecordFormIdFileId(rCell)].A['XTELReferences'].Add(RecordFormIdFileId(ref));
        //         joInteriors.O[RecordFormIdFileId(rCell)].A['XTELReferenceCells'].Add(cellRecordId);
        //     end;
        // end;
    end;
end;

procedure ProcessInteriors;
{
    Process collected interiors;
}
var
    bSkip: boolean;
    a, i, r, idx, count, countHere, totalChanged, totalChecked: integer;
    cellRecordId, originalWeatherRegion, correctedWeatherRegion, weatherRegionHere: string;
    rCell: IwbElement;
begin
    totalChanged := 0;
    totalChecked := 0;
    for i := 0 to Pred(joInteriors.Count) do begin
        Inc(totalChecked);
        bSkip := False;
        cellRecordId := joInteriors.Names[i];
        idx := slCellsWithSky.IndexOf(cellRecordId);
        if idx > -1 then slCellsWithSky.Delete(idx);
        rCell := GetRecordFromFormIdFileId(cellRecordId);
        originalWeatherRegion := joInteriors.O[cellRecordId].S['OriginalWeatherRegion'];

        //Skip if the cell already has the correct weather region assigned to it.
        for a := 0 to Pred(joInteriors.O[cellRecordId].O['CorrectedWeatherRegions'].Count) do begin
            if SameText(joInteriors.O[cellRecordId].O['CorrectedWeatherRegions'].Names[a], originalWeatherRegion) then begin
                bSkip := True;
            end;
        end;
        if bSkip then continue;
        count := 0;
        for r := 0 to Pred(joInteriors.O[cellRecordId].O['CorrectedWeatherRegions'].Count) do begin
            weatherRegionHere := joInteriors.O[cellRecordId].O['CorrectedWeatherRegions'].Names[r];
            countHere := joInteriors.O[cellRecordId].O['CorrectedWeatherRegions'].I[weatherRegionHere];
            if r = 0 then begin
                correctedWeatherRegion := weatherRegionHere;
                count := joInteriors.O[cellRecordId].O['CorrectedWeatherRegions'].I[correctedWeatherRegion];
            end
            else if countHere > count then begin
                correctedWeatherRegion := weatherRegionHere;
                count := countHere;
            end;
        end;
        Inc(totalChanged);
        AddMessage('Cell: ' + Name(rCell));
        AddMessage(#9 + 'Original weather region: ' + Name(GetRecordFromFormIdFileId(originalWeatherRegion)));
        AddMessage(#9 + 'Corrected weather region: ' + Name(GetRecordFromFormIdFileId(correctedWeatherRegion)));
    end;
    AddMessage('Total interiors checked: ' + IntToStr(totalChecked));
    AddMessage('Total interiors with mismatched weather region: ' + IntToStr(totalChanged));
    for i := 0 to Pred(slCellsWithSky.Count) do begin
        cellRecordId := slCellsWithSky[i];
        AddMessage('Cell not checked for weather region: ' + Name(GetRecordFromFormIdFileId(cellRecordId)));
    end;
end;

function FindWeatherRegionForWorldspaceCell(wrldEdid, cellRecordId: string): IwbElement;
{
    Finds the weather region for the given cell.
}
var
    rCell, rWrld, parentWorldspace: IwbElement;
begin
    rCell := WinningOverride(GetRecordFromFormIdFileId(cellRecordId));
    if not ElementExists(rCell, 'XCLR') then begin
        rCell := WinningOverride(GetRecordFromFormIdFileId(joWinningCells.O[wrldEdid].O['PersistentWorldspaceCell'].S['RecordID']));
        if not ElementExists(rCell, 'XCLR') then begin
            rWrld := WinningOverride(LinksTo(ElementByIndex(rCell, 0)));
            parentWorldspace := LinksTo(ElementByPath(rWrld, 'Parent Worldspace\WNAM'));
            if Assigned(parentWorldspace) then begin
                rCell := WinningOverride(GetRecordFromFormIdFileId(joWinningCells.O[GetElementEditValues(parentWorldspace, 'EDID')].O['PersistentWorldspaceCell'].S['RecordID']));
                if not ElementExists(rCell, 'XCLR') then begin
                    AddMessage('No XCLR found for cell or parent worldspace cell.');
                    Result := nil;
                    Exit;
                end;
            end;
        end;
    end;
    Result := FindWeatherRegionForCell(rCell);
end;

function FindWeatherRegionForCell(rCell: IwbElement): IwbElement;
{
    Finds the weather region for the given cell.
}
var
    bFoundWeatherRegion, bHasOverride: boolean;
    i, e, priority, priorityHere: integer;
    xclr, region, regionDataEntries, regionDataEntry, weatherRegion: IwbElement;
begin
    bFoundWeatherRegion := False;
    bHasOverride := False;
    priority := 0;
    xclr := ElementByPath(rCell, 'XCLR');
    for i := 0 to Pred(ElementCount(xclr)) do begin
        region := LinksTo(ElementByIndex(xclr, i));
        regionDataEntries := ElementByName(region, 'Region Data Entries');
        for e := 0 to Pred(ElementCount(regionDataEntries)) do begin
            regionDataEntry := ElementByIndex(regionDataEntries, e);
            if GetElementEditValues(regionDataEntry, 'RDAT\Type') = 'Weather' then begin
                bFoundWeatherRegion := True;
                if GetElementEditValues(regionDataEntry, 'RDAT\Override') = 'False' then begin
                    weatherRegion := region;
                    bHasOverride := True;
                end
                else if not bHasOverride then begin
                    priorityHere := GetElementNativeValues(regionDataEntry, 'RDAT\Priority');
                    if priorityHere > priority then begin
                        priority := priorityHere;
                        weatherRegion := region;
                    end;
                end;
            end;
        end;
    end;
    if bFoundWeatherRegion then Result := weatherRegion else Result := nil;
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
