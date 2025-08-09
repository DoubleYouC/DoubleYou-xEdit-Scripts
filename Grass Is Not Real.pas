{
  Make Grass that is not Grass
}
unit MakeGrassNotReal;

const
    SCALE_FACTOR_TERRAIN = 8;

var
    joGrass: TJsonObject;
    plugin: IwbFile;
    statGroup, scolGroup: IwbGroupRecord;
    slPluginFiles: TStringList;
    sIgnoredWorldspaces: string;

function Initialize: integer;
begin
    joGrass := TJsonObject.Create;
    sIgnoredWorldspaces := '000F93:Fallout4.esm,0A7FF4:Fallout4.esm,000810:DLCCoast.esm,0014F4:DLCCoast.esm,008B56:DLCNukaWorld.esm';

    CreatePluginList;
    CreatePlugin;

    CollectLand;
    Result := 0;
end;

function Finalize: integer;
begin
    joGrass.Free;
    slPluginFiles.Free;
    Result := 0;
end;

procedure CreatePluginList;
{
    Creates a list of the plugins in the load order.
}
var
    i: integer;
begin
    slPluginFiles := TStringList.Create;
    for i := 0 to Pred(FileCount) do begin
        slPluginFiles.Add(GetFileName(FileByIndex(i)));
    end;
end;

procedure CreatePlugin;
begin
    plugin := AddNewFile;
    AddMasterIfMissing(plugin, GetFileName(FileByIndex(0)));
    statGroup := Add(plugin, 'STAT', True);
    scolGroup := Add(plugin, 'SCOL', True);
    slPluginFiles.Add(GetFileName(plugin));
end;

procedure CollectLand;
var
    i, j, k, idx, total: integer;
    f: IwbFile;
    g: IwbGroupRecord;
    r, gnams, gnam, land: IwbElement;
    recordId, grassRecordId, staticGrassRecordId, landRecordId: string;
    slLtex, slLand: TStringList;
    tlLtex, tlLand: TList;
begin

    slLtex := TStringList.Create;
    tlLtex := TList.Create;
    slLand := TStringList.Create;
    tlLand := TList.Create;
    try
        for i := 0 to Pred(FileCount) do begin
            f := FileByIndex(i);

            g := GroupBySignature(f, 'LTEX');

            // iterate over Landscape Textures
            for j := 0 to Pred(ElementCount(g)) do begin
                r := WinningOverride(ElementByIndex(g, j));
                recordId := RecordFormIdFileId(r);
                idx := slLtex.IndexOf(recordId);
                if idx > -1 then continue
                slLtex.Add(recordId);

                // Check for grass
                if not ElementExists(r, 'GNAM') then continue;
                tlLtex.Add(r);
                //AddMessage(ShortName(r));


                gnams := ElementByPath(r, 'GNAM');
                // Iterate over grasses
                for k := 0 to Pred(ElementCount(gnams)) do begin
                    gnam := WinningOverride(LinksTo(ElementByIndex(gnams, k)));
                    //AddMessage(#9 + ShortName(gnam));
                    grassRecordId := RecordFormIdFileId(gnam);
                    joGrass.O['Landscape Textures'].O[recordId].A['Grasses'].Add(grassRecordId);
                    staticGrassRecordId := RecordFormIdFileId(GrassStatic(gnam));
                    joGrass.O['Landscape Textures'].O[recordId].A['StaticGrasses'].Add(staticGrassRecordId);
                end;

                // Iterate over ReferencedBy to get LAND records
                for k := Pred(ReferencedByCount(r)) downto 0 do begin
                    land := WinningOverride(ReferencedByIndex(r, k));
                    if Signature(land) <> 'LAND' then continue;
                    landRecordId := RecordFormIdFileId(land);
                    idx := slLand.IndexOf(landRecordId);
                    if idx > -1 then continue;
                    slLand.Add(landRecordId);
                    tlLand.Add(land);
                    joGrass.O['Cells'].O[landRecordId].A['Landscape Textures'].Add(recordId);
                end;
            end;
        end;

        // Now that we have all the LAND records that should get grass, we will iterate over them and add static grass to them.
        total := tlLand.Count;
        for i := 0 to Pred(total) do begin
            land := ObjectToElement(tlLand[i]);
            if i mod 10 = 0 then begin
                AddMessage('Processed ' + IntToStr(i + 1) + ' of ' + IntToStr(total) + ' landscape records.');
            end;
            AddStaticGrassToLand(land);
        end;
    finally
        slLtex.Free;
        tlLtex.Free;
        slLand.Free;
        tlLand.Free;
    end;
