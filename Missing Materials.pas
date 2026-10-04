{
    Check STAT for errors or possible issues.
}
unit CheckSTATs;

var
    slMissingMaterials, slNifErrors, slNeedsMaterials, slNeedsDecalFlag, slAddedMat: TStringList;
    sOutputDir: string;


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
    slNeedsDecalFlag := TStringList.Create;
    slNeedsDecalFlag.Sorted := True;
    slNeedsDecalFlag.Duplicates := dupIgnore;
    slAddedMat := TStringList.Create;
    slAddedMat.Sorted := True;
    slAddedMat.Duplicates := dupIgnore;
    try
        sOutputDir :=  wbScriptsPath + 'FixModels\output';
        CollectRecords;
        ListStringsInStringList(slNifErrors);
        ListStringsInStringList(slMissingMaterials);
        ListStringsInStringList(slNeedsMaterials);
        ListStringsInStringList(slAddedMat);
        ListStringsInStringList(slNeedsDecalFlag);
    finally
        slMissingMaterials.Free;
        slNifErrors.Free;
        slNeedsMaterials.Free;
        slNeedsDecalFlag.Free;
        slAddedMat.Free;
    end;
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
    mat, matExt, blockName, diffuse, matPath, matSuffix: string;
    bBlockMissingMat, bChanged: boolean;

    nif: TwbNifFile;
    block, TextureSet: TwbNifBlock;
    bgsm: TwbBGSMFile;
    Textures, TextureSetEle: TdfElement;
begin
    Result := False;
    bChanged := False;
    //try
        nif := TwbNifFile.Create;
        bgsm := TwbBGSMFile.Create;
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
                    TextureSetEle := block.Elements['Texture Set'];
                    if not Assigned(TextureSetEle) then continue;
                    TextureSet := TextureSetEle.LinksTo;
                    if not Assigned(TextureSet) then continue;
                    Textures := TextureSet.Elements['Textures'];
                    diffuse := wbNormalizeResourceName(Textures[0].EditValue, resTexture);
                    //AddMessage('diffuse: ' + diffuse);
                    if diffuse = '' then continue;
                    if (block.BlockType = 'BSEffectShaderProperty') then matSuffix := '.bgem' else matSuffix := '.bgsm';
                    matPath := 'materials' + TrimLeftChars(TrimRightChars(diffuse, 8), 6) + matSuffix;
                    //AddMessage('material path: ' + matPath);
                    if not ResourceExists(matPath) then continue;
                    block.EditValues['Name'] := matPath;
                    bChanged := true;
                    slAddedMat.Add('Added material to model: ' + #9 + matPath + #9 + model + #9 + blockName);
                end else begin
                    if not ResourceExists(mat) then begin
                        bBlockMissingMat := True;
                        Result := True;
                        slMissingMaterials.Add('Material does not exist: ' + #9 + ShortName(stat) + #9 + model + #9 + mat + #9 + blockName);
                    end 
                    else if SameText(matExt, '.bgsm') then begin
                        bgsm.LoadFromResource(mat);
                        if ((bgsm.EditValues['Decal'] = 'yes') and (block.NativeValues['Shader Flags 1\Decal'] = 0)) then begin
                            slNeedsDecalFlag.Add('Mesh is missing decal flag on BSLightingShaderProperty: ' + #9 + ShortName(stat) + #9 + model + #9 + mat + #9 + blockName);
                            block.NativeValues['Shader Flags 1\Decal'] := 1;
                            bChanged := true;
                        end;
                    end;
                end;
            end;
        finally
            if bChanged then begin
                EnsureDirectoryExists(sOutputDir + '\' + ExtractFilePath(model));
                nif.SaveToFile(sOutputDir + '\' + model);
            end;
            nif.Free;
            bgsm.Free;
        end;
    // except on E: Exception do slNifErrors.Add('Error reading NIF: ' + E.Message + #9 + ShortName(stat) + #9 + model);
    // end;
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

procedure EnsureDirectoryExists(f: string);
{
    Create directories if they do not exist.
}
begin
    if not DirectoryExists(f) then
        if not ForceDirectories(f) then
            raise Exception.Create('Can not create destination directory ' + f);
end;

function TrimRightChars(s: string; chars: integer): string;
{
    Returns right string - chars
    TrimRightChars('Example', 2) -> 'ample'
}
begin
    Result := RightStr(s, Length(s) - chars);
end;

function TrimLeftChars(s: string; chars: integer): string;
{
    Returns left string - chars
    TrimLeftChars('Example', 3) -> 'Exam'
}
begin
    Result := LeftStr(s, Length(s) - chars);
end;

end.