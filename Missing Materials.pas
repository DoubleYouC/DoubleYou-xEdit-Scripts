{
    Check STAT for errors or possible issues.
}
unit CheckSTATs;

var
    slMissingMaterials, slNifErrors, slNeedsMaterials, slNeedsDecalFlag, slAddedMat, slTreeAnimations,
    slMaterialWarnings, slContainers, slMaterialsToVerify, slModelsToCheck, slMaterialsAdded,
    slMaterialFixes, slUsedMaterials, slAllMaterials, slUnusedMaterials, slAffectedSCOL: TStringList;

    sOutputDir, sFixedMaterialsOutput: string;
    joTextureMswpMap, joCustomMaterials, joModelRecord: TJsonObject;

const
    bSaveModels = false;
    bSaveMaterials = false;
    bSaveNewMaterials = false;
    bProcessStats = true;
    bProcessNonStats = true;

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
    slTreeAnimations := TStringList.Create;
    slTreeAnimations.Sorted := True;
    slMaterialFixes := TStringList.Create;
    slMaterialFixes.Sorted := True;
    slUsedMaterials := TStringList.Create;
    slUsedMaterials.Sorted := True;
    slAllMaterials := TStringList.Create;
    slAllMaterials.Sorted := True;
    slUnusedMaterials := TStringList.Create;
    slUnusedMaterials.Sorted := True;
    slAffectedSCOL := TStringList.Create;
    slAffectedSCOL.Sorted := True;

    joTextureMswpMap := TJsonObject.Create;
    joCustomMaterials := TJsonObject.Create;
    joModelRecord := TJsonObject.Create;
    try
        sOutputDir :=  wbScriptsPath + 'FixModels\output';
        sFixedMaterialsOutput := sOutputDir + '\FixedMaterials';

        if not FileExists(sOutputDir + '\joTextureMswpMap.json') then begin
            ResourceContainerList(slContainers);
            FilesInContainers(slContainers);
        end else begin
            joTextureMswpMap.LoadFromFile(sOutputDir + '\joTextureMswpMap.json');
        end;
        ListStringsInStringList(slMaterialWarnings);
        slMaterialWarnings.SaveToFile(sOutputDir + '\Material Warnings.txt');
        ListStringsInStringList(slMaterialFixes);
        slMissingMaterials.SaveToFile(sOutputDir + '\Material Fixes.txt');

        CollectRecords;
        // sOutputDir was created in FilesInContainers
        joModelRecord.SaveToFile(sOutputDir + '\joModelRecord.json', False, TEncoding.UTF8, True);

        CheckModels;

        ListStringsInStringList(slNifErrors);
        ListStringsInStringList(slMissingMaterials);
        slMissingMaterials.SaveToFile(sOutputDir + '\Missing Materials.txt');
        // ListStringsInStringList(slNeedsMaterials);
        ListStringsInStringList(slAddedMat);
        slAddedMat.SaveToFile(sOutputDir + '\Models Assigned Materials.txt');
        ListStringsInStringList(slNeedsDecalFlag);
        slNeedsDecalFlag.SaveToFile(sOutputDir + '\Added Decal Flag.txt');
        ListStringsInStringList(slMaterialsToVerify);
        slMaterialsToVerify.SaveToFile(sOutputDir + '\Models Assigned Materials - Verify.txt');
        ListStringsInStringList(slMaterialsAdded);
        slMaterialsAdded.SaveToFile(sOutputDir + '\Materials Added.txt');
        ListStringsInStringList(slTreeAnimations);
        slTreeAnimations.SaveToFile(sOutputDir + '\Tree Animations.txt');
        slAffectedSCOL.SaveToFile(sOutputDir + '\Affected SCOLs.txt');

        // sOutputDir was created in FilesInContainers
        joCustomMaterials.SaveToFile(sOutputDir + '\joCustomMaterials.json', False, TEncoding.UTF8, True);

        slUnusedMaterials.Assign(slAllMaterials);
        slUnusedmaterials.Difference(slUsedMaterials);
        slUnusedMaterials.SaveToFile(sOutputDir + '\Unused Materials.txt');
        slUsedMaterials.SaveToFile(sOutputDir + '\Used Materials.txt');
        slAllMaterials.SaveToFile(sOutputDir + '\All Materials.txt');
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
        joModelRecord.Free;
        slModelsToCheck.Free;
        slMaterialsAdded.Free;
        slMaterialWarnings.Free;
        slTreeAnimations.Free;
        slMaterialFixes.Free;
        slUsedMaterials.Free;
        slAllMaterials.Free;
        slUnusedMaterials.Free;
        slAffectedSCOL.Free;
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
    WetnessControl_SpecScale, WetnessControl_SpecPowerScale, WetnessControl_SpecMinvar, WetnessControl_Metalness, WetnessControl_FresnelPower, 
    GlowTexture, WetnessControl_EnvMapScale, DisplacementTexture, InnerLayerTexture, EnvmapMaskTexture, NewEnvmapTexture, RootMaterialPath: string;
    bgsm: TwbBGSMFile;
    bgem: TwbBGEMFile;
    bChanged, bEverUsesEnvironmentMapping: boolean;
