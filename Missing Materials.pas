{
    Check STAT for errors or possible issues.
}
unit CheckSTATs;

var
    slMissingMaterials, slNifErrors, slNeedsMaterials, slNeedsDecalFlag, slAddedMat, slContainers, slMaterialsToVerify: TStringList;
    sOutputDir: string;
    joTextureMswpMap: TJsonObject;


function Initialize: integer;
{
    This function is called at the beginning.
}
begin
    Result := 0;

    slMissingMaterials := TStringList.Create;
    slMissingMaterials.Sorted := True;
    slNifErrors := TStringList.Create;
    slNifErrors.Sorted := True;
    slNeedsMaterials := TStringList.Create;
    slNeedsMaterials.Sorted := True;
    slNeedsDecalFlag := TStringList.Create;
    slNeedsDecalFlag.Sorted := True;
    slAddedMat := TStringList.Create;
    slAddedMat.Sorted := True;
    slContainers := TStringList.Create;
    slMaterialsToVerify := TStringList.Create;
    slMaterialsToVerify.Sorted := True;

    joTextureMswpMap := TJsonObject.Create;
    try
        sOutputDir :=  wbScriptsPath + 'FixModels\output';
        ResourceContainerList(slContainers);
        FilesInContainers(slContainers);
        CollectRecords;
        ListStringsInStringList(slNifErrors);
        ListStringsInStringList(slMissingMaterials);
        ListStringsInStringList(slNeedsMaterials);
        ListStringsInStringList(slAddedMat);
        ListStringsInStringList(slNeedsDecalFlag);
        ListStringsInStringList(slMaterialsToVerify);
    finally
        slMissingMaterials.Free;
        slNifErrors.Free;
        slNeedsMaterials.Free;
        slNeedsDecalFlag.Free;
        slAddedMat.Free;
        slContainers.Free;
        slMaterialsToVerify.Free;
        joTextureMswpMap.Free;
    end;
end;

procedure FilesInContainers(containers: TStringList);
{
    Retrieves the files.
}
var
    slArchivedFiles: TStringList;
    i: integer;
    f, ext, diffuse: string;
    bgsm: TwbBGSMFile;
    bgem: TwbBGEMFile;
