{
    Fix cubemaps
}
unit Cubemaps;

// ----------------------------------------------------
//Create variables that will need to be used accross multiple functions/procedures.
// ----------------------------------------------------

var
    uiScale: integer;
    slCubemaps: TStringList;
    output: string;

// ----------------------------------------------------
// Main functions and procedures go up immediately below.
// ----------------------------------------------------

function Initialize: integer;
{
    This function is called at the beginning.
}
begin
    //Get scaling
    uiScale := Screen.PixelsPerInch * 100 / 96;
    AddMessage('UI scale: ' + IntToStr(uiScale));

    output := wbScriptsPath + 'FixCubemaps\';

    slCubemaps := TStringList.Create;

    // if not MainMenuForm then begin
    //     Result := 1;
    //     Exit;
    // end;

    CollectAssets;
    ConvertCubemaps;

    Result := 0;
end;

function Finalize: integer;
{
    This function is called at the end.
}
var
    cmdline: string;
begin
    AddMessage('Zipping up cubemaps for easy installation...');
    cmdline := '-Command "Compress-Archive -Path ''' + output + '\textures'' -DestinationPath ''' + output + 'FixCubemaps.zip''"';
    AddMessage(cmdline);
    AddMessage('Exit Code: ' + IntToStr(ShellExecuteWait(0, 'open', 'Powershell', cmdline, '', SW_SHOWNORMAL)));

    ListStringsInStringList(slCubemaps);
    slCubemaps.Free;
    Result := 0;
end;

procedure CollectAssets;
{
    Collect assets
}
var
    slContainers: TwbFastStringList;
    slFiles: TStringList;
    i, j: integer;
    archive, f, folder, filename, outfile: string;
    joTextureContainer: TJsonObject;
