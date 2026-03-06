{
  New script template, only shows processed records
  Assigning any nonzero value to Result will terminate script
}
unit xccm;

var
    joWinningCells, joInteriors, joSounds, joImageSpaces, joWeatherRegions, joWeathers: TJsonObject;
    xtelRefs, tlWeatherRegions: TList;
    slCellsWithSky: TStringList;
    xccmPatchFile: IwbFile;
    exteriorWeatherSoundCategory, interiorWeatherSoundCategory: IwbElement;
    exteriorWeatherSoundCategoryFormId, interiorWeatherSoundCategoryFormId: string;
const
    typesToAttenuate = 'Thunder,Precipitation';

// Called before processing
// You can remove it if script doesn't require initialization code
function Initialize: integer;
begin
    try
        joWinningCells := TJsonObject.Create;
        joInteriors := TJsonObject.Create;
        joSounds := TJsonObject.Create;
        joImageSpaces := TJsonObject.Create;
        joWeatherRegions := TJsonObject.Create;
        joWeathers := TJsonObject.Create;
        xtelRefs := TList.Create;
        slCellsWithSky := TStringList.Create;
        tlWeatherRegions := TList.Create;

        CollectRecords;
        ProcessXTELRefs;
        ProcessInteriors;
        ProcessWeatherRegions;
    finally
        joWinningCells.Free;
        joInteriors.Free;
        joSounds.Free;
        joImageSpaces.Free;
        joWeatherRegions.Free;
        joWeathers.Free;
        xtelRefs.Free;
        tlWeatherRegions.Free;
        slCellsWithSky.Free;
    end;
    Result := 0;
end;

// Called after processing
// You can remove it if script doesn't require finalization code
function Finalize: integer;
begin
    Result := 0;
end;

function AddRefToPatch(ref: IwbElement): IwbElement;
{
    Adds a reference to the patch file and returns the new reference element.
}
var
    n: IwbElement;
begin
    AddRequiredElementMasters(ref, xccmPatchFile, False, True);
    SortMasters(xccmPatchFile);
    n := wbCopyElementToFile(ref, xccmPatchFile, False, True);
    SetFormVCS1(n, GetFormVCS1(ref));
    SetFormVCS2(n, GetFormVCS2(ref));
    Result := n;
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
                        if not IsWinningOverride(rCell) then continue;
                        if (Signature(rCell) <> 'CELL') then continue;
                        if not GetIsPersistent(rCell) then begin
                            cellX := GetElementNativeValues(rCell, 'XCLC\X');
                            cellY := GetElementNativeValues(rCell, 'XCLC\Y');
                            //AddMessage('Found cell: ' + Name(rCell) + ' at ' + cellX + ',' + cellY);
                            joWinningCells.O[wrldEdid].O[cellX].O[cellY].S['RecordID'] := RecordFormIdFileId(rCell);
                            VerifyWeatherRegionsForCell(rCell);
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
        //if (GetElementNativeValues(rCell, 'DATA - Flags\Show Sky') = 0) then continue;
        //if (GetElementNativeValues(rCell, 'DATA - Flags\Use Sky Lighting') <> 0) then continue;

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
        weatherRegion := FindWeatherRegionForWorldspaceCell(wrldEdid, cellRecordId, c.X, c.Y);
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
    bSkip, bWeatherRegionHasPrecipitation: boolean;
    a, i, r, c, idx, count, countHere, totalChanged, totalChecked: integer;
    cellRecordId, originalWeatherRegion, correctedWeatherRegion, weatherRegionHere,
    xcimEditorID: string;
    rCell, rCellOverride, newWeatherRegion, xcim, xtelCell, xtelCellOverride, rWrld: IwbElement;
