{
    Use to Deep Copy a Quest as New records
}
unit DuplicateQuestAsNew;

var
    plugin: IwbFile;
    json: TJsonObject;

function Initialize: integer;
var
    sTargetFileName: string;
begin
    if not InputQuery('Enter', 'Enter the Target File.', sTargetFileName) then begin
        AddMessage('Operation cancelled.');
        Result := 2;
        Exit;
    end else AddMessage('Target File: ' + sTargetFileName);
    if not ((RightStr(sTargetFileName, 4) = '.esp') or (RightStr(sTargetFileName, 4) = '.esm')) then begin
        sTargetFileName := sTargetFileName + '.esp';
    end;
    plugin := FileByName(sTargetFileName);
    if not Assigned(plugin) then begin
        plugin := AddNewFileName(sTargetFileName, False);
    end;
    json := TJsonObject.Create;
    Result := 0;
end;

function Finalize: integer;
begin
    json.Free;
    Result := 0;
end;

function Process(e: IwbElement): integer;
var
    newQuest, child, info, newDial, newInfo, newScene, newDLBR, edid, elementHere: IwbElement;
    questChildren, dialChildren: IwbGroupRecord;
    i, j: integer;
    questFormID, dialFormID: string;
    formList: TList;
begin
    if Signature(e) <> 'QUST' then Exit;
    formList := TList.Create;
    try
        AddMessage('Processing: ' + Name(e));
        AddRequiredElementMasters(e, plugin, False, True);
        SortMasters(plugin);
        newQuest := wbCopyElementToFileWithPrefix(e, plugin, True, True, '', '', '_Dup');
        questFormID := IntToHex(GetLoadOrderFormID(newQuest), 8);
        json.O[RecordFormIdFileId(e)].S['formid'] := questFormID;
        questChildren := ChildGroup(e);
        for i := 0 to Pred(ElementCount(questChildren)) do begin
            child := ElementByIndex(questChildren, i);
            AddRequiredElementMasters(child, plugin, False, True);
            SortMasters(plugin);
            if Signature(child) = 'DIAL' then begin
                edid := ElementByPath(child, 'EDID');
                if not Assigned(edid) then
                    newDial := wbCopyElementToFile(child, plugin, True, True)
                else newDial := wbCopyElementToFileWithPrefix(child, plugin, True, True, '', '', '_Dup');
                dialFormID := IntToHex(GetLoadOrderFormID(newDial), 8);
                json.O[RecordFormIdFileId(child)].S['formid'] := dialFormID;
                formList.Add(newDial);

                dialChildren := ChildGroup(child);
                for j := 0 to Pred(ElementCount(dialChildren)) do begin
                    info := ElementByIndex(dialChildren, j);
                    if Signature(info) = 'INFO' then begin
                        AddRequiredElementMasters(info, plugin, False, True);
                        SortMasters(plugin);
                        edid := ElementByPath(info, 'EDID');
                        if not Assigned(edid) then
                            newInfo := wbCopyElementToFile(info, plugin, True, True)
                        else newInfo := wbCopyElementToFileWithPrefix(info, plugin, True, True, '', '', '_Dup');
                        json.O[RecordFormIdFileId(info)].S['formid'] := IntToHex(GetLoadOrderFormID(newInfo), 8);
                        formList.Add(newInfo);
                    end;
                end;
            end;
            if Signature(child) = 'SCEN' then begin
                newScene := wbCopyElementToFileWithPrefix(child, plugin, True, True, '', '', '_Dup');
                json.O[RecordFormIdFileId(child)].S['formid'] := IntToHex(GetLoadOrderFormID(newScene), 8);
                formList.Add(newScene);
            end;
            if Signature(child) = 'DLBR' then begin
                newDLBR := wbCopyElementToFileWithPrefix(child, plugin, True, True, '', '', '_Dup');
                json.O[RecordFormIdFileId(child)].S['formid'] := IntToHex(GetLoadOrderFormID(newDLBR), 8);
                formList.Add(newDLBR);
            end;
        end;
        for i := 0 to Pred(formList.Count) do begin
            elementHere := ObjectToElement(formList[i]);
            ProcessElements(elementHere);
        end;
    finally
        formList.Free;
    end;
    Result := 0;
end;

procedure ProcessElements(e: IwbElement);
var
    elementHere, linkedRef: IwbElement;
    newFormID: string;
    j: integer;
begin
    for j := 0 to Pred(ElementCount(e)) do begin
        elementHere := ElementByIndex(e, j);
        if not Assigned(elementHere) then Continue;
        linkedRef := LinksTo(elementHere);
        if not Assigned(linkedRef) then begin
            if ElementCount(elementHere) > 0 then
                ProcessElements(elementHere);
            Continue;
        end;
        newFormID := json.O[RecordFormIdFileId(linkedRef)].S['formid'];
        if newFormID = '' then begin
            if ElementCount(elementHere) > 0 then
                ProcessElements(elementHere);
            Continue;
        end;
        SetEditValue(elementHere, newFormID);
        AddMessage('Updated reference in ' + ShortName(e));
        if ElementCount(elementHere) > 0 then
            ProcessElements(elementHere);
    end;
end;

function RecordFormIdFileId(e: IwbElement): string;
{
    Returns the record ID of an element.
}
begin
    e := MasterOrSelf(e);
    Result := IntToHex(FormID(e), 8) + ':' + GetFileName(GetFile(e));
end;

end.