begin
    slArchivedFiles := TStringList.Create;
    slArchivedFiles.Sorted := True;
    try
        for i := 0 to Pred(containers.Count) do begin
            ResourceList(containers[i], slArchivedFiles);
        end;
        for i := 0 to Pred(slArchivedFiles.Count) do begin
            f := slArchivedFiles[i];
            ext := ExtractFileExt(f);
            if SameText(ext, '.bgsm') then begin
                bgsm := TwbBGSMFile.Create;
                try
                    bgsm.LoadFromResource(f);
                    diffuse := LowerCase(wbNormalizeResourceName(bgsm.EditValues['Textures\Diffuse'], resTexture));
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['AlphaTest'] := bgsm.EditValues['AlphaTest'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['Decal'] := bgsm.EditValues['Decal'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TwoSided'] := bgsm.EditValues['TwoSided'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['EnvironmentMapping'] := bgsm.EditValues['EnvironmentMapping'];
                finally
                    bgsm.Free;
                end;
            end else if SameText(ext, '.bgem') then begin
                bgem := TwbBGEMFile.Create;
                try
                    bgem.LoadFromResource(f);
                    diffuse := LowerCase(wbNormalizeResourceName(bgem.EditValues['Textures\Base'], resTexture));
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['AlphaTest'] := bgem.EditValues['AlphaTest'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['Decal'] := bgem.EditValues['Decal'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['TwoSided'] := bgem.EditValues['TwoSided'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['EnvironmentMapping'] := bgem.EditValues['EnvironmentMapping'];
                finally
                    bgem.Free;
                end;
            end;
        end;
    finally
        EnsureDirectoryExists(sOutputDir);
        joTextureMswpMap.SaveToFile(sOutputDir + '\joTextureMswpMap.json', False, TEncoding.UTF8, True);
        slArchivedFiles.Free;
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
            if not IsEverPrecombined(r) then continue;
            NifNeedsMaterial(model, r);
        end;
    end;
end;

function IsEverPrecombined(s: IwbMainRecord): boolean;
var
    i: integer;
    r: IwbMainRecord;
begin
    Result := false;
    for i := Pred(ReferencedByCount(s)) downto 0 do begin
        r := ReferencedByIndex(s, i);
        if Signature(r) <> 'REFR' then continue;
        if not IsWinningOverride(r) then continue;
        if GetIsDeleted(r) then continue;
        if GetIsCleanDeleted(r) then continue;
        //if not IsRefPrecombined(r) then continue;
        Result := true;
        break;
    end;
end;

function IsRefPrecombined(r: IwbMainRecord): boolean;
{
    Checks if a reference is precombined.
}
var
    i, t: integer;

    rCell: IwbMainRecord;
begin
    Result := false;
    t := ReferencedByCount(r) - 1;
    if t < 0 then Exit;
    for i := 0 to t do begin
        rCell := ReferencedByIndex(r, i);
        if Signature(rCell) <> 'CELL' then continue;
        if not IsWinningOverride(rCell) then continue;
        //AddMessage(ShortName(r) + ' is referenced in ' + Name(c));
        Result := true;
        Exit;
    end;
end;

function PickMaterial(mess, model, matType, diffuse, alpha: string): string;
var
    i, count: integer;
    mat, alphaMat: string;
begin
    Result := nil;
    if not joTextureMswpMap.O[matType].Contains(diffuse) then Exit;
    count := joTextureMswpMap.O[matType].O[diffuse].Count;
    
    for i := 0 to Pred(count) do begin
       mat := joTextureMswpMap.O[matType].O[diffuse].Names[i];
       alphaMat := joTextureMswpMap.O[matType].O[diffuse].O[mat].S['AlphaTest'];
       Result := mat;
       if SameText(alphaMat, alpha) then break;
    end;
    if count > 1 then slMaterialsToVerify.Add(mess + mat + '"');
end;

function NifNeedsMaterial(model: string; stat: IwbElement): boolean;
var
    i: integer;
    mat, matExt, blockName, diffuse, matPath, matSuffix, alpha, mess: string;
    bBlockMissingMat, bChanged: boolean;

    nif: TwbNifFile;
    block, TextureSet: TwbNifBlock;
    bgsm: TwbBGSMFile;
    Textures, TextureSetEle, AlphaPropEle: TdfElement;
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
                    if (block.BlockType = 'BSEffectShaderProperty') then begin
                        matSuffix := 'bgem';
                        diffuse := LowerCase(wbNormalizeResourceName(block.EditValues['Source Texture'], resTexture));
                    end else begin
                        matSuffix := 'bgsm';
                        TextureSetEle := block.Elements['Texture Set'];
                        if not Assigned(TextureSetEle) then continue;
                        TextureSet := TextureSetEle.LinksTo;
                        if not Assigned(TextureSet) then continue;
                        Textures := TextureSet.Elements['Textures'];
                        diffuse := LowerCase(wbNormalizeResourceName(Textures[0].EditValue, resTexture));
                    end;
                    //AddMessage('diffuse: ' + diffuse);
                    if diffuse = '' then continue;
                    alpha := 'no';
                    AlphaPropEle := nif.Blocks[i - 1].Elements['Alpha Property'];
                    if Assigned(AlphaPropEle) then if Assigned(AlphaPropEle.LinksTo) then alpha := 'yes';
                    mess := model + #9 + IntToStr(i) + ' ' + block.BlockType + '\Name: Assigned material to "';
                    matPath := PickMaterial(mess, model, matSuffix, diffuse, alpha);
                    if not Assigned(matPath) then continue;
                    //matPath := 'materials' + TrimLeftChars(TrimRightChars(diffuse, 8), 6) + matSuffix;
                    //AddMessage('material path: ' + matPath);
                    block.EditValues['Name'] := matPath;
                    bChanged := true;
                    slAddedMat.Add(mess + matPath + '"');
                end else begin
                    if not ResourceExists(mat) then begin
                        bBlockMissingMat := True;
                        Result := True;
                        slMissingMaterials.Add('Material does not exist: ' + #9 + ShortName(stat) + #9 + model + #9 + mat + #9 + blockName);
                    end 
                    else if SameText(matExt, '.bgsm') then begin
                        bgsm.LoadFromResource(mat);
                        if ((bgsm.EditValues['Decal'] = 'yes') and (block.NativeValues['Shader Flags 1\Decal'] = 0)) then begin
                            slNeedsDecalFlag.Add(model + #9 + IntToStr(i) + ' ' + block.BlockType + ': Added missing Decal shader flag.');
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

function GetIsCleanDeleted(r: IwbMainRecord): Boolean;
{
    Checks to see if a reference has an XESP set to opposite of the PlayerRef
}
begin
    Result := False;
    if not ElementExists(r, 'XESP') then Exit;
    if (GetElementNativeValues(r, 'XESP\Flags\Set Enable State to Opposite of Parent') = 0) then Exit;
    if (GetElementEditValues(r, 'XESP\Reference') <> 'PlayerRef [PLYR:00000014]') then Exit;
    Result := True;
end;

end.