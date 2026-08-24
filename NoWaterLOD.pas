{
    Replace water LOD with Is Full LOD Water Supermesh
}
unit NoWaterLOD;

var
    joElements: TJsonObject;
    NoLodPlugin: IwbFile;
    statGroup, scolGroup: IwbGroupRecord;
    water4096, water1024, watercircle: string;

const
    sIgnoredWorldspaces = '00000F93:Fallout4.esm, 00000F94:Fallout4.esm, 00054BD5:Fallout4.esm, 000A7FF4:Fallout4.esm, 01000810:DLCCoast.esm, 010014F4:DLCCoast.esm, 01004EA4:DLCCoast.esm, 01008B56:DLCNukaWorld.esm, 01052931:DLCNukaWorld.esm, 01053C58:DLCNukaWorld.esm';
    SCALE_FACTOR_TERRAIN = 8;

function Initialize: integer;
{
    This function is called at the beginning.
}
begin
    Result := 0;
    joElements := TJsonObject.Create;
    try
        // create plugin
        NoLodPlugin := AddNewFileName('NoWaterLOD.esp', False);
        AddMasterIfMissing(NoLodPlugin, GetFileName(FileByIndex(0)));
        statGroup := Add(NoLodPlugin, 'STAT', True);
        scolGroup := Add(NoLodPlugin, 'SCOL', True);
        //water4096 := CreateWaterStat('DefaultProceduralWater', 'waterstatic\DefaultProceduralWater.nif');
        water1024 := CreateWaterStat('Water1024', 'waterstatic\Water1024.nif');
        watercircle := CreateWaterStat('WaterCircle1024', 'waterstatic\WaterCircle1024.nif');

        //CollectRecords;
        joElements.LoadFromFile(wbScriptsPath + 'NoWaterLOD\joWater.json');
        ProcessWater;
    finally
        joElements.SaveToFile(wbScriptsPath + 'NoWaterLOD\joWater.json', False, TEncoding.UTF8, True);
        joElements.Free;
    end;
end;

function CreateWaterStat(edid, model: string): string;
{
    Create a water static record.
}
var
    newStatic: IwbMainRecord;
    newStaticModel: IwbElement;
begin
    newStatic := Add(statGroup, 'STAT', True);
    SetEditorID(newStatic, edid);
    newStaticModel := Add(Add(newStatic, 'Model', True), 'MODL', True);
    SetEditValue(newStaticModel, model);
    Result := IntToHex(GetLoadOrderFormID(newStatic), 8);
end;

procedure CollectRecords;
{
    Collect records;
}
var
    i, j, h, blockidx, subblockidx, cellidx: integer;
    fileName, wrldRecordId, cellX, cellY, defaultWaterHeight, cellWaterHeight, recordId,
    waterRecordId, cellWaterRecordId, wrldEdid, model, waterhere, scale, parentref,
    px, py, pz, rx, ry, rz: string;
    bHasWater, bOppositeEnableParent: boolean;

    f: IwbFile;
    g, wrldgroup: IwbGroupRecord;
    rWrld, wWrld, rCell, wCell, land, acti, r: IwbMainRecord;
    block, subblock, water, cellWater, waterType, xesp: IwbElement;
