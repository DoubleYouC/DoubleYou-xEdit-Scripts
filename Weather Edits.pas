{
  Don't use this.
}
unit DoStuff;


// Called before processing
// You can remove it if script doesn't require initialization code
function Initialize: integer;
begin
    Result := 0;

end;

// called for every record selected in xEdit
function Process(e: IInterface): integer;
var
    i: integer;
    cloudTexture: IwbElement;
begin
    Result := 0;
    AddMessage(EditorID(e));
    if not SameText(Signature(e), 'WTHR') then Exit;
    for i := 0 to 29 do begin
        if GetElementNativeValues(e, 'NAM1\' + IntToStr(i)) then begin
            AddMessage('Cloud layer ' + IntToStr(i) + ' is disabled.');

            //set alpha to 0.
            SetElementNativeValues(e, 'JNAM\Layer #' + IntToStr(i) + '\Sunrise', 0);
            SetElementNativeValues(e, 'JNAM\Layer #' + IntToStr(i) + '\Day', 0);
            SetElementNativeValues(e, 'JNAM\Layer #' + IntToStr(i) + '\Sunset', 0);
            SetElementNativeValues(e, 'JNAM\Layer #' + IntToStr(i) + '\Night', 0);
            SetElementNativeValues(e, 'JNAM\Layer #' + IntToStr(i) + '\Early Sunrise', 0);
            SetElementNativeValues(e, 'JNAM\Layer #' + IntToStr(i) + '\Late Sunrise', 0);
            SetElementNativeValues(e, 'JNAM\Layer #' + IntToStr(i) + '\Early Sunset', 0);
            SetElementNativeValues(e, 'JNAM\Layer #' + IntToStr(i) + '\Late Sunset', 0);

            //set color to black
            SetElementNativeValues(e, 'PNAM\Layer #' + IntToStr(i) + '\Sunrise\Red', 0);
            SetElementNativeValues(e, 'PNAM\Layer #' + IntToStr(i) + '\Sunrise\Green', 0);
            SetElementNativeValues(e, 'PNAM\Layer #' + IntToStr(i) + '\Sunrise\Blue', 0);
            SetElementNativeValues(e, 'PNAM\Layer #' + IntToStr(i) + '\Day\Red', 0);
            SetElementNativeValues(e, 'PNAM\Layer #' + IntToStr(i) + '\Day\Green', 0);
            SetElementNativeValues(e, 'PNAM\Layer #' + IntToStr(i) + '\Day\Blue', 0);
            SetElementNativeValues(e, 'PNAM\Layer #' + IntToStr(i) + '\Sunset\Red', 0);
            SetElementNativeValues(e, 'PNAM\Layer #' + IntToStr(i) + '\Sunset\Green', 0);
            SetElementNativeValues(e, 'PNAM\Layer #' + IntToStr(i) + '\Sunset\Blue', 0);
            SetElementNativeValues(e, 'PNAM\Layer #' + IntToStr(i) + '\Night\Red', 0);
            SetElementNativeValues(e, 'PNAM\Layer #' + IntToStr(i) + '\Night\Green', 0);
            SetElementNativeValues(e, 'PNAM\Layer #' + IntToStr(i) + '\Night\Blue', 0);
            SetElementNativeValues(e, 'PNAM\Layer #' + IntToStr(i) + '\Early Sunrise\Red', 0);
            SetElementNativeValues(e, 'PNAM\Layer #' + IntToStr(i) + '\Early Sunrise\Green', 0);
            SetElementNativeValues(e, 'PNAM\Layer #' + IntToStr(i) + '\Early Sunrise\Blue', 0);
            SetElementNativeValues(e, 'PNAM\Layer #' + IntToStr(i) + '\Late Sunrise\Red', 0);
            SetElementNativeValues(e, 'PNAM\Layer #' + IntToStr(i) + '\Late Sunrise\Green', 0);
            SetElementNativeValues(e, 'PNAM\Layer #' + IntToStr(i) + '\Late Sunrise\Blue', 0);
            SetElementNativeValues(e, 'PNAM\Layer #' + IntToStr(i) + '\Early Sunset\Red', 0);
            SetElementNativeValues(e, 'PNAM\Layer #' + IntToStr(i) + '\Early Sunset\Green', 0);
            SetElementNativeValues(e, 'PNAM\Layer #' + IntToStr(i) + '\Early Sunset\Blue', 0);
            SetElementNativeValues(e, 'PNAM\Layer #' + IntToStr(i) + '\Late Sunset\Red', 0);
            SetElementNativeValues(e, 'PNAM\Layer #' + IntToStr(i) + '\Late Sunset\Green', 0);
            SetElementNativeValues(e, 'PNAM\Layer #' + IntToStr(i) + '\Late Sunset\Blue', 0);

            //undisable layer
            SetElementNativeValues(e, 'NAM1\' + IntToStr(i), 0);
        end;
        if ((GetElementNativeValues(e, 'JNAM\Layer #' + IntToStr(i) + '\Sunrise') = 0) and
            (GetElementNativeValues(e, 'JNAM\Layer #' + IntToStr(i) + '\Day') = 0) and
            (GetElementNativeValues(e, 'JNAM\Layer #' + IntToStr(i) + '\Sunset') = 0) and
            (GetElementNativeValues(e, 'JNAM\Layer #' + IntToStr(i) + '\Night') = 0) and
            (GetElementNativeValues(e, 'JNAM\Layer #' + IntToStr(i) + '\Early Sunrise') = 0) and
            (GetElementNativeValues(e, 'JNAM\Layer #' + IntToStr(i) + '\Late Sunrise') = 0) and
            (GetElementNativeValues(e, 'JNAM\Layer #' + IntToStr(i) + '\Early Sunset') = 0) and
            (GetElementNativeValues(e, 'JNAM\Layer #' + IntToStr(i) + '\Late Sunset') = 0)) then begin
                AddMessage('Cloud layer ' + IntToStr(i) + ' is disabled.');
                cloudTexture := ElementByIndex(ElementByPath(e, 'Cloud Textures'), i);
                SetEditValue(cloudTexture, '');
            end;
    end;
end;


// Called after processing
// You can remove it if script doesn't require finalization code
function Finalize: integer;
begin
    Result := 0;

end;

end.