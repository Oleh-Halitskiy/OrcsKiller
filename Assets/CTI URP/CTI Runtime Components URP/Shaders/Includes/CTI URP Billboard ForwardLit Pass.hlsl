//  Please note: CTI shaders do not support light mapping.

#if (defined(_NORMALMAP) || (defined(_PARALLAXMAP) && !defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR))) || defined(_DETAIL)
    #define REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR
#endif

//  Structs

struct Attributes {
    float4  positionOS                  : POSITION;
    float3  normalOS                    : NORMAL;
    float4  tangentOS                   : TANGENT;
    float2  texcoord                    : TEXCOORD0;
    float3  texcoord1                   : TEXCOORD1;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings {
    float4 positionCS   : SV_POSITION;
    float2 uv           : TEXCOORD0;

    //DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
    half3 vertexSH                      : TEXCOORD1;
    //#ifdef _ADDITIONAL_LIGHTS
    float3 positionWS                   : TEXCOORD2;
    //#endif
    half3 normalWS                      : TEXCOORD3;
    #if defined(_NORMALMAP) || defined(DEPTHNORMALPASS)
        half4 tangentWS                 : TEXCOORD4;
    #endif
    
    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        half4 fogFactorAndVertexLight   : TEXCOORD5;
    #else
        half  fogFactor                 : TEXCOORD5;
    #endif

//  Due to the order of our includes we have to check for both defines 
    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) || !defined(_MAIN_LIGHT_SHADOWS_CASCADE)
        float4 shadowCoord              : TEXCOORD7;
    #endif
    half colorVariation                 : TEXCOORD8;

    //UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

//--------------------------------------
//  Include the surface function
#include "Includes/CTI URP Billboard SurfaceData.hlsl"


//--------------------------------------
//  Vertex shader


#include "Includes/CTI URP Billboard.hlsl"

Varyings LitPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    //UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    half4 color;
    CTIBillboardVert(input, 0, color);

//  Set color variation
    output.colorVariation = color.r;

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    
    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
    half fogFactor = 0;
    #if !defined(_FOG_FRAGMENT)
        fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
    #endif

    output.uv = input.texcoord;

    // Already normalized from normal transform to WS.
    output.normalWS = normalInput.normalWS;
    #if defined(_NORMALMAP)
        float sign = input.tangentOS.w * GetOddNegativeScale();
        output.tangentWS = float4(normalInput.tangentWS.xyz, sign);
    #endif

    //OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
    //#ifdef DYNAMICLIGHTMAP_ON
    //    output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    //#endif
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);
    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
    #else
        output.fogFactor = fogFactor;
    #endif

    #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
        output.positionWS = vertexInput.positionWS;
    #endif

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        output.shadowCoord = GetShadowCoord(vertexInput);
    #endif

    output.positionCS = vertexInput.positionCS;

    return output;
}

//--------------------------------------
//  Fragment shader and functions

//  InitializeSurfaceData


//  InitializeInputData

void InitializeInputData(Varyings input, half3 normalTS, out InputData inputData)
{
    inputData = (InputData)0;
    #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
        inputData.positionWS = input.positionWS;
    #endif
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    #if defined(_NORMALMAP)
        float sgn = input.tangentWS.w;      // should be either +1 or -1
        float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
        inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent, input.normalWS.xyz));
    #else
        inputData.normalWS = input.normalWS;
    #endif
    
    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = viewDirWS;

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        inputData.shadowCoord = input.shadowCoord;
    #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
        inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
    #else
        inputData.shadowCoord = float4(0, 0, 0, 0);
    #endif

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactorAndVertexLight.x);
        inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
    #else
        inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor);
    #endif

    //#if defined(DYNAMICLIGHTMAP_ON)
    //  inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, inputData.normalWS);
    //#else
    //  inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
        inputData.bakedGI = SAMPLE_GI(input.texcoord1, input.vertexSH, inputData.normalWS);
    //#endif
    
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.lightmapUV);

    #if defined(DEBUG_DISPLAY)
    #if defined(DYNAMICLIGHTMAP_ON)
    //inputData.dynamicLightmapUV = input.dynamicLightmapUV;
    #endif
    #if defined(LIGHTMAP_ON)
    //inputData.staticLightmapUV = input.staticLightmapUV;
    #else
    inputData.vertexSH = input.vertexSH;
    #endif
    #endif
}

// Fragment shader

half4 LitPassFragment(Varyings input) : SV_Target
{
    //UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    #if defined(LOD_FADE_CROSSFADE) && !defined(SHADER_API_GLES)
        LODDitheringTransition(input.positionCS.xyz, unity_LODFade.x);
    #endif

    SurfaceData surfaceData;
    AdditionalSurfaceData additionalSurfaceData;
//  Get the surface description
    InitializeBillboardLitSurfaceData(input.colorVariation.x, input.uv, surfaceData, additionalSurfaceData);

//  Add ambient occlusion from alpha
    surfaceData.occlusion = (surfaceData.occlusion <= _AlphaLeak) ? 1 : surfaceData.occlusion; // Eliminate alpha leaking into ao
    surfaceData.occlusion  = lerp(1, surfaceData.occlusion * 2 - 1, _OcclusionStrength);

    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData);

//  Apply lighting
    half4 color = CTIURPFragmentPBR(
        inputData, 
        surfaceData,
        _Translucency * half4(additionalSurfaceData.translucency, 1, 1, 1),
        _AmbientReflection,
        _Wrap);

//  Add fog
    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    return color;
}