end;

function AddStaticGrassToLand(land: IwbElement): integer;
var
    rCell, rWrld, nCell, landHeightData, grassSCOL, grassSCOLRef, base: IwbElement;
    cellX, cellY, unitsX, unitsY, row, column: integer;
    waterHeightZ, landOffsetZ, rowColumnOffsetZ: double;
    rowColumn, pX, pY, pZ, rX, rY, rZ, scale, grassSCOLFormid, landRecordId, grassHere: string;
    joGrassSCOL: TJsonObject;
begin
    rCell := WinningOverride(LinksTo(ElementByIndex(land, 0)));
    rWrld := WinningOverride(LinksTo(ElementByIndex(rCell, 0)));
    if Pos(RecordFormIdFileId(rWrld), sIgnoredWorldspaces) <> 0 then Exit;
    cellX := GetElementNativeValues(rCell, 'XCLC\X');
    cellY := GetElementNativeValues(rCell, 'XCLC\Y');
    unitsX := cellX * 4096;
    unitsY := cellY * 4096;

    if GetElementEditValues(rCell, 'XCLW') <> 'Default' then begin
        waterHeightZ := GetElementNativeValues(rCell, 'XCLW');
    end
    else begin
        waterHeightZ := GetElementNativeValues(rWrld, 'DNAM\Default Water Height');
    end;
    landOffsetZ := GetElementNativeValues(land, 'VHGT\Offset');

    landHeightData := ElementByPath(land, 'VHGT\Height Data');

    landRecordId := RecordFormIdFileId(land);

    joGrassSCOL := TJsonObject.Create;
    try
        for row := 0 to 32 do begin
            for column := 0 to 32 do begin
                if random(10) > 0 then continue;
                rowColumn := 'Row #' + IntToStr(row) + '\Column #' + IntToStr(column);
                rowColumnOffsetZ := GetElementNativeValues(landHeightData, rowColumn);
                pX := FloatToStr(column * 128);
                pY := FloatToStr(row * 128);
                pZ := FloatToStr((rowColumnOffsetZ + landOffsetZ) * SCALE_FACTOR_TERRAIN);

                rx := '0.0';
                rY := '0.0';
                rZ := IntToStr(Random(360));
                scale := '1.0';

                grassHere := GetRandomGrass(landRecordId);
                joGrassSCOL.O[grassHere].A['Placements'].Add(pX + ',' + pY + ',' + pZ + ',' + rX + ',' + rY + ',' + rZ + ',' + scale);
            end;
        end;
        grassSCOL := MakeSCOLFromJson(joGrassSCOL, 'GrassSCOL_' + EditorID(rWrld) + '_' + IntToStr(cellX) + '_' + IntToStr(cellY));
    finally
        joGrassSCOL.Free;
    end;
    AddRequiredElementMasters(rWrld, plugin, False, True);
    AddRequiredElementMasters(rCell, plugin, False, True);
  	SortMasters(plugin);
    wbCopyElementToFile(rWrld, plugin, False, True);
    nCell := wbCopyElementToFile(rCell, plugin, False, True);
    grassSCOLRef := Add(nCell, 'REFR', True);
    grassSCOLFormid := IntToHex(GetLoadOrderFormID(grassSCOL), 8);

    SetElementEditValues(grassSCOLRef, 'DATA\Position\X', IntToStr(unitsX));
    SetElementEditValues(grassSCOLRef, 'DATA\Position\Y', IntToStr(unitsY));
    SetElementEditValues(grassSCOLRef, 'DATA\Position\Z', FloatToStr(waterHeightZ));

    base := ElementByPath(grassSCOLRef, 'NAME');
    SetEditValue(base, grassSCOLFormid);
    //raise Exception.Create('debug');

    Result := 0;
end;

function MakeSCOLFromJson(joSCOL: TJsonObject; sSCOLEditorId: string): IwbElement;
{
    Creates a SCOL record from the given JSON object.
    The JSON object should have the structure:

        "BaseRecordId":
            "Placements": [
                "pX,pY,pZ,rX,rY,rZ,scale",
                ...
            ]
}
var
    a, c, n, DelimPos, t: integer;
    placementValue, Token, key, onamValue: string;
    scol, stat, parts, part, onam, placement, placements: IwbElement;
