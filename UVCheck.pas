{
    Check LOD Assets are within range.
}
unit UVCheck;

var
    sDir: string;

function Initialize: integer;
{
    This function is called at the beginning.
}
var
    i: integer;
begin
    ScanLOD;
    Result := 0;
end;

function Finalize: integer;
{
    This function is called at the end.
}
begin
    Result := 0;
end;

procedure ScanLOD;
var
    i: integer;
    model: string;
    TDirectory: TDirectory;
    files: TStringDynArray;
begin
    sDir := SelectDirectory('Select a directory', '', '', nil);
    files := TDirectory.GetFiles(sDir, '*.nif', soAllDirectories);
    for i := 0 to Pred(Length(files)) do begin
        model := files[i];
        if MeshOutsideUVRange(model) then AddMessage('Warning: ' + model + ' may have UVs outside proper 0 to 1 UV range.');
    end;
end;

function MeshOutsideUVRange(f: string): Boolean;
{
    Checks a mesh resource to see if its UVs are outside of range.
}
var
    tsUV: TStrings;
    j, k, vertexCount, iTimesOutsideRange: integer;
    uv, u, v: string;
    nif: TwbNifFile;
    arr, vertex: TdfElement;
    block, b: TwbNifBlock;
    bWasEverAbleToCheck, bIsTrishape: boolean;
begin
    bWasEverAbleToCheck := False;
    iTimesOutsideRange := 0;
    nif := TwbNifFile.Create;
    Result := True;
    try
        nif.LoadFromFile(f);
        // iterate over all nif blocks
        for j := 0 to Pred(nif.BlocksCount) do begin
            block := nif.Blocks[j];
            bIsTrishape := False;
            if block.IsNiObject('NiTriStripsData', True) then bIsTrishape := True;
            if not bIsTrishape then continue;
            vertexCount := block.NativeValues['Num Vertices'];
            if vertexCount < 1 then continue;
            arr := block.Elements['UV Sets'];
            for k := 0 to Pred(arr.Count) do begin
                bWasEverAbleToCheck := True;
                AddMessage(arr[k].EditValue);
                tsUV := SplitString(arr[k].EditValue, ' ');
                AddMessage(tsUV[0]);
                u := tsUV[0];
                AddMessage(IntToStr(u));
                v := tsUV[1];
                AddMessage(IntToStr(v));
                if StrToFloatDef(u, 9) < -0.1 then iTimesOutsideRange := iTimesOutsideRange + 1;
                if StrToFloatDef(u, 9) > 1.1 then iTimesOutsideRange := iTimesOutsideRange + 1;
                if StrToFloatDef(v, 9) < -0.1 then iTimesOutsideRange := iTimesOutsideRange + 1;
                if StrToFloatDef(v, 9) > 1.1 then iTimesOutsideRange := iTimesOutsideRange + 1;
                if iTimesOutsideRange = 0 then Result := False else begin
                    Result := True;
                    Exit;
                end;
            end;
        end;
    finally
        nif.free;
    end;
    if not bWasEverAbleToCheck then Result := False;
end;

end.