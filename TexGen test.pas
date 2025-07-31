{
  New script template, only shows processed records
  Assigning any nonzero value to Result will terminate script
}
unit DoStuff;

const
    texgen_noalpha = 'DynDOLOD\DynDOLOD_FO4_TexGen_noalpha_folipnewlodsesp.txt';
    texgen_copy = 'DynDOLOD\DynDOLOD_FO4_TexGen_copy_folipnewlodsesp.txt';
    texgen_texture_example1 = 'Textures\SetDressing\Signage\BillboardsLrgFallons01_d.dds';
    texgen_texture_example2 = 'textures\Interiors\Building\BldCarpetDecoGreen01_d.DDS';
    texgen_texture_example3 = 'textures\Interiors\Building\BldCarpetDeco01Alpha_d.dds';
    texgen_texture_example4 = 'Textures\SetDressing\Signage\BillboardsNukaColaNukaCherry_d.dds';
    texgen_texture_example5 = 'Textures\Architecture\Buildings\PanelsTin01_d.dds';
    texgen_texture_example6 = 'Textures\setdressing\drivein\driveindetails01_d.dds';

var
    slTexgen_noalpha, slTexgen_copy, slTexgen_alpha: TStringList;



// Called before processing
// You can remove it if script doesn't require initialization code
function Initialize: integer;
begin
    Result := 0;
    slTexgen_Noalpha := TStringList.Create;
    slTexgen_Copy := TStringList.Create;

    if ResourceExists(texgen_noalpha) then slTexgen_Noalpha.LoadFromFile(wbDataPath + texgen_noalpha)
    else Result := 1;

    if ResourceExists(texgen_copy) then slTexgen_Copy.LoadFromFile(wbDataPath + texgen_noalpha)
    else Result := 1;

    // ListStringsInStringList(slTexgen_Noalpha);
    // ListStringsInStringList(slTexgen_Copy);

    GetTexGenFromTexture(texgen_texture_example1);
    GetTexGenFromTexture(texgen_texture_example2);
    GetTexGenFromTexture(texgen_texture_example3);
    GetTexGenFromTexture(texgen_texture_example4);
    GetTexGenFromTexture(texgen_texture_example5);
    GetTexGenFromTexture(texgen_texture_example6);
    AddMessage(StripNonAlphanumeric('FOLIP - New Lods.esp'));
end;

// called for every record selected in xEdit
function Process(e: IInterface): integer;
begin
    Result := 0;

end;


// Called after processing
// You can remove it if script doesn't require finalization code
function Finalize: integer;
begin
    Result := 0;
    slTexgen_Noalpha.Free;
    slTexgen_Copy.Free;
end;

function StripNonAlphanumeric(Input: string): string;
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


function GetTexGenFromTexture(texture: string): integer;
{
    Given a texture path, return the relevant TexGen lines.
}
var
    i, c, t: integer;
    slTexgen_lines, slLine, slTextureList: TStringList;
    bTextureMatch, bCanAutomate: boolean;
    size: string;
begin
    Result := 0;
    bCanAutomate := True;

    size := GetTextureInfo(texture);
    AddMessage(size);

    slTexgen_lines := TStringList.Create;
    slTextureList := TStringList.Create;
    try
        slTextureList.Add(texture);
        for i := 0 to Pred(slTexgen_Noalpha.Count) do begin
            bTextureMatch := False;

            for t := 0 to Pred(slTextureList.Count) do begin
                if ContainsText(slTexgen_Noalpha[i], slTextureList[t]) then begin
                    bTextureMatch := True;
                    Break; // Exit the inner loop if a match is found
                end;
            end;

            if bTextureMatch then begin

                slLine := TStringList.Create;
                try
                    //slTexgen_lines.Add(slTexgen_Noalpha[i]);
                    slLine.Delimiter := #9; // Set delimiter to tab character
                    slLine.DelimitedText := slTexgen_Noalpha[i];

                    if ContainsText(slLine[0], '//') then begin // skip comment lines
                        continue;
                    end else if slLine[5] = 'x' then begin // skip x lines (temporary texture setup for mipmaps, typically for adjusting specular, which we should do automatically)
                        slTextureList.Add(TrimLeftChars(slLine[9], 5)); // Add the texture to the match list, removing the d.dds suffix
                        //continue;
                    end else if slLine[5] = 'r' then begin // skip r lines (rotation lines)
                        slTextureList.Add(slLine[9]); // Add the texture to the match list
                        bCanAutomate := False; // We don't want to automate this
                        continue;
                    end;

                    if ContainsText(slLine[9], 'DynDOLOD-Temp') then begin // This one is complicated. Temporary texture(s) are being used to create the new lod texture.

                        slTextureList.Add(slLine[9]); // Add the texture to the match list
                        bCanAutomate := False;
                        // continue; // Skip for now.
                    end;

                    slTexgen_lines.Add(slTexgen_Noalpha[i]);
                    // for c := 0 to Pred(slLine.Count) do begin
                    //     slTexgen_lines.Add(slLine[c]);
                    // end;
                finally
                    slLine.Free;
                end;
            end;
        end;
    finally
        if bCanAutomate then ListStringsInStringList(slTexgen_lines);
        slTexgen_lines.Free;
        slTextureList.Free;
    end;
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

function GetTextureInfo(f: string): string;
{
    Get resolution of texture in h x w format
}
var
    dds: TwbDDSFile;
    height, width: integer;
begin
    dds := TwbDDSFile.Create;
    try
        try
            dds.LoadFromResource(f);
            if dds.EditValues['Magic'] <> 'DDS ' then
                raise Exception.Create('Not a valid DDS file');
        except
            on E: Exception do begin
                AddMessage('Error reading: ' + f + ' <' + E.Message + '>');
            end;
        end;
        height := dds.NativeValues['HEADER\dwHeight'];
        width := dds.NativeValues['HEADER\dwWidth'];
        Result := IntToStr(height) + 'x' + IntToStr(width);
    finally
        dds.Free;
    end;
end;

end.