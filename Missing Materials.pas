{
    Check STAT for errors or possible issues.
}
unit CheckSTATs;

var
    slMissingMaterials, slNifErrors, slNeedsMaterials: TStringList;


function Initialize: integer;
{
    This function is called at the beginning.
}
begin
    Result := 0;
    slMissingMaterials := TStringList.Create;
    slMissingMaterials.Sorted := True;
    slMissingMaterials.Duplicates := dupIgnore;
    slNifErrors := TStringList.Create;
    slNifErrors.Sorted := True;
    slNifErrors.Duplicates := dupIgnore;
    slNeedsMaterials := TStringList.Create;
    slNeedsMaterials.Sorted := True;
    slNeedsMaterials.Duplicates := dupIgnore;
    CollectRecords;
end;

procedure CollectRecords;
{
    Collect records.
}
var
    i, j: integer;
    model: string;

    f: IwbFile;
    g: IwbGroupRecord;
    r: IwbElement;
begin
    for i := 0 to Pred(FileCount) do begin
        f := FileByIndex(i);

        //Collect STAT
        g := GroupBySignature(f, 'STAT');
        for j := 0 to Pred(ElementCount(g)) do begin
            r := ElementByIndex(g, j);
            if not IsWinningOverride(r) then continue;
            model := wbNormalizeResourceName(GetElementEditValues(r, 'Model\MODL'), resMesh);
            if model = '' then continue;
            if not (ReferencedByCount(r) > 0) then continue;
            if not ResourceExists(model) then begin
                AddMessage('Warning: STAT references a model that does not seem to exist: ' + ShortName(r) + #9 + model);
                continue;
            end;
            NifNeedsMaterial(model, r);
        end;
    end;
end;

function NifNeedsMaterial(model: string; stat: IwbElement): boolean;
var
    i: integer;
    mat, matExt, blockName: string;
    bBlockMissingMat: boolean;

    nif: TwbNifFile;
    block: TwbNifBlock;
begin
    Result := False;
    try
        nif := TwbNifFile.Create;
        try
            nif.LoadFromResource(model);
            for i := 0 to Pred(nif.BlocksCount) do begin
                block := nif.Blocks[i];
                if ((block.BlockType = 'BSTrishape') or (block.BlockType = 'BSMeshLODTriShape')) then blockName := block.EditValues['Name'];
                if not ((block.BlockType = 'BSLightingShaderProperty') or (block.BlockType = 'BSEffectShaderProperty')) then continue;
                mat := wbNormalizeResourceName(block.EditValues['Name'], resMaterial);
                matExt := ExtractFileExt(mat);
                if not (SameText(matExt, '.bgsm') or SameText(matExt, '.bgem')) then begin
                    slNeedsMaterials.Add('Model may need a ' + block.BlockType + ' material: ' + #9 + ShortName(stat) + #9 + model + #9 + blockName);
                    bBlockMissingMat := True;
                    Result := True;
                end else begin
                    if not ResourceExists(mat) then begin
                        bBlockMissingMat := True;
                        Result := True;
                        slMissingMaterials.Add('Material does not exist: ' + #9 + ShortName(stat) + #9 + model + #9 + mat + #9 + blockName);
                    end;
                end;
            end;
        finally
            nif.Free;
        end;
    except on E: Exception do slNifErrors.Add('Error reading NIF: ' + E.Message + #9 + ShortName(stat) + #9 + model);
    end;
end;

function Finalize: integer;
{
    This function is called at the end.
}
begin
    Result := 0;

    ListStringsInStringList(slNifErrors);
    ListStringsInStringList(slMissingMaterials);
    ListStringsInStringList(slNeedsMaterials);

    slMissingMaterials.Free;
    slNifErrors.Free;
    slNeedsMaterials.Free;
end;

procedure ListStringsInStringList(sl: TStringList);
{
    Given a TStringList, add a message for all items in the list.
}
var
    i, count: integer;
begin
    count := sl.Count;
    if count < 1 then Exit;
    AddMessage('=======================================================================================');
    for i := 0 to Pred(count) do AddMessage(sl[i]);
    AddMessage('=======================================================================================');
end;

end.