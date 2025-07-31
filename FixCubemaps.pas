{
    Fix cubemaps
}
unit Cubemaps;

// ----------------------------------------------------
//Create variables that will need to be used accross multiple functions/procedures.
// ----------------------------------------------------

var
    uiScale: integer;

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

    if not MainMenuForm then begin
        Result := 1;
        Exit;
    end;

    Result := 0;
end;

function Finalize: integer;
{
    This function is called at the end.
}
begin
    Result := 0;
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

end.