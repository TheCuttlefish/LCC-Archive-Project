Shader "Custom/BoxDecalBuiltIn_SurfaceBlend_Safe"
{
    Properties
    {
        _MainTex ("Decal Texture", 2D) = "white" {}

        _ColorA ("Color A", Color) = (1.0, 0.25, 0.02, 1)
        _ColorB ("Color B", Color) = (1.0, 0.75, 0.10, 1)

        _ColorSpread ("Color Spread", Range(0,1)) = 1.0
        _SeedScale ("Seed Scale", Range(0.01,10)) = 1.0

        _UpDotCutoff ("Up Dot Cutoff", Range(-1,1)) = 0.0
        _UpDotSpread ("Up Dot Spread", Range(0.001,1)) = 0.25

        _Alpha ("Alpha", Range(0,1)) = 1.0

        _BoxFeather ("Box Feather", Range(0,0.5)) = 0.05

        // NEW:
        // Extends the shader's accepted projector bounds
        // without physically changing the cube.
        _BoxPadding ("Box Padding", Range(0,0.5)) = 0.0

        _SurfaceBlend ("Surface Blend", Range(0,1)) = 1.0
        _SurfaceDarkening ("Surface Darkening", Range(0,1)) = 0.5
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
            ZTest Greater

            // Important for camera-inside-volume situations.
            Cull Off

            Blend SrcAlpha OneMinusSrcAlpha


            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            #include "UnityCG.cginc"


            sampler2D _MainTex;
            float4 _MainTex_ST;

            sampler2D _DecalBackground;


            fixed4 _ColorA;
            fixed4 _ColorB;

            float _ColorSpread;
            float _SeedScale;

            float _UpDotCutoff;
            float _UpDotSpread;

            float _Alpha;

            float _BoxFeather;
            float _BoxPadding;

            float _SurfaceBlend;
            float _SurfaceDarkening;


            UNITY_DECLARE_DEPTH_TEXTURE(
                _CameraDepthTexture
            );

            sampler2D
                _CameraDepthNormalsTexture;


            struct appdata
            {
                float4 vertex : POSITION;
            };


            struct v2f
            {
                float4 pos : SV_POSITION;

                float4 screenPos : TEXCOORD0;

                // Keep our non-perspective interpolation.
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
                // VIEW POSITION OF PROJECTOR VERTEX
                //------------------------------------------------

                float3 viewPos =
                    UnityObjectToViewPos(
                        v.vertex
                    );


                //------------------------------------------------
                // SAFE SIGNED Z
                //
                // OLD VERSION:
                //
                // max(0.0001, -viewPos.z)
                //
                // Problem:
                // vertices behind the camera got clamped
                // to +0.0001, producing enormous rays.
                //
                // NEW VERSION:
                // preserve which side of the camera
                // the vertex is on.
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
                // SCENE DEPTH
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
                // WORLD-UP FILTER
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
                // BOX EXTENT + PADDING
                //
                // Normal cube extent = 0.5
                //
                // Padding 0.10:
                // accepted extent becomes 0.60
                //------------------------------------------------

                float boxExtent =
                    0.5 +
                    _BoxPadding;


                //------------------------------------------------
                // PROJECTOR BOUNDS
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
                // BOX FEATHER
                //
                // Feather relative to our padded extent.
                //------------------------------------------------

                float3 distanceToEdge =
                    boxExtent -
                    abs(localPos);


                float nearestEdge =
                    min(
                        distanceToEdge.x,

                        min(
                            distanceToEdge.y,
                            distanceToEdge.z
                        )
                    );


                float boxFade =
                    1.0;


                if (_BoxFeather > 0.0001)
                {
                    boxFade =
                        smoothstep(
                            0.0,
                            _BoxFeather,
                            nearestEdge
                        );
                }


                //------------------------------------------------
                // DECAL UV
                //
                // IMPORTANT:
                // Still based on original 0.5 cube UV area.
                //
                // Padding does NOT stretch the decal texture.
                //------------------------------------------------

                float2 uv =
                    localPos.xy +
                    0.5;


                uv =
                    TRANSFORM_TEX(
                        uv,
                        _MainTex
                    );


                //------------------------------------------------
                // DECAL TEXTURE
                //------------------------------------------------

                fixed4 tex =
                    tex2D(
                        _MainTex,
                        uv
                    );


                clip(
                    tex.a -
                    0.001
                );


                //------------------------------------------------
                // PROJECTOR POSITION
                //------------------------------------------------

                float3 projectorPosition =
                    float3(
                        unity_ObjectToWorld._m03,
                        unity_ObjectToWorld._m13,
                        unity_ObjectToWorld._m23
                    );


                //------------------------------------------------
                // RANDOM COLOUR
                //------------------------------------------------

                float randomValue =
                    RandomFromPosition(
                        projectorPosition
                    );


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
                // DECAL COLOUR
                //------------------------------------------------

                float3 decalColor =
                    tex.rgb *
                    randomColour.rgb;


                //------------------------------------------------
                // SURFACE COLOUR
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
                    boxFade *
                    _Alpha;


                return fixed4(
                    finalRGB,
                    finalAlpha
                );
            }

            ENDCG
        }
    }
}