Shader "Custom/BoxDecalBuiltIn_RadialFade_Wet"
{
    Properties
    {
        _MainTex ("Decal Texture", 2D) = "white" {}

        //------------------------------------------------
        // COLOUR VARIATION
        //------------------------------------------------

        _ColorA ("Color A", Color) = (1.0, 0.25, 0.02, 1)
        _ColorB ("Color B", Color) = (1.0, 0.75, 0.10, 1)

        _ColorSpread ("Color Spread", Range(0,1)) = 1.0
        _SeedScale ("Seed Scale", Range(0.01,10)) = 1.0


        //------------------------------------------------
        // SURFACE ANGLE
        //------------------------------------------------

        _UpDotCutoff ("Up Dot Cutoff", Range(-1,1)) = 0.0
        _UpDotSpread ("Up Dot Spread", Range(0.001,1)) = 0.25


        //------------------------------------------------
        // GLOBAL ALPHA
        //------------------------------------------------

        _Alpha ("Alpha", Range(0,1)) = 1.0


        //------------------------------------------------
        // TEXTURE RADIAL FADE
        //------------------------------------------------

        _FadeRadius ("Fade Radius", Range(0,1.5)) = 1.0
        _FadeSpread ("Fade Spread", Range(0.001,1)) = 0.15


        //------------------------------------------------
        // SURFACE COLOUR
        //------------------------------------------------

        _SurfaceBlend ("Surface Blend", Range(0,1)) = 1.0
        _SurfaceDarkening ("Surface Darkening", Range(0,1)) = 0.5


        //------------------------------------------------
        // WET SPECULAR
        //------------------------------------------------

        _WetSmoothness ("Wet Smoothness", Range(0,1)) = 0.7
        _WetSpecular ("Wet Specular", Range(0,1)) = 0.5
        _WetSpecularColor ("Wet Specular Color", Color) = (1,1,1,1)
    }


    SubShader
    {
        Tags
        {
            "Queue"="Transparent+10"
            "RenderType"="Transparent"
        }


        GrabPass
        {
            "_DecalBackground"
        }


        Pass
        {
            ZWrite Off
            ZTest Always
            Cull Front

            Blend SrcAlpha OneMinusSrcAlpha


            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            #include "UnityCG.cginc"


            //------------------------------------------------
            // TEXTURES
            //------------------------------------------------

            sampler2D _MainTex;
            float4 _MainTex_ST;

            sampler2D _DecalBackground;


            //------------------------------------------------
            // PROPERTIES
            //------------------------------------------------

            fixed4 _ColorA;
            fixed4 _ColorB;

            float _ColorSpread;
            float _SeedScale;

            float _UpDotCutoff;
            float _UpDotSpread;

            float _Alpha;

            float _FadeRadius;
            float _FadeSpread;

            float _SurfaceBlend;
            float _SurfaceDarkening;

            float _WetSmoothness;
            float _WetSpecular;
            fixed4 _WetSpecularColor;


            //------------------------------------------------
            // CAMERA BUFFERS
            //------------------------------------------------

            UNITY_DECLARE_DEPTH_TEXTURE(
                _CameraDepthTexture
            );

            sampler2D
                _CameraDepthNormalsTexture;


            //------------------------------------------------
            // STRUCTS
            //------------------------------------------------

            struct appdata
            {
                float4 vertex : POSITION;
            };


            struct v2f
            {
                float4 pos : SV_POSITION;

                float4 screenPos : TEXCOORD0;

                noperspective float3 ray : TEXCOORD1;

                float4 grabPos : TEXCOORD2;
            };


            //------------------------------------------------
            // POSITION RANDOM
            //------------------------------------------------

            float RandomFromPosition(
                float3 position
            )
            {
                position *= _SeedScale;

                return frac(
                    sin(
                        dot(
                            position,
                            float3(
                                12.9898,
                                78.233,
                                37.719
                            )
                        )
                    )
                    * 43758.5453
                );
            }


            //------------------------------------------------
            // VERTEX
            //------------------------------------------------

            v2f vert(appdata v)
            {
                v2f o;


                o.pos =
                    UnityObjectToClipPos(
                        v.vertex
                    );


                o.screenPos =
                    ComputeScreenPos(
                        o.pos
                    );


                o.grabPos =
                    ComputeGrabScreenPos(
                        o.pos
                    );


                //------------------------------------------------
                // PROJECTOR VERTEX IN VIEW SPACE
                //------------------------------------------------

                float3 viewPos =
                    UnityObjectToViewPos(
                        v.vertex
                    );


                //------------------------------------------------
                // SAFE SIGNED Z
                //------------------------------------------------

                float z =
                    -viewPos.z;


                float zSign =
                    (z >= 0.0)
                    ? 1.0
                    : -1.0;


                float safeZ =
                    zSign *
                    max(
                        abs(z),
                        0.0001
                    );


                //------------------------------------------------
                // RECONSTRUCTION RAY
                //------------------------------------------------

                o.ray =
                    viewPos *
                    (
                        _ProjectionParams.z /
                        safeZ
                    );


                return o;
            }


            //------------------------------------------------
            // FRAGMENT
            //------------------------------------------------

            fixed4 frag(v2f i) : SV_Target
            {
                //------------------------------------------------
                // SCREEN UV
                //------------------------------------------------

                float2 screenUV =
                    i.screenPos.xy /
                    i.screenPos.w;


                //------------------------------------------------
                // CAMERA DEPTH
                //------------------------------------------------

                float rawDepth =
                    SAMPLE_DEPTH_TEXTURE(
                        _CameraDepthTexture,
                        screenUV
                    );


                float depth =
                    Linear01Depth(
                        rawDepth
                    );


                //------------------------------------------------
                // RECONSTRUCT VIEW POSITION
                //------------------------------------------------

                float3 viewPos =
                    i.ray *
                    depth;


                viewPos.z =
                    -viewPos.z;


                //------------------------------------------------
                // VIEW -> WORLD
                //------------------------------------------------

                float3 worldPos =
                    mul(
                        unity_CameraToWorld,
                        float4(
                            viewPos,
                            1.0
                        )
                    ).xyz;


                //------------------------------------------------
                // DEPTH NORMAL
                //------------------------------------------------

                float4 depthNormal =
                    tex2D(
                        _CameraDepthNormalsTexture,
                        screenUV
                    );


                float decodedDepth;
                float3 viewNormal;


                DecodeDepthNormal(
                    depthNormal,
                    decodedDepth,
                    viewNormal
                );


                //------------------------------------------------
                // NORMAL FIX
                //------------------------------------------------

                viewNormal.z =
                    -viewNormal.z;


                //------------------------------------------------
                // VIEW NORMAL -> WORLD NORMAL
                //------------------------------------------------

                float3 worldNormal =
                    normalize(
                        mul(
                            (float3x3)
                            unity_CameraToWorld,
                            viewNormal
                        )
                    );


                //------------------------------------------------
                // WORLD-UP DOT
                //------------------------------------------------

                float upDot =
                    dot(
                        worldNormal,
                        float3(
                            0.0,
                            1.0,
                            0.0
                        )
                    );


                //------------------------------------------------
                // SURFACE ANGLE FADE
                //------------------------------------------------

                float dotFade =
                    smoothstep(
                        _UpDotCutoff -
                        _UpDotSpread,

                        _UpDotCutoff +
                        _UpDotSpread,

                        upDot
                    );


                //------------------------------------------------
                // WORLD -> PROJECTOR LOCAL
                //------------------------------------------------

                float3 localPos =
                    mul(
                        unity_WorldToObject,
                        float4(
                            worldPos,
                            1.0
                        )
                    ).xyz;


                //------------------------------------------------
                // PROJECTOR SAFETY BOUNDS
                //------------------------------------------------

                const float safetyPadding =
                    0.02;


                const float normalExtent =
                    0.5;


                float boxExtent =
                    normalExtent +
                    safetyPadding;


                //------------------------------------------------
                // HARD PROJECTOR BOUNDS
                //------------------------------------------------

                clip(
                    boxExtent -
                    abs(localPos.x)
                );


                clip(
                    boxExtent -
                    abs(localPos.y)
                );


                clip(
                    boxExtent -
                    abs(localPos.z)
                );


                //------------------------------------------------
                // DECAL UV
                //------------------------------------------------

                float2 baseUV =
                    localPos.xy +
                    0.5;


                //------------------------------------------------
                // RADIAL DISTANCE
                //------------------------------------------------

                float2 centeredUV =
                    baseUV -
                    0.5;


                float radialDistance =
                    length(
                        centeredUV
                    ) * 2.0;


                //------------------------------------------------
                // RADIAL FADE
                //------------------------------------------------

                float fadeStart =
                    max(
                        0.0,
                        _FadeRadius -
                        _FadeSpread
                    );


                float textureFade =
                    1.0 -
                    smoothstep(
                        fadeStart,
                        _FadeRadius,
                        radialDistance
                    );


                //------------------------------------------------
                // TEXTURE TRANSFORM
                //------------------------------------------------

                float2 uv =
                    TRANSFORM_TEX(
                        baseUV,
                        _MainTex
                    );


                //------------------------------------------------
                // READ DECAL
                //------------------------------------------------

                fixed4 tex =
                    tex2D(
                        _MainTex,
                        uv
                    );


                //------------------------------------------------
                // TRANSPARENT PIXELS
                //------------------------------------------------

                clip(
                    tex.a -
                    0.001
                );


                //------------------------------------------------
                // PROJECTOR WORLD POSITION
                //------------------------------------------------

                float3 projectorPosition =
                    float3(
                        unity_ObjectToWorld._m03,
                        unity_ObjectToWorld._m13,
                        unity_ObjectToWorld._m23
                    );


                //------------------------------------------------
                // RANDOM VALUE
                //------------------------------------------------

                float randomValue =
                    RandomFromPosition(
                        projectorPosition
                    );


                //------------------------------------------------
                // RANDOM COLOUR
                //------------------------------------------------

                float colourT =
                    lerp(
                        0.5,
                        randomValue,
                        _ColorSpread
                    );


                fixed4 randomColour =
                    lerp(
                        _ColorA,
                        _ColorB,
                        colourT
                    );


                //------------------------------------------------
                // BASE DECAL COLOUR
                //------------------------------------------------

                float3 decalColor =
                    tex.rgb *
                    randomColour.rgb;


                //------------------------------------------------
                // READ SURFACE COLOUR
                //------------------------------------------------

                float3 surfaceColor =
                    tex2Dproj(
                        _DecalBackground,

                        UNITY_PROJ_COORD(
                            i.grabPos
                        )
                    ).rgb;


                //------------------------------------------------
                // SURFACE LUMINANCE
                //------------------------------------------------

                float surfaceLum =
                    dot(
                        surfaceColor,

                        float3(
                            0.2126,
                            0.7152,
                            0.0722
                        )
                    );


                //------------------------------------------------
                // SURFACE DARKENING
                //------------------------------------------------

                float surfaceBrightness =
                    lerp(
                        1.0,
                        surfaceLum,
                        _SurfaceDarkening
                    );


                float3 stainedColor =
                    decalColor *
                    surfaceBrightness;


                //------------------------------------------------
                // SURFACE BLEND
                //------------------------------------------------

                float3 finalRGB =
                    lerp(
                        decalColor,
                        stainedColor,
                        _SurfaceBlend
                    );


                //------------------------------------------------
                // FINAL ALPHA
                //------------------------------------------------

                float finalAlpha =
                    tex.a *
                    randomColour.a *
                    dotFade *
                    textureFade *
                    _Alpha;


                //================================================
                // WET SPECULAR
                //================================================


                //------------------------------------------------
                // VIEW DIRECTION
                //------------------------------------------------

                float3 viewDir =
                    normalize(
                        _WorldSpaceCameraPos -
                        worldPos
                    );


                //------------------------------------------------
                // LIGHT DIRECTION
                //------------------------------------------------

                float3 lightDir =
                    normalize(
                        _WorldSpaceLightPos0.xyz
                    );


                //------------------------------------------------
                // HALF VECTOR
                //------------------------------------------------

                float3 halfDir =
                    normalize(
                        lightDir +
                        viewDir
                    );


                //------------------------------------------------
                // SPECULAR ANGLES
                //------------------------------------------------

                float NdotH =
                    saturate(
                        dot(
                            worldNormal,
                            halfDir
                        )
                    );


                float NdotL =
                    saturate(
                        dot(
                            worldNormal,
                            lightDir
                        )
                    );


                //------------------------------------------------
                // SMOOTHNESS
                //
                // 0 = broad / rough
                // 1 = tight / smooth
                //------------------------------------------------

                float specPower =
                    lerp(
                        4.0,
                        256.0,
                        _WetSmoothness
                    );


                //------------------------------------------------
                // SPECULAR RESPONSE
                //------------------------------------------------

                float wetSpecular =
                    pow(
                        NdotH,
                        specPower
                    );


                wetSpecular *=
                    NdotL;


                //------------------------------------------------
                // WET MASK
                //------------------------------------------------

                float wetMask =
                    finalAlpha;


                //------------------------------------------------
                // APPLY COLOURED WET SPECULAR
                //------------------------------------------------

                finalRGB +=
                    wetSpecular *
                    _WetSpecular *
                    _WetSpecularColor.rgb *
                    wetMask;


                //------------------------------------------------
                // OUTPUT
                //------------------------------------------------

                return fixed4(
                    finalRGB,
                    finalAlpha
                );
            }

            ENDCG
        }
    }
}