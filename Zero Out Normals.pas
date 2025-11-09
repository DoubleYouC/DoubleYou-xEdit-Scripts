{
    FaceGen Fix for bad BSClothExtraData
}
unit FaceGenFix;

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
        ProcessModel(model);
    end;
end;

procedure ProcessModel(model: string);
var
    i, j, vertexCount: integer;
    folder: string;

    vertexData, vertex: TdfElement;

    nif: TwbNifFile;
    block: TwbNifBlock;
begin
    nif := TwbNifFile.Create;
    try
        nif.LoadFromFile(model);
        for j := Pred(nif.BlocksCount) downto 0 do begin
            block := nif.Blocks[j];
            vertexCount := block.NativeValues['Num Vertices'];
            vertexData := block.Elements['Vertex Data'];
            for i := 0 to Pred(vertexCount) do begin
                vertex := vertexData[i];
                vertex.EditValues['Normal'] := '0.003922 0.003922 1.000000';
                vertex.EditValues['Bitangent X'] := '1.000000';
                vertex.EditValues['Bitangent Y'] := '0.003922';
                vertex.EditValues['Bitangent Z'] := '0.003922';
                vertex.EditValues['Tangent'] := '0.003922 -1.000000 0.003922';
            end;
        end;
        folder := StringReplace(ExtractFilePath(model), sVEFSDir + '\', '', [rfIgnoreCase]);
        EnsureDirectoryExists(sVEFSDir + '\output\' + folder);
        nif.SaveToFile(sVEFSDir + '\output\' + folder + ExtractFileName(model));
        AddMessage('Saved to : ' + sVEFSDir + '\output\' + folder + ExtractFileName(model));
    finally
        nif.free;
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