begin
    for i := 0 to Pred(FileCount) do begin
        f := FileByIndex(i);
        fileName := GetFileName(f);

        //Collect LAND
        g := GroupBySignature(f, 'WRLD');
        for j := 0 to Pred(ElementCount(g)) do begin
            rWrld := ElementByIndex(g, j);
            wrldRecordId := RecordFormIdFileId(rWrld);
            if Pos(wrldRecordId, sIgnoredWorldspaces) <> 0 then continue;
            wrldEdid := EditorID(rWrld);
            wWrld := WinningOverride(rWrld);
            water := ElementByPath(wWrld, 'NAM2');
            if not Assigned(water) then continue;
            waterRecordId := RecordFormIdFileId(LinksTo(water));
            defaultWaterHeight := GetElementEditValues(wWrld, 'DNAM\Default Water Height');

            joElements.O['worldspaces'].O[wrldEdid].S['RecordID'] := wrldRecordId;
            joElements.O['worldspaces'].O[wrldEdid].S['Default Water'] := waterRecordId;
            joElements.O['worldspaces'].O[wrldEdid].S['Default Water Height'] := defaultWaterHeight;
            AddMessage(wrldEdid + #9 + waterRecordId + #9 + defaultWaterHeight);

            wrldgroup := ChildGroup(rWrld);
            for blockidx := 0 to Pred(ElementCount(wrldgroup)) do begin
                block := ElementByIndex(wrldgroup, blockidx);
                for subblockidx := 0 to Pred(ElementCount(block)) do begin
                    subblock := ElementByIndex(block, subblockidx);
                    for cellidx := 0 to Pred(ElementCount(subblock)) do begin
                        rCell := ElementByIndex(subblock, cellidx);
                        if (Signature(rCell) <> 'CELL') then continue;
                        cellX := GetElementEditValues(rCell, 'XCLC\X');
                        cellY := GetElementEditValues(rCell, 'XCLC\Y');
                        wCell := WinningOverride(rCell);
                        bHasWater := (GetElementNativeValues(wCell,'DATA\Has Water') <> 0);
                        if not bHasWater then continue;
                        land := GetLandscapeForCell(rCell);
                        if not Assigned(land) then continue;
                        if not IsWinningOverride(land) then continue;
                        if not ElementExists(land, 'VHGT') then continue;
                        cellWaterHeight := GetElementEditValues(wCell, 'XCLW');
                        if cellWaterHeight = 'Default' then cellWaterHeight := defaultWaterHeight;
                        if not WaterAboveLand(land, cellWaterHeight) then continue;
                        cellWater := ElementByPath(wCell, 'XCWT');
                        if Assigned(cellWater) then cellWaterRecordId := RecordFormIdFileId(LinksTo(cellWater)) else cellWaterRecordId := waterRecordId;

                        joElements.O['worldspaces'].O[wrldEdid].O[cellWaterRecordId].O[cellX].O[cellY].S['ID'] := RecordFormIdFileId(rCell);
                        if not SameText(cellWaterHeight, defaultWaterHeight) then
                            joElements.O['worldspaces'].O[wrldEdid].O[cellWaterRecordId].O[cellX].O[cellY].S['XCLW'] := cellWaterHeight;
                        px := StrToInt(cellX) * 4096 + 2048;
                        py := StrToInt(cellY) * 4096 + 2048;
                        pz := cellWaterHeight;
                        joElements.O['water acti'].O[wrldEdid].O[cellWaterRecordId].O[water1024].A['refs'].Add('4' + '|' + px + '|' + py + '|' + pz + '|' + '0' + '|' + '0' + '|' + '0');
                        AddMessage(#9 + wrldEdid + ' [' + cellX + ',' + cellY + ']' + #9 + cellWaterRecordId + #9 + cellWaterHeight);
                    end;
                end;
            end;
        end;

        //Collect Water ACTI
        g := GroupBySignature(f, 'ACTI');
        for j := 0 to Pred(ElementCount(g)) do begin
            acti := ElementByIndex(g, j);
            waterType := ElementByPath(acti, 'WNAM');
            if not Assigned(waterType) then continue;
            waterRecordId := RecordFormIdFileId(LinksTo(waterType));
            if not IsWinningOverride(acti) then continue;
            model := GetElementEditValues(acti, 'Model\MODL');
            if ContainsText(model, 'Water1024.nif') then waterhere := water1024
            else if ContainsText(model, 'WaterCircle1024.nif') then waterhere := watercircle
            else continue;
            for h := Pred(ReferencedByCount(acti)) downto 0 do begin
                r := ReferencedByIndex(acti, h);
                if Signature(r) <> 'REFR' then continue;
                if not IsWinningOverride(r) then continue;
                rCell := LinksTo(ElementByIndex(r, 0));
                if IsInteriorCell(rCell) then continue;
                rWrld := LinksTo(ElementByIndex(rCell, 0));
                wrldEdid := EditorID(rWrld);
                wrldRecordId := RecordFormIdFileId(rWrld);
                if Pos(wrldRecordId, sIgnoredWorldspaces) <> 0 then continue;
                recordId := RecordFormIdFileId(r);
                if ElementExists(r, 'XSCL') then scale := GetElementEditValues(r, 'XSCL') else scale := '1';
                px := GetElementEditValues(r, 'DATA\Position\X');
                py := GetElementEditValues(r, 'DATA\Position\Y');
                pz := GetElementEditValues(r, 'DATA\Position\Z');
                rx := GetElementEditValues(r, 'DATA\Rotation\X');
                ry := GetElementEditValues(r, 'DATA\Rotation\Y');
                rz := GetElementEditValues(r, 'DATA\Rotation\Z');
                xesp := ElementByPath(r, 'XESP');
                if Assigned(xesp) then begin
                    bOppositeEnableParent := (GetElementNativeValues(r, 'XESP\Flags\Set Enable State to Opposite of Parent') <> 0);
                    parentref := IntToHex(GetLoadOrderFormID(LinksTo(ElementByName(xesp, 'Reference'))), 8);
                    joElements.O['water acti xesp'].O[wrldEdid].O[waterRecordId].O[parentref].O[BoolToStr(bOppositeEnableParent)].O[waterhere].A['refs'].Add(scale + '|' + px + '|' + py + '|' + pz + '|' + rx + '|' + ry + '|' + rz);
                end else begin
                    joElements.O['water acti'].O[wrldEdid].O[waterRecordId].O[waterhere].A['refs'].Add(scale + '|' + px + '|' + py + '|' + pz + '|' + rx + '|' + ry + '|' + rz);
                end;
            end;
        end;

    end;
end;

procedure ProcessWater;
{
    Process water json
}
var
    w, j, p, o: integer;
    wrldEdid, waterRecordId, parentref, bOppositeEnableParent: string;
begin
    for w := 0 to Pred(joElements.O['water acti'].Count) do begin
        wrldEdid := joElements.O['water acti'].Names[w];
        for j := 0 to Pred(joElements.O['water acti'].O[wrldEdid].Count) do begin
            waterRecordId := joElements.O['water acti'].O[wrldEdid].Names[j];
            MakeWaterSCOL(wrldEdid, waterRecordId, '', 'false', joElements.O['water acti'].O[wrldEdid].O[waterRecordId]);
        end;
    end;

    for w := 0 to Pred(joElements.O['water acti xesp'].Count) do begin
        wrldEdid := joElements.O['water acti xesp'].Names[w];
        for j := 0 to Pred(joElements.O['water acti xesp'].O[wrldEdid].Count) do begin
            waterRecordId := joElements.O['water acti xesp'].O[wrldEdid].Names[j];
            for p := 0 to Pred(joElements.O['water acti xesp'].O[wrldEdid].O[waterRecordId].Count) do begin
                parentref := joElements.O['water acti xesp'].O[wrldEdid].O[waterRecordId].Names[p];
                for o := 0 to Pred(joElements.O['water acti xesp'].O[wrldEdid].O[waterRecordId].O[parentref].Count) do begin
                    bOppositeEnableParent := joElements.O['water acti xesp'].O[wrldEdid].O[waterRecordId].O[parentref].Names[o];
                    MakeWaterSCOL(wrldEdid, waterRecordId, parentref, bOppositeEnableParent, joElements.O['water acti xesp'].O[wrldEdid].O[waterRecordId]);
                end;
            end;
        end;
    end;
end;

function MakeWaterSCOL(wrldEdid, waterRecordId, parentref, bOppositeEnableParent: string; waterJson: TJsonObject): IwbMainRecord;
{
    Creates water SCOLs.
}
var
    waterSCOL: IwbMainRecord;
    parts, part, onam, placements, placement: IwbElement;
    i, n, p, DelimPos: integer;
    waterhere, Token, placementValue, edid: string;
begin
    Result := nil;
    waterSCOL := Add(scolGroup, 'SCOL', True);
    edid := wrldEdid + '_' + StripNonAlphanumeric(waterRecordId) + '_' + parentref + '_' + bOppositeEnableParent;
    SetEditorID(waterSCOL, edid);

    //Add Parts
    parts := Add(waterSCOL, 'Parts', True);
    part := ElementbyIndex(parts, 0);
    onam := ElementByPath(part, 'ONAM');
    SetEditValue(onam, 'StaticCollectionPivotDummy [STAT:00035812]');

    for i := 0 to Pred(waterJson.Count) do begin
        waterhere := waterJson.Names[i];
        // Add ONAM for each base STAT
        part := Add(parts, 'Part', True);
        onam := ElementByPath(part, 'ONAM');
        SetEditValue(onam, waterhere);

        placements := Add(part, 'DATA', True);
        for p := 0 to Pred(waterJson.O[waterhere].A['refs'].Count) do begin
            placement := Add(placements, 'Placement', True);
            placementValue := waterJson.O[waterhere].A['refs'].S[p];
            AddMessage(edid + #9 + waterhere + #9 + placementValue);
            n := 0;
            while placementValue <> '' do begin
                DelimPos := Pos('|', placementValue);
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
                    1 : SetElementEditValues(placement, 'Scale', Token);
                    2 : SetElementEditValues(placement, 'Position\X', Token);
                    3 : SetElementEditValues(placement, 'Position\Y', Token);
                    4 : SetElementEditValues(placement, 'Position\Z', Token);
                    5 : SetElementEditValues(placement, 'Rotation\X', Token);
                    6 : SetElementEditValues(placement, 'Rotation\Y', Token);
                    7 : SetElementEditValues(placement, 'Rotation\Z', Token);
                end;
            end;
        end;

    end;
    Result := waterSCOL;
end;

function WaterAboveLand(land: IwbMainRecord; cellWaterHeight: string): boolean;
{
    Returns true if landscape ever falls below the water height.
}
var
    cellWaterHeightInt, landOffsetZ, row, column, rowColumnOffsetZ, rowStartVal, landValue,
    landValueScaled: integer;
    rowColumn: string;

    landHeightData, eRow: IwbElement;
begin
    Result := True;
    cellWaterHeightInt := StrToFloatDef(cellWaterHeight, 0);
    landOffsetZ := GetElementNativeValues(land, 'VHGT\Offset');
    landHeightData := ElementByPath(land, 'VHGT\Height Data');
    for row := 0 to 32 do begin
        eRow := ElementByPath(landHeightData, 'Row #' + IntToStr(row));
        for column := 0 to 32 do begin
            rowColumn := 'Column #' + IntToStr(column);
            rowColumnOffsetZ := GetElementNativeValues(eRow, rowColumn);
            if rowColumnOffsetZ > 127 then rowColumnOffsetZ := rowColumnOffsetZ - 256;

            if(column = 0) then begin //check if first column
                if(row = 0) then begin // check if first row of first column
                    rowStartVal := rowColumnOffsetZ; //rowColumnOffsetZ + landOffsetZ; //if first column, first row, height is the LAND's offset + the offset value. We are omitting landOffsetZ since we want to simply place the landscape snow at z height of landOffsetZ.
                end else begin
                    rowStartVal := rowColumnOffsetZ + rowStartVal; //if first column, but 2nd or higher row, height is the 1st row's offset + the current offset value
                end;
                landValue := rowStartVal;
            end else begin
                // If it is the 2nd or higher column, height is the previous rowColumn's height + the current offset value.
                landValue := landValue + rowColumnOffsetZ;
            end;
            landValueScaled := (landValue + landOffsetZ) * SCALE_FACTOR_TERRAIN; //This will be the Z height we apply to the vertex of the nif.
            if (landValueScaled < cellWaterHeightInt) then Exit;
        end;
    end;
    Result := False;
end;

function GetLandscapeForCell(rCell: IwbMainRecord): IwbMainRecord;
{
    Gets the landscape record for the cell.
}
var
    i: integer;

    r: IwbMainRecord;
    cellchild: IwbGroupRecord;
begin
    Result := nil;
    cellchild := FindChildGroup(ChildGroup(rCell), 9, rCell); // get Temporary group of cell
    for i := 0 to Pred(ElementCount(cellchild)) do begin
        r := ElementByIndex(cellchild, i);
        if Signature(r) <> 'LAND' then continue;
        Result := r;
        Exit;
    end;
end;

function IsInteriorCell(cell: IwbMainRecord): boolean;
{
    Checks if a cell is in an interior.
}
begin
    Result := (GetElementNativeValues(cell, 'DATA - Flags\Is Interior Cell') <> 0);
end;

function RecordFormIdFileId(e: IwbMainRecord): string;
{
    Returns the record ID of an element.
}
begin
    e := MasterOrSelf(e);
    Result := IntToHex(FormID(e), 8) + ':' + GetFileName(GetFile(e));
end;

function BoolToStr(b: boolean): string;
{
    Given a boolean, return a string.
}
begin
    if b then Result := 'true' else Result := 'false';
end;

function StrToBool(str: string): boolean;
{
    Given a string, return a boolean.
}
begin
    if (LowerCase(str) = 'true') or (str = '1') then Result := True else Result := False;
end;

function StripNonAlphanumeric(Input: string): string;
{
    Removes characters from a string that are not a number or letter.
}
var
  i: Integer;
  c: char;
begin
    Result := '';
    i := 1;
    while i <= Length(Input) do begin
        c := Copy(Input,i,1);
        if Pos(c,'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789') <> 0 then Result := Result + c;
        inc(i);
    end;
end;

end.