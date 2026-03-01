{
  New script template, only shows processed records
  Assigning any nonzero value to Result will terminate script
}
unit xccm;

var
    joWinningCells, joInteriors, joSounds: TJsonObject;
    xtelRefs, tlWeatherRegions: TList;
    slCellsWithSky: TStringList;
    xccmPatchFile: IwbFile;

// Called before processing
// You can remove it if script doesn't require initialization code
function Initialize: integer;
begin
    joWinningCells := TJsonObject.Create;
    joInteriors := TJsonObject.Create;
    joSounds := TJsonObject.Create;
    xtelRefs := TList.Create;
    slCellsWithSky := TStringList.Create;
    tlWeatherRegions := TList.Create;

    CollectRecords;
    ProcessXTELRefs;
    ProcessInteriors;
    ProcessWeatherRegions;
    Result := 0;
end;

// Called after processing
// You can remove it if script doesn't require finalization code
function Finalize: integer;
begin
    joWinningCells.Free;
    joInteriors.Free;
    joSounds.Free;
    xtelRefs.Free;
    tlWeatherRegions.Free;
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
        weatherRegionOriginal := nil;
        weatherRegion := nil;
        cellRecordId := '';


        xtelLinkedRef := WinningOverride(LinksTo(ElementByPath(ref, 'XTEL\Door')));
        if not Assigned(xtelLinkedRef) then continue;
        rCell := WinningOverride(LinksTo(ElementByIndex(xtelLinkedRef, 0)));
        if not Assigned(rCell) then continue;
        if Signature(rCell) <> 'CELL' then continue;
        if (GetElementNativeValues(rCell, 'DATA - Flags\Is Interior Cell') = 0) then continue;
        if (GetElementNativeValues(rCell, 'DATA - Flags\Show Sky') = 0) then continue;
        if (GetElementNativeValues(rCell, 'DATA - Flags\Use Sky Lighting') <> 0) then continue;

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
    rCell, rCellOverride, newWeatherRegion: IwbElement;
