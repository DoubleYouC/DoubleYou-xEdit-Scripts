{
  Make Grass that is not Grass
}
unit MakeGrassNotReal;

var
    joGrass: TJsonObject;
    plugin: IwbFile;
    statGroup: IwbGroupRecord;
    slPluginFiles: TStringList;

function Initialize: integer;
begin
    joGrass := TJsonObject.Create;

    CreatePluginList;
    CreatePlugin;

    CollectLand;
    Result := 0;
end;

function Finalize: integer;
begin
    AddMessage(joGrass.ToJSON(True));
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
    statGroup := Add(plugin, 'STAT', True);
    slPluginFiles.Add(GetFileName(plugin));
end;

procedure CollectLand;
var
    i, j, k, idx: integer;
    f: IwbFile;
    g: IwbGroupRecord;
    r, gnams, gnam: IwbElement;
    recordId, grassRecordId, staticGrassRecordId: string;
    slLtex, slGrasses: TStringList;
    tlLtex: TList;
begin

    slLtex := TStringList.Create;
    tlLtex := TList.Create;
    try
        for i := 0 to Pred(FileCount) do begin
            f := FileByIndex(i);

            g := GroupBySignature(f, 'LTEX');

            for j := 0 to Pred(ElementCount(g)) do begin
                r := WinningOverride(ElementByIndex(g, j));
                recordId := RecordFormIdFileId(r);
                idx := slLtex.IndexOf(recordId);
                if idx > -1 then continue
                slLtex.Add(recordId);
                if not ElementExists(r, 'GNAM') then continue;
                tlLtex.Add(r);
                AddMessage(ShortName(r));
                gnams := ElementByPath(r, 'GNAM');
                for k := 0 to Pred(ElementCount(gnams)) do begin
                    gnam := WinningOverride(LinksTo(ElementByIndex(gnams, k)));
                    AddMessage(#9 + ShortName(gnam));
                    grassRecordId := RecordFormIdFileId(gnam);
                    joGrass.O['Landscape Textures'].O[recordId].A['Grasses'].Add(grassRecordId);
                    staticGrassRecordId := RecordFormIdFileId(GrassStatic(gnam));
                    joGrass.O['Landscape Textures'].O[recordId].A['StaticGrasses'].Add(staticGrassRecordId);
                end;
            end;
        end;

        for i := 0 to Pred(tlLtex.Count) do begin
            r := ObjectToElement(tlLtex[i]);
        end;
    finally
        slLtex.Free;
        tlLtex.Free;
    end;
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
    Returns the record from the given record ID.
}
var
    colonPos, recordFormId: integer;
    f: IwbFile;
begin
    colonPos := Pos(':', recordId);
    recordFormId := StrToInt('$' + Copy(recordId, 1, Pred(colonPos)));
    f := FileByIndex(slPluginFiles.IndexOf(Copy(recordId, Succ(colonPos), Length(recordId))));
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