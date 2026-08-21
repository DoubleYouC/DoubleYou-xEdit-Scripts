{
    Replace water LOD with Is Full LOD Water Supermesh
}
unit NoWaterLOD;

var
    joElements: TJsonObject;

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
        CollectRecords;
    finally
        joElements.SaveToFile(wbScriptsPath + 'joWater.json', False, TEncoding.UTF8, True);
        joElements.Free;
    end;
end;

procedure CollectRecords;
{
    Collect records;
}
var
    i, j, blockidx, subblockidx, cellidx: integer;
    fileName, recordid, cellX, cellY, defaultWaterHeight, cellWaterHeight, waterRecordId, cellWaterRecordId, wrldEdid: string;
    bHasWater: boolean;

    f: IwbFile;
    g, wrldgroup: IwbGroupRecord;
    rWrld, wWrld, rCell, wCell, land: IwbMainRecord;
    block, subblock, water, cellWater: IwbElement;
begin
    for i := 0 to Pred(FileCount) do begin
        f := FileByIndex(i);
        fileName := GetFileName(f);

        //Collect LAND
        g := GroupBySignature(f, 'WRLD');
        for j := 0 to Pred(ElementCount(g)) do begin
            rWrld := ElementByIndex(g, j);
            recordid := RecordFormIdFileId(rWrld);
            if Pos(recordid, sIgnoredWorldspaces) <> 0 then continue;
            wrldEdid := EditorID(rWrld);
            wWrld := WinningOverride(rWrld);
            water := ElementByPath(wWrld, 'NAM2');
            if not Assigned(water) then continue;
            waterRecordId := RecordFormIdFileId(LinksTo(water));
            defaultWaterHeight := GetElementEditValues(wWrld, 'DNAM\Default Water Height');

            joElements.O['worldspaces'].O[wrldEdid].S['RecordID'] := recordid;
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
                        cellX := GetElementNativeValues(rCell, 'XCLC\X');
                        cellY := GetElementNativeValues(rCell, 'XCLC\Y');
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
                        AddMessage(#9 + wrldEdid + ' [' + cellX + ',' + cellY + ']' + #9 + cellWaterRecordId + #9 + cellWaterHeight);

                        
                    end;
                end;
            end;
        end;


    end;
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

end.