unit ModifyJson;

var
    joAlterLandRules: TJsonObject;

function Initialize: integer;
begin
    joAlterLandRules := TJsonObject.Create;
    OpenFile;
end;

function Finalize: integer;
begin
    joAlterLandRules.Free;
end;

procedure OpenFile;
var
    toFile : TOpenDialog;
begin
    toFile := TOpenDialog.Create(nil);
    try
        toFile.Title := 'Select JSON';
        toFile.Filter := 'All files (*.*)|*.*';
        toFile.Options := [ofFileMustExist, ofPathMustExist];
        toFile.InitialDir := wbDataPath;
        if toFile.Execute then begin
            ShowMessage('Selected file: ' + toFile.FileName);
            ProcessJson(toFile.FileName);
        end;
    finally
        toFile.Free;
    end;
end;

procedure ProcessJson(jsonFile: string);
var
    folder, fileName, newFolder: string;
begin
    joAlterLandRules.LoadFromFile(jsonFile);
    SortAlterLandJSONObjectKeys;
    folder := ExtractFilePath(jsonFile);
    fileName := ExtractFileName(jsonFile);
    newFolder := folder + '\output\';
    EnsureDirectoryExists(newFolder);
    joAlterLandRules.SaveToFile(newFolder + fileName, False, TEncoding.UTF8, True);
end;

procedure SortAlterLandJSONObjectKeys;
{
    Sorts Alter Land JSON keys by Editor ID.
}
var
    SortedEDIDs: TStringList;
    Key, edid: string;
    NewJSONObj, joEDIDKeyMap: TJsonObject;
    i: integer;
begin
    // Create a sorted list of keys
    SortedEDIDs := TStringList.Create;
    joEDIDKeyMap := TJsonObject.Create;
    NewJSONObj := TJsonObject.Create;
    try
        for i := 0 to Pred(joAlterLandRules.Count) do begin
            Key := joAlterLandRules.Names[i];
            edid := EditorID(GetRecordFromFormIdFileId(Key));
            SortedEDIDs.Add(edid);
            joEDIDKeyMap.S[edid] := Key;
        end;
        SortedEDIDs.Sort; // Sort the keys alphabetically

        for i := 0 to Pred(SortedEDIDs.Count) do begin
            edid := SortedEDIDs[i];
            Key := joEDIDKeyMap.S[edid];
            NewJSONObj.O[Key].S['editorid'] := edid;
            NewJSONObj.O[Key].S['alteration'] := joAlterLandRules.S[Key];
            NewJSONObj.O[Key].O['references'] := TJsonObject.Create;
        end;

        // Replace the original joAlterLandRules with the sorted one
        joAlterLandRules.Clear;
        joAlterLandRules.Assign(NewJSONObj);
    finally
        SortedEDIDs.Free;
        joEDIDKeyMap.Free;
        NewJSONObj.Free;
    end;
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

function GetRecordFromFormIdFileId(recordId: string): IwbElement;
{
    Returns the record from the given formid:filename.
}
var
    colonPos, recordFormId: integer;
    f: IwbFile;
begin
    colonPos := Pos(':', recordId);
    recordFormId := StrToInt('$' + Copy(recordId, 1, Pred(colonPos)));
    f := FileByName(Copy(recordId, Succ(colonPos), Length(recordId)));
    Result := RecordByFormID(f, recordFormId, False);
end;

end.