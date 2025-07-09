{
  Used to make MakeMultiRefLOD json rule for use with FOLIP.
}
unit MakeMultiRefLODJson;

var
    joMultiRefLOD: TJsonObject;
    jsonFileName, MultiRefEditorID, MultiRefLODReference, yourPluginName: string;
    slPluginFiles: TStringList;

// Called before processing
// You can remove it if script doesn't require initialization code
function Initialize: integer;
var
    colonPos: integer;
    i, MultiRefFormid: integer;
    MultiRefLODFile: IwbFile;
    MultiRefLODElement, base: IwbElement;
    f: string;
begin
    if not InputQuery('Enter', 'Enter the MultiRefLOD Reference. Format should be 1CA31B:Fallout4.esm', MultiRefLODReference) then begin
        AddMessage('Operation cancelled.');
        Result := 2;
        Exit;
    end else AddMessage('MultiRefLOD Reference: ' + MultiRefLODReference);
    if not InputQuery('Enter', 'Enter the name of your plugin (Cancel to use default FOLIP - New LODs).', yourPluginName) then begin
        yourPluginName := 'FOLIP - New LODs';
        AddMessage('Operation cancelled. Using default plugin name: ' + yourPluginName);
    end else AddMessage('Your Plugin Name: ' + yourPluginName);
    slPluginFiles := TStringList.Create;
    for i := 0 to Pred(FileCount) do begin
        f := GetFileName(FileByIndex(i));
        slPluginFiles.Add(f);
    end;
    joMultiRefLOD := TJsonObject.Create;
    jsonFileName := 'FOLIP\' + yourPluginName + ' - MultiRefLOD.json';
    if ResourceExists(jsonFileName) then
        joMultiRefLOD.LoadFromResource(jsonFileName);

    colonPos := Pos(':', MultiRefLODReference);
    MultiRefFormid := StrToInt('$' + Copy(MultiRefLODReference, 1, Pred(colonPos)));
    MultiRefLODFile := FileByIndex(slPluginFiles.IndexOf(Copy(MultiRefLODReference, Succ(colonPos), Length(MultiRefLODReference))));
    MultiRefLODElement := RecordByFormID(MultiRefLODFile, MultiRefFormid, False);
    if not Assigned(MultiRefLODElement) then begin
        AddMessage('MultiRefLOD element not found in ' + MultiRefLODFile.FileName + '.');
        Result := 1;
        Exit;
    end;
    base := LinksTo(ElementBySignature(MultiRefLODElement, 'NAME'));
    MultiRefEditorID := GetElementEditValues(base, 'EDID');
    AddMessage('MultiRefLOD EditorID: ' + MultiRefEditorID);
    Result := 0;
end;

// called for every record selected in xEdit
function Process(e: IInterface): integer;
var
    s: string;
begin
    if Signature(e) <> 'REFR' then Exit;
    s := TrimRightChars(IntToHex(FixedFormID(e), 8), 2) + ':' + GetFileName(GetFile(MasterOrSelf(e)));
    joMultiRefLOD.O[MultiRefEditorID].S['MultiRefLOD'] := MultiRefLODReference;
    joMultiRefLOD.O[MultiRefEditorID].A['References to add MultiRefLOD'].Add(s);
    AddMessage(s);

    Result := 0;
end;

// Called after processing
// You can remove it if script doesn't require finalization code
function Finalize: integer;
begin
    joMultiRefLOD.SaveToFile(wbDataPath + jsonFileName, False, TEncoding.UTF8, True);

    joMultiRefLOD.Free;
    slPluginFiles.Free;
    Result := 0;
end;

function TrimRightChars(s: string; chars: integer): string;
{
    Returns right string - chars
}
begin
    Result := RightStr(s, Length(s) - chars);
end;

end.