begin
    AddMessage('Scanning assets for cubemaps. This may take awhile.');
    slContainers := TwbFastStringList.Create;
    joTextureContainer := TJsonObject.Create;
    try
        ResourceContainerList(slContainers);

        for i := Pred(slContainers.Count) downto 0 do begin
            archive := TrimRightChars(slContainers[i], Length(wbDataPath));
            //Skip archives that will not contain cubemaps
            if ContainsText(archive, ' - Animations.ba2') then continue;
            if ContainsText(archive, ' - Interface.ba2') then continue;
            if ContainsText(archive, ' - Materials.ba2') then continue;
            if ContainsText(archive, ' - Meshes.ba2') then continue;
            if ContainsText(archive, ' - MeshesExtra.ba2') then continue;
            if ContainsText(archive, ' - Misc.ba2') then continue;
            if ContainsText(archive, ' - Nvflex.ba2') then continue;
            if ContainsText(archive, ' - Shaders.ba2') then continue;
            if ContainsText(archive, ' - Sounds.ba2') then continue;
            if ContainsText(archive, ' - Voices.ba2') then continue;
            if ContainsText(archive, ' - Voices_cn.ba2') then continue;
            if ContainsText(archive, ' - Voices_de.ba2') then continue;
            if ContainsText(archive, ' - Voices_en.ba2') then continue;
            if ContainsText(archive, ' - Voices_es.ba2') then continue;
            if ContainsText(archive, ' - Voices_esmx.ba2') then continue;
            if ContainsText(archive, ' - Voices_fr.ba2') then continue;
            if ContainsText(archive, ' - Voices_it.ba2') then continue;
            if ContainsText(archive, ' - Voices_ja.ba2') then continue;
            if ContainsText(archive, ' - Voices_pl.ba2') then continue;
            if ContainsText(archive, ' - Voices_ptbr.ba2') then continue;
            if ContainsText(archive, ' - Voices_ru.ba2') then continue;
            if SameText(archive,'') then AddMessage('Scanning loose files for cubemaps') else AddMessage('Scanning archive for cubemaps: ' + archive);

            slFiles := TStringList.Create;
            try
                ResourceList(slContainers[i], slFiles);

                for j := 0 to Pred(slFiles.Count) do begin
                    f := LowerCase(slFiles[j]);
                    if not SameText(RightStr(f,4),'.dds') then continue;
                    if IsCubeMap(slContainers[i], f) then begin
                        folder := ExtractFilePath(f);
                        filename := ExtractFileName(f);
                        outfile := output + folder + filename;
                        if FileExists(outfile) then continue;
                        slCubemaps.Add(f);
                        AddMessage(#9 + 'Found cubemap: ' + f);
                        EnsureDirectoryExists(output + folder);
                        ResourceCopy(slContainers[i], f, outfile);
                    end;
                end;
            finally
                slFiles.Free;
            end;
        end;
    finally
        slContainers.Free;
    end;
end;

function IsCubeMap(cont, f: string): Boolean;
{
    Check if a DDS file is a cubemap.
}
var
    dds: TwbDDSFile;
begin
    dds := TwbDDSFile.Create;
    try
        try
            dds.LoadFromResource(cont, f);
            if dds.EditValues['Magic'] <> 'DDS ' then
                raise Exception.Create('Not a valid DDS file');
        except
            on E: Exception do begin
                AddMessage('Error reading: ' + f + ' <' + E.Message + '>');
            end;
        end;

        Result := dds.NativeValues['HEADER\dwCaps2\DDSCAPS2_CUBEMAP'];
        if not Result and (dds.NativeValues['HEADER\dwWidth']/dds.NativeValues['HEADER\dwHeight'] = 4/3) then begin
            // If the cubemap is not flagged, but the width/height ratio is 4:3, assume it is a cubemap.
            AddMessage('Warning: ' + f + ' is not flagged as a cubemap, but has a 4:3 aspect ratio. The texture likely is bugged.');
        end;
    finally
        dds.Free;
    end;
end;

procedure ConvertCubemaps;
var
    i: integer;
    f, texconv, dir, filepath, cmdline: string;
begin
    texconv := wbScriptsPath + 'Texconvx64.exe';
    for i:=0 to Pred(slCubemaps.Count) do begin
        f := slCubemaps[i];
        dir := output + TrimLeftChars(ExtractFilePath(f), 1);
        filepath := output + f;
        AddMessage('Processing ' + f);

        //B8G8R8X8_UNORM first to strip alpha
        cmdline := '-f B8G8R8X8_UNORM -m 1 -y -w 128 -h 128 -o "' + dir + '" "' + filepath + '"';
        AddMessage('Command line: "' + texconv + '" ' + cmdline);
        AddMessage('Texconv finished with exit code: ' + IntToStr(ShellExecuteWait(0, 'open', texconv, cmdline, '', SW_HIDE)));

        //B8G8R8A8_UNORM
        cmdline := '-f B8G8R8A8_UNORM -m 8 -y -w 128 -h 128 -o "' + dir + '" "' + filepath + '"';
        AddMessage('Command line: "' + texconv + '" ' + cmdline);
        AddMessage('Texconv finished with exit code: ' + IntToStr(ShellExecuteWait(0, 'open', texconv, cmdline, '', SW_HIDE)));
    end;
end;

function MainMenuForm: Boolean;
{
    Main menu form.
}
var
    frm: TForm;
    btnStart, btnCancel: TButton;
begin
    frm := TForm.Create(nil);
    try
        frm.Caption := 'Fix Cubemaps';
        frm.Width := 300;
        frm.Height := 200;
        frm.Position := poMainFormCenter;
        frm.BorderStyle := bsDialog;
        frm.KeyPreview := True;
        frm.OnClose := frmOptionsFormClose;
        frm.OnKeyDown := FormKeyDown;

        btnStart := TButton.Create(frm);
        btnStart.Parent := frm;
        btnStart.Caption := 'Start';
        btnStart.ModalResult := mrOk;
        btnStart.Top := frm.Height - btnStart.Height - 48;

        btnCancel := TButton.Create(frm);
        btnCancel.Parent := frm;
        btnCancel.Caption := 'Cancel';
        btnCancel.ModalResult := mrCancel;
        btnCancel.Top := btnStart.Top;

        btnStart.Left := frm.Width - btnStart.Width - btnCancel.Width - 24;
        btnCancel.Left := btnStart.Left + btnStart.Width + 8;

        frm.ScaleBy(uiScale, 100);
        frm.Font.Size := 8;

        if frm.ShowModal <> mrOk then begin
            Result := False;
            Exit;
        end
        else Result := True;

    finally
        frm.Free;
    end;
end;

procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
{
    Cancel if Escape key is pressed.
}
begin
    if Key = VK_ESCAPE then TForm(Sender).ModalResult := mrCancel;
end;

procedure frmOptionsFormClose(Sender: TObject; var Action: TCloseAction);
{
    Close form handler.
}
begin
    if TForm(Sender).ModalResult <> mrOk then begin
        AddMessage('Clicked cancel.');
        Exit;
    end else AddMessage('Clicked start.');
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

function BoolToStr(b: boolean): string;
{
    Given a boolean, return a string.
}
begin
    if b then Result := 'true' else Result := 'false';
end;

procedure ListStringsInStringList(sl: TStringList);
{
    Given a TStringList, add a message for all items in the list.
}
var
    i: integer;
begin
    AddMessage('=======================================================================================');
    for i := 0 to Pred(sl.Count) do AddMessage(sl[i]);
    AddMessage('=======================================================================================');
end;

end.