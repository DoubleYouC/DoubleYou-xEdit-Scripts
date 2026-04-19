{
    Flutter Flicker Fixer for Foliage
}
unit FFFFF;

// ----------------------------------------------------
//Create variables that will need to be used accross multiple functions/procedures.
// ----------------------------------------------------
var
    sVEFSDir: string;

// ----------------------------------------------------
// Main functions and procedures go up immediately below.
// ----------------------------------------------------

function Initialize: integer;
{
    This function is called at the beginning.
}
var
    i: integer;
begin
    ProcessFiles;
    Result := 0;
end;

function Finalize: integer;
{
    This function is called at the end.
}
begin
    Result := 0;
end;

procedure ProcessFiles;
var
    i: integer;
    model: string;
    TDirectory: TDirectory;
    files: TStringDynArray;
begin
    sVEFSDir := SelectDirectory('Select a directory', '', '', nil);
    files := TDirectory.GetFiles(sVEFSDir, '*.nif', soAllDirectories);
    for i := 0 to Pred(Length(files)) do begin
        model := files[i];
        if ContainsText(model, '\PreCombined\') then Continue;
        if ContainsText(model, '\LOD\') then Continue;
        ProcessModel(model);
    end;
end;

procedure ProcessModel(model: string);
var
    bMaterialMissing, bHasTreeAnimations, bTree, bHasVertexColors: boolean;
    i, j, vertexCount: integer;
    folder, mat, matExt: string;

    vertexData, vertex: TdfElement;

    nif: TwbNifFile;
    block, rootBlock, previousBlock: TwbNifBlock;
begin
    bHasTreeAnimations := False;
    bTree := False;
    nif := TwbNifFile.Create;
    try
        try
            nif.LoadFromFile(model);
        except
            AddMessage('Error loading file: ' + model);
            Exit;
        end;
        for j := Pred(nif.BlocksCount) downto 1 do begin
            block := nif.Blocks[j];

            //Check if a trishape's shader property has tree animations.
            if SameText(block.BlockType, 'BSLightingShaderProperty') then begin
                bMaterialMissing := False;
                bHasVertexColors := False;
                mat := wbNormalizeResourceName(block.EditValues['Name'], resMaterial);
                matExt := ExtractFileExt(mat);
                if not (SameText(matExt, '.bgsm') or SameText(matExt, '.bgem')) then begin
                    //Does not have a material
                    bMaterialMissing := True;
                end else begin
                    if not ResourceExists(mat) then begin
                        //does not have a material
                        AddMessage('Material does not exist: ' + mat);
                        bMaterialMissing := True;
                    end else begin
                        bHasTreeAnimations := DoesMatHaveTreeAnimations(mat);
                    end;
                end;
                if bMaterialMissing then begin
                    if block.EditValues['Shader Flags 2\Tree_Anim'] = '1' then bHasTreeAnimations := True;
                end;
                if j = 0 then break;
                previousBlock := nif.Blocks[j - 1];
                if (previousBlock.EditValues['VertexDesc\VF\VF_COLORS'] = '1') then bHasVertexColors := True;
                if (bHasTreeAnimations and not bHasVertexColors) then begin
                    AddMessage('WARNING! Trishape has tree animations but no vertex colors: ' + #9 + model + #9 + previousBlock.EditValues['Name']);
                end else if (bHasTreeAnimations and not bTree) then bTree := True;
            end;
        end;
        if not bTree then Exit;
        rootBlock := nif.Blocks[0];
        if SameText(rootBlock.BlockType, 'NiNode') then begin
            nif.ConvertBlock(0, 'BSLeafAnimNode');
        end else Exit;
        folder := StringReplace(ExtractFilePath(model), sVEFSDir + '\', '', [rfIgnoreCase]);
        EnsureDirectoryExists(sVEFSDir + '\output\' + folder);
        nif.SaveToFile(sVEFSDir + '\output\' + folder + ExtractFileName(model));
        AddMessage('Saved to : ' + sVEFSDir + '\output\' + folder + ExtractFileName(model));

    finally
        nif.free;
    end;
end;

function DoesMatHaveTreeAnimations(mat: string): boolean;
var
    bgsm: TwbBGSMFile;
begin
    Result := False;
    bgsm := TwbBGSMFile.Create;
    try
        bgsm.LoadFromResource(mat);
        if SameText(bgsm.EditValues['Tree'], 'yes') then Result := True;
    finally
        bgsm.free;
    end;
end;

function TrimRightChars(s: string; chars: integer): string;
{
    Returns right string - chars
}
begin
    Result := RightStr(s, Length(s) - chars);
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

end.