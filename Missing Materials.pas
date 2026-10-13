{
    Check STAT for errors or possible issues.
}
unit CheckSTATs;

var
    slMissingMaterials, slNifErrors, slNeedsMaterials, slNeedsDecalFlag, slAddedMat, 
    slMaterialWarnings, slContainers, slMaterialsToVerify, slModelsToCheck, slMaterialsAdded: TStringList;
    sOutputDir: string;
    joTextureMswpMap, joCustomMaterials: TJsonObject;


function Initialize: integer;
{
    This function is called at the beginning.
}
begin
    Result := 0;

    slMissingMaterials := TStringList.Create;
    slMissingMaterials.Sorted := True;
    slNifErrors := TStringList.Create;
    slNifErrors.Sorted := True;
    slNeedsMaterials := TStringList.Create;
    slNeedsMaterials.Sorted := True;
    slNeedsDecalFlag := TStringList.Create;
    slNeedsDecalFlag.Sorted := True;
    slAddedMat := TStringList.Create;
    slAddedMat.Sorted := True;
    slContainers := TStringList.Create;
    slMaterialsToVerify := TStringList.Create;
    slMaterialsToVerify.Sorted := True;
    slModelsToCheck := TStringList.Create;
    slMaterialsAdded := TStringList.Create;
    slMaterialsAdded.Sorted := True;
    slMaterialWarnings := TStringList.Create;
    slMaterialWarnings.Sorted := True;

    joTextureMswpMap := TJsonObject.Create;
    joCustomMaterials := TJsonObject.Create;
    try
        sOutputDir :=  wbScriptsPath + 'FixModels\output';

        if not FileExists(sOutputDir + '\joTextureMswpMap.json') then begin
            ResourceContainerList(slContainers);
            FilesInContainers(slContainers);
        end else begin
            joTextureMswpMap.LoadFromFile(sOutputDir + '\joTextureMswpMap.json');
        end;
        ListStringsInStringList(slMaterialWarnings);
        CollectRecords;
        //CheckModels;
        ListStringsInStringList(slNifErrors);
        ListStringsInStringList(slMissingMaterials);
        // ListStringsInStringList(slNeedsMaterials);
        ListStringsInStringList(slAddedMat);
        ListStringsInStringList(slNeedsDecalFlag);
        ListStringsInStringList(slMaterialsToVerify);
        ListStringsInStringList(slMaterialsAdded);

        joCustomMaterials.SaveToFile(sOutputDir + '\joCustomMaterials.json', False, TEncoding.UTF8, True);
    finally
        slMissingMaterials.Free;
        slNifErrors.Free;
        slNeedsMaterials.Free;
        slNeedsDecalFlag.Free;
        slAddedMat.Free;
        slContainers.Free;
        slMaterialsToVerify.Free;
        joTextureMswpMap.Free;
        joCustomMaterials.Free;
        slModelsToCheck.Free;
        slMaterialsAdded.Free;
        slMaterialWarnings.Free;
    end;
end;

procedure FilesInContainers(containers: TStringList);
{
    Retrieves the files.
}
var
    slArchivedFiles: TStringList;
    i, TileFlags: integer;
    f, ext, diffuse, EnvironmentMappingMaskScale, EnvironmentMapping, SpecularMult, SpecularColor, SpecularEnabled,
    RimLighting, RimPower, EmitEnabled, EmittanceColor, EmittanceMult, BackLighting, BackLightPower, Refraction, NormalTexture,
    RefractionPower, GrayscaleToPaletteColor, GrayscaleTexture, GrayscaleToPaletteScale, EnvmapTexture, SmoothSpecTexture, testTexture,
    WetnessControl_SpecScale, WetnessControl_SpecPowerScale, WetnessControl_SpecMinvar, WetnessControl_Metalness, WetnessControl_FresnelPower, WetnessControl_EnvMapScale: string;
    bgsm: TwbBGSMFile;
    bgem: TwbBGEMFile;
