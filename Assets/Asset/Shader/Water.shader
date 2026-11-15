
Shader "Custom/PoEStyleWater"
{
    Properties
    {
        [Header(Water Colors)]
        _WaterColor ("Water Color", Color) = (0.10, 0.19, 0.23, 1)
        _DeepColor ("Deep Color", Color) = (0.015, 0.035, 0.055, 1)
        _ReflectionTint ("Reflection Tint", Color) = (0.65, 0.75, 0.82, 1)

        [Header(Wave Settings)]
        _WaveHeight ("Wave Height", Range(0, 0.5)) = 0.12
        _WaveLength ("Wave Length", Range(1, 30)) = 9
        _WaveSpeed ("Wave Speed", Range(0, 3)) = 0.7
        _WaveSteepness ("Wave Steepness", Range(0, 1)) = 0.35

        [Header(Surface Detail)]
        _RippleScale ("Ripple Scale", Range(1, 30)) = 12
        _RippleStrength ("Ripple Strength", Range(0, 0.2)) = 0.045
        _RippleSpeed ("Ripple Speed", Range(0, 3)) = 0.5

        [Header(Reflections)]
        _ReflectionStrength ("Reflection Strength", Range(0, 2)) = 1
        _Smoothness ("Smoothness", Range(0, 1)) = 0.92
        _FresnelPower ("Fresnel Power", Range(0.1, 10)) = 4

        [Header(Transparency)]
        _Opacity ("Opacity", Range(0, 1)) = 0.85
        _Refraction ("Refraction", Range(0, 0.1)) = 0.025

        [Header(Foam)]
        _FoamColor ("Foam Color", Color) = (0.65, 0.75, 0.78, 1)
        _FoamAmount ("Foam Amount", Range(0, 1)) = 0.25
        _FoamWidth ("Foam Width", Range(0.01, 2)) = 0.3
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
        }

        Pass
        {
            Name "Water"
            Tags { "LightMode" = "UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Back

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            CBUFFER_START(UnityPerMaterial)

            float4 _WaterColor;
            float4 _DeepColor;
            float4 _ReflectionTint;
            float4 _FoamColor;

            float _WaveHeight;
            float _WaveLength;
            float _WaveSpeed;
            float _WaveSteepness;

            float _RippleScale;
            float _RippleStrength;
            float _RippleSpeed;

            float _ReflectionStrength;
            float _Smoothness;
            float _FresnelPower;

            float _Opacity;
            float _Refraction;

            float _FoamAmount;
            float _FoamWidth;

            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 viewDirWS : TEXCOORD2;
                float4 screenPos : TEXCOORD3;
                float fogFactor : TEXCOORD4;
                float eyeDepth : TEXCOORD5;
            };

            // ---------------------------------------
            // GERSTNER WAVES
            // ---------------------------------------

            float3 Gerstner(
                float2 p,
                float2 direction,
                float amplitude,
                float wavelength,
                float speed,
                float steepness
            )
            {
                direction = normalize(direction);

                float k = 6.2831853 / wavelength;
                float frequency = sqrt(9.81 * k);

                float phase =
                    k * dot(direction, p)
                    - _Time.y * speed * frequency;

                float q = steepness;

                return float3(
                    q * amplitude * direction.x * cos(phase),
                    amplitude * sin(phase),
                    q * amplitude * direction.y * cos(phase)
                );
            }

            float3 WaterPosition(float3 p)
            {
                float2 uv = p.xz;

                float3 displacement = 0;

                displacement += Gerstner(
                    uv,
                    float2(1, 0.25),
                    _WaveHeight,
                    _WaveLength,
                    _WaveSpeed,
                    _WaveSteepness
                );

                displacement += Gerstner(
                    uv,
                    float2(-0.4, 1),
                    _WaveHeight * 0.45,
                    _WaveLength * 0.65,
                    _WaveSpeed * 0.75,
                    _WaveSteepness * 0.65
                );

                displacement += Gerstner(
                    uv,
                    float2(0.8, -0.6),
                    _WaveHeight * 0.2,
                    _WaveLength * 0.3,
                    _WaveSpeed * 1.3,
                    _WaveSteepness * 0.4
                );

                return p + displacement;
            }

            // ---------------------------------------
            // WATER NORMAL
            // ---------------------------------------

            float3 WaterNormal(float3 p)
            {
                float epsilon = 0.04;

                float3 center = WaterPosition(p);

                float3 px = WaterPosition(
                    p + float3(epsilon, 0, 0)
                );

                float3 pz = WaterPosition(
                    p + float3(0, 0, epsilon)
                );

                float3 tangentX = px - center;
                float3 tangentZ = pz - center;

                return normalize(cross(tangentZ, tangentX));
            }

            // ---------------------------------------
            // SMALL SURFACE RIPPLES
            // ---------------------------------------

            float3 RippleNormal(float3 p)
            {
                float2 uv = p.xz * _RippleScale;

                float t = _Time.y * _RippleSpeed;

                float wave1 = sin(uv.x + t) *
                              cos(uv.y * 0.8 - t);

                float wave2 = sin(
                    (uv.x + uv.y) * 0.65 + t * 0.7
                );

                float wave3 = cos(
                    (uv.x * 0.5 - uv.y) * 1.4 - t
                );

                float dx = cos(uv.x + t) *
                           cos(uv.y * 0.8 - t);

                float dz = -0.8 * sin(uv.x + t) *
                           sin(uv.y * 0.8 - t);

                dx += 0.65 * cos(
                    (uv.x + uv.y) * 0.65 + t * 0.7
                );

                dz += 0.65 * cos(
                    (uv.x + uv.y) * 0.65 + t * 0.7
                );

                return normalize(float3(
                    -dx * _RippleStrength,
                    1,
                    -dz * _RippleStrength
                ));
            }

            // ---------------------------------------
            // VERTEX
            // ---------------------------------------

            Varyings vert(Attributes input)
            {
                Varyings output;

                float3 originalPos =
                    TransformObjectToWorld(input.positionOS.xyz);

                float3 displacedPos = WaterPosition(originalPos);

                output.positionWS = displacedPos;

                output.positionCS =
                    TransformWorldToHClip(displacedPos);

                output.normalWS = WaterNormal(originalPos);

                output.viewDirWS =
                    GetWorldSpaceViewDir(displacedPos);

                output.screenPos =
                    ComputeScreenPos(output.positionCS);

                output.fogFactor =
                    ComputeFogFactor(output.positionCS.z);

                output.eyeDepth =
                    -TransformWorldToView(displacedPos).z;

                return output;
            }

            // ---------------------------------------
            // FRAGMENT
            // ---------------------------------------

            half4 frag(Varyings input) : SV_Target
            {
                float3 viewDir = normalize(input.viewDirWS);

                float3 normal = normalize(input.normalWS);

                float3 ripple = RippleNormal(input.positionWS);

                normal = normalize(
                    normal + float3(ripple.x, 0, ripple.z)
                );

                // Fresnel
                float fresnel = pow(
                    1 - saturate(dot(normal, viewDir)),
                    _FresnelPower
                );

                // Water depth appearance
                float3 waterColor = lerp(
                    _WaterColor.rgb,
                    _DeepColor.rgb,
                    fresnel * 0.75
                );

                // Main light
                Light mainLight = GetMainLight();

                float3 lightDir = normalize(mainLight.direction);

                float diffuse = saturate(
                    dot(normal, lightDir)
                );

                // Specular highlights
                float3 halfVector = normalize(
                    lightDir + viewDir
                );

                float specular = pow(
                    saturate(dot(normal, halfVector)),
                    lerp(24, 512, _Smoothness)
                );

                float3 directSpecular =
                    mainLight.color * specular;

                // Reflection probe
                float3 reflectionDir = reflect(
                    -viewDir,
                    normal
                );

                float3 environmentReflection =
                    GlossyEnvironmentReflection(
                        reflectionDir,
                        input.positionWS,
                        1 - _Smoothness,
                        1,
                        input.screenPos.xy / input.screenPos.w
                    );

                environmentReflection *= _ReflectionTint.rgb;

                // Refraction
                float2 screenUV =
                    input.screenPos.xy / input.screenPos.w;

                float2 distortion =
                    normal.xz * _Refraction;

                float3 sceneColor = SampleSceneColor(
                    saturate(screenUV + distortion)
                );

                // Lighting
                float3 litWater = waterColor *
                    (0.3 + diffuse * mainLight.color);

                litWater += directSpecular;

                // Foam at intersections
                float sceneDepth = LinearEyeDepth(
                    SampleSceneDepth(screenUV),
                    _ZBufferParams
                );

                float depthDifference =
                    max(0, sceneDepth - input.eyeDepth);

                float foam = 1 - smoothstep(
                    0,
                    max(_FoamWidth, 0.001),
                    depthDifference
                );

                foam *= _FoamAmount;

                // Mix water and scene
                float3 finalColor = lerp(
                    sceneColor,
                    litWater,
                    _Opacity
                );

                // Reflections
                finalColor = lerp(
                    finalColor,
                    environmentReflection + litWater * 0.2,
                    saturate(fresnel * _ReflectionStrength)
                );

                // Foam
                finalColor = lerp(
                    finalColor,
                    _FoamColor.rgb,
                    foam
                );

                finalColor = MixFog(
                    finalColor,
                    input.fogFactor
                );

                return half4(finalColor, 1);
            }

            ENDHLSL
        }
    }

    FallBack "Universal Render Pipeline/Unlit"
}