begin
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
        stat := GetRecordFromFormIdFileId(key);

        // Add ONAM for each key (base STAT)
        part := Add(parts, 'Part', True);
        onam := ElementByPath(part, 'ONAM');
        onamValue := SetEditValue(onam, ShortName(stat));

        placements := Add(part, 'DATA', True);
        for a := 0 to Pred(joSCOL.O[key].A['Placements'].Count) do begin
            t := t + 1;
            placement := Add(placements, 'Placement', True);
            // Add Placement for each placement in the key
            placementValue := joSCOL.O[key].A['Placements'].S[a];
            //AddMessage(#9 + 'Placement: ' + placementValue);
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
    Result := scol;
    //AddMessage('Total placements: ' + IntToStr(t));
end;

function GetRandomGrass(landRecordId: string): string;
{
    Returns a random static grass record id for the given LAND record.
}
var
    ltexIdx, grassIdx: integer;
    ltex: string;
begin
    ltexIdx := Random(joGrass.O['Cells'].O[landRecordId].A['Landscape Textures'].Count);
    ltex := joGrass.O['Cells'].O[landRecordId].A['Landscape Textures'].S[ltexIdx];
    grassIdx := Random(joGrass.O['Landscape Textures'].O[ltex].A['StaticGrasses'].Count);
    Result := joGrass.O['Landscape Textures'].O[ltex].A['StaticGrasses'].S[grassIdx];
end;

function GrassStatic(grassRecord: IwbElement): IwbElement;
{
    Returns a static element for the given model.
}
var
    n, modl, elmodel: IwbElement;
    model: string;
begin
    Result := nil;
    model := GetElementEditValues(grassRecord, 'Model\MODL');
    if model = '' then Exit;

    // Check if the model is already a static
    if joGrass.O['Grasses'].O[model].S['Static'] <> '' then begin
        Result := GetRecordFromFormIdFileId(joGrass.O['Grasses'].O[model].S['Static']);
        if Assigned(Result) then Exit;
    end;

    // Create STAT
    n := Add(statGroup, 'STAT', True);
    // Set the editor ID
    SetEditorID(n, 'StaticGrass_' + EditorID(grassRecord));
    // Set the model
    elmodel := Add(n, 'Model', True);
    modl := Add(elmodel, 'MODL', True);
    SetEditValue(modl, model);
    // Copy the object bounds
    CopyObjectBounds(grassRecord, n);
    // Add to JSON
    joGrass.O['Grasses'].O[model].S['Static'] := RecordFormIdFileId(n);
    Result := n;
end;

procedure CopyObjectBounds(copyFrom, copyTo: IwbElement);
{
    Copies the object bounds of the first reference to the second reference.
}
begin
    SetElementNativeValues(copyTo, 'OBND\X1', GetElementNativeValues(copyFrom, 'OBND\X1'));
    SetElementNativeValues(copyTo, 'OBND\X2', GetElementNativeValues(copyFrom, 'OBND\X2'));
    SetElementNativeValues(copyTo, 'OBND\Y1', GetElementNativeValues(copyFrom, 'OBND\Y1'));
    SetElementNativeValues(copyTo, 'OBND\Y2', GetElementNativeValues(copyFrom, 'OBND\Y2'));
    SetElementNativeValues(copyTo, 'OBND\Z1', GetElementNativeValues(copyFrom, 'OBND\Z1'));
    SetElementNativeValues(copyTo, 'OBND\Z2', GetElementNativeValues(copyFrom, 'OBND\Z2'));
end;

function RecordFormIdFileId(e: IwbElement): string;
{
    Returns the record ID of an element.
}
begin
    Result := TrimRightChars(IntToHex(FixedFormID(e), 8), 2) + ':' + GetFileName(GetFile(MasterOrSelf(e)));
end;

function GetRecordFromFormIdFileId(recordId: string): IwbElement;
{
    Returns the record from the given formid:filename.
}
var
    colonPos, recordFormId, c: integer;
    f: IwbFile;
    fileMasterIndex: string;
begin
    colonPos := Pos(':', recordId);
    f := FileByIndex(slPluginFiles.IndexOf(Copy(recordId, Succ(colonPos), Length(recordId))));
    c := MasterCount(f);
    if c > 9 then fileMasterIndex := IntToStr(c) else fileMasterIndex := '0' + IntToStr(c);
    recordFormId := StrToInt('$' + fileMasterIndex + Copy(recordId, 1, Pred(colonPos)));
    Result := RecordByFormID(f, recordFormId, False);
end;

function TrimRightChars(s: string; chars: integer): string;
{
    Returns right string - chars
}
begin
    Result := RightStr(s, Length(s) - chars);
end;

function TrimLeftChars(s: string; chars: integer): string;
{
    Returns left string - chars
}
begin
    Result := LeftStr(s, Length(s) - chars);
end;

end.