begin
    totalChanged := 0;
    totalChecked := 0;
    for i := 0 to Pred(joInteriors.Count) do begin
        originalWeatherRegion := '';
        correctedWeatherRegion := '';
        weatherRegionHere := '';
        countHere := 0;
        bSkip := False;
        bWeatherRegionHasPrecipitation := True;

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
        // if not Assigned(correctedWeatherRegion) then begin
        //     AddMessage('Could not locate the weather region for this interior: ' + Name(GetRecordFromFormIdFileId(cellRecordId)));
        //     if originalWeatherRegion <> 'NONE' then AddMessage(#9 + 'Original weather region: ' + Name(GetRecordFromFormIdFileId(originalWeatherRegion)));
        //     AddMessage(#9#9 + 'XTEL references:');
        //     for a := 0 to Pred(joInteriors.O[cellRecordId].A['XTELReferences'].Count) do begin
        //         AddMessage(#9#9#9 + joInteriors.O[cellRecordId].A['XTELReferences'].S[a]);
        //         AddMessage(#9#9#9 + 'In cell: ' + Name(GetRecordFromFormIdFileId(joInteriors.O[cellRecordId].A['XTELReferenceCells'].S[a])));
        //     end;
        //     continue;
        // end;



        if Assigned(correctedWeatherRegion) then begin
            newWeatherRegion := WinningOverride(GetRecordFromFormIdFileId(correctedWeatherRegion));
            bWeatherRegionHasPrecipitation := DoesWeatherRegionHavePrecipitation(newWeatherRegion);
        end else newWeatherRegion := nil;
        if ContainsText(GetElementEditValues(newWeatherRegion, 'EDID'), 'FXlight') or
        ContainsText(GetElementEditValues(newWeatherRegion, 'EDID'), 'FXDiamondSky') then begin
            newWeatherRegion := nil; //Skip this region?
        end;


        if (GetElementNativeValues(rCell, 'DATA - Flags\Use Sky Lighting') <> 0) then begin
            if bWeatherRegionHasPrecipitation then begin
                //This cell has a weather region with precipitation but is using sky lighting, so we will not change the weather region for this cell since it can cause rain in interiors.
                AddMessage('Cell has a corrected weather region with precipitation but is using sky lighting. Skipping weather region assignment for this cell: ' + Name(GetRecordFromFormIdFileId(cellRecordId)));
                if originalWeatherRegion <> 'NONE' then AddMessage(#9 + 'Original weather region: ' + Name(GetRecordFromFormIdFileId(originalWeatherRegion)));
                AddMessage(#9#9 + 'XTEL references:');
                for a := 0 to Pred(joInteriors.O[cellRecordId].A['XTELReferences'].Count) do begin
                    AddMessage(#9#9#9 + Name(GetRecordFromFormIdFileId(joInteriors.O[cellRecordId].A['XTELReferences'].S[a])));
                    AddMessage(#9#9#9 + 'In cell: ' + Name(GetRecordFromFormIdFileId(joInteriors.O[cellRecordId].A['XTELReferenceCells'].S[a])));
                end;
                continue;
                // newWeatherRegion := CreateReplacementWeatherRegion(newWeatherRegion);
                // if not Assigned(newWeatherRegion) then continue;
                // for c := 0 to Pred(joInteriors.O[cellRecordId].A['XTELReferenceCells'].Count) do begin
                //     xtelCell := WinningOverride(GetRecordFromFormIdFileId(joInteriors.O[cellRecordId].A['XTELReferenceCells'].S[c]));
                //     if not Assigned(xtelCell) then continue;
                //     rWrld := WinningOverride(LinksTo(ElementByIndex(xtelCell, 0)));
                //     AddRefToPatch(rWrld);
                //     xtelCellOverride := AddRefToPatch(xtelCell);
                //     ReplaceWeatherRegion(xtelCellOverride, newWeatherRegion);
                //     tlWeatherRegions.Add(newWeatherRegion);
                // end;
            end else AddMessage('Cell is using sky lighting but the corrected weather region does not have precipitation, so it is safe to assign the corrected weather region for this cell.');
        end;
        if SameText(originalWeatherRegion, 'NONE') and not Assigned(newWeatherRegion) then continue; //No original weather region and no corrected weather region, so skip this cell since there is no mismatch.
        Inc(totalChanged);
        AddMessage('Cell: ' + Name(rCell));
        if originalWeatherRegion <> 'NONE' then AddMessage(#9 + 'Original weather region: ' + Name(GetRecordFromFormIdFileId(originalWeatherRegion)));
        if Assigned(newWeatherRegion) then
            AddMessage(#9 + 'Corrected weather region: ' + Name(newWeatherRegion))
        else AddMessage(#9 + 'Corrected weather region: NONE');
        AddMessage(#9#9 + 'XTEL references:');
        for a := 0 to Pred(joInteriors.O[cellRecordId].A['XTELReferences'].Count) do begin
            AddMessage(#9#9#9 + Name(GetRecordFromFormIdFileId(joInteriors.O[cellRecordId].A['XTELReferences'].S[a])));
            AddMessage(#9#9#9 + 'In cell: ' + Name(GetRecordFromFormIdFileId(joInteriors.O[cellRecordId].A['XTELReferenceCells'].S[a])));
        end;

        if not Assigned(xccmPatchFile) then begin
            xccmPatchFile := AddNewFile;
            AddMasterIfMissing(xccmPatchFile, GetFileName(FileByIndex(0)));
        end;

        rCellOverride := AddRefToPatch(rCell);
        if Assigned(newWeatherRegion) then begin
            SetElementEditValues(rCellOverride, 'XCCM', IntToHex(GetLoadOrderFormID(newWeatherRegion), 8));
            tlWeatherRegions.Add(newWeatherRegion);
        end
        else if ElementExists(rCellOverride, 'XCCM') then RemoveElement(rCellOverride, 'XCCM');
        if (GetElementNativeValues(rCellOverride, 'DATA - Flags\Show Sky') <> 0) then continue;
        SetElementEditValues(rCellOverride, 'DATA - Flags\Show Sky', 1);
        //Since we are adding show sky flag, we need to check the imagespaces.
        xcim := WinningOverride(LinksTo(ElementByPath(rCellOverride, 'XCIM')));
        if not Assigned(xcim) then continue;
        SetElementEditValues(rCellOverride, 'XCIM', overrideImagespace(xcim));
    end;
    AddMessage('Total interiors checked: ' + IntToStr(totalChecked));
    AddMessage('Total interiors with mismatched weather region: ' + IntToStr(totalChanged));
    for i := 0 to Pred(slCellsWithSky.Count) do begin
        cellRecordId := slCellsWithSky[i];
        AddMessage('Cell not checked for weather region: ' + Name(GetRecordFromFormIdFileId(cellRecordId)));
    end;
end;

function CreateReplacementWeatherRegion(originalWeatherRegion: IwbElement): IwbElement;
{
    Creates a new weather region based on the original weather region but with precipitation removed from it.
}
var
    weatherRegionNew, weatherTypes, weatherType, weatherHere, alreadyMadeRegion: IwbElement;
    regnGroup: IwbGroupRecord;
    i: integer;
    edidWeatherRegion: string;
begin
    Result := nil;
    if not Assigned(originalWeatherRegion) then Exit; //handle this later, for now just return nil if there is no original weather region.
    edidWeatherRegion := GetElementEditValues(originalWeatherRegion, 'EDID');
    regnGroup := GroupBySignature(xccmPatchFile, 'REGN');
    alreadyMadeRegion := MainRecordByEditorID(regnGroup, edidWeatherRegion + '_XCCM');
    if Assigned(alreadyMadeRegion) then begin
        Result := alreadyMadeRegion;
        Exit;
    end;

    AddRequiredElementMasters(originalWeatherRegion, xccmPatchFile, False, True);
    SortMasters(xccmPatchFile);
    weatherRegionNew := wbCopyElementToFile(originalWeatherRegion, xccmPatchFile, True, True);
    SetEditorID(weatherRegionNew, edidWeatherRegion + '_XCCM');
    RemovePrecipitationFromWeathersInRegion(weatherRegionNew);
    Result := weatherRegionNew;
end;

function overrideImagespace(xcim: IwbElement): string;
{
    Returns the load order formid of the imagespace that will be used.
}
var
    xcimEditorID: string;
    skyScale: double;
    xcimOverride: IwbElement;
begin
    Result := IntToHex(GetLoadOrderFormID(xcim), 8);
    xcimEditorID := GetElementEditValues(xcim, 'EDID');
    if joImageSpaces.O[xcimEditorID].S['override'] <> '' then begin
        Result := joImageSpaces.O[xcimEditorID].S['override'];
        Exit;
    end;
    skyScale := GetElementNativeValues(xcim, 'HNAM\Sky Scale');
    if (skyScale > 1.0) then begin
        //This imagespace has a sky scale that is greater than 1, so we will create an override with the sky scale reduced to 1.
        AddRequiredElementMasters(xcim, xccmPatchFile, False, True);
        SortMasters(xccmPatchFile);
        xcimOverride := wbCopyElementToFile(xcim, xccmPatchFile, True, True);
        SetEditorID(xcimOverride, xcimEditorID + '_Sky');
        SetElementEditValues(xcimOverride, 'HNAM\Sky Scale', '1.0');
        Result := IntToHex(GetLoadOrderFormID(xcimOverride), 8);
        joImageSpaces.O[xcimEditorID].S['override'] := Result;
    end;
end;

function DoesWeatherRegionHavePrecipitation(weatherRegion: IwbElement): boolean;
{
    Checks if the given weather region has precipitation.
}
var
    regionDataEntries, regionDataEntry, weatherTypes, weatherType, weatherHere: IwbElement;
    e, j: integer;
begin
    regionDataEntries := ElementByName(weatherRegion, 'Region Data Entries');
    for e := 0 to Pred(ElementCount(regionDataEntries)) do begin
        regionDataEntry := ElementByIndex(regionDataEntries, e);
        if GetElementEditValues(regionDataEntry, 'RDAT\Type') = 'Weather' then begin
            weatherTypes := ElementByPath(regionDataEntry, 'RDWT - Weather Types');
            for j := 0 to Pred(ElementCount(weatherTypes)) do begin
                weatherType := ElementByIndex(weatherTypes, j);
                weatherHere := WinningOverride(LinksTo(ElementByIndex(weatherType, 0)));
                if Assigned(weatherHere) then begin
                    if ElementExists(weatherHere, 'MNAM') then begin
                        Result := True;
                        Exit;
                    end;
                end;
            end;
        end;
    end;
    Result := False;
end;

procedure RemovePrecipitationFromWeathersInRegion(weatherRegion: IwbElement);
{
    Removes precipitation from all weathers in the given weather region.
}
var
    regionDataEntries, regionDataEntry, weatherTypes, weatherType, weatherHere, newWeather: IwbElement;
    e, j: integer;
    newWeatherFormid: string;
begin
    regionDataEntries := ElementByName(weatherRegion, 'Region Data Entries');
    for e := 0 to Pred(ElementCount(regionDataEntries)) do begin
        regionDataEntry := ElementByIndex(regionDataEntries, e);
        if GetElementEditValues(regionDataEntry, 'RDAT\Type') = 'Weather' then begin
            weatherTypes := ElementByPath(regionDataEntry, 'RDWT - Weather Types');
            for j := Pred(ElementCount(weatherTypes)) downto 0 do begin
                weatherType := ElementByIndex(weatherTypes, j);
                weatherHere := WinningOverride(LinksTo(ElementByIndex(weatherType, 0)));
                if Assigned(weatherHere) then begin
                    newWeather := FixWeather(weatherHere);
                    if Assigned(newWeather) then begin
                        newWeatherFormid := IntToHex(GetLoadOrderFormID(newWeather), 8);
                        SetElementEditValues(weatherType, 'Weather', newWeatherFormid);
                    end;
                end;
            end;
        end;
    end;
end;

function FixWeather(weather: IwbElement): IwbElement;
{
    Creates a new weather record based on the given weather record but with precipitation removed from it.
}
var
    newWeatherHere, defaultInteriorWeather, alreadyMadeWeather, imagespaces, imgspc, imgspcNew: IwbElement;
    edidWeather: string;
    i: integer;
    weatherGroup: IwbGroupRecord;
begin
    Result := nil;
    if not Assigned(weather) then Exit;
    edidWeather := GetElementEditValues(weather, 'EDID');
    if ContainsText(edidWeather, '_XCCM') then begin
        //This weather record has already been processed, so return it.
        Result := weather;
        Exit;
    end;

    weatherGroup := GroupBySignature(xccmPatchFile, 'WTHR');
    alreadyMadeWeather := MainRecordByEditorID(weatherGroup, edidWeather + '_XCCM');
    if Assigned(alreadyMadeWeather) then begin
        Result := alreadyMadeWeather;
        Exit;
    end;

    AddRequiredElementMasters(weather, xccmPatchFile, False, True);
    SortMasters(xccmPatchFile);
    newWeatherHere := wbCopyElementToFile(weather, xccmPatchFile, True, True);
    SetEditorID(newWeatherHere, GetElementEditValues(weather, 'EDID') + '_XCCM');
    SetElementEditValues(newWeatherHere, 'MNAM', '0');
    SetElementEditValues(newWeatherHere, 'NNAM', '0002AE7A');

    defaultInteriorWeather := WinningOverride(RecordByFormID(FileByIndex(0), $001A65F0, False));
    ElementAssign(ElementByPath(newWeatherHere, 'FNAM'), LowInteger, ElementByPath(defaultInteriorWeather, 'FNAM'), False);
    ElementAssign(ElementByPath(newWeatherHere, 'DATA'), LowInteger, ElementByPath(defaultInteriorWeather, 'DATA'), False);
    ElementAssign(ElementByPath(newWeatherHere, 'UNAM'), LowInteger, ElementByPath(defaultInteriorWeather, 'UNAM'), False);
    Remove(ElementByPath(newWeatherHere, 'Sounds'));
    // imagespaces := ElementByPath(newWeatherHere, 'IMSP');
    // for i := Pred(ElementCount(imagespaces)) downto 0 do begin
    //     imgspc := WinningOverride(LinksTo(ElementByIndex(imagespaces, i)));
    //     if not Assigned(imgspc) then continue;
    //     SetEditValue(ElementByIndex(imagespaces, i), FixImagespace(imgspc));
    // end;

    Result := newWeatherHere;
end;

function FixImagespace(imsp: IwbElement): string;
{
    Returns the load order formid of the imagespace that will be used.
}
var
    imspEditorID: string;
    brightness: double;
    imspOverride: IwbElement;
begin
    Result := IntToHex(GetLoadOrderFormID(imsp), 8);
    imspEditorID := GetElementEditValues(imsp, 'EDID');
    if joImageSpaces.O[imspEditorID].S['interior'] <> '' then begin
        Result := joImageSpaces.O[imspEditorID].S['interior'];
        Exit;
    end;
    brightness := GetElementNativeValues(imsp, 'HNAM\Middle Gray');
    if (brightness < 0.18) then begin
        AddRequiredElementMasters(imsp, xccmPatchFile, False, True);
        SortMasters(xccmPatchFile);
        imspOverride := wbCopyElementToFile(imsp, xccmPatchFile, True, True);
        SetEditorID(imspOverride, imspEditorID + '_InteriorBrightness');
        SetElementEditValues(imspOverride, 'HNAM\Middle Gray', '0.18');
        Result := IntToHex(GetLoadOrderFormID(imspOverride), 8);
        joImageSpaces.O[imspEditorID].S['interior'] := Result;
    end;
end;

procedure ProcessWeatherRegions;
{
    Process collected weather regions;
}
var
    i, e, j: integer;
    weatherRecordId, weatherSoundType, weatherSoundRecordEditorID: string;
    weatherRegion, regionDataEntries, regionDataEntry, weatherTypes, weatherType, weatherHere,
    weatherSounds, weatherSound, weatherSoundRecord, intExtSound, weatherOverride: IwbElement;
    slWeatherRecordIds: TStringList;
begin
    AddMessage('Processing weather regions for interior cells...');
    slWeatherRecordIds := TStringList.Create;
    slWeatherRecordIds.Sorted := True;
    slWeatherRecordIds.Duplicates := dupIgnore;
    try
        for i := 0 to Pred(tlWeatherRegions.Count) do begin
            weatherRegion := WinningOverride(ObjectToElement(tlWeatherRegions[i]));
            //AddMessage('Processing weather region: ' + Name(weatherRegion));
            regionDataEntries := ElementByName(weatherRegion, 'Region Data Entries');
            for e := 0 to Pred(ElementCount(regionDataEntries)) do begin
                regionDataEntry := ElementByIndex(regionDataEntries, e);
                if GetElementEditValues(regionDataEntry, 'RDAT\Type') = 'Weather' then begin
                    weatherTypes := ElementByPath(regionDataEntry, 'RDWT - Weather Types');
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
            //AddMessage('Processing weather record: ' + slWeatherRecordIds[i]);
            weatherOverride := nil;
            weatherRecordId := slWeatherRecordIds[i];
            weatherHere := WinningOverride(GetRecordFromFormIdFileId(weatherRecordId));
            if SameText(GetFileName(GetFile(weatherHere)), GetFileName(xccmPatchFile)) then
                weatherOverride := weatherHere;
            weatherSounds := ElementByName(weatherHere, 'Sounds');
            for e := 0 to Pred(ElementCount(weatherSounds)) do begin
                weatherSound := ElementByIndex(weatherSounds, e);
                weatherSoundType := GetElementEditValues(weatherSound, 'Type');
                //if Pos(weatherSoundType, typesToAttenuate) = 0 then continue;
                weatherSoundRecord := WinningOverride(LinksTo(ElementByIndex(weatherSound, 0)));
                weatherSoundRecordEditorID := GetElementEditValues(weatherSoundRecord, 'EDID');
                // if (ContainsText(weatherSoundRecordEditorID, 'rain') or ContainsText(weatherSoundRecordEditorID, 'thunder')) then begin
                if not Assigned(weatherSoundRecord) then continue;
                intExtSound := MakeAttenuatedCompoundSound(weatherSoundRecord);
                if not Assigned(intExtSound) then continue;
                if SameText(RecordFormIdFileId(intExtSound), RecordFormIdFileId(weatherSoundRecord)) then continue; //No changes made to this sound, skip it.
                if not Assigned(weatherOverride) then begin
                    AddRequiredElementMasters(weatherHere, xccmPatchFile, False, True);
                    SortMasters(xccmPatchFile);
                    weatherOverride := wbCopyElementToFile(weatherHere, xccmPatchFile, False, True);
                end;
                SetElementEditValues(weatherOverride, 'Sounds\SNAM - Sound #' + IntToStr(e) + '\Sound', IntToHex(GetLoadOrderFormID(intExtSound), 8));
                // end;
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
    compoundSound, intSound, extSound, conditions, descriptors, descriptor,
    soundHere, descriptorsNew, gnam: IwbElement;
    soundGroup: IwbGroupRecord;
    i: integer;
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
    if SameText(GetElementEditValues(soundRecord, 'CNAM'), 'Compound') then begin
        //Compound sound descriptors
        descriptors := ElementByName(soundRecord, 'Descriptors');
        for i := 0 to Pred(ElementCount(descriptors)) do begin
            soundHere := WinningOverride(LinksTo(ElementByIndex(descriptors, i)));
            AddMessage('Processing sound descriptor: ' + Name(soundHere));
            if SoundAlreadyHasInteriorConditionCheck(soundHere) then continue;

            AddRequiredElementMasters(soundHere, xccmPatchFile, False, True);
            SortMasters(xccmPatchFile);

            if not Assigned(interiorWeatherSoundCategory) then CreateWeatherSoundCategories;

            //Add condition to original sound to not play in interiors
            extSound := wbCopyElementToFile(soundHere, xccmPatchFile, False, True);
            AddCondition(extSound, '10000000', 'IsInInterior', '0.0', 'Subject');
            currentAttenuation := GetElementNativeValues(extSound, 'BNAM - Data\Values\Static Attenuation (db)');
            SetElementEditValues(extSound, 'GNAM', exteriorWeatherSoundCategoryFormId);

            //Duplicate sound and attenuate for interiors
            intSound := wbCopyElementToFile(soundHere, xccmPatchFile, True, True);
            SetEditorID(intSound, edid + '_Interior');
            AddCondition(intSound, '10000000', 'IsInInterior', '1.0', 'Subject');
            //Increase attenuation by 20db for interiors
            SetElementNativeValues(intSound, 'BNAM - Data\Values\Static Attenuation (db)', (currentAttenuation + 2000));
            //set output model to have increased reverb for interiors.
            if SameText(EditorID(LinksTo(ElementByPath(intSound, 'ONAM'))), 'SOMStereo') then
                SetElementEditValues(intSound, 'ONAM', 'd78b8'); //SOMStereo_verb
            SetElementEditValues(intSound, 'GNAM', interiorWeatherSoundCategoryFormId);

            if not Assigned(compoundSound) then begin
                //copy the pre-existing compound sound to the patch file and add the new sound to its descriptors
                AddRequiredElementMasters(soundHere, xccmPatchFile, False, True);
                SortMasters(xccmPatchFile);

                compoundSound := wbCopyElementToFile(soundRecord, xccmPatchFile, False, True);
                descriptorsNew := ElementByName(compoundSound, 'Descriptors');
            end;

            //Add the duplicated sound to the compound sound's descriptors
            descriptor := ElementAssign(descriptorsNew, HighInteger, nil, False);
            SetEditValue(descriptor, IntToHex(GetLoadOrderFormID(intSound), 8));
        end;
    end else begin
        //Normal sound descriptors
        AddRequiredElementMasters(soundRecord, xccmPatchFile, False, True);
        SortMasters(xccmPatchFile);

        if not Assigned(interiorWeatherSoundCategory) then CreateWeatherSoundCategories;

        //Add condition to original sound to not play in interiors
        extSound := wbCopyElementToFile(soundRecord, xccmPatchFile, False, True);
        AddCondition(extSound, '10000000', 'IsInInterior', '0.0', 'Subject');
        currentAttenuation := GetElementNativeValues(extSound, 'BNAM - Data\Values\Static Attenuation (db)');
        gnam := ElementByPath(extSound, 'GNAM');



        //Duplicate sound and attenuate for interiors
        intSound := wbCopyElementToFile(soundRecord, xccmPatchFile, True, True);
        SetEditorID(intSound, edid + '_Interior');
        AddCondition(intSound, '10000000', 'IsInInterior', '1.0', 'Subject');
        //Increase attenuation by 20db for interiors
        SetElementNativeValues(intSound, 'BNAM - Data\Values\Static Attenuation (db)', (currentAttenuation + 2000));
        //set output model to have increased reverb for interiors.
        if SameText(EditorID(LinksTo(ElementByPath(intSound, 'ONAM'))), 'SOMStereo') then
            SetElementEditValues(intSound, 'ONAM', 'd78b8'); //SOMStereo_verb
        SetElementEditValues(intSound, 'GNAM', interiorWeatherSoundCategoryFormId);

        //create compound sound to play the correct sound based on interior/exterior conditions
        soundGroup := GroupBySignature(xccmPatchFile, 'SNDR');
        compoundSound := Add(soundGroup, 'SNDR', True);
        SetEditorID(compoundSound, edid + '_Compound');
        SetElementEditValues(compoundSound, 'CNAM', 'Compound');
        descriptors := Add(compoundSound, 'Descriptors', True);
        descriptor := ElementByIndex(descriptors, 0);
        SetEditValue(descriptor, IntToHex(GetLoadOrderFormID(extSound), 8));
        descriptor := ElementAssign(descriptors, HighInteger, nil, False);
        SetEditValue(descriptor, IntToHex(GetLoadOrderFormID(intSound), 8));
        ElementAssign(Add(compoundSound, 'GNAM', True), 0, gnam, False);

        SetElementEditValues(extSound, 'GNAM', exteriorWeatherSoundCategoryFormId);

        joSounds.O[edid + '_Compound'].S['compound'] := RecordFormIdFileId(compoundSound);
    end;

    Result := compoundSound;
end;

procedure CreateWeatherSoundCategories;
{
    Creates the sound categories needed for the weather sounds.
}
var
    snctGroup: IwbGroupRecord;
begin
    snctGroup := Add(xccmPatchFile, 'SNCT', True);

    exteriorWeatherSoundCategory := Add(snctGroup, 'SNCT', True);
    SetEditorID(exteriorWeatherSoundCategory, 'AudioCategoryExteriorWeather_XCCM');
    SetElementEditValues(exteriorWeatherSoundCategory, 'FULL', 'Exterior Weather Sounds');
    SetElementEditValues(exteriorWeatherSoundCategory, 'PNAM', 'EB803'); //Set Master as parent
    SetElementEditValues(exteriorWeatherSoundCategory, 'FNAM\Should Appear on Menu', '1');
    SetElementEditValues(exteriorWeatherSoundCategory, 'FNAM\Mute When Submerged', '1');
    SetElementEditValues(exteriorWeatherSoundCategory, 'VNAM', '1.0');
    SetElementEditValues(exteriorWeatherSoundCategory, 'UNAM', '1.0');
    SetElementEditValues(exteriorWeatherSoundCategory, 'MNAM', '1.0');
    exteriorWeatherSoundCategoryFormId := IntToHex(GetLoadOrderFormID(exteriorWeatherSoundCategory), 8);

    interiorWeatherSoundCategory := Add(snctGroup, 'SNCT', True);
    SetEditorID(interiorWeatherSoundCategory, 'AudioCategoryInteriorWeather_XCCM');
    SetElementEditValues(interiorWeatherSoundCategory, 'FULL', 'Interior Weather Sounds');
    SetElementEditValues(interiorWeatherSoundCategory, 'PNAM', 'EB803'); //Set Master as parent
    SetElementEditValues(interiorWeatherSoundCategory, 'FNAM\Should Appear on Menu', '1');
    SetElementEditValues(interiorWeatherSoundCategory, 'FNAM\Mute When Submerged', '1');
    SetElementEditValues(interiorWeatherSoundCategory, 'VNAM', '1.0');
    SetElementEditValues(interiorWeatherSoundCategory, 'UNAM', '1.0');
    SetElementEditValues(interiorWeatherSoundCategory, 'MNAM', '1.0');
    interiorWeatherSoundCategoryFormId := IntToHex(GetLoadOrderFormID(interiorWeatherSoundCategory), 8);
end;

function SoundAlreadyHasInteriorConditionCheck(soundRecord: IwbElement): boolean;
{
    Checks if the given sound record has an interior condition check.
}
var
    conditions: IwbElement;
    i: integer;
    gnamRecordId: string;
begin
    conditions := ElementByName(soundRecord, 'Conditions');
    for i := 0 to Pred(ElementCount(conditions)) do begin
        if GetElementEditValues(ElementByIndex(conditions, i), 'CTDA\Function') = 'IsInInterior' then begin
            gnamRecordId := RecordFormIdFileId(LinksTo(ElementByPath(soundRecord, 'GNAM')));
            if SameText(gnamRecordId, RecordFormIdFileId(interiorWeatherSoundCategory))
            or SameText(gnamRecordId, RecordFormIdFileId(exteriorWeatherSoundCategory)) then begin
                Result := True;
                Exit;
            end;
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
        //Check if the condition already exists before adding a new one
        conditions := ElementByPath(e, 'Conditions');
        for i := 0 to Pred(ElementCount(conditions)) do begin
            if GetElementEditValues(ElementByIndex(conditions, i), 'CTDA\Function') = conditionFunction then begin
                condition := ElementByIndex(conditions, i);
            end;
        end;
        if not Assigned(condition) then
            condition := ElementAssign(conditions, HighInteger, nil, False);
        SetElementEditValues(condition, 'CTDA\Type', conditionType);
        SetElementEditValues(condition, 'CTDA\Function', conditionFunction);
        SetElementEditValues(condition, 'CTDA\Comparison Value - Float', conditionValue);
        SetElementEditValues(condition, 'CTDA\Run On', conditionRunOn);
    end;
end;

procedure VerifyWeatherRegionsForCell(rCell: IwbElement);
{
    Verifies that the weather regions for the given cell are correct and patches as necessary.
}
var
    bFoundWeatherRegion, bHasOverride: boolean;
    i, e, priority, priorityHere, priorityOverride, priorityOverrideHere, previousIndex: integer;
    regionEditorID: string;
    xclr, region, regionDataEntries, regionDataEntry, weatherRegion, rWrld, cellOverride: IwbElement;
    slRegionsToRemove: TStringList;
begin
    slRegionsToRemove := TStringList.Create;
    try
        bFoundWeatherRegion := False;
        bHasOverride := False;
        priority := 0;
        priorityOverride := 0;
        priorityOverrideHere := 0;
        previousIndex := -1;
        xclr := ElementByPath(rCell, 'XCLR');

        //iterate over regions for the cell
        for i := 0 to Pred(ElementCount(xclr)) do begin
            //new region
            region := WinningOverride(LinksTo(ElementByIndex(xclr, i)));
            regionEditorID := GetElementEditValues(region, 'EDID');
            if ContainsText(regionEditorID, 'FXlight') then slRegionsToRemove.Add(i); //Mark FXlight regions for removal since they are incorrect.
            //if SameText(regionEditorID, 'NoGlow') then slRegionsToRemove.Add(i);
            // regionDataEntries := ElementByName(region, 'Region Data Entries');
            // for e := 0 to Pred(ElementCount(regionDataEntries)) do begin
            //     regionDataEntry := ElementByIndex(regionDataEntries, e);
            //     if GetElementEditValues(regionDataEntry, 'RDAT\Type') = 'Weather' then begin
            //         bFoundWeatherRegion := True;
            //         if GetElementEditValues(regionDataEntry, 'RDAT\Override') = 'False' then begin
            //             bHasOverride := True;
            //             priorityOverrideHere := GetElementNativeValues(regionDataEntry, 'RDAT\Priority');
            //             if priorityOverrideHere > priorityOverride then begin
            //                 if (priorityOverride <> 0) and (previousIndex <> -1) then begin
            //                     //There should only be one Override = False weather region. If there is more than one, we will keep the one with the highest priority and remove the others.
            //                     //slRegionsToRemove.Add(previousIndex);
            //                     slOverrideRegions.Add(i);
            //                     slOverrideRegions.Add(previousIndex);
            //                 end;
            //                 priorityOverride := priorityOverrideHere;
            //                 previousIndex := i;
            //                 //weatherRegion := region;
            //             end else if (priorityOverride <> 0) and (previousIndex <> -1) then begin
            //                 //There should only be one Override = False weather region. If there is more than one, we will keep the one with the highest priority and remove the others.
            //                 //slRegionsToRemove.Add(i);
            //                 slOverrideRegions.Add(i);
            //             end;
            //         // end
            //         // else if not bHasOverride then begin
            //         //     priorityHere := GetElementNativeValues(regionDataEntry, 'RDAT\Priority');
            //         //     if priorityHere > priority then begin
            //         //         priority := priorityHere;
            //         //         //weatherRegion := region;
            //         //     end;
            //         end;
            //     end;
            // end;
        end;

        if slRegionsToRemove.Count > 0 then begin
            rWrld := WinningOverride(LinksTo(ElementByIndex(rCell, 0)));

            if not ContainsText(EditorID(rWrld), 'DiamondCityFX') then begin
                AddMessage('Found ' + IntToStr(slRegionsToRemove.Count) + ' region(s) to remove for cell: ' + Name(rCell));

                if not Assigned(xccmPatchFile) then begin
                    xccmPatchFile := AddNewFile;
                    AddMasterIfMissing(xccmPatchFile, GetFileName(FileByIndex(0)));
                end;
                AddRefToPatch(rWrld);
                cellOverride := AddRefToPatch(rCell);

                xclr := ElementByPath(cellOverride, 'XCLR');
                for i := Pred(slRegionsToRemove.Count) downto 0 do begin
                    RemoveElement(xclr, ElementByIndex(xclr, slRegionsToRemove[i]));
                end;
            end;
        end;
    finally
        slRegionsToRemove.Free;
    end;

end;

procedure ReplaceWeatherRegion(xtelCell: IwbElement; newWeatherRegion: IwbElement);
{
    Replaces the weather region for the given cell with the new weather region.
}
var
    weatherRegion, xclr: IwbElement;
    i: integer;
begin
    weatherRegion := FindWeatherRegionForCell(xtelCell);
    xclr := ElementByPath(xtelCell, 'XCLR');
    if not Assigned(weatherRegion) then begin
        ElementAssign(xclr, HighInteger, newWeatherRegion, False);
    end else begin
        for i := 0 to Pred(ElementCount(xclr)) do begin
            if SameText(RecordFormIdFileId(LinksTo(ElementByIndex(xclr, i))), RecordFormIdFileId(weatherRegion)) then begin
                ElementAssign(ElementByIndex(xclr, i), LowInteger, newWeatherRegion, False);
                Break;
            end;
        end;
    end;
end;


function FindWeatherRegionForWorldspaceCell(wrldEdid, cellRecordId: string; x, y: integer): IwbElement;
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
    i, e, priority, priorityHere, priorityOverride, priorityOverrideHere: integer;
    regionEditorID: string;
    xclr, region, regionDataEntries, regionDataEntry, weatherRegion: IwbElement;
begin
    bFoundWeatherRegion := False;
    bHasOverride := False;
    priority := 0;
    priorityOverride := 0;
    priorityOverrideHere := 0;
    xclr := ElementByPath(rCell, 'XCLR');

    //iterate over regions for the cell
    for i := 0 to Pred(ElementCount(xclr)) do begin
        //new region
        region := WinningOverride(LinksTo(ElementByIndex(xclr, i)));
        regionEditorID := GetElementEditValues(region, 'EDID');
        if ContainsText(regionEditorID, 'FXlight') then continue; //Skip FXlight regions
        regionDataEntries := ElementByName(region, 'Region Data Entries');
        for e := 0 to Pred(ElementCount(regionDataEntries)) do begin
            regionDataEntry := ElementByIndex(regionDataEntries, e);
            if GetElementEditValues(regionDataEntry, 'RDAT\Type') = 'Weather' then begin
                bFoundWeatherRegion := True;
                if GetElementEditValues(regionDataEntry, 'RDAT\Override') = 'False' then begin
                    bHasOverride := True;
                    priorityOverrideHere := GetElementNativeValues(regionDataEntry, 'RDAT\Priority');
                    if priorityOverrideHere > priorityOverride then begin
                        priorityOverride := priorityOverrideHere;
                        weatherRegion := region;
                    end;
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