begin
    slArchivedFiles := TStringList.Create;
    slArchivedFiles.Sorted := True;
    try
        for i := 0 to Pred(containers.Count) do begin
            ResourceList(containers[i], slArchivedFiles);
        end;
        for i := 0 to Pred(slArchivedFiles.Count) do begin
            bChanged := false;
            bEverUsesEnvironmentMapping := false;
            testTexture := '';
            f := slArchivedFiles[i];
            ext := ExtractFileExt(f);
            if SameText(ext, '.bgsm') then begin
                bgsm := TwbBGSMFile.Create;
                AddMessage(f);
                try
                    bgsm.LoadFromResource(f);
                    diffuse := LowerCase(wbNormalizeResourceName(bgsm.EditValues['Textures\Diffuse'], resTexture));
                    if diffuse <> '' then if not ResourceExists(diffuse) then begin
                        slMaterialWarnings.Add(f + #9 + 'Warning! Material uses a diffuse texture that does not exist:' + #9 + diffuse);
                        slMaterialFixes.Add(f + #9 + 'Textures\Diffuse was changed to blank due to missing texture' + #9 + diffuse);
                        bgsm.EditValues['Textures\Diffuse'] := '';
                        diffuse := '';
                        bChanged := true;
                    end;

                    EnvmapTexture := LowerCase(wbNormalizeResourceName(bgsm.EditValues['Textures\Envmap'], resTexture));
                    if EnvmapTexture <> '' then if not ResourceExists(EnvmapTexture) then begin
                        slMaterialWarnings.Add(f + #9 + 'Warning! Material uses a cubemap texture that does not exist:' + #9 + EnvmapTexture);
                        NewEnvmapTexture := 'textures\Shared\Cubemaps\' + ExtractFileName(f);
                        if ResourceExists(NewEnvmapTexture) then bgsm.EditValues['Textures\Envmap'] := 'Shared/Cubemaps/' + ExtractFileName(f)
                        else if ResourceExists(EnvmapTexture + '.dds') then begin
                            bgsm.EditValues['Textures\Envmap'] := bgsm.EditValues['Textures\Envmap'] + '.dds';
                            NewEnvmapTexture := EnvmapTexture + '.dds';
                        end 
                        else begin
                            NewEnvmapTexture := 'textures\Shared\Cubemaps\mipblur_DefaultOutside1.dds';
                            bgsm.EditValues['Textures\Envmap'] := 'Shared/Cubemaps/mipblur_DefaultOutside1.dds';
                        end;
                        slMaterialFixes.Add(f + #9 + 'Textures\Envmap was changed to ' + NewEnvmapTexture + ' due to missing texture' + #9 + EnvmapTexture);
                        
                        EnvmapTexture := NewEnvmapTexture;
                        bChanged := true;
                    end;
                    EnvironmentMapping := bgsm.EditValues['EnvironmentMapping'];
                    if EnvironmentMapping = 'yes' then bEverUsesEnvironmentMapping := true;
                    EnvironmentMappingMaskScale := bgsm.EditValues['EnvironmentMappingMaskScale'];
                    if (EnvmapTexture = '') and (EnvironmentMapping = 'yes') then begin
                        slMaterialWarnings.Add(f + #9 + 'Warning! Material uses environment mapping but does not have a cubemap!');
                        slMaterialFixes.Add(f + #9 + 'Textures\Envmap was changed to Shared/Cubemaps/mipblur_DefaultOutside1.dds due to no cubemap being specified.');
                        bgsm.EditValues['Textures\Envmap'] := 'Shared/Cubemaps/mipblur_DefaultOutside1.dds';
                        EnvmapTexture := 'Shared/Cubemaps/mipblur_DefaultOutside1.dds';
                        bChanged := true;
                    end;
                    if EnvmapTexture = '' then EnvironmentMapping := 'no';
                    if EnvironmentMapping = 'no' then EnvironmentMappingMaskScale := '0.000000';
                    if (EnvironmentMapping = 'yes') and (EnvironmentMappingMaskScale = '0.000000') then begin
                        slMaterialWarnings.Add(f + #9 + 'Warning! Material uses environment mapping with a scale of 0.');
                        slMaterialFixes.Add(f + #9 + 'EnvironmentMappingMaskScale was changed to 1 due to using environment mapping but scale was 0.');
                        bgsm.EditValues['EnvironmentMappingMaskScale'] := '1.000000';
                        bChanged := true;
                    end;
                    if EnvironmentMappingMaskScale = '0.000000' then EnvironmentMapping := 'no';
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['EnvironmentMappingMaskScale'] := EnvironmentMappingMaskScale;
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['EnvironmentMapping'] := EnvironmentMapping;
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['EnvironmentMappingWindow'] := bgsm.EditValues['EnvironmentMappingWindow'];
                    if bgsm.EditValues['EnvironmentMappingWindow'] = 'yes' then bEverUsesEnvironmentMapping := true;
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['EnvironmentMappingEye'] := bgsm.EditValues['EnvironmentMappingEye'];
                    if bgsm.EditValues['EnvironmentMappingEye'] = 'yes' then bEverUsesEnvironmentMapping := true;
                    if (EnvmapTexture <> '') and (not bEverUsesEnvironmentMapping) then begin
                        slMaterialWarnings.Add(f + #9 + 'Warning! Material has a cubemap but does not use environment mapping!');
                    end;
                    if (EnvmapTexture = '') and bEverUsesEnvironmentMapping then begin
                        slMaterialWarnings.Add(f + #9 + 'Warning! Material uses environment mapping but does not have a cubemap!');
                        slMaterialFixes.Add(f + #9 + 'Textures\Envmap was changed to Shared/Cubemaps/mipblur_DefaultOutside1.dds due to no cubemap being specified.');
                        bgsm.EditValues['Textures\Envmap'] := 'Shared/Cubemaps/mipblur_DefaultOutside1.dds';
                        EnvmapTexture := 'Shared/Cubemaps/mipblur_DefaultOutside1.dds';
                        bChanged := true;
                    end;

                    GrayscaleToPaletteColor := bgsm.EditValues['GrayscaleToPaletteColor'];
                    GrayscaleTexture := LowerCase(wbNormalizeResourceName(bgsm.EditValues['Textures\Grayscale'], resTexture));
                    if GrayscaleTexture <> '' then if not ResourceExists(GrayscaleTexture) then begin
                        slMaterialWarnings.Add(f + #9 + 'Warning! Material uses a grayscale texture that does not exist:' + #9 + GrayscaleTexture);
                        slMaterialFixes.Add(f + #9 + 'Textures\Grayscale was changed to blank due to missing texture' + #9 + GrayscaleTexture);
                        bgsm.EditValues['Textures\Grayscale'] := '';
                        GrayscaleTexture := '';
                        bChanged := true;
                    end;
                    GrayscaleToPaletteScale := bgsm.EditValues['GrayscaleToPaletteScale'];
                    if (GrayscaleTexture = '') and (GrayscaleToPaletteColor = 'yes') then begin
                        slMaterialWarnings.Add(f + #9 + 'Warning! Material uses grayscale to palette but does not have a palette!');
                        slMaterialFixes.Add(f + #9 + 'GrayscaleToPaletteColor was disabled due to not using a palette texture.');
                        bgsm.EditValues['GrayscaleToPaletteColor'] := 'no';
                        bChanged := true;
                    end;
                    if GrayscaleToPaletteColor = 'yes' then if GrayscaleTexture = '' then GrayscaleToPaletteColor := 'no';
                    if GrayscaleToPaletteColor = 'no' then GrayscaleToPaletteScale := '0.000000';
                    bgsm.EditValues['GrayscaleToPaletteScale'] := GrayscaleToPaletteScale;
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['GrayscaleToPaletteColor'] := GrayscaleToPaletteColor;
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['GrayscaleToPaletteScale'] := GrayscaleToPaletteScale;

                    Refraction := bgsm.EditValues['Refraction'];
                    RefractionPower := bgsm.EditValues['RefractionPower'];
                    if Refraction = 'no' then RefractionPower := '0.000000';
                    if (Refraction = 'yes') and (RefractionPower = '0.000000') then begin
                        slMaterialWarnings.Add(f + #9 + 'Warning! Material uses refraction with a scale of 0.');
                        slMaterialFixes.Add(f + #9 + 'Refraction was disabled due to it having a scale of 0.');
                        bgsm.EditValues['Refraction'] := 'no';
                        bChanged := true;
                    end;
                    if RefractionPower = '0.000000' then Refraction := 'no';
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['Refraction'] := Refraction;
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['RefractionPower'] := RefractionPower;

                    BackLighting := bgsm.EditValues['BackLighting'];
                    BackLightPower := bgsm.EditValues['BackLightPower'];
                    if BackLighting = 'no' then BackLightPower := '0.000000';
                    if (BackLighting = 'yes') and (BackLightPower = '0.000000') then begin
                        slMaterialWarnings.Add(f + #9 + 'Warning! Material uses backlighting with a scale of 0.');
                        slMaterialFixes.Add(f + #9 + 'BackLighting was disabled due to it having a scale of 0.');
                        bgsm.EditValues['BackLighting'] := 'no';
                        bChanged := true;
                    end;
                    if BackLightPower = '0.000000' then BackLighting := 'no';
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['BackLighting'] := BackLighting;
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['BackLightPower'] := BackLightPower;

                    EmitEnabled := bgsm.EditValues['EmitEnabled'];
                    EmittanceColor := bgsm.EditValues['EmittanceColor'];
                    EmittanceMult := bgsm.EditValues['EmittanceMult'];
                    if EmitEnabled = 'yes' then begin
                        if EmittanceColor = '#000000' then EmitEnabled := 'no';
                        if EmittanceMult = '0.000000' then EmitEnabled := 'no';
                        if EmitEnabled = 'no' then begin
                            slMaterialWarnings.Add(f + #9 + 'Warning! Material uses Emittance with a scale of 0 or a color of black.');
                            slMaterialFixes.Add(f + #9 + 'Emittance was disabled due to not being used.');
                            bgsm.EditValues['EmitEnabled'] := 'no';
                            bChanged := true;
                        end;
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
                    if (RimLighting = 'yes') and (RimPower = '0.000000') then begin
                        slMaterialWarnings.Add(f + #9 + 'Warning! Material uses Character Rim Lighting with a scale of 0.');
                        slMaterialFixes.Add(f + #9 + 'Character Rim Lighting was disabled due to not being used.');
                        bgsm.EditValues['RimLighting'] := 'no';
                        bChanged := true;
                    end;
                    if RimPower = '0.000000' then RimLighting := 'no';
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['RimLighting'] := bgsm.EditValues['RimLighting'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['RimPower'] := bgsm.EditValues['RimPower'];

                    SpecularEnabled := bgsm.EditValues['SpecularEnabled'];
                    SpecularColor := bgsm.EditValues['SpecularColor'];
                    SpecularMult := bgsm.EditValues['SpecularMult'];
                    SmoothSpecTexture := LowerCase(wbNormalizeResourceName(bgsm.EditValues['Textures\SmoothSpec'], resTexture));
                    if (SmoothSpecTexture <> '') and (not SameText(RightStr(SmoothSpecTexture, 6), '_s.dds')) then slMaterialWarnings.Add(f + #9 + 'Warning! Material has a specular texture that does not use the _s suffix:' + #9 + SmoothSpecTexture);
                    
                    if SmoothSpecTexture <> '' then if not ResourceExists(SmoothSpecTexture) then begin
                        slMaterialWarnings.Add(f + #9 + 'Warning! Material uses a specular texture that does not exist:' + #9 + SmoothSpecTexture);
                        if SameText(RightStr(diffuse, 6), '_d.dds') then testTexture := TrimLeftChars(diffuse, 6) + '_s.dds';
                        if ResourceExists(testTexture) then begin
                            slMaterialFixes.Add(f + #9 + 'Textures\SmoothSpec was changed to ' + testTexture + ' due to missing texture' + #9 + SmoothSpecTexture);
                            SmoothSpecTexture := testTexture;
                            bgsm.EditValues['Textures\SmoothSpec'] := TrimRightChars(testTexture, 9);
                        end 
                        else if (SpecularEnabled = 'yes') then begin
                            slMaterialFixes.Add(f + #9 + 'Textures\SmoothSpec was changed from ' + SmoothSpecTexture + ' due to the texture not existing.' + #9 + 'textures\shared\blue_d.dds');
                            SmoothSpecTexture := 'textures\shared\blue_d.dds';
                            bgsm.EditValues['Textures\SmoothSpec'] := 'Shared/Blue_d.dds';
                        end 
                        else begin
                            slMaterialFixes.Add(f + #9 + 'Textures\SmoothSpec was changed to blank due to missing texture' + #9 + SmoothSpecTexture);
                            SmoothSpecTexture := '';
                            bgsm.EditValues['Textures\SmoothSpec'] := '';
                        end;
                        bChanged := true;
                    end;
                    if (SmoothSpecTexture = '') and (SpecularEnabled = 'yes') then begin
                        slMaterialWarnings.Add(f + #9 + 'Warning! Material uses specular but does not have a specular texture!');
                        if SameText(RightStr(diffuse, 6), '_d.dds') then testTexture := TrimLeftChars(diffuse, 6) + '_s.dds';
                        if ResourceExists(testTexture) then begin
                            slMaterialFixes.Add(f + #9 + 'Textures\SmoothSpec was added due to using specular but not using its existing specular map.' + #9 + testTexture);
                            SmoothSpecTexture := testTexture;
                            bgsm.EditValues['Textures\SmoothSpec'] := TrimRightChars(testTexture, 9);
                        end 
                        else begin
                            slMaterialFixes.Add(f + #9 + 'Textures\SmoothSpec was added due to using specular but not using a specular map.' + #9 + 'textures\shared\blue_d.dds');
                            SmoothSpecTexture := 'textures\shared\blue_d.dds';
                            bgsm.EditValues['Textures\SmoothSpec'] := 'Shared/Blue_d.dds';
                        end;
                        bChanged := true;
                    end;
                    if (SmoothSpecTexture = '') and (SpecularEnabled = 'no') then begin
                        if SameText(RightStr(diffuse, 6), '_d.dds') then testTexture := TrimLeftChars(diffuse, 6) + '_s.dds';
                        if ResourceExists(testTexture) then begin
                            slMaterialWarnings.Add(f + #9 + 'Warning! Material does not use its existing specular texture:' + #9 + testTexture);
                            slMaterialFixes.Add(f + #9 + 'Textures\SmoothSpec was added to use its existing specular map.' + #9 + testTexture);
                            SmoothSpecTexture := testTexture;
                            bgsm.EditValues['Textures\SmoothSpec'] := TrimRightChars(testTexture, 9);
                            slMaterialFixes.Add(f + #9 + 'SpecularEnabled was enabled to make use of its existing specular map.');
                            SpecularEnabled := 'yes';
                            bgsm.EditValues['SpecularEnabled'] := 'yes';
                            bChanged := true;
                        end;
                    end;
                    if (SmoothSpecTexture <> '') and (SpecularEnabled = 'no') then begin
                        slMaterialWarnings.Add(f + #9 + 'Warning! Material has a specular texture but does not use specular!');
                        if SameText(RightStr(SmoothSpecTexture, 6), '_s.dds') then begin
                            slMaterialFixes.Add(f + #9 + 'SpecularEnabled was enabled due to material specifying a specular texture but not enabling specular.');
                            SpecularEnabled := 'yes';
                            bgsm.EditValues['SpecularEnabled'] := 'yes';
                            bChanged := true;
                        end;
                    end;
                    if SpecularEnabled = 'yes' then begin
                        // if SpecularColor = '#000000' then SpecularEnabled := 'no';
                        if SpecularMult = '0.000000' then begin                            
                            slMaterialWarnings.Add(f + #9 + 'Warning! Material uses specular with a scale of 0.');
                            slMaterialFixes.Add(f + #9 + 'SpecularMult was set to 1 due to using specular with a scale of 0.');
                            SpecularMult := '1.000000';
                            bgsm.EditValues['SpecularMult'] := SpecularMult;
                            bChanged := true;
                        end;
                    end;
                    if SpecularEnabled = 'no' then begin
                        SpecularColor := '#000000';
                        SpecularMult := '0.000000';
                    end;
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['SpecularEnabled'] := SpecularEnabled;
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['SpecularColor'] := SpecularColor;
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['SpecularMult'] := SpecularMult;
                    
                    

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

                    RootMaterialPath := wbNormalizeResourceName(bgsm.EditValues['RootMaterialPath'], resMaterial);
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['RootMaterialPath'] := bgsm.EditValues['RootMaterialPath'];
                    if RootMaterialPath <> '' then if not ResourceExists(RootMaterialPath) then begin
                        slMaterialWarnings.Add(f + #9 + 'Warning! Material specifies a root material path that does not exist!' + #9 + RootMaterialPath);
                        slMaterialFixes.Add(f + #9 + 'RootMaterialPath was set to blank due to specifying a non-existent material.' + #9 + RootMaterialPath);
                        joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['RootMaterialPath'] := '';
                        bgsm.EditValues['RootMaterialPath'] := '';
                        bChanged := true;
                    end;
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['DissolveFade'] := bgsm.EditValues['DissolveFade'];

                    //no nif equivalent it would seem
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['NonOccluder'] := bgsm.EditValues['NonOccluder'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['SubsurfaceLighting'] := bgsm.EditValues['SubsurfaceLighting'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['HairTintColor'] := bgsm.EditValues['HairTintColor'];

                    //textures
                    NormalTexture := LowerCase(wbNormalizeResourceName(bgsm.EditValues['Textures\Normal'], resTexture));
                    if NormalTexture <> '' then if not ResourceExists(NormalTexture) then begin
                        slMaterialWarnings.Add(f + #9 + 'Warning! Material uses a normal texture that does not exist:' + #9 + NormalTexture);
                        if SameText(RightStr(diffuse, 6), '_d.dds') then testTexture := TrimLeftChars(diffuse, 6) + '_n.dds';
                        if ResourceExists(testTexture) then begin
                            slMaterialFixes.Add(f + #9 + 'Textures\Normal was changed from ' + NormalTexture + ' due to the texture not existing.' + #9 + testTexture);
                            NormalTexture := testTexture;
                            bgsm.EditValues['Textures\Normal'] := TrimRightChars(testTexture, 9);
                        end 
                        else begin
                            slMaterialFixes.Add(f + #9 + 'Textures\Normal was changed to textures\shared\FlatFlat_n.dds due to missing texture' + #9 + NormalTexture);
                            SmoothSpecTexture := 'textures\shared\FlatFlat_n.dds';
                            bgsm.EditValues['Textures\Normal'] := 'Shared/FlatFlat_n.dds';
                        end;
                        bChanged := true;
                    end;
                    if NormalTexture = '' then begin
                        if SameText(RightStr(diffuse, 6), '_d.dds') then testTexture := TrimLeftChars(diffuse, 6) + '_n.dds';
                        if ResourceExists(testTexture) then begin
                            slMaterialWarnings.Add(f + #9 + 'Warning! Material does not use its existing normal texture:' + #9 + testTexture);
                            slMaterialFixes.Add(f + #9 + 'Textures\Normal was added to use its existing normal texture.' + #9 + testTexture);
                            NormalTexture := testTexture;
                            bgsm.EditValues['Textures\Normal'] := TrimRightChars(testTexture, 9);
                            bChanged := true;
                        end;
                    end;
                    if (NormalTexture <> '') and (NormalTexture <> 'textures\effects\colornormalspecutility.dds') and (not SameText(RightStr(NormalTexture, 6), '_n.dds'))
                    then slMaterialWarnings.Add(f + #9 + 'Warning! Material has a normal texture that does not use the _n suffix:' + #9 + NormalTexture);
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['NormalTexture'] := NormalTexture;
                    
                    
                    GlowTexture := LowerCase(wbNormalizeResourceName(bgsm.EditValues['Textures\Glow'], resTexture));
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['GlowTexture'] := GlowTexture;
                    if GlowTexture <> '' then if not ResourceExists(GlowTexture) then slMaterialWarnings.Add(f + #9 + 'Warning! Material uses a glowmap texture that does not exist:' + #9 + GlowTexture);
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['GrayscaleTexture'] := GrayscaleTexture;
                    DisplacementTexture := LowerCase(wbNormalizeResourceName(bgsm.EditValues['Textures\Displacement'], resTexture));
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['DisplacementTexture'] := DisplacementTexture;
                    if DisplacementTexture <> '' then if not ResourceExists(DisplacementTexture) then slMaterialWarnings.Add(f + #9 + 'Warning! Material uses a displacement texture that does not exist:' + #9 + DisplacementTexture);
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['EnvmapTexture'] := EnvmapTexture;
                    InnerLayerTexture := LowerCase(wbNormalizeResourceName(bgsm.EditValues['Textures\InnerLayer'], resTexture));
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['InnerLayerTexture'] := InnerLayerTexture;
                    if InnerLayerTexture <> '' then if not ResourceExists(InnerLayerTexture) then slMaterialWarnings.Add(f + #9 + 'Warning! Material uses a inner layer texture that does not exist:' + #9 + InnerLayerTexture);
                    
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
                    if bChanged and bSaveMaterials then begin
                        EnsureDirectoryExists(sFixedMaterialsOutput + '\' + ExtractFilePath(f));
                        bgsm.SaveToFile(sFixedMaterialsOutput + '\' + f);
                    end;
                    bgsm.Free;
                end;
            end else if SameText(ext, '.bgem') then begin
                bgem := TwbBGEMFile.Create;
                AddMessage(f);
                try
                    bgem.LoadFromResource(f);
                    diffuse := LowerCase(wbNormalizeResourceName(bgem.EditValues['Textures\Base'], resTexture));
                    if diffuse <> '' then if not ResourceExists(diffuse) then slMaterialWarnings.Add(f + #9 + 'Warning! Material uses a diffuse texture that does not exist:' + #9 + diffuse);
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
                    if EnvmapTexture <> '' then if not ResourceExists(EnvmapTexture) then slMaterialWarnings.Add(f + #9 + 'Warning! Material uses a cubemap texture that does not exist:' + #9 + EnvmapTexture);
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

                    EnvmapMaskTexture := LowerCase(wbNormalizeResourceName(bgem.EditValues['Textures\EnvmapMask'], resTexture));
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['EnvmapMaskTexture'] := EnvmapMaskTexture;
                    if EnvmapMaskTexture <> '' then if not ResourceExists(EnvmapMaskTexture) then slMaterialWarnings.Add(f + #9 + 'Warning! Material uses a environment mapping mask texture that does not exist:' + #9 + EnvmapMaskTexture);
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['EnvmapTexture'] := EnvmapTexture;
                    GrayscaleTexture := LowerCase(wbNormalizeResourceName(bgem.EditValues['Textures\Grayscale'], resTexture));
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['GrayscaleTexture'] := GrayscaleTexture;
                    if GrayscaleTexture <> '' then if not ResourceExists(GrayscaleTexture) then slMaterialWarnings.Add(f + #9 + 'Warning! Material uses a grayscale texture that does not exist:' + #9 + GrayscaleTexture);
                    NormalTexture := LowerCase(wbNormalizeResourceName(bgem.EditValues['Textures\Normal'], resTexture));
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['NormalTexture'] := NormalTexture;
                    if NormalTexture <> '' then if not ResourceExists(NormalTexture) then slMaterialWarnings.Add(f + #9 + 'Warning! Material uses a normal texture that does not exist:' + #9 + NormalTexture);

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
                    if bChanged and bSaveMaterials then begin
                        EnsureDirectoryExists(sFixedMaterialsOutput + '\' + ExtractFilePath(f));
                        bgem.SaveToFile(sFixedMaterialsOutput + '\' + f);
                    end;
                    bgem.Free;
                end;
            end else continue;
            slAllMaterials.Add(LowerCase(f));
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
    if not bSaveNewMaterials then Exit;
    if joCustomMaterial.S['DoNotCreateMaterial'] = 'yes' then Exit;
    if shader = 'bgsm' then begin
        bgsm := TwbBGSMFile.Create;
        try
            bgsm.LoadFromResource('materials\default.bgsm');
            mat := DiffuseToMaterial(diffuse, shader);
            if not Assigned(mat) then Exit;
            bgsm.EditValues['Textures\Diffuse'] := TrimRightChars(diffuse, 9);
            bgsm.EditValues['ReceiveShadows'] := 'no';
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
                    bgsm.EditValues['Textures\Normal'] := TrimRightChars(joCustomMaterial.S[key], 9);
                end else if key = 'GlowTexture' then begin
                    bgsm.EditValues['Textures\Glow'] := TrimRightChars(joCustomMaterial.S[key], 9);
                end else if key = 'GrayscaleTexture' then begin
                    bgsm.EditValues['Textures\Grayscale'] := TrimRightChars(joCustomMaterial.S[key], 9);
                end else if key = 'DisplacementTexture' then begin
                    bgsm.EditValues['Textures\Displacement'] := TrimRightChars(joCustomMaterial.S[key], 9);
                end else if key = 'EnvmapTexture' then begin
                    bgsm.EditValues['Textures\Envmap'] := TrimRightChars(joCustomMaterial.S[key], 9);
                end else if key = 'InnerLayerTexture' then begin
                    bgsm.EditValues['Textures\InnerLayer'] := TrimRightChars(joCustomMaterial.S[key], 9);
                end else if key = 'SmoothSpecTexture' then begin
                    bgsm.EditValues['Textures\SmoothSpec'] := TrimRightChars(joCustomMaterial.S[key], 9);
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

            bgem.EditValues['Textures\Base'] := TrimRightChars(diffuse, 9);
            for i := 0 to Pred(joCustomMaterial.Count) do begin
                key := joCustomMaterial.Names[i];
                if key = 'NormalTexture' then begin
                    bgem.EditValues['Textures\Normal'] := TrimRightChars(joCustomMaterial.S[key], 9);
                end else if key = 'GrayscaleTexture' then begin
                    bgem.EditValues['Textures\Grayscale'] := TrimRightChars(joCustomMaterial.S[key], 9);
                end else if key = 'EnvmapTexture' then begin
                    bgem.EditValues['Textures\Envmap'] := TrimRightChars(joCustomMaterial.S[key], 9);
                end else if key = 'EnvmapMaskTexture' then begin
                    bgem.EditValues['Textures\EnvmapMask'] := TrimRightChars(joCustomMaterial.S[key], 9);
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
    matHere := matBase + '.' + shader;
    if (not ResourceExists(matHere)) then if (not FileExists(sOutputDir + '\' + matHere)) then
        Result := matHere
    else begin
        for i:=1 to 20 do begin
            matHere := matBase + '_' + IntToStr(i) + '.' + shader;
            if (not ResourceExists(matHere)) then if (not FileExists(sOutputDir + '\' + matHere)) then begin
                Result := matHere;
                break;
            end;
        end;
    end;
end;

procedure CollectRecords;
{
    Collect records.
}
var
    i, j: integer;
    f: IwbFile;
    g: IwbGroupRecord;
    r: IwbMainRecord;
    model: string;
begin
    for i := 0 to Pred(FileCount) do begin
        f := FileByIndex(i);

        if bProcessStats then CheckGroup(f, 'STAT', true);
        if not bProcessNonStats then continue;
        CheckGroup(f, 'ACTI', true);
        CheckGroup(f, 'ADDN', false);
        CheckGroup(f, 'AMMO', false);
        CheckGroup(f, 'ANIO', false);
        CheckGroup(f, 'ARTO', false);
        CheckGroup(f, 'BOOK', false);
        CheckGroup(f, 'CONT', true);
        CheckGroup(f, 'DOOR', true);
        CheckGroup(f, 'EXPL', false);
        CheckGroup(f, 'FLOR', true);
        CheckGroup(f, 'FURN', true);
        CheckGroup(f, 'GRAS', false);
        CheckGroup(f, 'HAZD', false);
        CheckGroup(f, 'HDPT', false);
        CheckGroup(f, 'IPCT', false);
        CheckGroup(f, 'ALCH', false);
        CheckGroup(f, 'KEYM', false);
        CheckGroup(f, 'LIGH', false);
        CheckGroup(f, 'MISC', true);
        CheckGroup(f, 'MSTT', true);
        CheckGroup(f, 'NOTE', false);
        CheckGroup(f, 'OMOD', false);
        CheckGroup(f, 'PROJ', false);
        CheckGroup(f, 'TERM', false);
        CheckGroup(f, 'WEAP', false);
        CheckGroup(f, 'MSTT', false);

        g := GroupBySignature(f, 'ARMA');
        for j := 0 to Pred(ElementCount(g)) do begin
            r := ElementByIndex(g, j);
            if not IsWinningOverride(r) then continue;

            model := wbNormalizeResourceName(GetElementEditValues(r, 'Biped Model\Male\MOD2'), resMesh);
            CheckModel(r, model, 'ARMA', false);
            model := wbNormalizeResourceName(GetElementEditValues(r, 'Biped Model\Female\MOD3'), resMesh);
            CheckModel(r, model, 'ARMA', false);
            model := wbNormalizeResourceName(GetElementEditValues(r, '1st Person\Male\MOD4'), resMesh);
            CheckModel(r, model, 'ARMA', false);
            model := wbNormalizeResourceName(GetElementEditValues(r, '1st Person\Female\MOD5'), resMesh);
            CheckModel(r, model, 'ARMA', false);
        end;
    end;
end;

procedure CheckModel(const r: IwbMainRecord; const model, sig: string; const bCheckRefs: boolean);
var
    bEverUsed: boolean;
begin
    if model = '' then Exit;
    bEverUsed := false;
    if not ResourceExists(model) then begin
        AddMessage('Warning: Record references a model that does not seem to exist: ' + ShortName(r) + #9 + model);
        Exit;
    end;
    if bCheckRefs then begin
        if not (ReferencedByCount(r) > 0) then Exit;
        bEverUsed := IsEverUsed(r, model, sig);
        if not bEverUsed then Exit;
    end;
    //NifNeedsMaterial(model);
    slModelsToCheck.Add(model);
    joModelRecord.O[model].A['records'].Add(ShortName(r));
    if bEverUsed then joModelRecord.O[model].S['Used'] := true;
end;

procedure CheckGroup(const f: IwbFile; const sig: string; const bCheckRefs: boolean);
var
    j: integer;
    model: string;
    g: IwbGroupRecord;
    r: IwbMainRecord;
begin
    g := GroupBySignature(f, sig);
    for j := 0 to Pred(ElementCount(g)) do begin
        r := ElementByIndex(g, j);
        if not IsWinningOverride(r) then continue;
        AddMessage(ShortName(r));
        model := LowerCase(wbNormalizeResourceName(GetElementEditValues(r, 'Model\MODL'), resMesh));

        CheckModel(r, model, sig, bCheckRefs);
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

function IsEverUsed(const s: IwbMainRecord; const model, sig: string): boolean;
var
    i: integer;
    r: IwbMainRecord;
    bIsSCOLEverUsed: boolean;
    rSig: string;
begin
    Result := false;
    for i := Pred(ReferencedByCount(s)) downto 0 do begin
        r := ReferencedByIndex(s, i);
        rSig := Signature(r);
        if SameText(rSig, 'SCOL') then begin
            AddMessage(ShortName(r));
            bIsSCOLEverUsed := IsEverUsed(r, model, rSig);
            if not bIsSCOLEverUsed then continue;
            Result := true;
            joModelRecord.O[model].A['SCOL'].Add(RecordFormIdFileId(r));
            joModelRecord.O[model].S['bSCOL'] := '1';
        end;
        if Signature(r) <> 'REFR' then continue;
        if not IsWinningOverride(r) then continue;
        if GetIsDeleted(r) then continue;
        if GetIsCleanDeleted(r) then continue;
        //if not IsRefPrecombined(r) then continue;
        Result := true;
        //break;
        if sig <> 'STAT' then break;
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
            else if (key = 'Tree') and (y = 'yes') then score := -100
            else if (key = 'UOffset') then score := -100
            else if (key = 'VOffset') then score := -100
            else if (key = 'Alpha') then score := -100
            else if (key = 'UScale') then score := -100
            else if (key = 'VScale') then score := -100
            else if (key = 'AlphaTest') then score := -100
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
    //AddMessage(mess + Result + '"'+ #9 + 'Match Score: ' + IntToStr(bestScore) + '/' + IntToStr(total));
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
    i, count, NiAlphaPropFlags, s: integer;
    mat, matExt, blockName, diffuse, matPath, matSuffix, mess, emit, emitColor, 
    BackLighting, uv, blocknamehere, clampMode, emitMult, BackLightPower, RefractionPower,
    GrayscaleToPaletteColor, RimPower, RimLighting, SpecularEnabled, SpecularMult, SpecularColor, Refraction,
    FalloffEnabled, SoftEnabled, EnvironmentMapping, EnvironmentMappingMaskScale: string;
    bBlockMissingMat, bChanged, bHasShaderProperty, bHasAlpha, bHasTreeAnimations, bTree, bHasVertexColors: boolean;

    tsUV: TStrings;
    nif: TwbNifFile;
    block, rootBlock, TextureSet, NiAlphaProp, controllerLink, prop, shaderProp: TwbNifBlock;
    Textures, TextureSetEle, AlphaPropEle, ShaderPropEle, controller: TdfElement;
    joCustomMaterial: TJsonObject;
begin
    Result := False;
    bChanged := False;
    bHasTreeAnimations := False;
    bTree := False;
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
                bHasVertexColors := false;
                diffuse := '';
                block := nif.Blocks[i];
                if i = 0 then rootBlock := block;

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

                //Block has a shader property
                blockName := block.EditValues['Name'];
                blocknamehere := IntToStr(i) + ' ' + block.BlockType + '\' + shaderProp.BlockType;

                //Get Material
                mat := wbNormalizeResourceName(shaderProp.EditValues['Name'], resMaterial);
                matExt := ExtractFileExt(mat);
                

                //Check for if the block uses vertex colors
                if (block.EditValues['VertexDesc\VF\VF_COLORS'] = '1') then bHasVertexColors := True;

                //AddMessage(model + #9 + blocknamehere);
                joCustomMaterial := TJsonObject.Create;
                try
                    if (not (SameText(matExt, '.' + matSuffix))) or (not ResourceExists(mat)) then begin
                        //Material does not exist
                        slNeedsMaterials.Add('Model may need a ' + shaderProp.BlockType + ' material: ' + #9 + model + #9 + blockName);
                        bBlockMissingMat := True;
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

                                    if NiAlphaPropFlags = 4333 then begin
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Standard';
                                    end
                                    else if NiAlphaPropFlags = 4844 then begin
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaTest'] := 'yes';
                                    end
                                    else if NiAlphaPropFlags = 4845 then begin
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaTest'] := 'yes';
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Additive';
                                    end
                                    else if NiAlphaPropFlags = 4137 then begin
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Multiplicative';
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaTest'] := 'yes';
                                    end
                                    else if NiAlphaPropFlags = 37101 then begin
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Standard';
                                    end
                                    else if NiAlphaPropFlags = 37612 then begin
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaTest'] := 'yes';
                                    end
                                    else if NiAlphaPropFlags = 37613 then begin
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaTest'] := 'yes';
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Additive';
                                    end
                                    else if NiAlphaPropFlags = 36905 then begin
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaTest'] := 'yes';
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Multiplicative';
                                    end else begin
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['DoNotCreateMaterial'] := 'yes';
                                    end;

                                    // //Alpha Blending 4333
                                    // if (NiAlphaPropFlags and 1) <> 0 then
                                    //     joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Standard';
                                    
                                    // //Alpha Testing 4844
                                    // if (NiAlphaPropFlags and 2) <> 0 then
                                    //     joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaTest'] := 'yes';

                                    // //Alpha Blending and Testing Additive 4845
                                    // if ((NiAlphaPropFlags and 1) <> 0) and ((NiAlphaPropFlags and 2) <> 0) then
                                    //     joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Additive';

                                    // //Alpha Blending Multiplicative 4137
                                    // //Alpha Blending    Source Blend Mode: Dst Color    Alpha Test Function: Greater
                                    // if ((NiAlphaPropFlags and 1) <> 0) and ((NiAlphaPropFlags and 8) <> 0) and ((NiAlphaPropFlags and 4096) <> 0) then
                                    //     joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Multiplicative';

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
                            diffuse := LowerCase(wbNormalizeResourceName(Textures[0].EditValue, resTexture));
                            if diffuse = '' then continue;
                            controller := shaderProp.Elements['Controller'];
                            if Assigned(controller) then begin
                                controllerLink := controller.LinksTo;
                                if Assigned(controllerLink) then continue;
                            end;
                            if not ResourceExists(diffuse) then continue;

                            count := joCustomMaterials.O[matSuffix].O[diffuse].Count + 1;

                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Unknown';
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaTest'] := 'no';
                            if bHasAlpha then begin
                                if Assigned(NiAlphaProp) then begin
                                    NiAlphaPropFlags := NiAlphaProp.NativeValues['Flags'];

                                    if NiAlphaPropFlags = 4333 then begin
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Standard';
                                    end
                                    else if NiAlphaPropFlags = 4844 then begin
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaTest'] := 'yes';
                                    end
                                    else if NiAlphaPropFlags = 4845 then begin
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaTest'] := 'yes';
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Additive';
                                    end
                                    else if NiAlphaPropFlags = 4137 then begin
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Multiplicative';
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaTest'] := 'yes';
                                    end
                                    else if NiAlphaPropFlags = 37101 then begin
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Standard';
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['EnableEditorAlphaRef'] := 'yes';
                                    end
                                    else if NiAlphaPropFlags = 37612 then begin
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaTest'] := 'yes';
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['EnableEditorAlphaRef'] := 'yes';
                                    end
                                    else if NiAlphaPropFlags = 37613 then begin
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaTest'] := 'yes';
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Additive';
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['EnableEditorAlphaRef'] := 'yes';
                                    end
                                    else if NiAlphaPropFlags = 36905 then begin
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaTest'] := 'yes';
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Multiplicative';
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['EnableEditorAlphaRef'] := 'yes';
                                    end else begin
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['DoNotCreateMaterial'] := 'yes';
                                        joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['EnableEditorAlphaRef'] := 'yes';
                                    end;

                                    // //Alpha Blending 4333
                                    // if (NiAlphaPropFlags and 1) <> 0 then
                                    //     joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Standard';
                                    
                                    // //Alpha Testing 4844
                                    // if (NiAlphaPropFlags and 2) <> 0 then
                                    //     joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaTest'] := 'yes';

                                    // //Alpha Blending and Testing Additive 4845
                                    // if ((NiAlphaPropFlags and 1) <> 0) and ((NiAlphaPropFlags and 2) <> 0) then
                                    //     joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Additive';

                                    // //Alpha Blending Multiplicative 4137
                                    // //Alpha Blending    Source Blend Mode: Dst Color    Alpha Test Function: Greater
                                    // if ((NiAlphaPropFlags and 1) <> 0) and ((NiAlphaPropFlags and 8) <> 0) and ((NiAlphaPropFlags and 4096) <> 0) then
                                    //     joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['AlphaBlendMode'] := 'Multiplicative';

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
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['EnvmapTexture'] := LowerCase(wbNormalizeResourceName(Textures[4].EditValue, resTexture));
                            joCustomMaterial.O[matSuffix].O[diffuse].O[count].S['DisplacementTexture'] := LowerCase(wbNormalizeResourceName(Textures[5].EditValue, resTexture));
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
                            if shaderProp.EditValues['Shader Flags 2\Tree_Anim'] = '1' then bHasTreeAnimations := True;

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
                            slAddedMat.Add(mess + matPath + '"');
                        end else begin
                            IsCustomMaterialUnique(joCustomMaterial.O[matSuffix].O[diffuse].O[count], matSuffix, diffuse, model, blocknamehere, matPath);
                            bHasTreeAnimations := DoesMatHaveTreeAnimations(matPath);
                        end;
                        shaderProp.EditValues['Name'] := matPath;
                        mat := matPath;
                        bChanged := true;
                    end else begin
                        //material exists
                        slUsedMaterials.Add(LowerCase(mat));
                        bHasTreeAnimations := DoesMatHaveTreeAnimations(mat);
                    end;
                    if bHasTreeAnimations then begin
                        //If the shader specifies tree animations, check for vertex colors and BSLeafAnimNode
                        if (bHasTreeAnimations and not bHasVertexColors) then begin
                            slTreeAnimations.Add(model + #9 + blocknamehere + #9 + 'WARNING! Trishape has tree animations but no vertex colors.');
                        end else if (bHasTreeAnimations and not bTree) then bTree := True;
                    end;
                    CheckForMaterialMismatch(shaderProp, bChanged, mat, matExt, model, blocknamehere);
                finally
                    joCustomMaterial.Free;
                end;
            end;
            if bTree and SameText(rootBlock.BlockType, 'NiNode') then begin
                nif.ConvertBlock(0, 'BSLeafAnimNode');
                bChanged := True;
                blockName := block.EditValues['Name'];
                slTreeAnimations.Add(model + #9 + '0 NiNode\' + blockName + ' was converted to BSLeafAnimNode.');
            end;
        finally
            if bChanged and bSaveModels then begin
                EnsureDirectoryExists(sOutputDir + '\' + ExtractFilePath(model));
                nif.SaveToFile(sOutputDir + '\' + model);
                Result := True;
                if joModelRecord.O[model].S['bSCOL'] = '1' then begin
                    for s := 0 to Pred(joModelRecord.O[model].A['SCOL'].Count) do begin
                        slAffectedSCOL.Add(joModelRecord.O[model].A['SCOL'].S[s]);
                    end;
                end;
            end;
            nif.Free;
        end;
    // except on E: Exception do slNifErrors.Add('Error reading NIF: ' + E.Message + #9 + model);
    // end;
end;

procedure CheckForMaterialMismatch(var shaderProp: TwbNifBlock; var bChanged: boolean; const mat, matExt, model, blocknamehere: string);
{
    Fix Shader flags that need to be set the same as the material.
}
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

function DoesMatHaveTreeAnimations(mat: string): boolean;
{
    Checks a material to see if Tree flag is enabled.
}
var
    bgsm: TwbBGSMFile;
begin
    Result := False;
    if ExtractFileExt(mat) <> 'bgsm' then Exit;
    bgsm := TwbBGSMFile.Create;
    try
        bgsm.LoadFromResource(mat);
        if SameText(bgsm.EditValues['Tree'], 'yes') then Result := True;
    finally
        bgsm.free;
    end;
end;

function RecordFormIdFileId(e: IwbMainRecord): string;
{
    Returns the record ID of an element.
}
begin
    e := MasterOrSelf(e);
    Result := IntToHex(FormID(e), 8) + ':' + GetFileName(GetFile(e));
end;

function GetRecordFromFormIdFileId(recordId: string): IwbMainRecord;
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
{
    Turns an integer into a yes/no based on if it is 0 or not.
}
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