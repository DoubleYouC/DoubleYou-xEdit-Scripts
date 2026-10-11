{
    Check STAT for errors or possible issues.
}
unit CheckSTATs;

var
    slMissingMaterials, slNifErrors, slNeedsMaterials, slNeedsDecalFlag, slAddedMat, slContainers, slMaterialsToVerify: TStringList;
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

    joTextureMswpMap := TJsonObject.Create;
    joCustomMaterials := TJsonObject.Create;
    try
        sOutputDir :=  wbScriptsPath + 'FixModels\output';
        ResourceContainerList(slContainers);
        FilesInContainers(slContainers);
        CollectRecords;
        ListStringsInStringList(slNifErrors);
        ListStringsInStringList(slMissingMaterials);
        ListStringsInStringList(slNeedsMaterials);
        ListStringsInStringList(slAddedMat);
        ListStringsInStringList(slNeedsDecalFlag);
        ListStringsInStringList(slMaterialsToVerify);

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
    end;
end;

procedure FilesInContainers(containers: TStringList);
{
    Retrieves the files.
}
var
    slArchivedFiles: TStringList;
    i: integer;
    f, ext, diffuse: string;
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
                try
                    bgsm.LoadFromResource(f);
                    diffuse := LowerCase(wbNormalizeResourceName(bgsm.EditValues['Textures\Diffuse'], resTexture));
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['AlphaTest'] := bgsm.EditValues['AlphaTest'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['Decal'] := bgsm.EditValues['Decal'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['DecalNoFade'] := bgsm.EditValues['DecalNoFade'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['EnvironmentMapping'] := bgsm.EditValues['EnvironmentMapping'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['GrayscaleToPaletteColor'] := bgsm.EditValues['GrayscaleToPaletteColor'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['Refraction'] := bgsm.EditValues['Refraction'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['ScreenSpaceReflections'] := bgsm.EditValues['ScreenSpaceReflections'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TileU'] := bgsm.EditValues['TileU'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TileV'] := bgsm.EditValues['TileV'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TwoSided'] := bgsm.EditValues['TwoSided'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WetnessControl_ScreenSpaceReflections'] := bgsm.EditValues['WetnessControl_ScreenSpaceReflections'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['ZBufferTest'] := bgsm.EditValues['ZBufferTest'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['ZBufferWrite'] := bgsm.EditValues['ZBufferWrite'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['AlphaBlendMode'] := bgsm.EditValues['AlphaBlendMode'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['Alpha'] := bgsm.EditValues['Alpha'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['AlphaTestRef'] := bgsm.EditValues['AlphaTestRef'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['EnvironmentMappingMaskScale'] := bgsm.EditValues['EnvironmentMappingMaskScale'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['RefractionPower'] := bgsm.EditValues['RefractionPower'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['UOffset'] := bgsm.EditValues['UOffset'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['UScale'] := bgsm.EditValues['UScale'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['VOffset'] := bgsm.EditValues['VOffset'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['VScale'] := bgsm.EditValues['VScale'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['AnisoLighting'] := bgsm.EditValues['AnisoLighting'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['BackLighting'] := bgsm.EditValues['BackLighting'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['CastShadows'] := bgsm.EditValues['CastShadows'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['EmitEnabled'] := bgsm.EditValues['EmitEnabled'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['EnvironmentMappingEye'] := bgsm.EditValues['EnvironmentMappingEye'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['ExternalEmittance'] := bgsm.EditValues['ExternalEmittance'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['Facegen'] := bgsm.EditValues['Facegen'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['Glowmap'] := bgsm.EditValues['Glowmap'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['Hair'] := bgsm.EditValues['Hair'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['HideSecret'] := bgsm.EditValues['HideSecret'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['ModelSpaceNormals'] := bgsm.EditValues['ModelSpaceNormals'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['RimLighting'] := bgsm.EditValues['RimLighting'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['SkewSpecularAlpha'] := bgsm.EditValues['SkewSpecularAlpha'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['SkinTint'] := bgsm.EditValues['SkinTint'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['SpecularEnabled'] := bgsm.EditValues['SpecularEnabled'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['Terrain'] := bgsm.EditValues['Terrain'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['Tessellate'] := bgsm.EditValues['Tessellate'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['Tree'] := bgsm.EditValues['Tree'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['EmittanceColor'] := bgsm.EditValues['EmittanceColor'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['SpecularColor'] := bgsm.EditValues['SpecularColor'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['BackLightPower'] := bgsm.EditValues['BackLightPower'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['EmittanceMult'] := bgsm.EditValues['EmittanceMult'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['FresnelPower'] := bgsm.EditValues['FresnelPower'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['GrayscaleToPaletteScale'] := bgsm.EditValues['GrayscaleToPaletteScale'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['RimPower'] := bgsm.EditValues['RimPower'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['Smoothness'] := bgsm.EditValues['Smoothness'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['SpecularMult'] := bgsm.EditValues['SpecularMult'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['SubsurfaceLightingRolloff'] := bgsm.EditValues['SubsurfaceLightingRolloff'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WetnessControl_EnvMapScale'] := bgsm.EditValues['WetnessControl_EnvMapScale'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WetnessControl_FresnelPower'] := bgsm.EditValues['WetnessControl_FresnelPower'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WetnessControl_Metalness'] := bgsm.EditValues['WetnessControl_Metalness'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WetnessControl_SpecMinvar'] := bgsm.EditValues['WetnessControl_SpecMinvar'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WetnessControl_SpecPowerScale'] := bgsm.EditValues['WetnessControl_SpecPowerScale'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WetnessControl_SpecScale'] := bgsm.EditValues['WetnessControl_SpecScale'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['RootMaterialPath'] := bgsm.EditValues['RootMaterialPath'];

                    //no nif equivalent it would seem
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['NonOccluder'] := bgsm.EditValues['NonOccluder'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['SubsurfaceLighting'] := bgsm.EditValues['SubsurfaceLighting'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['HairTintColor'] := bgsm.EditValues['HairTintColor'];

                    //textures
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['NormalTexture'] := LowerCase(wbNormalizeResourceName(bgsm.EditValues['NormalTexture'], resTexture));
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['GlowTexture'] := LowerCase(wbNormalizeResourceName(bgsm.EditValues['GlowTexture'], resTexture));
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['GreyscaleTexture'] := LowerCase(wbNormalizeResourceName(bgsm.EditValues['GreyscaleTexture'], resTexture));
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['DisplacementTexture'] := LowerCase(wbNormalizeResourceName(bgsm.EditValues['DisplacementTexture'], resTexture));
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['EnvmapTexture'] := LowerCase(wbNormalizeResourceName(bgsm.EditValues['EnvmapTexture'], resTexture));
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['InnerLayerTexture'] := LowerCase(wbNormalizeResourceName(bgsm.EditValues['InnerLayerTexture'], resTexture));
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['SmoothSpecTexture'] := LowerCase(wbNormalizeResourceName(bgsm.EditValues['SmoothSpecTexture'], resTexture));

                    //perhaps unused
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['SpecularTexture'] := LowerCase(wbNormalizeResourceName(bgsm.EditValues['SpecularTexture'], resTexture));
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['DistanceFieldAlphaTexture'] := LowerCase(wbNormalizeResourceName(bgsm.EditValues['DistanceFieldAlphaTexture'], resTexture));
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['FlowTexture'] := LowerCase(wbNormalizeResourceName(bgsm.EditValues['FlowTexture'], resTexture));
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['LightingTexture'] := LowerCase(wbNormalizeResourceName(bgsm.EditValues['LightingTexture'], resTexture));
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WrinklesTexture'] := LowerCase(wbNormalizeResourceName(bgsm.EditValues['WrinklesTexture'], resTexture));
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['DepthBias'] := bgsm.EditValues['DepthBias'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WriteMaskAlbedo'] := bgsm.EditValues['WriteMaskAlbedo'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WriteMaskAmbientOcclusion'] := bgsm.EditValues['WriteMaskAmbientOcclusion'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WriteMaskEmissive'] := bgsm.EditValues['WriteMaskEmissive'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WriteMaskGloss'] := bgsm.EditValues['WriteMaskGloss'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WriteMaskNormal'] := bgsm.EditValues['WriteMaskNormal'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['WriteMaskSpecular'] := bgsm.EditValues['WriteMaskSpecular'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['RefractionFalloff'] := bgsm.EditValues['RefractionFalloff'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['AssumeShadowmask'] := bgsm.EditValues['AssumeShadowmask'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['CustomPorosity'] := bgsm.EditValues['CustomPorosity'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['DissolveFade'] := bgsm.EditValues['DissolveFade'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['EnableEditorAlphaRef'] := bgsm.EditValues['EnableEditorAlphaRef'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['EnvironmentMappingWindow'] := bgsm.EditValues['EnvironmentMappingWindow'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['PBR'] := bgsm.EditValues['PBR'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['ReceiveShadows'] := bgsm.EditValues['ReceiveShadows'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['Translucency'] := bgsm.EditValues['Translucency'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TranslucencyMixAlbedoWithSubsurfaceColor'] := bgsm.EditValues['TranslucencyMixAlbedoWithSubsurfaceColor'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TranslucencyThickObject'] := bgsm.EditValues['TranslucencyThickObject'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TranslucencySubsurfaceColor'] := bgsm.EditValues['TranslucencySubsurfaceColor'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['UseAdaptativeEmissive'] := bgsm.EditValues['UseAdaptativeEmissive'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['AdaptativeEmissive_ExposureOffset'] := bgsm.EditValues['AdaptativeEmissive_ExposureOffset'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['AdaptativeEmissive_FinalExposureMax'] := bgsm.EditValues['AdaptativeEmissive_FinalExposureMax'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['AdaptativeEmissive_FinalExposureMin'] := bgsm.EditValues['AdaptativeEmissive_FinalExposureMin'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['DisplacementTextureBias'] := bgsm.EditValues['DisplacementTextureBias'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['DisplacementTextureScale'] := bgsm.EditValues['DisplacementTextureScale'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['LumEmittance'] := bgsm.EditValues['LumEmittance'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['PorosityValue'] := bgsm.EditValues['PorosityValue'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TerrainRotationAngle'] := bgsm.EditValues['TerrainRotationAngle'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TerrainThresholdFalloff'] := bgsm.EditValues['TerrainThresholdFalloff'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TerrainTilingDistance'] := bgsm.EditValues['TerrainTilingDistance'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TessellationBaseFactor'] := bgsm.EditValues['TessellationBaseFactor'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TessellationFadeDistance'] := bgsm.EditValues['TessellationFadeDistance'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TessellationPnScale'] := bgsm.EditValues['TessellationPnScale'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TranslucencyTransmissiveScale'] := bgsm.EditValues['TranslucencyTransmissiveScale'];
                    joTextureMswpMap.O['bgsm'].O[diffuse].O[f].S['TranslucencyTurbulence'] := bgsm.EditValues['TranslucencyTurbulence'];
                finally
                    bgsm.Free;
                end;
            end else if SameText(ext, '.bgem') then begin
                bgem := TwbBGEMFile.Create;
                try
                    bgem.LoadFromResource(f);
                    diffuse := LowerCase(wbNormalizeResourceName(bgem.EditValues['Textures\Base'], resTexture));
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['AlphaTest'] := bgem.EditValues['AlphaTest'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['Decal'] := bgem.EditValues['Decal'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['DecalNoFade'] := bgem.EditValues['DecalNoFade'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['EnvironmentMapping'] := bgem.EditValues['EnvironmentMapping'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['GrayscaleToPaletteColor'] := bgem.EditValues['GrayscaleToPaletteColor'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['Refraction'] := bgem.EditValues['Refraction'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['TileU'] := bgem.EditValues['TileU'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['TileV'] := bgem.EditValues['TileV'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['TwoSided'] := bgem.EditValues['TwoSided'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['ZBufferTest'] := bgem.EditValues['ZBufferTest'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['ZBufferWrite'] := bgem.EditValues['ZBufferWrite'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['AlphaBlendMode'] := bgem.EditValues['AlphaBlendMode'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['AlphaTestRef'] := bgem.EditValues['AlphaTestRef'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['EnvironmentMappingMaskScale'] := bgem.EditValues['EnvironmentMappingMaskScale'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['UOffset'] := bgem.EditValues['UOffset'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['UScale'] := bgem.EditValues['UScale'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['VOffset'] := bgem.EditValues['VOffset'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['VScale'] := bgem.EditValues['VScale'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['EffectLightingEnabled'] := bgem.EditValues['EffectLightingEnabled'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['FalloffColorEnabled'] := bgem.EditValues['FalloffColorEnabled'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['FalloffEnabled'] := bgem.EditValues['FalloffEnabled'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['Glowmap'] := bgem.EditValues['Glowmap'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['GrayscaleToPaletteAlpha'] := bgem.EditValues['GrayscaleToPaletteAlpha'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['SoftEnabled'] := bgem.EditValues['SoftEnabled'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['BaseColor'] := bgem.EditValues['BaseColor'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['BaseColorScale'] := bgem.EditValues['BaseColorScale'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['FalloffStartAngle'] := bgem.EditValues['FalloffStartAngle'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['FalloffStartOpacity'] := bgem.EditValues['FalloffStartOpacity'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['FalloffStopAngle'] := bgem.EditValues['FalloffStopAngle'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['FalloffStopOpacity'] := bgem.EditValues['FalloffStopOpacity'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['LightingInfluence'] := bgem.EditValues['LightingInfluence'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['SoftDepth'] := bgem.EditValues['SoftDepth'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['EnvmapMinLOD'] := bgem.EditValues['EnvmapMinLOD'];

                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['EnvmapMaskTexture'] := LowerCase(wbNormalizeResourceName(bgem.EditValues['EnvmapMaskTexture'], resTexture));
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['EnvmapTexture'] := LowerCase(wbNormalizeResourceName(bgem.EditValues['EnvmapTexture'], resTexture));
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['GrayscaleTexture'] := LowerCase(wbNormalizeResourceName(bgem.EditValues['GrayscaleTexture'], resTexture));
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['NormalTexture'] := LowerCase(wbNormalizeResourceName(bgem.EditValues['NormalTexture'], resTexture));

                    //no nif equivalent it would seem
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['NonOccluder'] := bgem.EditValues['NonOccluder'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['ScreenSpaceReflections'] := bgem.EditValues['ScreenSpaceReflections'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['WetnessControl_ScreenSpaceReflections'] := bgem.EditValues['WetnessControl_ScreenSpaceReflections'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['Alpha'] := bgem.EditValues['Alpha'];

                    //perhaps unused
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['DepthBias'] := bgem.EditValues['DepthBias'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['WriteMaskAlbedo'] := bgem.EditValues['WriteMaskAlbedo'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['WriteMaskAmbientOcclusion'] := bgem.EditValues['WriteMaskAmbientOcclusion'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['WriteMaskEmissive'] := bgem.EditValues['WriteMaskEmissive'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['WriteMaskGloss'] := bgem.EditValues['WriteMaskGloss'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['WriteMaskNormal'] := bgem.EditValues['WriteMaskNormal'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['WriteMaskSpecular'] := bgem.EditValues['WriteMaskSpecular'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['RefractionFalloff'] := bgem.EditValues['RefractionFalloff'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['RefractionPower'] := bgem.EditValues['RefractionPower'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['BloodEnabled'] := bgem.EditValues['BloodEnabled'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['EffectPbrSpecular'] := bgem.EditValues['EffectPbrSpecular'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['GlassEnabled'] := bgem.EditValues['GlassEnabled'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['EmittanceColor'] := bgem.EditValues['EmittanceColor'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['GlassFresnelColor'] := bgem.EditValues['GlassFresnelColor'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['AdaptativeEmissive_ExposureOffset'] := bgem.EditValues['AdaptativeEmissive_ExposureOffset'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['AdaptativeEmissive_FinalExposureMax'] := bgem.EditValues['AdaptativeEmissive_FinalExposureMax'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['AdaptativeEmissive_FinalExposureMin'] := bgem.EditValues['AdaptativeEmissive_FinalExposureMin'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['GlassBlurScaleBase'] := bgem.EditValues['GlassBlurScaleBase'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['GlassBlurScaleFactor'] := bgem.EditValues['GlassBlurScaleFactor'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['GlassRefractionScaleBase'] := bgem.EditValues['GlassRefractionScaleBase'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['GlassDirtOverlay'] := bgem.EditValues['GlassDirtOverlay'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['GlassRoughnessScratch'] := bgem.EditValues['GlassRoughnessScratch'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['GlowTexture'] := bgem.EditValues['GlowTexture'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['LightingTexture'] := bgem.EditValues['LightingTexture'];
                    joTextureMswpMap.O['bgem'].O[diffuse].O[f].S['SpecularTexture'] := bgem.EditValues['SpecularTexture'];
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
            if not IsEverPrecombined(r) then continue;
            NifNeedsMaterial(model, r);
        end;
    end;
end;

function IsEverPrecombined(s: IwbMainRecord): boolean;
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
    j, m, count, score, bestScore: integer;
    mat, key: string;
    joBestMatch: TJsonObject;
begin
    Result := nil;
    if not joTextureMswpMap.O[matType].Contains(diffuse) then Exit;
    count := joTextureMswpMap.O[matType].O[diffuse].Count;

    bestScore := 0;
    for m := 0 to Pred(count) do begin
        score := 0
        mat := joTextureMswpMap.O[matType].O[diffuse].Names[m];
        for j := 0 to Pred(joCustomMaterial.Count) do begin
            key := joCustomMaterial.Names[j];
            if key = 'nifs' then continue;
            if SameText(joTextureMswpMap.O[matType].O[diffuse].S[key], joCustomMaterial.S[key])
            then score := score + 1;
        end;
        if score > bestScore then begin
            bestScore := score;
            Result := mat;
        end;
    end;

    if count > 1 then slMaterialsToVerify.Add(mess + mat + '"');
end;

procedure IsCustomMaterialUnique(joCustomMaterial: TJsonObject; shader, diffuse, model: string);
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
            if not SameText(joCustomMaterials.O[shader].O[diffuse].O[i].S[key], joCustomMaterial.S[key])
            then materialsMatch := false;
        end;
        if materialsMatch then break;
    end;
    if materialsMatch then begin
        joCustomMaterials.O[shader].O[diffuse].O[i].A['nifs'].Add(model);
    end else begin
        joCustomMaterials.O[shader].O[diffuse].O[count + 1].Assign(joCustomMaterial);
    end;
end;

function NifNeedsMaterial(model: string; stat: IwbElement): boolean;
var
    i, count, NiAlphaPropFlags: integer;
    mat, matExt, blockName, diffuse, matPath, matSuffix, mess, clampMode, emit, emitColor, BackLightPower, BackLighting: string;
    bBlockMissingMat, bChanged: boolean;

    nif: TwbNifFile;
    block, TextureSet, NiAlphaProp: TwbNifBlock;
    bgsm: TwbBGSMFile;
    Textures, TextureSetEle, AlphaPropEle: TdfElement;
    joCustomMaterial: TJsonObject;
begin
    Result := False;
    bChanged := False;
    //try
        nif := TwbNifFile.Create;
        bgsm := TwbBGSMFile.Create;
        try
            nif.LoadFromResource(model);
            for i := 0 to Pred(nif.BlocksCount) do begin
                block := nif.Blocks[i];
                if ((block.BlockType = 'BSTrishape') or (block.BlockType = 'BSMeshLODTriShape')) then blockName := block.EditValues['Name'];
                if not ((block.BlockType = 'BSLightingShaderProperty') or (block.BlockType = 'BSEffectShaderProperty')) then continue;
                mat := wbNormalizeResourceName(block.EditValues['Name'], resMaterial);
                matExt := ExtractFileExt(mat);
                joCustomMaterial := TJsonObject.Create;
                try
                    if not (SameText(matExt, '.bgsm') or SameText(matExt, '.bgem')) then begin
                        slNeedsMaterials.Add('Model may need a ' + block.BlockType + ' material: ' + #9 + ShortName(stat) + #9 + model + #9 + blockName);
                        bBlockMissingMat := True;
                        Result := True;
                        if (block.BlockType = 'BSEffectShaderProperty') then begin
                            matSuffix := 'bgem';
                            diffuse := LowerCase(wbNormalizeResourceName(block.EditValues['Source Texture'], resTexture));
                            if diffuse = '' then continue;
                            count := joCustomMaterials.O['bgem'].O[diffuse].Count + 1;

                            AlphaPropEle := nif.Blocks[i - 1].Elements['Alpha Property'];
                            if Assigned(AlphaPropEle) then begin
                                NiAlphaProp := AlphaPropEle.LinksTo;
                                if Assigned(NiAlphaProp) then begin
                                    alpha := 'yes';
                                    NiAlphaPropFlags := NiAlphaProp.NativeValues['Flags'];
                                    //Alpha Blending
                                    if (NiAlphaPropFlags and 1) <> 0 then
                                        joCustomMaterial.O['bgem'].O[diffuse].O[count].S['AlphaBlendMode'] := 'Standard';
                                    else
                                        joCustomMaterial.O['bgem'].O[diffuse].O[count].S['AlphaBlendMode'] := 'Unknown';
                                    
                                    //Alpha Testing
                                    if (NiAlphaPropFlags and 2) <> 0 then
                                        joCustomMaterial.O['bgem'].O[diffuse].O[count].S['AlphaTest'] := 'yes';
                                    else
                                        joCustomMaterial.O['bgem'].O[diffuse].O[count].S['AlphaTest'] := 'no';

                                    joCustomMaterial.O['bgem'].O[diffuse].O[count].S['AlphaTestRef'] := NiAlphaProp.EditValues['Threshold'];
                                end;
                            end;

                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['UOffset'] := FloatToStr(StrToFloatDef(SplitString(block.EditValues['UV Offset'], ' ')[0], 0));
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['VOffset'] := FloatToStr(StrToFloatDef(SplitString(block.EditValues['UV Offset'], ' ')[1], 0));
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['UScale'] := FloatToStr(StrToFloatDef(SplitString(block.EditValues['UV Scale'], ' ')[0], 1));
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['VScale'] := FloatToStr(StrToFloatDef(SplitString(block.EditValues['UV Scale'], ' ')[1], 1));
                            
                            clampMode := block.EditValues['Texture Clamp Mode'];
                            if ContainsText(clampMode, 'WRAP_S') then
                                joCustomMaterial.O['bgem'].O[diffuse].O[count].S['TileU'] := 'yes';
                            else joCustomMaterial.O['bgem'].O[diffuse].O[count].S['TileU'] := 'no';
                            if ContainsText(clampMode, 'WRAP_T') then
                                joCustomMaterial.O['bgem'].O[diffuse].O[count].S['TileV'] := 'yes';
                            else joCustomMaterial.O['bgem'].O[diffuse].O[count].S['TileV'] := 'no';

                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['BaseColor'] := block.EditValues['Base Color'];

                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['LightingInfluence'] := block.EditValues['Lighting Influence'];
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['EnvmapMinLOD'] := block.EditValues['Env Map Min LOD'];
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['FalloffStartAngle'] := block.EditValues['Falloff Start Angle'];
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['FalloffStopAngle'] := block.EditValues['Falloff Stop Angle'];
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['FalloffStartOpacity'] := block.EditValues['Falloff Start Opacity'];
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['FalloffStopOpacity'] := block.EditValues['Falloff Stop Opacity'];
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['BaseColorScale'] := block.EditValues['Base Color Scale'];
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['SoftDepth'] := block.EditValues['Soft Falloff Depth'];
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['GrayscaleTexture'] := block.EditValues['Greyscale Texture'];
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['EnvmapTexture'] := block.EditValues['Env Map Texture'];
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['NormalTexture'] := block.EditValues['Normal Texture'];
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['EnvmapMaskTexture'] := block.EditValues['Env Mask Texture'];
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['EnvironmentMappingMaskScale'] := block.EditValues['Environment Map Scale'];

                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['GrayscaleToPaletteColor'] := IntToYesNo(block.NativeValues['Shader Flags 1\GreyscaleToPalette_Color']);
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['GrayscaleToPaletteAlpha'] := IntToYesNo(block.NativeValues['Shader Flags 1\GreyscaleToPalette_Alpha']);
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['FalloffEnabled'] := IntToYesNo(block.NativeValues['Shader Flags 1\Use_Falloff']);
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['EnvironmentMapping'] := IntToYesNo(block.NativeValues['Shader Flags 1\Environment_Mapping']);
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['FalloffColorEnabled'] := IntToYesNo(block.NativeValues['Shader Flags 1\RGB_Falloff']);
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['Refraction'] := IntToYesNo(block.NativeValues['Shader Flags 1\Refraction']);
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['Decal'] := IntToYesNo(block.NativeValues['Shader Flags 1\Decal']);
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['SoftEnabled'] := IntToYesNo(block.NativeValues['Shader Flags 1\Soft_Effect']);
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['ZBufferTest'] := IntToYesNo(block.NativeValues['Shader Flags 1\ZBuffer_Test']);

                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['ZBufferWrite'] := IntToYesNo(block.NativeValues['Shader Flags 2\ZBuffer_Write']);
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['DecalNoFade'] := IntToYesNo(block.NativeValues['Shader Flags 2\No_Fade']);
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['TwoSided'] :=IntToYesNo(block.NativeValues['Shader Flags 2\Double_Sided']);
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['Glowmap'] := IntToYesNo(block.NativeValues['Shader Flags 2\Glow_Map']);
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].S['EffectLightingEnabled'] := IntToYesNo(block.NativeValues['Shader Flags 2\Effect_Lighting']);
                            joCustomMaterial.O['bgem'].O[diffuse].O[count].A['nifs'].Add(model);
                            IsCustomMaterialUnique(joCustomMaterial.O['bgem'].O[diffuse].O[count], matSuffix, diffuse, model);


                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['DepthBias'] := block.EditValues['DepthBias'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['NonOccluder'] := block.EditValues['NonOccluder'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['ScreenSpaceReflections'] := block.EditValues['ScreenSpaceReflections'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['WetnessControl_ScreenSpaceReflections'] := block.EditValues['WetnessControl_ScreenSpaceReflections'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['WriteMaskAlbedo'] := block.EditValues['WriteMaskAlbedo'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['WriteMaskAmbientOcclusion'] := block.EditValues['WriteMaskAmbientOcclusion'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['WriteMaskEmissive'] := block.EditValues['WriteMaskEmissive'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['WriteMaskGloss'] := block.EditValues['WriteMaskGloss'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['WriteMaskNormal'] := block.EditValues['WriteMaskNormal'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['WriteMaskSpecular'] := block.EditValues['WriteMaskSpecular'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['Alpha'] := block.EditValues['Alpha'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['RefractionFalloff'] := block.EditValues['RefractionFalloff'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['RefractionPower'] := block.EditValues['RefractionPower'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['BloodEnabled'] := block.EditValues['BloodEnabled'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['EffectPbrSpecular'] := block.EditValues['EffectPbrSpecular'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['GlassEnabled'] := block.EditValues['GlassEnabled'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['EmittanceColor'] := block.EditValues['EmittanceColor'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['GlassFresnelColor'] := block.EditValues['GlassFresnelColor'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['AdaptativeEmissive_ExposureOffset'] := block.EditValues['AdaptativeEmissive_ExposureOffset'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['AdaptativeEmissive_FinalExposureMax'] := block.EditValues['AdaptativeEmissive_FinalExposureMax'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['AdaptativeEmissive_FinalExposureMin'] := block.EditValues['AdaptativeEmissive_FinalExposureMin'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['GlassBlurScaleBase'] := block.EditValues['GlassBlurScaleBase'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['GlassBlurScaleFactor'] := block.EditValues['GlassBlurScaleFactor'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['GlassRefractionScaleBase'] := block.EditValues['GlassRefractionScaleBase'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['GlassDirtOverlay'] := block.EditValues['GlassDirtOverlay'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['GlassRoughnessScratch'] := block.EditValues['GlassRoughnessScratch'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['GlowTexture'] := block.EditValues['GlowTexture'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['LightingTexture'] := block.EditValues['LightingTexture'];
                            // joCustomMaterial.O['bgem'].O[diffuse].O[count].S['SpecularTexture'] := block.EditValues['SpecularTexture'];
                        end else begin
                            matSuffix := 'bgsm';
                            TextureSetEle := block.Elements['Texture Set'];
                            if not Assigned(TextureSetEle) then continue;
                            TextureSet := TextureSetEle.LinksTo;
                            if not Assigned(TextureSet) then continue;
                            Textures := TextureSet.Elements['Textures'];
                            diffuse := LowerCase(wbNormalizeResourceName(Textures[0].EditValue, resTexture));
                            if diffuse = '' then continue;

                            count := joCustomMaterials.O['bgsm'].O[diffuse].Count + 1;

                            AlphaPropEle := nif.Blocks[i - 1].Elements['Alpha Property'];
                            if Assigned(AlphaPropEle) then begin
                                NiAlphaProp := AlphaPropEle.LinksTo;
                                if Assigned(NiAlphaProp) then begin
                                    alpha := 'yes';
                                    NiAlphaPropFlags := NiAlphaProp.NativeValues['Flags'];
                                    //Alpha Blending
                                    if (NiAlphaPropFlags and 1) <> 0 then
                                        joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['AlphaBlendMode'] := 'Standard';
                                    else
                                        joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['AlphaBlendMode'] := 'Unknown';
                                    
                                    //Alpha Testing
                                    if (NiAlphaPropFlags and 2) <> 0 then
                                        joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['AlphaTest'] := 'yes';
                                    else
                                        joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['AlphaTest'] := 'no';

                                    joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['AlphaTestRef'] := NiAlphaProp.EditValues['Threshold'];
                                end;
                            end;

                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['UOffset'] := FloatToStr(StrToFloatDef(SplitString(block.EditValues['UV Offset'], ' ')[0], 0));
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['VOffset'] := FloatToStr(StrToFloatDef(SplitString(block.EditValues['UV Offset'], ' ')[1], 0));
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['UScale'] := FloatToStr(StrToFloatDef(SplitString(block.EditValues['UV Scale'], ' ')[0], 1));
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['VScale'] := FloatToStr(StrToFloatDef(SplitString(block.EditValues['UV Scale'], ' ')[1], 1));
                            
                            clampMode := block.EditValues['Texture Clamp Mode'];
                            if ContainsText(clampMode, 'WRAP_S') then
                                joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['TileU'] := 'yes';
                            else joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['TileU'] := 'no';
                            if ContainsText(clampMode, 'WRAP_T') then
                                joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['TileV'] := 'yes';
                            else joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['TileV'] := 'no';

                            emitColor := block.EditValues['Emissive Color'];
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['EmittanceColor'] := emitColor;
                            emitMult := block.NativeValues['Emissive Multiple'];
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['EmittanceMult'] := emitMult;
                            emit := IntToYesNo(block.NativeValues['Shader Flags 1\Own_Emit']);
                            // if emit = 'yes' then begin
                            //     if emitColor = '#000000' then emit := 'no';
                            //     if emitMult = 0 then emit := 'no';
                            // end;
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['EmitEnabled'] := emit;
                            
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['RootMaterialPath'] := block.EditValues['Root Material'];
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['Alpha'] := block.EditValues['Alpha'];
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['RefractionPower'] := block.EditValues['Refraction Strength'];
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['Smoothness'] := block.EditValues['Smoothness'];
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['SpecularColor'] := block.EditValues['Specular Color'];
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['SpecularMult'] := block.EditValues['Specular Strength'];
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['SubsurfaceLightingRolloff'] := block.EditValues['Subsurface Rolloff'];
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['RimPower'] := block.EditValues['Rimlight Power'];
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['RimLighting'] := IntToYesNo(block.NativeValues['Shader Flags 1\Character_Lighting']);
                            BackLightPower := block.NativeValues['Backlight Power'];
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['BackLightPower'] := BackLightPower;
                            if BackLightPower > 0 then BackLighting := 'yes' else BackLighting := 'no';
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['BackLighting'] := BackLighting;
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['GrayscaleToPaletteScale'] := block.EditValues['Grayscale To Palette Scale'];
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['FresnelPower'] := block.EditValues['Fresnel Power'];
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['WetnessControl_SpecScale'] := block.EditValues['Wetness\Spec Scale'];
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['WetnessControl_SpecPowerScale'] := block.EditValues['Wetness\Spec Power'];
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['WetnessControl_SpecMinvar'] := block.EditValues['Wetness\Min Var'];
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['WetnessControl_EnvMapScale'] := block.EditValues['Wetness\Env Map Scale'];
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['WetnessControl_FresnelPower'] := block.EditValues['Wetness\Fresnel Power'];
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['WetnessControl_Metalness'] := block.EditValues['Wetness\Metalness'];
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['EnvironmentMappingMaskScale'] := block.EditValues['Environment Map Scale'];
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['ScreenSpaceReflections'] := IntToYesNo(block.NativeValues['Use Screen Space Reflections']);
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['WetnessControl_ScreenSpaceReflections'] := IntToYesNo(block.NativeValues['Wetness Control: Use SSR']);

                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['NormalTexture'] := LowerCase(wbNormalizeResourceName(Textures[1].EditValue, resTexture));
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['GlowTexture'] := LowerCase(wbNormalizeResourceName(Textures[2].EditValue, resTexture));
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['GreyscaleTexture'] := LowerCase(wbNormalizeResourceName(Textures[3].EditValue, resTexture));
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['DisplacementTexture'] := LowerCase(wbNormalizeResourceName(Textures[4].EditValue, resTexture));
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['EnvmapTexture'] := LowerCase(wbNormalizeResourceName(Textures[5].EditValue, resTexture));
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['InnerLayerTexture'] := LowerCase(wbNormalizeResourceName(Textures[6].EditValue, resTexture));
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['SmoothSpecTexture'] := LowerCase(wbNormalizeResourceName(Textures[7].EditValue, resTexture));
                            
                            
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['SpecularEnabled'] := IntToYesNo(block.NativeValues['Shader Flags 1\Specular']);
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['GrayscaleToPaletteColor'] := IntToYesNo(block.NativeValues['Shader Flags 1\GreyscaleToPalette_Color']);
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['EnvironmentMapping'] := IntToYesNo(block.NativeValues['Shader Flags 1\Environment_Mapping']);
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['CastShadows'] := IntToYesNo(block.NativeValues['Shader Flags 1\Cast_Shadows']);
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['Facegen'] := IntToYesNo(block.NativeValues['Shader Flags 1\Face']);
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['ModelSpaceNormals'] := IntToYesNo(block.NativeValues['Shader Flags 1\Model_Space_Normals']);
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['Terrain'] := IntToYesNo(block.NativeValues['Shader Flags 1\Landscape']);
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['Refraction'] := IntToYesNo(block.NativeValues['Shader Flags 1\Refraction']);
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['EnvironmentMappingEye'] := IntToYesNo(block.NativeValues['Shader Flags 1\Eye_Environment_Mapping']);
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['Hair'] := IntToYesNo(block.NativeValues['Shader Flags 1\Hair']);
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['HideSecret'] := IntToYesNo(block.NativeValues['Shader Flags 1\Localmap_Hide_Secret']);
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['SkinTint'] := IntToYesNo(block.NativeValues['Shader Flags 1\Skin_Tint']);
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['Tessellate'] := IntToYesNo(block.NativeValues['Shader Flags 1\Tessellate']);
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['Decal'] := IntToYesNo(block.NativeValues['Shader Flags 1\Decal']);
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['ExternalEmittance'] := IntToYesNo(block.NativeValues['Shader Flags 1\External_Emittance']);
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['ZBufferTest'] := IntToYesNo(block.NativeValues['Shader Flags 1\ZBuffer_Test']);

                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['ZBufferWrite'] := IntToYesNo(block.NativeValues['Shader Flags 2\ZBuffer_Write']);
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['DecalNoFade'] := IntToYesNo(block.NativeValues['Shader Flags 2\No_Fade']);
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['TwoSided'] := IntToYesNo(block.NativeValues['Shader Flags 2\Double_Sided']);
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['Glowmap'] := IntToYesNo(block.NativeValues['Shader Flags 2\Glow_Map']);
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['AnisoLighting'] := IntToYesNo(block.NativeValues['Shader Flags 2\Anisotropic_Lighting']);
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['SkewSpecularAlpha'] := IntToYesNo(block.NativeValues['Shader Flags 2\Skew_Specular_Alpha']);
                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['Tree'] := IntToYesNo(block.NativeValues['Shader Flags 2\Tree_Anim']);

                            joCustomMaterial.O['bgsm'].O[diffuse].O[count].A['nifs'].Add(model);
                            IsCustomMaterialUnique(joCustomMaterial.O['bgsm'].O[diffuse].O[count], matSuffix, diffuse, model);

                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['NonOccluder'] := block.EditValues['NonOccluder'];

                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['DistanceFieldAlphaTexture'] := LowerCase(wbNormalizeResourceName(Textures[0].EditValue, resTexture));
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['FlowTexture'] := LowerCase(wbNormalizeResourceName(Textures[0].EditValue, resTexture));
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['LightingTexture'] := LowerCase(wbNormalizeResourceName(Textures[0].EditValue, resTexture));
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['SpecularTexture'] := LowerCase(wbNormalizeResourceName(Textures[0].EditValue, resTexture));
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['WrinklesTexture'] := LowerCase(wbNormalizeResourceName(Textures[0].EditValue, resTexture));

                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['DepthBias'] := block.EditValues['DepthBias'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['WriteMaskAlbedo'] := block.EditValues['WriteMaskAlbedo'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['WriteMaskAmbientOcclusion'] := block.EditValues['WriteMaskAmbientOcclusion'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['WriteMaskEmissive'] := block.EditValues['WriteMaskEmissive'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['WriteMaskGloss'] := block.EditValues['WriteMaskGloss'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['WriteMaskNormal'] := block.EditValues['WriteMaskNormal'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['WriteMaskSpecular'] := block.EditValues['WriteMaskSpecular'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['RefractionFalloff'] := block.EditValues['RefractionFalloff'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['AssumeShadowmask'] := block.EditValues['AssumeShadowmask'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['CustomPorosity'] := block.EditValues['CustomPorosity'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['DissolveFade'] := block.EditValues['DissolveFade'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['EnableEditorAlphaRef'] := block.EditValues['EnableEditorAlphaRef'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['EnvironmentMappingWindow'] := block.EditValues['EnvironmentMappingWindow'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['PBR'] := block.EditValues['PBR'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['ReceiveShadows'] := block.EditValues['ReceiveShadows'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['SubsurfaceLighting'] := block.EditValues['SubsurfaceLighting'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['Translucency'] := block.EditValues['Translucency'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['TranslucencyMixAlbedoWithSubsurfaceColor'] := block.EditValues['TranslucencyMixAlbedoWithSubsurfaceColor'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['TranslucencyThickObject'] := block.EditValues['TranslucencyThickObject'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['UseAdaptativeEmissive'] := block.EditValues['UseAdaptativeEmissive'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['HairTintColor'] := block.EditValues['HairTintColor'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['TranslucencySubsurfaceColor'] := block.EditValues['TranslucencySubsurfaceColor'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['AdaptativeEmissive_ExposureOffset'] := block.EditValues['AdaptativeEmissive_ExposureOffset'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['AdaptativeEmissive_FinalExposureMax'] := block.EditValues['AdaptativeEmissive_FinalExposureMax'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['AdaptativeEmissive_FinalExposureMin'] := block.EditValues['AdaptativeEmissive_FinalExposureMin'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['DisplacementTextureBias'] := block.EditValues['DisplacementTextureBias'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['DisplacementTextureScale'] := block.EditValues['DisplacementTextureScale'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['LumEmittance'] := block.EditValues['LumEmittance'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['PorosityValue'] := block.EditValues['PorosityValue'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['TerrainRotationAngle'] := block.EditValues['TerrainRotationAngle'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['TerrainThresholdFalloff'] := block.EditValues['TerrainThresholdFalloff'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['TerrainTilingDistance'] := block.EditValues['TerrainTilingDistance'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['TessellationBaseFactor'] := block.EditValues['TessellationBaseFactor'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['TessellationFadeDistance'] := block.EditValues['TessellationFadeDistance'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['TessellationPnScale'] := block.EditValues['TessellationPnScale'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['TranslucencyTransmissiveScale'] := block.EditValues['TranslucencyTransmissiveScale'];
                            // joCustomMaterial.O['bgsm'].O[diffuse].O[count].S['TranslucencyTurbulence'] := block.EditValues['TranslucencyTurbulence'];
                        end;
                        mess := model + #9 + IntToStr(i) + ' ' + block.BlockType + '\Name: Assigned material to "';
                        matPath := PickMaterial(mess, model, matSuffix, diffuse, joCustomMaterial);
                        if not Assigned(matPath) then continue;
                        //matPath := 'materials' + TrimLeftChars(TrimRightChars(diffuse, 8), 6) + matSuffix;
                        //AddMessage('material path: ' + matPath);
                        block.EditValues['Name'] := matPath;
                        bChanged := true;
                        slAddedMat.Add(mess + matPath + '"');
                    end else begin
                        if not ResourceExists(mat) then begin
                            bBlockMissingMat := True;
                            Result := True;
                            slMissingMaterials.Add('Material does not exist: ' + #9 + ShortName(stat) + #9 + model + #9 + mat + #9 + blockName);
                        end 
                        else if SameText(matExt, '.bgsm') then begin
                            bgsm.LoadFromResource(mat);
                            if ((bgsm.EditValues['Decal'] = 'yes') and (block.NativeValues['Shader Flags 1\Decal'] = 0)) then begin
                                slNeedsDecalFlag.Add(model + #9 + IntToStr(i) + ' ' + block.BlockType + ': Added missing Decal shader flag.');
                                block.NativeValues['Shader Flags 1\Decal'] := 1;
                                bChanged := true;
                            end;
                        end;
                    end;
                finally
                    joCustomMaterial.Free;
                end;
            end;
        finally
            if bChanged then begin
                EnsureDirectoryExists(sOutputDir + '\' + ExtractFilePath(model));
                //nif.SaveToFile(sOutputDir + '\' + model);
            end;
            nif.Free;
            bgsm.Free;
        end;
    // except on E: Exception do slNifErrors.Add('Error reading NIF: ' + E.Message + #9 + ShortName(stat) + #9 + model);
    // end;
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
    if i = 0 then Result := 'yes' else Result := 'no';
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

end.