begin
    totalChanged := 0;
    totalChecked := 0;
    for i := 0 to Pred(joInteriors.Count) do begin
        originalWeatherRegion := '';
        correctedWeatherRegion := '';
        weatherRegionHere := '';
        countHere := 0;
        bSkip := False;

        Inc(totalChecked);

        cellRecordId := joInteriors.Names[i];
        idx := slCellsWithSky.IndexOf(cellRecordId);
        if idx > -1 then slCellsWithSky.Delete(idx);
        rCell := WinningOverride(GetRecordFromFormIdFileId(cellRecordId));
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
        if not Assigned(correctedWeatherRegion) then begin
            AddMessage('Could not locate the weather region for this interior: ' + Name(GetRecordFromFormIdFileId(cellRecordId)));
            if originalWeatherRegion <> 'NONE' then AddMessage(#9 + 'Original weather region: ' + Name(GetRecordFromFormIdFileId(originalWeatherRegion)));
            AddMessage(#9#9 + 'XTEL references:');
            for a := 0 to Pred(joInteriors.O[cellRecordId].A['XTELReferences'].Count) do begin
                AddMessage(#9#9#9 + joInteriors.O[cellRecordId].A['XTELReferences'].S[a]);
                AddMessage(#9#9#9 + 'In cell: ' + Name(GetRecordFromFormIdFileId(joInteriors.O[cellRecordId].A['XTELReferenceCells'].S[a])));
            end;
            continue;
        end;

        Inc(totalChanged);
        newWeatherRegion := GetRecordFromFormIdFileId(correctedWeatherRegion);
        //if SameText(GetElementEditValues(newWeatherRegion, 'EDID'), 'FXlightRegioninvertWarm') then continue; //Skip this region?
        AddMessage('Cell: ' + Name(rCell));
        if originalWeatherRegion <> 'NONE' then AddMessage(#9 + 'Original weather region: ' + Name(GetRecordFromFormIdFileId(originalWeatherRegion)));
        AddMessage(#9 + 'Corrected weather region: ' + Name(newWeatherRegion));
        AddMessage(#9#9 + 'XTEL references:');
        for a := 0 to Pred(joInteriors.O[cellRecordId].A['XTELReferences'].Count) do begin
            AddMessage(#9#9#9 + Name(GetRecordFromFormIdFileId(joInteriors.O[cellRecordId].A['XTELReferences'].S[a])));
            AddMessage(#9#9#9 + 'In cell: ' + Name(GetRecordFromFormIdFileId(joInteriors.O[cellRecordId].A['XTELReferenceCells'].S[a])));
        end;

        if not Assigned(xccmPatchFile) then begin
            xccmPatchFile := AddNewFile;
            AddMasterIfMissing(xccmPatchFile, GetFileName(FileByIndex(0)));
        end;

        AddRequiredElementMasters(rCell, xccmPatchFile, False, True);
        SortMasters(xccmPatchFile);
        rCellOverride := wbCopyElementToFile(rCell, xccmPatchFile, False, True);
        SetElementEditValues(rCellOverride, 'XCCM', IntToHex(GetLoadOrderFormID(newWeatherRegion), 8));
        SetElementEditValues(rCellOverride, 'DATA - Flags\Show Sky', 1);
    end;
    AddMessage('Total interiors checked: ' + IntToStr(totalChecked));
    AddMessage('Total interiors with mismatched weather region: ' + IntToStr(totalChanged));
    for i := 0 to Pred(slCellsWithSky.Count) do begin
        cellRecordId := slCellsWithSky[i];
        AddMessage('Cell not checked for weather region: ' + Name(GetRecordFromFormIdFileId(cellRecordId)));
    end;
end;

procedure ProcessWeatherRegions;
{
    Process collected weather regions;
}
var
    i, e, j: integer;
    weatherRecordId, weatherSoundType: string;
    weatherRegion, regionDataEntries, regionDataEntry, weatherTypes, weatherType, weatherHere,
    weatherSounds, weatherSound, weatherSoundRecord, intExtSound, weatherOverride: IwbElement;
    slWeatherRecordIds: TStringList;
const
    typesToAttenuate = 'Thunder,Precipitation';
begin
    slWeatherRecordIds := TStringList.Create;
    slWeatherRecordIds.Sorted := True;
    slWeatherRecordIds.Duplicates := dupIgnore;
    try
        for i := 0 to Pred(tlWeatherRegions.Count) do begin
            weatherRegion := ObjectToElement(tlWeatherRegions[i]);
            regionDataEntries := ElementByName(weatherRegion, 'Region Data Entries');
            for e := 0 to Pred(ElementCount(regionDataEntries)) do begin
                regionDataEntry := ElementByIndex(regionDataEntries, e);
                if GetElementEditValues(regionDataEntry, 'RDAT\Type') = 'Weather' then begin
                    weatherTypes := ElementByPath(regionDataEntry, 'RDWT\Weather Types');
                    for j := 0 to Pred(ElementCount(weatherTypes)) do begin
                        weatherType := ElementByIndex(weatherTypes, j);
                        weatherHere := LinksTo(ElementByIndex(weatherType, 0));
                        if Assigned(weatherHere) then begin
                            weatherRecordId := RecordFormIdFileId(weatherHere);
                            slWeatherRecordIds.Add(weatherRecordId);
                            //AddMessage('Found weather: ' + Name(weatherHere));
                        end;
                    end;
                end;
            end;
        end;

        for i := 0 to Pred(slWeatherRecordIds.Count) do begin
            weatherOverride := nil;
            weatherRecordId := slWeatherRecordIds[i];
            weatherHere := WinningOverride(GetRecordFromFormIdFileId(weatherRecordId));
            weatherSounds := ElementByName(weatherHere, 'Sounds');
            for e := 0 to Pred(ElementCount(weatherSounds)) do begin
                weatherSound := ElementByIndex(weatherSounds, e);
                weatherSoundType := GetElementEditValues(weatherSound, 'Type');
                if Pos(weatherSoundType, typesToAttenuate) = 0 then continue;
                weatherSoundRecord := WinningOverride(LinksTo(ElementByIndex(weatherSound, 0)));
                if not Assigned(weatherSoundRecord) then continue;
                intExtSound := MakeAttenuatedCompoundSound(weatherSoundRecord);
                if not Assigned(intExtSound) then continue;
                if not Assigned(weatherOverride) then begin
                    AddRequiredElementMasters(weatherHere, xccmPatchFile, False, True);
                    SortMasters(xccmPatchFile);
                    weatherOverride := wbCopyElementToFile(weatherHere, xccmPatchFile, False, True);
                end;
                SetElementEditValues(weatherOverride, 'Sounds\SNAM - Sound #' + IntToStr(e) + '\Sound', IntToHex(GetLoadOrderFormID(intExtSound), 8));
            end;
        end;

    finally
        slWeatherRecordIds.Free;
    end;
end;

function MakeAttenuatedCompoundSound(soundRecord: IwbElement): IwbElement;
{
    Creates a new sound record with attenuated interior sound levels based on the given sound record.
}
var
    compoundSound, intSound, extSound, conditions, descriptors, descriptor: IwbElement;
    soundGroup: IwbGroupRecord;
    edid: string;
    currentAttenuation: double;
begin
    Result := nil;
    edid := GetElementEditValues(soundRecord, 'EDID');
    if joSounds.O[edid + '_Compound'].S['compound'] <> '' then begin
        Result := GetRecordFromFormIdFileId(joSounds.O[edid + '_Compound'].S['compound']);
        Exit;
    end;
    if SoundAlreadyHasInteriorConditionCheck(soundRecord) then Exit;

    AddRequiredElementMasters(soundRecord, xccmPatchFile, False, True);
    SortMasters(xccmPatchFile);

    //Add condition to original sound to not play in interiors
    extSound := wbCopyElementToFile(soundRecord, xccmPatchFile, False, True);
    AddCondition(extSound, 'Equal To', 'IsInInterior', '0.0', 'Subject');
    currentAttenuation := GetElementNativeValues(extSound, 'BNAM - Data\Values\Static Attenuation (db)');

    //Duplicate sound and attenuate for interiors
    intSound := wbCopyElementToFile(soundRecord, xccmPatchFile, True, True);
    SetEditorID(intSound, edid + '_Interior');
    AddCondition(intSound, 'Equal To', 'IsInInterior', '1.0', 'Subject');
    //Increase attenuation by 20db for interiors
    SetElementNativeValues(intSound, 'BNAM - Data\Values\Static Attenuation (db)', currentAttenuation + 20);

    //create compound sound to play the correct sound based on interior/exterior conditions
    soundGroup := GroupBySignature(xccmPatchFile, 'SNDR');
    compoundSound := Add(soundGroup, 'Compound Sound', True);
    SetEditorID(compoundSound, edid + '_Compound');
    SetElementEditValues(compoundSound, 'CNAM', 'Compound');
    descriptors := Add(compoundSound, 'Descriptors', True);
    descriptor := ElementAssign(descriptors, HighInteger, nil, False);
    SetEditValue(descriptor, IntToHex(GetLoadOrderFormID(extSound), 8));
    descriptor := ElementAssign(descriptors, HighInteger, nil, False);
    SetEditValue(descriptor, IntToHex(GetLoadOrderFormID(intSound), 8));
    joSounds.O[edid + '_Compound'].S['compound'] := RecordFormIdFileId(compoundSound);

    Result := compoundSound;
end;

function SoundAlreadyHasInteriorConditionCheck(soundRecord: IwbElement): boolean;
{
    Checks if the given sound record has an interior condition check.
}
var
    conditions: IwbElement;
    i: integer;
begin
    conditions := ElementByName(soundRecord, 'Conditions');
    for i := 0 to Pred(ElementCount(conditions)) do begin
        if GetElementEditValues(ElementByIndex(conditions, i), 'CTDA\Function') = 'IsInInterior' then begin
            Result := True;
            Exit;
        end;
    end;
    Result := False;
end;

procedure AddCondition(e: IwbElement; conditionType, conditionFunction, conditionValue, conditionRunOn: string);
{
  Add a condition to the given element.
}
var
    i: integer;

    el, conditions, condition: IwbElement;
begin
    if not ElementExists(e, 'Conditions') then begin
        conditions := Add(e, 'Conditions', True);
        condition := ElementByIndex(conditions, 0);
        SetElementEditValues(condition, 'CTDA\Type', conditionType);
        SetElementEditValues(condition, 'CTDA\Function', conditionFunction);
        SetElementEditValues(condition, 'CTDA\Comparison Value - Float', conditionValue);
        SetElementEditValues(condition, 'CTDA\Run On', conditionRunOn);
    end
    else begin
        conditions := ElementByPath(e, 'Conditions');
        condition := ElementAssign(conditions, HighInteger, nil, False);
        SetElementEditValues(condition, 'CTDA\Type', conditionType);
        SetElementEditValues(condition, 'CTDA\Function', conditionFunction);
        SetElementEditValues(condition, 'CTDA\Comparison Value - Float', conditionValue);
        SetElementEditValues(condition, 'CTDA\Run On', conditionRunOn);
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