begin
    slArchivedFiles := TStringList.Create;
    slArchivedFiles.Sorted := True;
    try
        for i := 0 to Pred(containers.Count) do begin
            ResourceList(containers[i], slArchivedFiles);
        end;
        for i := 0 to Pred(slArchivedFiles.Count) do begin
            f := slArchivedFiles[i];
            ext := ExtractFileExt(f);
            if SameText(ext, '.bgsm') then begin
                bgsm := TwbBGSMFile.Create;
                AddMessage(f);
                try
                    bgsm.LoadFromResource(f);
                    diffuse := LowerCase(wbNormalizeResourceName(bgsm.EditValues['Textures\Diffuse'], resTexture));

                    EnvmapTexture := LowerCase(wbNormalizeResourceName(bgsm.EditValues['Textures\Envmap'], resTexture));
                    EnvironmentMapping := bgsm.EditValues['EnvironmentMapping'];
                    EnvironmentMappingMaskScale := bgsm.EditValues['EnvironmentMappingMaskScale'];
                    if (EnvmapTexture = '') and (EnvironmentMapping = 'yes') then slMaterialWarnings.Add(f + #9 + 'Warning! Material uses environment mapping but does not have a cubemap!');
                    if (EnvmapTexture <> '') and (EnvironmentMapping = 'no') then slMaterialWarnings.Add(f + #9 + 'Warning! Material has a cubemap but does not use environment mapping!');
                    if EnvmapTexture = '' then EnvironmentMapping := 'no';
                    if EnvironmentMapping = 'no' then EnvironmentMappingMaskScale := '0.000000';
                    if EnvironmentMappingMaskScale = '0.000000' then EnvironmentMapping := 'no';
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['EnvironmentMappingMaskScale'] := EnvironmentMappingMaskScale;
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['EnvironmentMapping'] := EnvironmentMapping;

                    GrayscaleToPaletteColor := bgsm.EditValues['GrayscaleToPaletteColor'];
                    GrayscaleTexture := LowerCase(wbNormalizeResourceName(bgsm.EditValues['Textures\Grayscale'], resTexture));
                    GrayscaleToPaletteScale := bgsm.EditValues['GrayscaleToPaletteScale'];
                    if (GrayscaleTexture = '') and (GrayscaleToPaletteColor = 'yes') then slMaterialWarnings.Add(f + #9 + 'Warning! Material uses grayscale to palette but does not have a palette!');
                    if GrayscaleToPaletteColor = 'yes' then if GrayscaleTexture = '' then GrayscaleToPaletteColor := 'no';
                    if GrayscaleToPaletteColor = 'no' then GrayscaleToPaletteScale := '0.000000';
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['GrayscaleToPaletteColor'] := GrayscaleToPaletteColor;
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['GrayscaleToPaletteScale'] := GrayscaleToPaletteScale;

                    Refraction := bgsm.EditValues['Refraction'];
                    RefractionPower := bgsm.EditValues['RefractionPower'];
                    if Refraction = 'no' then RefractionPower := '0.000000';
                    if RefractionPower = '0.000000' then Refraction := 'no';
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['Refraction'] := Refraction;
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['RefractionPower'] := RefractionPower;

                    BackLighting := bgsm.EditValues['BackLighting'];
                    BackLightPower := bgsm.EditValues['BackLightPower'];
                    if BackLighting = 'no' then BackLightPower := '0.000000';
                    if BackLightPower = '0.000000' then BackLighting := 'no';
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['BackLighting'] := BackLighting;
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['BackLightPower'] := BackLightPower;

                    EmitEnabled := bgsm.EditValues['EmitEnabled'];
                    EmittanceColor := bgsm.EditValues['EmittanceColor'];
                    EmittanceMult := bgsm.EditValues['EmittanceMult'];
                    if EmitEnabled = 'yes' then begin
                        if EmittanceColor = '#000000' then EmitEnabled := 'no';
                        if EmittanceMult = '0.000000' then EmitEnabled := 'no';
                    end;
                    if EmitEnabled = 'no' then begin
                        EmittanceColor := '#000000';
                        EmittanceMult := '0.000000';
                    end;
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['EmitEnabled'] := EmitEnabled;
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['EmittanceColor'] := EmittanceColor;
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['EmittanceMult'] := EmittanceMult;

                    RimLighting := bgsm.EditValues['RimLighting'];
                    RimPower := bgsm.EditValues['RimPower'];
                    if RimLighting = 'no' then RimPower := '0.000000';
                    if RimPower = '0.000000' then RimLighting := 'no';
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['RimLighting'] := bgsm.EditValues['RimLighting'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['RimPower'] := bgsm.EditValues['RimPower'];

                    SpecularEnabled := bgsm.EditValues['SpecularEnabled'];
                    SpecularColor := bgsm.EditValues['SpecularColor'];
                    SpecularMult := bgsm.EditValues['SpecularMult'];
                    SmoothSpecTexture := LowerCase(wbNormalizeResourceName(bgsm.EditValues['Textures\SmoothSpec'], resTexture));
                    if (SmoothSpecTexture = '') and (SpecularEnabled = 'yes') then slMaterialWarnings.Add(f + #9 + 'Warning! Material uses specular but does not have a specular texture!');
                    if (SmoothSpecTexture <> '') and (SpecularEnabled = 'no') then slMaterialWarnings.Add(f + #9 + 'Warning! Material has a specular texture but does not use specular!');
                    if SpecularEnabled = 'yes' then begin
                        // if SpecularColor = '#000000' then SpecularEnabled := 'no';
                        if SpecularMult = '0.000000' then SpecularEnabled := 'no';
                    end;
                    if SpecularEnabled = 'no' then begin
                        SpecularColor := '#000000';
                        SpecularMult := '0.000000';
                    end;
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['SpecularEnabled'] := bgsm.EditValues['SpecularEnabled'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['SpecularColor'] := bgsm.EditValues['SpecularColor'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['SpecularMult'] := bgsm.EditValues['SpecularMult'];

                    TileFlags := bgsm.NativeValues['TileFlags'];
                    if ((TileFlags and 1) <> 0) and ((TileFlags and 2) <> 0)
                    then joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TileFlags'] := 3
                    else if ((TileFlags and 1) = 0) and ((TileFlags and 2) = 0)
                    then joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TileFlags'] := 0
                    else if ((TileFlags and 1) <> 0) and ((TileFlags and 2) = 0)
                    then joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TileFlags'] := 1
                    else if ((TileFlags and 1) = 0) and ((TileFlags and 2) <> 0)
                    then joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TileFlags'] := 2;

                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['AlphaTest'] := bgsm.EditValues['AlphaTest'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['Decal'] := bgsm.EditValues['Decal'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['DecalNoFade'] := bgsm.EditValues['DecalNoFade'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['ScreenSpaceReflections'] := bgsm.EditValues['ScreenSpaceReflections'];
                    
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TwoSided'] := bgsm.EditValues['TwoSided'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WetnessControl_ScreenSpaceReflections'] := bgsm.EditValues['WetnessControlScreenSpaceReflections'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['ZBufferTest'] := bgsm.EditValues['ZBufferTest'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['ZBufferWrite'] := bgsm.EditValues['ZBufferWrite'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['AlphaBlendMode'] := bgsm.EditValues['AlphaBlendMode'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['Alpha'] := FloatToStr(StrToFloatDef(bgsm.EditValues['Alpha'],1));
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['AlphaTestRef'] := bgsm.EditValues['AlphaTestRef'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['UOffset'] := bgsm.EditValues['UOffset'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['UScale'] := bgsm.EditValues['UScale'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['VOffset'] := bgsm.EditValues['VOffset'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['VScale'] := bgsm.EditValues['VScale'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['AnisoLighting'] := bgsm.EditValues['AnisoLighting'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['CastShadows'] := bgsm.EditValues['CastShadows'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['EnvironmentMappingEye'] := bgsm.EditValues['EnvironmentMappingEye'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['ExternalEmittance'] := bgsm.EditValues['ExternalEmittance'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['Facegen'] := bgsm.EditValues['Facegen'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['Glowmap'] := bgsm.EditValues['Glowmap'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['Hair'] := bgsm.EditValues['Hair'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['HideSecret'] := bgsm.EditValues['HideSecret'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['ModelSpaceNormals'] := bgsm.EditValues['ModelSpaceNormals'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['SkewSpecularAlpha'] := bgsm.EditValues['SkewSpecularAlpha'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['SkinTint'] := bgsm.EditValues['SkinTint'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['Tessellate'] := bgsm.EditValues['Tessellate'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['Tree'] := bgsm.EditValues['Tree'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['FresnelPower'] := bgsm.EditValues['FresnelPower'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['Smoothness'] := bgsm.EditValues['Smoothness'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['SubsurfaceLightingRolloff'] := bgsm.EditValues['SubsurfaceLightingRolloff'];

                    WetnessControl_EnvMapScale := bgsm.EditValues['WetnessControlEnvMapScale'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WetnessControl_EnvMapScale'] := WetnessControl_EnvMapScale;
                    if (LeftStr(WetnessControl_EnvMapScale, 1) = '-') and (WetnessControl_EnvMapScale <> '-1.000000') then slMaterialWarnings.Add(f + #9 + 'Warning! Material has a non-passthru, negative WetnessControl_EnvMapScale value:' + #9 + WetnessControl_EnvMapScale);
                    WetnessControl_FresnelPower := bgsm.EditValues['WetnessControlFresnelPower'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WetnessControl_FresnelPower'] := WetnessControl_FresnelPower;
                    if (LeftStr(WetnessControl_FresnelPower, 1) = '-') and (WetnessControl_FresnelPower <> '-1.000000') then slMaterialWarnings.Add(f + #9 + 'Warning! Material has a non-passthru, negative WetnessControl_FresnelPower value:' + #9 + WetnessControl_FresnelPower);
                    WetnessControl_Metalness := bgsm.EditValues['WetnessControlMetalness'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WetnessControl_Metalness'] := WetnessControl_Metalness;
                    if (LeftStr(WetnessControl_Metalness, 1) = '-') and (WetnessControl_Metalness <> '-1.000000') then slMaterialWarnings.Add(f + #9 + 'Warning! Material has a non-passthru, negative WetnessControl_Metalness value:' + #9 + WetnessControl_Metalness);
                    WetnessControl_SpecMinvar := bgsm.EditValues['WetnessControlSpecMinvar'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WetnessControl_SpecMinvar'] := WetnessControl_SpecMinvar;
                    if (LeftStr(WetnessControl_SpecMinvar, 1) = '-') and (WetnessControl_SpecMinvar <> '-1.000000') then slMaterialWarnings.Add(f + #9 + 'Warning! Material has a non-passthru, negative WetnessControl_SpecMinvar value:' + #9 + WetnessControl_SpecMinvar);
                    WetnessControl_SpecPowerScale := bgsm.EditValues['WetnessControlSpecPowerScale'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WetnessControl_SpecPowerScale'] := WetnessControl_SpecPowerScale;
                    if (LeftStr(WetnessControl_SpecPowerScale, 1) = '-') and (WetnessControl_SpecPowerScale <> '-1.000000') then slMaterialWarnings.Add(f + #9 + 'Warning! Material has a non-passthru, negative WetnessControl_SpecPowerScale value:' + #9 + WetnessControl_SpecPowerScale);
                    WetnessControl_SpecScale := bgsm.EditValues['WetnessControlSpecScale'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WetnessControl_SpecScale'] := WetnessControl_SpecScale;
                    if (LeftStr(WetnessControl_SpecScale, 1) = '-') and (WetnessControl_SpecScale <> '-1.000000') then slMaterialWarnings.Add(f + #9 + 'Warning! Material has a non-passthru, negative WetnessControl_SpecScale value:' + #9 + WetnessControl_SpecScale);

                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['RootMaterialPath'] := bgsm.EditValues['RootMaterialPath'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['DissolveFade'] := bgsm.EditValues['DissolveFade'];

                    //no nif equivalent it would seem
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['NonOccluder'] := bgsm.EditValues['NonOccluder'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['SubsurfaceLighting'] := bgsm.EditValues['SubsurfaceLighting'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['HairTintColor'] := bgsm.EditValues['HairTintColor'];

                    //textures
                    NormalTexture := LowerCase(wbNormalizeResourceName(bgsm.EditValues['Textures\Normal'], resTexture));
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['NormalTexture'] := NormalTexture;
                    if (NormalTexture <> '') and (NormalTexture <> 'textures\effects\colornormalspecutility.dds') and (not SameText(RightStr(NormalTexture, 6), '_n.dds'))
                    then slMaterialWarnings.Add(f + #9 + 'Warning! Material has a normal texture that does not use the _n suffix:' + #9 + NormalTexture);
                    if NormalTexture = '' then begin
                        if SameText(RightStr(diffuse, 6), '_d.dds') then testTexture := TrimLeftChars(diffuse, 6) + '_n.dds';
                        if ResourceExists(testTexture) then slMaterialWarnings.Add(f + #9 + 'Warning! Material does not use its existing normal texture:' + #9 + testTexture);
                    end;
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['GlowTexture'] := LowerCase(wbNormalizeResourceName(bgsm.EditValues['Textures\Glow'], resTexture));
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['GrayscaleTexture'] := GrayscaleTexture;
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['DisplacementTexture'] := LowerCase(wbNormalizeResourceName(bgsm.EditValues['Textures\Displacement'], resTexture));
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['EnvmapTexture'] := EnvmapTexture;
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['InnerLayerTexture'] := LowerCase(wbNormalizeResourceName(bgsm.EditValues['Textures\InnerLayer'], resTexture));
                    if (SmoothSpecTexture <> '') and (not SameText(RightStr(SmoothSpecTexture, 6), '_s.dds')) then slMaterialWarnings.Add(f + #9 + 'Warning! Material has a specular texture that does not use the _s suffix:' + #9 + SmoothSpecTexture);
                    if SmoothSpecTexture = '' then begin
                        if SameText(RightStr(diffuse, 6), '_d.dds') then testTexture := TrimLeftChars(diffuse, 6) + '_s.dds';
                        if ResourceExists(testTexture) then slMaterialWarnings.Add(f + #9 + 'Warning! Material does not use its existing specular texture:' + #9 + testTexture);
                    end;
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['SmoothSpecTexture'] := SmoothSpecTexture;


                    //perhaps unused
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WrinklesTexture'] := LowerCase(wbNormalizeResourceName(bgsm.EditValues['WrinklesTexture'], resTexture));
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['EnableEditorAlphaRef'] := bgsm.EditValues['EnableEditorAlphaRef'];
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['Terrain'] := bgsm.EditValues['Terrain'];
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['SpecularTexture'] := LowerCase(wbNormalizeResourceName(bgsm.EditValues['SpecularTexture'], resTexture));
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['DistanceFieldAlphaTexture'] := LowerCase(wbNormalizeResourceName(bgsm.EditValues['DistanceFieldAlphaTexture'], resTexture));
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['FlowTexture'] := LowerCase(wbNormalizeResourceName(bgsm.EditValues['FlowTexture'], resTexture));
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['LightingTexture'] := LowerCase(wbNormalizeResourceName(bgsm.EditValues['LightingTexture'], resTexture));
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['DepthBias'] := bgsm.EditValues['DepthBias'];
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WriteMaskAlbedo'] := bgsm.EditValues['WriteMaskAlbedo'];
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WriteMaskAmbientOcclusion'] := bgsm.EditValues['WriteMaskAmbientOcclusion'];
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WriteMaskEmissive'] := bgsm.EditValues['WriteMaskEmissive'];
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WriteMaskGloss'] := bgsm.EditValues['WriteMaskGloss'];
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WriteMaskNormal'] := bgsm.EditValues['WriteMaskNormal'];
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WriteMaskSpecular'] := bgsm.EditValues['WriteMaskSpecular'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['RefractionFalloff'] := bgsm.EditValues['RefractionFalloff'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['AssumeShadowmask'] := bgsm.EditValues['AssumeShadowmask'];
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['CustomPorosity'] := bgsm.EditValues['CustomPorosity'];
                    
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['EnvironmentMappingWindow'] := bgsm.EditValues['EnvironmentMappingWindow'];
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['PBR'] := bgsm.EditValues['PBR'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['ReceiveShadows'] := bgsm.EditValues['ReceiveShadows'];
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['Translucency'] := bgsm.EditValues['Translucency'];
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TranslucencyMixAlbedoWithSubsurfaceColor'] := bgsm.EditValues['TranslucencyMixAlbedoWithSubsurfaceColor'];
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TranslucencyThickObject'] := bgsm.EditValues['TranslucencyThickObject'];
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TranslucencySubsurfaceColor'] := bgsm.EditValues['TranslucencySubsurfaceColor'];
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['UseAdaptativeEmissive'] := bgsm.EditValues['UseAdaptativeEmissive'];
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['AdaptativeEmissive_ExposureOffset'] := bgsm.EditValues['AdaptativeEmissive_ExposureOffset'];
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['AdaptativeEmissive_FinalExposureMax'] := bgsm.EditValues['AdaptativeEmissive_FinalExposureMax'];
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['AdaptativeEmissive_FinalExposureMin'] := bgsm.EditValues['AdaptativeEmissive_FinalExposureMin'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['DisplacementTextureBias'] := bgsm.EditValues['DisplacementTextureBias'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['DisplacementTextureScale'] := bgsm.EditValues['DisplacementTextureScale'];
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['LumEmittance'] := bgsm.EditValues['LumEmittance'];
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['PorosityValue'] := bgsm.EditValues['PorosityValue'];
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TerrainRotationAngle'] := bgsm.EditValues['TerrainRotationAngle'];
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TerrainThresholdFalloff'] := bgsm.EditValues['TerrainThresholdFalloff'];
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TerrainTilingDistance'] := bgsm.EditValues['TerrainTilingDistance'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TessellationBaseFactor'] := bgsm.EditValues['TessellationBaseFactor'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TessellationFadeDistance'] := bgsm.EditValues['TessellationFadeDistance'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TessellationPnScale'] := bgsm.EditValues['TessellationPnScale'];
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TranslucencyTransmissiveScale'] := bgsm.EditValues['TranslucencyTransmissiveScale'];
                    // joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TranslucencyTurbulence'] := bgsm.EditValues['TranslucencyTurbulence'];
                finally
                    bgsm.Free;
                end;
            end else if SameText(ext, '.bgem') then begin
                bgem := TwbBGEMFile.Create;
                AddMessage(f);
                try
                    bgem.LoadFromResource(f);
                    diffuse := LowerCase(wbNormalizeResourceName(bgem.EditValues['Textures\Base'], resTexture));
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['UOffset'] := bgem.EditValues['UOffset'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['VOffset'] := bgem.EditValues['VOffset'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['UScale'] := bgem.EditValues['UScale'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['VScale'] := bgem.EditValues['VScale'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['AlphaBlendMode'] := bgem.EditValues['AlphaBlendMode'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['AlphaTestRef'] := bgem.EditValues['AlphaTestRef'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['AlphaTest'] := bgem.EditValues['AlphaTest'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['ZBufferTest'] := bgem.EditValues['ZBufferTest'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['ZBufferWrite'] := bgem.EditValues['ZBufferWrite'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['Decal'] := bgem.EditValues['Decal'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['TwoSided'] := bgem.EditValues['TwoSided'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['DecalNoFade'] := bgem.EditValues['DecalNoFade'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['Refraction'] := bgem.EditValues['Refraction'];

                    EnvmapTexture := LowerCase(wbNormalizeResourceName(bgem.EditValues['Textures\Envmap'], resTexture));
                    EnvironmentMapping := bgem.EditValues['EnvironmentMapping'];
                    EnvironmentMappingMaskScale := bgem.EditValues['EnvironmentMappingMaskScale'];
                    if (EnvmapTexture = '') and (EnvironmentMapping = 'yes') then slMaterialWarnings.Add(f + #9 + 'Warning! Material uses environment mapping but does not have a cubemap!');
                    if (EnvmapTexture <> '') and (EnvironmentMapping = 'no') then slMaterialWarnings.Add(f + #9 + 'Warning! Material has a cubemap but does not use environment mapping!');
                    if EnvmapTexture = '' then EnvironmentMapping := 'no';
                    if EnvironmentMapping = 'no' then EnvironmentMappingMaskScale := '0.000000';
                    if EnvironmentMappingMaskScale = '0.000000' then EnvironmentMapping := 'no';
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['EnvironmentMappingMaskScale'] := EnvironmentMappingMaskScale;
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['EnvironmentMapping'] := EnvironmentMapping;

                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['GrayscaleToPaletteColor'] := bgem.EditValues['GrayscaleToPaletteColor'];

                    TileFlags := bgem.NativeValues['TileFlags'];
                    if ((TileFlags and 1) <> 0) and ((TileFlags and 2) <> 0)
                    then joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['TileFlags'] := 3
                    else if ((TileFlags and 1) = 0) and ((TileFlags and 2) = 0)
                    then joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['TileFlags'] := 0
                    else if ((TileFlags and 1) <> 0) and ((TileFlags and 2) = 0)
                    then joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['TileFlags'] := 1
                    else if ((TileFlags and 1) = 0) and ((TileFlags and 2) <> 0)
                    then joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['TileFlags'] := 2;

                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['EffectLightingEnabled'] := bgem.EditValues['EffectLightingEnabled'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['FalloffColorEnabled'] := bgem.EditValues['FalloffColorEnabled'];

                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['FalloffEnabled'] := bgem.EditValues['FalloffEnabled'];
                    if bgem.EditValues['FalloffEnabled'] = 'yes' then begin
                        joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['FalloffStartAngle'] := bgem.EditValues['FalloffStartAngle'];
                        joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['FalloffStartOpacity'] := bgem.EditValues['FalloffStartOpacity'];
                        joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['FalloffStopAngle'] := bgem.EditValues['FalloffStopAngle'];
                        joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['FalloffStopOpacity'] := bgem.EditValues['FalloffStopOpacity'];
                    end else begin
                        joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['FalloffStartAngle'] := '1.000000';
                        joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['FalloffStartOpacity'] := '0.000000';
                        joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['FalloffStopAngle'] := '1.000000';
                        joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['FalloffStopOpacity'] := '0.000000';
                    end;
                    
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['GrayscaleToPaletteAlpha'] := bgem.EditValues['GrayscaleToPaletteAlpha'];

                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['SoftEnabled'] := bgem.EditValues['SoftEnabled'];
                    if bgem.EditValues['SoftEnabled'] = 'yes' then
                        joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['SoftDepth'] := bgem.EditValues['SoftDepth']
                    else
                        joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['SoftDepth'] := '0.000000';

                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['BaseColor'] := bgem.EditValues['BaseColor'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['Alpha'] := FloatToStr(StrToFloatDef(bgem.EditValues['Alpha'],1));
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['BaseColorScale'] := bgem.EditValues['BaseColorScale'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['LightingInfluence'] := bgem.EditValues['LightingInfluence'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['EnvmapMinLOD'] := bgem.EditValues['EnvmapMinLOD'];

                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['EnvmapMaskTexture'] := LowerCase(wbNormalizeResourceName(bgem.EditValues['Textures\EnvmapMask'], resTexture));
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['EnvmapTexture'] := EnvmapTexture;
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['GrayscaleTexture'] := LowerCase(wbNormalizeResourceName(bgem.EditValues['Textures\Grayscale'], resTexture));
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['NormalTexture'] := LowerCase(wbNormalizeResourceName(bgem.EditValues['Textures\Normal'], resTexture));

                    //no nif equivalent it would seem
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['NonOccluder'] := bgem.EditValues['NonOccluder'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['ScreenSpaceReflections'] := bgem.EditValues['ScreenSpaceReflections'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['WetnessControl_ScreenSpaceReflections'] := bgem.EditValues['WetnessControlScreenSpaceReflections'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['BloodEnabled'] := bgem.EditValues['BloodEnabled'];

                    // unused
                    //joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['Glowmap'] := bgem.EditValues['Glowmap'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['RefractionFalloff'] := bgem.EditValues['RefractionFalloff'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['RefractionPower'] := bgem.EditValues['RefractionPower'];
                    // joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['DepthBias'] := bgem.EditValues['DepthBias'];
                    // joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['WriteMaskAlbedo'] := bgem.EditValues['WriteMaskAlbedo'];
                    // joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['WriteMaskAmbientOcclusion'] := bgem.EditValues['WriteMaskAmbientOcclusion'];
                    // joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['WriteMaskEmissive'] := bgem.EditValues['WriteMaskEmissive'];
                    // joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['WriteMaskGloss'] := bgem.EditValues['WriteMaskGloss'];
                    // joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['WriteMaskNormal'] := bgem.EditValues['WriteMaskNormal'];
                    // joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['WriteMaskSpecular'] := bgem.EditValues['WriteMaskSpecular'];
                    // joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['EffectPbrSpecular'] := bgem.EditValues['EffectPbrSpecular'];
                    // joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['GlassEnabled'] := bgem.EditValues['GlassEnabled'];
                    // joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['EmittanceColor'] := bgem.EditValues['EmittanceColor'];
                    // joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['GlassFresnelColor'] := bgem.EditValues['GlassFresnelColor'];
                    // joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['AdaptativeEmissive_ExposureOffset'] := bgem.EditValues['AdaptativeEmissive_ExposureOffset'];
                    // joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['AdaptativeEmissive_FinalExposureMax'] := bgem.EditValues['AdaptativeEmissive_FinalExposureMax'];
                    // joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['AdaptativeEmissive_FinalExposureMin'] := bgem.EditValues['AdaptativeEmissive_FinalExposureMin'];
                    // joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['GlassBlurScaleBase'] := bgem.EditValues['GlassBlurScaleBase'];
                    // joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['GlassBlurScaleFactor'] := bgem.EditValues['GlassBlurScaleFactor'];
                    // joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['GlassRefractionScaleBase'] := bgem.EditValues['GlassRefractionScaleBase'];
                    // joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['GlassDirtOverlay'] := bgem.EditValues['GlassDirtOverlay'];
                    // joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['GlassRoughnessScratch'] := bgem.EditValues['GlassRoughnessScratch'];
                    // joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['GlowTexture'] := bgem.EditValues['GlowTexture'];
                    // joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['LightingTexture'] := bgem.EditValues['Textures\Lighting'];
                    // joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['SpecularTexture'] := bgem.EditValues['Textures\Specular'];
                finally
                    bgem.Free;
                end;
            end;
        end;
    finally
        EnsureDirectoryExists(sOutputDir);
        joTextureMswpMap.SaveToFile(sOutputDir + '\joTextureMswpMap.json', False, TEncoding.UTF8, True);
        slArchivedFiles.Free;
    end;
end;

function CreateMissingMaterial(joCustomMaterial: TJsonObject; diffuse, shader, model, blocknamehere: string): string;
var
    bgsm: TwbBGSMFile;
    bgem: TwbBGEMFile;
    mat, key, tileU, tileV: string;
    i, tileflags: integer;
begin
    Result := '';
    if shader = 'bgsm' then begin
        bgsm := TwbBGSMFile.Create;
        try
            bgsm.LoadFromResource('materials\default.bgsm');
            mat := DiffuseToMaterial(diffuse, shader);
            if not Assigned(mat) then Exit;
            bgsm.EditValues['Textures\Diffuse'] := diffuse;
            for i := 0 to Pred(joCustomMaterial.Count) do begin
                key := joCustomMaterial.Names[i];
                if key = 'WetnessControl_ScreenSpaceReflections' then begin
                    bgsm.EditValues['WetnessControlScreenSpaceReflections'] := joCustomMaterial.S[key];
                end else if key = 'WetnessControl_EnvMapScale' then begin
                    bgsm.EditValues['WetnessControlEnvMapScale'] := joCustomMaterial.S[key];
                end else if key = 'WetnessControl_FresnelPower' then begin
                    bgsm.EditValues['WetnessControlFresnelPower'] := joCustomMaterial.S[key];
                end else if key = 'WetnessControl_Metalness' then begin
                    bgsm.EditValues['WetnessControlMetalness'] := joCustomMaterial.S[key];
                end else if key = 'WetnessControl_SpecMinvar' then begin
                    bgsm.EditValues['WetnessControlSpecMinvar'] := joCustomMaterial.S[key];
                end else if key = 'WetnessControl_SpecPowerScale' then begin
                    bgsm.EditValues['WetnessControlSpecPowerScale'] := joCustomMaterial.S[key];
                end else if key = 'WetnessControl_SpecScale' then begin
                    bgsm.EditValues['WetnessControlSpecScale'] := joCustomMaterial.S[key];
                end else if key = 'NormalTexture' then begin
                    bgsm.EditValues['Textures\Normal'] := joCustomMaterial.S[key];
                end else if key = 'GlowTexture' then begin
                    bgsm.EditValues['Textures\Glow'] := joCustomMaterial.S[key];
                end else if key = 'GrayscaleTexture' then begin
                    bgsm.EditValues['Textures\Grayscale'] := joCustomMaterial.S[key];
                end else if key = 'DisplacementTexture' then begin
                    bgsm.EditValues['Textures\Displacement'] := joCustomMaterial.S[key];
                end else if key = 'EnvmapTexture' then begin
                    bgsm.EditValues['Textures\Envmap'] := joCustomMaterial.S[key];
                end else if key = 'InnerLayerTexture' then begin
                    bgsm.EditValues['Textures\InnerLayer'] := joCustomMaterial.S[key];
                end else if key = 'SmoothSpecTexture' then begin
                    bgsm.EditValues['Textures\SmoothSpec'] := joCustomMaterial.S[key];
                end else if key = 'RimPower' then begin
                    if joCustomMaterial.S[key] <> 'Max' then
                        bgsm.EditValues[key] := joCustomMaterial.S[key];
                end else if key = 'nifs' then continue
                else
                    bgsm.EditValues[key] := joCustomMaterial.S[key];
            end;

            EnsureDirectoryExists(sOutputDir + '\' + ExtractFilePath(mat));
            bgsm.SaveToFile(sOutputDir + '\' + mat);
        finally
            bgsm.Free;
        end;
    end
    else if shader = 'bgem' then begin
        bgem := TwbBGEMFile.Create;
        try
            bgem.LoadFromResource('materials\defaulteffect.bgem');
            mat := DiffuseToMaterial(diffuse, shader);
            if not Assigned(mat) then Exit;

            bgem.EditValues['Textures\Base'] := diffuse;
            for i := 0 to Pred(joCustomMaterial.Count) do begin
                key := joCustomMaterial.Names[i];
                if key = 'NormalTexture' then begin
                    bgem.EditValues['Textures\Normal'] := joCustomMaterial.S[key];
                end else if key = 'GrayscaleTexture' then begin
                    bgem.EditValues['Textures\Grayscale'] := joCustomMaterial.S[key];
                end else if key = 'EnvmapTexture' then begin
                    bgem.EditValues['Textures\Envmap'] := joCustomMaterial.S[key];
                end else if key = 'EnvmapMaskTexture' then begin
                    bgem.EditValues['Textures\EnvmapMask'] := joCustomMaterial.S[key];
                end else if key = 'nifs' then continue
                else
                    bgem.EditValues[key] := joCustomMaterial.S[key];
            end;

            EnsureDirectoryExists(sOutputDir + '\' + ExtractFilePath(mat));
            bgem.SaveToFile(sOutputDir + '\' + mat);
        finally
            bgem.Free
        end;
    end;
    slMaterialsAdded.Add(mat + #9 + 'Added a missing material based on block ' + blocknamehere + ' from ' + model);
    Result := mat;
end;

function DiffuseToMaterial(diffuse, shader: string): string;
var
    suffixLength, i: integer;
    matBase, matHere: string;
begin
    Result := nil;
    if SameText(RightStr(diffuse, 6), '_d.dds') then suffixLength := 6 else suffixLength := 4;
    matBase := 'materials' + TrimLeftChars(TrimRightChars(diffuse, Length('textures')), suffixLength);
    for i:=1 to 20 do begin
        matHere := matBase + '_' + IntToStr(i) + '.' + shader;
        if (not ResourceExists(matHere)) and (not FileExists(sOutputDir + '\' + matHere)) then begin
            Result := matHere;
            break;
        end;
    end;
end;

procedure CollectRecords;
{
    Collect records.
}
var
    i, j: integer;
    model: string;

    f: IwbFile;
    g: IwbGroupRecord;
    r: IwbElement;
begin
    for i := 0 to Pred(FileCount) do begin
        f := FileByIndex(i);

        //Collect STAT
        g := GroupBySignature(f, 'STAT');
        for j := 0 to Pred(ElementCount(g)) do begin
            r := ElementByIndex(g, j);
            if not IsWinningOverride(r) then continue;
            model := wbNormalizeResourceName(GetElementEditValues(r, 'Model\MODL'), resMesh);
            if model = '' then continue;
            if not (ReferencedByCount(r) > 0) then continue;
            if not ResourceExists(model) then begin
                AddMessage('Warning: STAT references a model that does not seem to exist: ' + ShortName(r) + #9 + model);
                continue;
            end;
            if not IsEverUsed(r) then continue;
            NifNeedsMaterial(model);
            
            slModelsToCheck.Add(model);
        end;
    end;
end;

procedure CheckModels;
var
    i: integer;
    model: string;
begin
    for i := 0 to Pred(slModelsToCheck.Count) do begin
        model := slModelsToCheck[i];
        NifNeedsMaterial(model);
    end;
end;

function IsEverUsed(s: IwbMainRecord): boolean;
var
    i: integer;
    r: IwbMainRecord;
begin
    Result := false;
    for i := Pred(ReferencedByCount(s)) downto 0 do begin
        r := ReferencedByIndex(s, i);
        if Signature(r) <> 'REFR' then continue;
        if not IsWinningOverride(r) then continue;
        if GetIsDeleted(r) then continue;
        if GetIsCleanDeleted(r) then continue;
        //if not IsRefPrecombined(r) then continue;
        Result := true;
        break;
    end;
end;

function IsRefPrecombined(r: IwbMainRecord): boolean;
{
    Checks if a reference is precombined.
}
var
    i, t: integer;

    rCell: IwbMainRecord;
begin
    Result := false;
    t := ReferencedByCount(r) - 1;
    if t < 0 then Exit;
    for i := 0 to t do begin
        rCell := ReferencedByIndex(r, i);
        if Signature(rCell) <> 'CELL' then continue;
        if not IsWinningOverride(rCell) then continue;
        //AddMessage(ShortName(r) + ' is referenced in ' + Name(c));
        Result := true;
        Exit;
    end;
end;

function PickMaterial(mess, model, matType, diffuse: string; joCustomMaterial: TJsonObject): string;
var
    j, m, count, score, bestScore, total: integer;
    mat, key, x, y: string;
    joBestMatch: TJsonObject;
begin
    Result := nil;
    if not joTextureMswpMap.O[matType].Contains(diffuse) then Exit;
    count := joTextureMswpMap.O[matType].O[diffuse].Count;
    bestScore := 0;
    total := joCustomMaterial.Count;
    for m := Pred(count) downto 0 do begin
        score := 0;
        mat := joTextureMswpMap.O[matType].O[diffuse].Names[m];
        if not Assigned(Result) then Result := mat;
        for j := Pred(total) downto 0 do begin
            key := joCustomMaterial.Names[j];
            if key = 'nifs' then continue;
            // try
            x := joTextureMswpMap.O[matType].O[diffuse].O[mat].S[key];
            y := joCustomMaterial.S[key];
            if x = y
            then score := score + 1
            else if (key = 'TwoSided') and (y = 'yes') then score := -100
            else if (key = 'Decal') and (y = 'yes') then score := -100
            else if (key = 'UOffset') then score := -100
            else if (key = 'VOffset') then score := -100
            else if (key = 'UScale') then score := -100
            else if (key = 'VScale') then score := -100
            else if (key = 'AlphaTest') then score := -100
            else if (key = 'Alpha') then score := -100
            else if (key = 'AlphaBlend') then score := -100
            else if (key = 'GrayscaleToPaletteColor') then score := -100
            else if (key = 'Glowmap') then score := -100
            else if (key = 'BaseColor') then score := -100
            else if (key = 'NormalTexture') then score := -100;
            //AddMessage(x + #9 + y + #9 + BoolToStr(x = y))
            // except on E: Exception do
            //     AddMessage('Error: ' + mat + #9 + diffuse + #9 + key + #9 E.Message);
            //     raise Exception.Create('Error: ' + mat + #9 + diffuse + #9 + key + #9 E.Message);
            // end;
        end;
        if score > bestScore then begin
            bestScore := score;
            Result := mat;
        end;
    end;
    if bestScore = 0 then begin
        Result := nil;
        Exit;
    end;
    AddMessage(mess + Result + '"'+ #9 + 'Match Score: ' + IntToStr(bestScore) + '/' + IntToStr(total));
    if count > 1 then slMaterialsToVerify.Add(mess + Result + '"' + #9 + 'Match Score: ' + IntToStr(bestScore) + '/' + IntToStr(total));
    slAddedMat.Add(mess + Result + '"'+ #9 + 'Match Score: ' + IntToStr(bestScore) + '/' + IntToStr(total));
end;

procedure IsCustomMaterialUnique(const joCustomMaterial: TJsonObject; const shader, diffuse, model, blocknamehere: string; var matPath: string);
var
    i, j, count: integer;
    key: string;
    materialsMatch: boolean;
begin
    //joCustomMaterials.O['bgsm'].O[diffuse].O[count]
    count := joCustomMaterials.O[shader].O[diffuse].Count; 
    for i := 0 to Pred(count) do begin
        materialsMatch := true;
        for j := 0 to Pred(joCustomMaterials.O[shader].O[diffuse].O[i].Count) do begin
            key := joCustomMaterials.O[shader].O[diffuse].O[i].Names[j];
            if key = 'nifs' then continue;
            if key = 'material' then continue;
            if not SameText(joCustomMaterials.O[shader].O[diffuse].O[i].S[key], joCustomMaterial.S[key])
            then materialsMatch := false;
        end;
        if materialsMatch then break;
    end;
    if materialsMatch then begin
        joCustomMaterials.O[shader].O[diffuse].O[i].A['nifs'].Add(model);
        matPath := joCustomMaterials.O[shader].O[diffuse].O[i].S['material'];
    end else begin
        joCustomMaterials.O[shader].O[diffuse].O[count].Assign(joCustomMaterial);
        if matPath = '' then matPath := CreateMissingMaterial(joCustomMaterial, diffuse, shader, model, blocknamehere);
        joCustomMaterials.O[shader].O[diffuse].O[count].S['material'] := matPath;
    end;
end;

function NifNeedsMaterial(model: string): boolean;
var
    i, count, NiAlphaPropFlags: integer;
    mat, matExt, blockName, diffuse, matPath, matSuffix, mess, emit, emitColor, 
    BackLighting, uv, blocknamehere, clampMode, emitMult, BackLightPower, RefractionPower,
    GrayscaleToPaletteColor, RimPower, RimLighting, SpecularEnabled, SpecularMult, SpecularColor, Refraction,
    FalloffEnabled, SoftEnabled, EnvironmentMapping, EnvironmentMappingMaskScale: string;
    bBlockMissingMat, bChanged, bHasShaderProperty, bHasAlpha: boolean;

    tsUV: TStrings;
    nif: TwbNifFile;
    block, TextureSet, NiAlphaProp, controllerLink, prop, shaderProp: TwbNifBlock;
    Textures, TextureSetEle, AlphaPropEle, ShaderPropEle, controller: TdfElement;
    joCustomMaterial: TJsonObject;
begin
    Result := False;
    bChanged := False;
    //try
        nif := TwbNifFile.Create;
        try
            nif.LoadFromResource(model);
            for i := 0 to Pred(nif.BlocksCount) do begin
                bHasShaderProperty := false;
                bHasAlpha := false;
                shaderProp := nil;
                NiAlphaProp := nil;
                TextureSet := nil;
                diffuse := '';
                block := nif.Blocks[i];

                AlphaPropEle := block.Elements['Alpha Property'];
                if Assigned(AlphaPropEle) then
                NiAlphaProp := AlphaPropEle.LinksTo;
                if Assigned(NiAlphaProp) then bHasAlpha := true;

                ShaderPropEle := block.Elements['Shader Property'];
                if Assigned(ShaderPropEle)
                then shaderProp := ShaderPropEle.LinksTo
                else continue;
                if Assigned(shaderProp) then begin
                    bHasShaderProperty := true;
                    if shaderProp.BlockType = 'BSLightingShaderProperty' then matSuffix := 'bgsm'
                    else if shaderProp.BlockType = 'BSEffectShaderProperty' then matSuffix := 'bgem'
                    else bHasShaderProperty := false;
                end else continue;

                if not bHasShaderProperty then continue;
                blockName := block.EditValues['Name'];

                mat := wbNormalizeResourceName(shaderProp.EditValues['Name'], resMaterial);
                matExt := ExtractFileExt(mat);
                blocknamehere := IntToStr(i) + ' ' + block.BlockType + '\' + shaderProp.BlockType;
                AddMessage(model + #9 + blocknamehere);
                joCustomMaterial := TJsonObject.Create;
                try
                    if (not (SameText(matExt, matSuffix))) or (not ResourceExists(mat)) then begin
                        slNeedsMaterials.Add('Model may need a ' + shaderProp.BlockType + ' material: ' + #9 + model + #9 + blockName);
                        bBlockMissingMat := True;
                        Result := True;
                        if matSuffix = 'bgem' then begin
                            diffuse := LowerCase(wbNormalizeResourceName(shaderProp.EditValues['Source Texture'], resTexture));
                            if diffuse = '' then continue;
                            controller := shaderProp.Elements['Controller'];
                            if Assigned(controller) then begin
                                controllerLink := controller.LinksTo;
                                if Assigned(controllerLink) then continue;
                            end;

                            count := joCustomMaterials.O[matSuffix].O[diffuse].Count + 1;

                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Unknown';
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaTest'] := 'no';
                            if bHasAlpha then begin
                                if Assigned(NiAlphaProp) then begin
                                    NiAlphaPropFlags := NiAlphaProp.NativeValues['Flags'];
                                    //Alpha Blending 4333
                                    if (NiAlphaPropFlags and 1) <> 0 then
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Standard';
                                    
                                    //Alpha Testing 4844
                                    if (NiAlphaPropFlags and 2) <> 0 then
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaTest'] := 'yes';

                                    //Alpha Blending and Testing Additive 4845
                                    if ((NiAlphaPropFlags and 1) <> 0) and ((NiAlphaPropFlags and 2) <> 0) then
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Additive';

                                    //Alpha Blending Multiplicative 4137
                                    //Alpha Blending    Source Blend Mode: Dst Color    Alpha Test Function: Greater
                                    if ((NiAlphaPropFlags and 1) <> 0) and ((NiAlphaPropFlags and 8) <> 0) and ((NiAlphaPropFlags and 4096) <> 0) then
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Multiplicative';

                                    joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaTestRef'] := NiAlphaProp.EditValues['Threshold'];
                                end;
                            end;

                            uv := shaderProp.EditValues['UV Offset'];
                            tsUV := SplitString(uv, ' ');
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['UOffset'] := tsUV[0];
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['VOffset'] := tsUV[1];
                            uv := shaderProp.EditValues['UV Scale'];
                            tsUV := SplitString(uv, ' ');
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['UScale'] := tsUV[0];
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['VScale'] := tsUV[1];
                            
                            clampMode := shaderProp.EditValues['Texture Clamp Mode'];
                            if clampMode = 'WRAP_S_WRAP_T'
                            then joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['TileFlags'] := 3
                            else if clampMode = 'CLAMP_S_CLAMP_T'
                            then joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['TileFlags'] := 0
                            else if clampMode = 'CLAMP_S_WRAP_T'
                            then joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['TileFlags'] := 1
                            else if clampMode = 'WRAP_S_CLAMP_T'
                            then joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['TileFlags'] := 2;

                            emitColor := shaderProp.EditValues['Emissive Color'];
                            if LeftStr(emitColor, 1) = '#' then begin
                                joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['BaseColor'] := LeftStr(emitColor, 7);
                                joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['Alpha'] := FloatToStr(StrToInt('$' + RightStr(emitColor, 2)) / 255.0);
                            end else begin
                                joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['BaseColor'] := '#' + StringReplace(LeftStr(emitColor, 8), ' ', '', [rfIgnoreCase]);
                                joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['Alpha'] := FloatToStr(StrToFloatDef(RightStr(emitColor, 8),1));
                            end;

                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['LightingInfluence'] := shaderProp.EditValues['Lighting Influence'];
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['EnvmapMinLOD'] := shaderProp.EditValues['Env Map Min LOD'];

                            FalloffEnabled := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\Use_Falloff']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['FalloffEnabled'] := FalloffEnabled;

                            if FalloffEnabled = 'yes' then begin
                                joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['FalloffStartAngle'] := shaderProp.EditValues['Falloff Start Angle'];
                                joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['FalloffStopAngle'] := shaderProp.EditValues['Falloff Stop Angle'];
                                joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['FalloffStartOpacity'] := shaderProp.EditValues['Falloff Start Opacity'];
                                joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['FalloffStopOpacity'] := shaderProp.EditValues['Falloff Stop Opacity'];
                            end else begin
                                joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['FalloffStartAngle'] := '1.000000';
                                joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['FalloffStopAngle'] := '1.000000';
                                joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['FalloffStartOpacity'] := '0.000000';
                                joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['FalloffStopOpacity'] := '0.000000';
                            end;

                            SoftEnabled := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\Soft_Effect']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['SoftEnabled'] := SoftEnabled;
                            if SoftEnabled = 'yes' then
                                joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['SoftDepth'] := shaderProp.EditValues['Soft Falloff Depth']
                            else
                                joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['SoftDepth'] := '0.000000';

                            EnvironmentMapping := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\Environment_Mapping']);
                            EnvironmentMappingMaskScale := shaderProp.EditValues['Environment Map Scale'];
                            if EnvironmentMapping = 'no' then EnvironmentMappingMaskScale := '0.000000';
                            if EnvironmentMappingMaskScale = '0.000000' then EnvironmentMapping := 'no';
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['EnvironmentMapping'] := EnvironmentMapping;
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['EnvironmentMappingMaskScale'] := EnvironmentMappingMaskScale;

                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['BaseColorScale'] := shaderProp.EditValues['Emissive Multiple'];
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['GrayscaleTexture'] := shaderProp.EditValues['Grayscale Texture'];
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['EnvmapTexture'] := shaderProp.EditValues['Env Map Texture'];
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['NormalTexture'] := shaderProp.EditValues['Normal Texture'];
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['EnvmapMaskTexture'] := shaderProp.EditValues['Env Mask Texture'];

                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['GrayscaleToPaletteColor'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\GrayscaleToPalette_Color']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['GrayscaleToPaletteAlpha'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\GrayscaleToPalette_Alpha']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['FalloffColorEnabled'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\RGB_Falloff']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['Refraction'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\Refraction']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['Decal'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\Decal']);
                            
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['ZBufferTest'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\ZBuffer_Test']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['ZBufferWrite'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 2\ZBuffer_Write']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['DecalNoFade'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 2\No_Fade']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['TwoSided'] :=IntToYesNo(shaderProp.NativeValues['Shader Flags 2\Double_Sided']);
                            //joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['Glowmap'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 2\Glow_Map']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['EffectLightingEnabled'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 2\Effect_Lighting']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].A['nifs'].Add(model);


                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['DepthBias'] := shaderProp.EditValues['DepthBias'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['NonOccluder'] := shaderProp.EditValues['NonOccluder'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['ScreenSpaceReflections'] := shaderProp.EditValues['ScreenSpaceReflections'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['WetnessControl_ScreenSpaceReflections'] := shaderProp.EditValues['WetnessControl_ScreenSpaceReflections'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['WriteMaskAlbedo'] := shaderProp.EditValues['WriteMaskAlbedo'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['WriteMaskAmbientOcclusion'] := shaderProp.EditValues['WriteMaskAmbientOcclusion'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['WriteMaskEmissive'] := shaderProp.EditValues['WriteMaskEmissive'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['WriteMaskGloss'] := shaderProp.EditValues['WriteMaskGloss'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['WriteMaskNormal'] := shaderProp.EditValues['WriteMaskNormal'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['WriteMaskSpecular'] := shaderProp.EditValues['WriteMaskSpecular'];
                            
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['RefractionFalloff'] := shaderProp.EditValues['RefractionFalloff'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['RefractionPower'] := shaderProp.EditValues['RefractionPower'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['BloodEnabled'] := shaderProp.EditValues['BloodEnabled'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['EffectPbrSpecular'] := shaderProp.EditValues['EffectPbrSpecular'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['GlassEnabled'] := shaderProp.EditValues['GlassEnabled'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['EmittanceColor'] := shaderProp.EditValues['EmittanceColor'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['GlassFresnelColor'] := shaderProp.EditValues['GlassFresnelColor'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AdaptativeEmissive_ExposureOffset'] := shaderProp.EditValues['AdaptativeEmissive_ExposureOffset'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AdaptativeEmissive_FinalExposureMax'] := shaderProp.EditValues['AdaptativeEmissive_FinalExposureMax'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AdaptativeEmissive_FinalExposureMin'] := shaderProp.EditValues['AdaptativeEmissive_FinalExposureMin'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['GlassBlurScaleBase'] := shaderProp.EditValues['GlassBlurScaleBase'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['GlassBlurScaleFactor'] := shaderProp.EditValues['GlassBlurScaleFactor'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['GlassRefractionScaleBase'] := shaderProp.EditValues['GlassRefractionScaleBase'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['GlassDirtOverlay'] := shaderProp.EditValues['GlassDirtOverlay'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['GlassRoughnessScratch'] := shaderProp.EditValues['GlassRoughnessScratch'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['GlowTexture'] := shaderProp.EditValues['GlowTexture'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['LightingTexture'] := shaderProp.EditValues['LightingTexture'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['SpecularTexture'] := shaderProp.EditValues['SpecularTexture'];
                        end else begin
                            TextureSetEle := shaderProp.Elements['Texture Set'];
                            if not Assigned(TextureSetEle) then continue;
                            TextureSet := TextureSetEle.LinksTo;
                            if not Assigned(TextureSet) then continue;
                            if TextureSet.BlockType <> 'BSShaderTextureSet' then continue;
                            Textures := TextureSet.Elements['Textures'];
                            try
                                diffuse := LowerCase(wbNormalizeResourceName(Textures[0].EditValue, resTexture));
                            except on E: Exception do
                                AddMessage('Error: ' + E.Message);
                                continue;
                            end;
                            if diffuse = '' then continue;
                            controller := shaderProp.Elements['Controller'];
                            if Assigned(controller) then begin
                                controllerLink := controller.LinksTo;
                                if Assigned(controllerLink) then continue;
                            end;

                            count := joCustomMaterials.O[matSuffix].O[diffuse].Count + 1;

                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Unknown';
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaTest'] := 'no';
                            if bHasAlpha then begin
                                if Assigned(NiAlphaProp) then begin
                                    NiAlphaPropFlags := NiAlphaProp.NativeValues['Flags'];
                                    //Alpha Blending 4333
                                    if (NiAlphaPropFlags and 1) <> 0 then
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Standard';
                                    
                                    //Alpha Testing 4844
                                    if (NiAlphaPropFlags and 2) <> 0 then
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaTest'] := 'yes';

                                    //Alpha Blending and Testing Additive 4845
                                    if ((NiAlphaPropFlags and 1) <> 0) and ((NiAlphaPropFlags and 2) <> 0) then
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Additive';

                                    //Alpha Blending Multiplicative 4137
                                    //Alpha Blending    Source Blend Mode: Dst Color    Alpha Test Function: Greater
                                    if ((NiAlphaPropFlags and 1) <> 0) and ((NiAlphaPropFlags and 8) <> 0) and ((NiAlphaPropFlags and 4096) <> 0) then
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Multiplicative';
                                end;
                            end;

                            uv := shaderProp.EditValues['UV Offset'];
                            tsUV := SplitString(uv, ' ');
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['UOffset'] := tsUV[0];
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['VOffset'] := tsUV[1];
                            uv := shaderProp.EditValues['UV Scale'];
                            tsUV := SplitString(uv, ' ');
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['UScale'] := tsUV[0];
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['VScale'] := tsUV[1];
                            
                            clampMode := shaderProp.EditValues['Texture Clamp Mode'];
                            if clampMode = 'WRAP_S_WRAP_T'
                            then joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['TileFlags'] := 3
                            else if clampMode = 'CLAMP_S_CLAMP_T'
                            then joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['TileFlags'] := 0
                            else if clampMode = 'CLAMP_S_WRAP_T'
                            then joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['TileFlags'] := 1
                            else if clampMode = 'WRAP_S_CLAMP_T'
                            then joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['TileFlags'] := 2;

                            emitColor := shaderProp.EditValues['Emissive Color'];
                            emitMult := shaderProp.EditValues['Emissive Multiple'];
                            emit := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\Own_Emit']);
                            if emit = 'yes' then begin
                                if emitColor = '#000000' then emit := 'no';
                                if emitMult = '0.000000' then emit := 'no';
                            end;
                            if emit = 'no' then begin
                                emitColor := '#000000';
                                emitMult := '0.000000';
                            end;
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['EmitEnabled'] := emit;
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['EmittanceMult'] := emitMult;
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['EmittanceColor'] := emitColor;

                            BackLightPower := shaderProp.EditValues['Backlight Power'];
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['BackLightPower'] := BackLightPower;
                            if BackLightPower = '0.000000' then BackLighting := 'no' else BackLighting := 'yes';
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['BackLighting'] := BackLighting;

                            Refraction := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\Refraction']);
                            RefractionPower := shaderProp.EditValues['Refraction Strength'];
                            if Refraction = 'no' then RefractionPower := '0.000000';
                            if RefractionPower = '0.000000' then Refraction := 'no';
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['Refraction'] := Refraction;
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['RefractionPower'] := RefractionPower;

                            SpecularEnabled := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\Specular']);
                            SpecularMult := shaderProp.EditValues['Specular Strength'];
                            SpecularColor := shaderProp.EditValues['Specular Color'];
                            if SpecularEnabled = 'no' then begin
                                SpecularMult := '0.000000';
                                SpecularColor := '#FFFFFF';
                            end;
                            if SpecularMult = '0.000000' then begin
                                SpecularColor := '#FFFFFF';
                                SpecularEnabled := 'no';
                            end;
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['SpecularEnabled'] := SpecularEnabled;
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['SpecularColor'] := SpecularColor;
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['SpecularMult'] := SpecularMult;

                            RimLighting := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\Character_Lighting']);
                            RimPower := shaderProp.EditValues['Rimlight Power'];
                            if RimLighting = 'no' then RimPower := '0.000000';
                            if RimPower = '0.000000' then RimLighting := 'no';
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['RimLighting'] := RimLighting;
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['RimPower'] := RimPower;

                            GrayscaleToPaletteColor := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\GrayscaleToPalette_Color']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['GrayscaleToPaletteColor'] := GrayscaleToPaletteColor;
                            if GrayscaleToPaletteColor = 'yes' then
                                joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['GrayscaleToPaletteScale'] := shaderProp.EditValues['Grayscale To Palette Scale']
                            else
                                joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['GrayscaleToPaletteScale'] := '0.000000';

                            EnvironmentMapping := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\Environment_Mapping']);
                            EnvironmentMappingMaskScale := shaderProp.EditValues['Environment Map Scale'];
                            if EnvironmentMapping = 'no' then EnvironmentMappingMaskScale := '0.000000';
                            if EnvironmentMappingMaskScale = '0.000000' then EnvironmentMapping := 'no';
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['EnvironmentMapping'] := EnvironmentMapping;
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['EnvironmentMappingMaskScale'] := EnvironmentMappingMaskScale;
                            
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['RootMaterialPath'] := shaderProp.EditValues['Root Material'];
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['Alpha'] := FloatToStr(StrToFloatDef(shaderProp.EditValues['Alpha'],1));
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['Smoothness'] := shaderProp.EditValues['Smoothness'];
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['SubsurfaceLightingRolloff'] := shaderProp.EditValues['Subsurface Rolloff'];
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['FresnelPower'] := shaderProp.EditValues['Fresnel Power'];
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['WetnessControl_SpecScale'] := shaderProp.EditValues['Wetness\Spec Scale'];
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['WetnessControl_SpecPowerScale'] := shaderProp.EditValues['Wetness\Spec Power'];
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['WetnessControl_SpecMinvar'] := shaderProp.EditValues['Wetness\Min Var'];
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['WetnessControl_EnvMapScale'] := shaderProp.EditValues['Wetness\Env Map Scale'];
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['WetnessControl_FresnelPower'] := shaderProp.EditValues['Wetness\Fresnel Power'];
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['WetnessControl_Metalness'] := shaderProp.EditValues['Wetness\Metalness'];
                            
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['ScreenSpaceReflections'] := IntToYesNo(shaderProp.NativeValues['Use Screen Space Reflections']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['WetnessControl_ScreenSpaceReflections'] := IntToYesNo(shaderProp.NativeValues['Wetness Control: Use SSR']);

                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['NormalTexture'] := LowerCase(wbNormalizeResourceName(Textures[1].EditValue, resTexture));
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['GlowTexture'] := LowerCase(wbNormalizeResourceName(Textures[2].EditValue, resTexture));
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['GrayscaleTexture'] := LowerCase(wbNormalizeResourceName(Textures[3].EditValue, resTexture));
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['DisplacementTexture'] := LowerCase(wbNormalizeResourceName(Textures[4].EditValue, resTexture));
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['EnvmapTexture'] := LowerCase(wbNormalizeResourceName(Textures[5].EditValue, resTexture));
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['InnerLayerTexture'] := LowerCase(wbNormalizeResourceName(Textures[6].EditValue, resTexture));
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['SmoothSpecTexture'] := LowerCase(wbNormalizeResourceName(Textures[7].EditValue, resTexture));

                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['CastShadows'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\Cast_Shadows']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['Facegen'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\Face']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['ModelSpaceNormals'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\Model_Space_Normals']);
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['Terrain'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\Landscape']);
                            
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['EnvironmentMappingEye'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\Eye_Environment_Mapping']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['DissolveFade'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\Screendoor_Alpha_Fade']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['Hair'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\Hair']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['HideSecret'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\Localmap_Hide_Secret']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['SkinTint'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\Skin_Tint']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['Tessellate'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\Tessellate']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['Decal'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\Decal']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['ExternalEmittance'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\External_Emittance']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['ZBufferTest'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 1\ZBuffer_Test']);

                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['ZBufferWrite'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 2\ZBuffer_Write']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['DecalNoFade'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 2\No_Fade']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['TwoSided'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 2\Double_Sided']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['Glowmap'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 2\Glow_Map']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AnisoLighting'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 2\Anisotropic_Lighting']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['SkewSpecularAlpha'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 2\Skew_Specular_Alpha']);
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['Tree'] := IntToYesNo(shaderProp.NativeValues['Shader Flags 2\Tree_Anim']);

                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].A['nifs'].Add(model);
                            

                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['NonOccluder'] := shaderProp.EditValues['NonOccluder'];

                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['DistanceFieldAlphaTexture'] := LowerCase(wbNormalizeResourceName(Textures[0].EditValue, resTexture));
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['FlowTexture'] := LowerCase(wbNormalizeResourceName(Textures[0].EditValue, resTexture));
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['LightingTexture'] := LowerCase(wbNormalizeResourceName(Textures[0].EditValue, resTexture));
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['SpecularTexture'] := LowerCase(wbNormalizeResourceName(Textures[0].EditValue, resTexture));
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['WrinklesTexture'] := LowerCase(wbNormalizeResourceName(Textures[0].EditValue, resTexture));

                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['DepthBias'] := shaderProp.EditValues['DepthBias'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['WriteMaskAlbedo'] := shaderProp.EditValues['WriteMaskAlbedo'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['WriteMaskAmbientOcclusion'] := shaderProp.EditValues['WriteMaskAmbientOcclusion'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['WriteMaskEmissive'] := shaderProp.EditValues['WriteMaskEmissive'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['WriteMaskGloss'] := shaderProp.EditValues['WriteMaskGloss'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['WriteMaskNormal'] := shaderProp.EditValues['WriteMaskNormal'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['WriteMaskSpecular'] := shaderProp.EditValues['WriteMaskSpecular'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['RefractionFalloff'] := shaderProp.EditValues['RefractionFalloff'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AssumeShadowmask'] := shaderProp.EditValues['AssumeShadowmask'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['CustomPorosity'] := shaderProp.EditValues['CustomPorosity'];
                            
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['EnableEditorAlphaRef'] := shaderProp.EditValues['EnableEditorAlphaRef'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['EnvironmentMappingWindow'] := shaderProp.EditValues['EnvironmentMappingWindow'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['PBR'] := shaderProp.EditValues['PBR'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['ReceiveShadows'] := shaderProp.EditValues['ReceiveShadows'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['SubsurfaceLighting'] := shaderProp.EditValues['SubsurfaceLighting'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['Translucency'] := shaderProp.EditValues['Translucency'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['TranslucencyMixAlbedoWithSubsurfaceColor'] := shaderProp.EditValues['TranslucencyMixAlbedoWithSubsurfaceColor'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['TranslucencyThickObject'] := shaderProp.EditValues['TranslucencyThickObject'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['UseAdaptativeEmissive'] := shaderProp.EditValues['UseAdaptativeEmissive'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['HairTintColor'] := shaderProp.EditValues['HairTintColor'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['TranslucencySubsurfaceColor'] := shaderProp.EditValues['TranslucencySubsurfaceColor'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AdaptativeEmissive_ExposureOffset'] := shaderProp.EditValues['AdaptativeEmissive_ExposureOffset'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AdaptativeEmissive_FinalExposureMax'] := shaderProp.EditValues['AdaptativeEmissive_FinalExposureMax'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AdaptativeEmissive_FinalExposureMin'] := shaderProp.EditValues['AdaptativeEmissive_FinalExposureMin'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['DisplacementTextureBias'] := shaderProp.EditValues['DisplacementTextureBias'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['DisplacementTextureScale'] := shaderProp.EditValues['DisplacementTextureScale'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['LumEmittance'] := shaderProp.EditValues['LumEmittance'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['PorosityValue'] := shaderProp.EditValues['PorosityValue'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['TerrainRotationAngle'] := shaderProp.EditValues['TerrainRotationAngle'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['TerrainThresholdFalloff'] := shaderProp.EditValues['TerrainThresholdFalloff'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['TerrainTilingDistance'] := shaderProp.EditValues['TerrainTilingDistance'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['TessellationBaseFactor'] := shaderProp.EditValues['TessellationBaseFactor'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['TessellationFadeDistance'] := shaderProp.EditValues['TessellationFadeDistance'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['TessellationPnScale'] := shaderProp.EditValues['TessellationPnScale'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['TranslucencyTransmissiveScale'] := shaderProp.EditValues['TranslucencyTransmissiveScale'];
                            // joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['TranslucencyTurbulence'] := shaderProp.EditValues['TranslucencyTurbulence'];
                        end;
                        mess := model + #9 + blocknamehere + '\Name: Assigned material to "';
                        
                        matPath := PickMaterial(mess, model, matSuffix, diffuse, joCustomMaterial.O[matSuffix].O[diffuse].O[count]);
                        
                        if not Assigned(matPath) then begin
                            matPath := '';
                            IsCustomMaterialUnique(joCustomMaterial.O[matSuffix].O[diffuse].O[count], matSuffix, diffuse, model, blocknamehere, matPath);
                            if matPath = '' then continue;
                        end else begin
                            IsCustomMaterialUnique(joCustomMaterial.O[matSuffix].O[diffuse].O[count], matSuffix, diffuse, model, blocknamehere, matPath);
                        end;
                        shaderProp.EditValues['Name'] := matPath;
                        bChanged := true;
                    end;
                    CheckForMaterialMismatch(shaderProp, bChanged, mat, matExt, model, blocknamehere);
                finally
                    joCustomMaterial.Free;
                end;
            end;
        finally
            if bChanged then begin
                EnsureDirectoryExists(sOutputDir + '\' + ExtractFilePath(model));
                nif.SaveToFile(sOutputDir + '\' + model);
            end;
            nif.Free;
        end;
    // except on E: Exception do slNifErrors.Add('Error reading NIF: ' + E.Message + #9 + model);
    // end;
end;

procedure CheckForMaterialMismatch(var shaderProp: TwbNifBlock; var bChanged: boolean; const mat, matExt, model, blocknamehere: string);
var
    bgsm: TwbBGSMFile;
begin
    if not ResourceExists(mat) then Exit;
    bgsm := TwbBGSMFile.Create;
    try
        if SameText(matExt, '.bgsm') then begin
            bgsm.LoadFromResource(mat);
            if ((bgsm.EditValues['Decal'] = 'yes') and (shaderProp.NativeValues['Shader Flags 1\Decal'] = 0)) then begin
                slNeedsDecalFlag.Add(model + #9 + blocknamehere + ': Added missing Decal shader flag.');
                shaderProp.NativeValues['Shader Flags 1\Decal'] := 1;
                bChanged := true;
            end;
        end;
    finally
        bgsm.Free;
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
    TrimRightChars('Example', 2) -> 'ample'
}
begin
    Result := RightStr(s, Length(s) - chars);
end;

function TrimLeftChars(s: string; chars: integer): string;
{
    Returns left string - chars
    TrimLeftChars('Example', 3) -> 'Exam'
}
begin
    Result := LeftStr(s, Length(s) - chars);
end;

function IntToYesNo(i: integer): string;
begin
    if i <> 0 then Result := 'yes' else Result := 'no';
end;

function GetIsCleanDeleted(r: IwbMainRecord): Boolean;
{
    Checks to see if a reference has an XESP set to opposite of the PlayerRef
}
begin
    Result := False;
    if not ElementExists(r, 'XESP') then Exit;
    if (GetElementNativeValues(r, 'XESP\Flags\Set Enable State to Opposite of Parent') = 0) then Exit;
    if (GetElementEditValues(r, 'XESP\Reference') <> 'PlayerRef [PLYR:00000014]') then Exit;
    Result := True;
end;

function BoolToStr(b: boolean): string;
{
    Given a boolean, return a string.
}
begin
    if b then Result := 'true' else Result := 'false';
end;

end.