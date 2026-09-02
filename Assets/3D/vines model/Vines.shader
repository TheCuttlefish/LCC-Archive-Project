Shader "Custom/Vines_DitherCutout_Modes"
{
    Properties
    {
        _MainTex ("Albedo (RGB) Alpha (A)", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)

        _Cutoff ("Alpha Cutoff", Range(0,1)) = 0.5

        _FadeStart ("Angle Fade Start", Range(0,1)) = 0.05
        _FadeEnd ("Angle Fade End", Range(0,1)) = 0.25

        _DitherScale ("Dither Scale", Range(0.25,4)) = 1

        // 0 = Current Noise
        // 1 = Bayer 4x4
        // 2 = Blue Noise
        _DitherMode ("Dither Mode", Range(0,2)) = 1

        _BlueNoise ("Blue Noise", 2D) = "gray" {}

        _Metallic ("Metallic", Range(0,1)) = 0
        _Smoothness ("Smoothness", Range(0,1)) = 0
    }

    SubShader
    {
        Tags
        {
            "Queue" = "AlphaTest"
            "RenderType" = "TransparentCutout"
        }

        LOD 200
        Cull Off

        CGPROGRAM

        #pragma surface surf Standard fullforwardshadows addshadow
        #pragma target 3.0

        sampler2D _MainTex;
        sampler2D _BlueNoise;

        fixed4 _Color;

        half _Cutoff;
        half _FadeStart;
        half _FadeEnd;
        half _DitherScale;
        half _DitherMode;

        half _Metallic;
        half _Smoothness;

        struct Input
        {
            float2 uv_MainTex;

            float3 worldPos;
            float3 worldNormal;

            float4 screenPos;

            INTERNAL_DATA
        };


        // ------------------------------------------------
        // CURRENT RANDOM / HASH DITHER
        // ------------------------------------------------

        float HashDither(float2 pixel)
        {
            pixel = floor(pixel);

            return frac(
                52.9829189 *
                frac(
                    dot(
                        pixel,
                        float2(0.06711056, 0.00583715)
                    )
                )
            );
        }


        // ------------------------------------------------
        // BAYER 4x4
        // ------------------------------------------------

        float Bayer4x4(float2 pixel)
        {
            int2 p = int2(floor(pixel)) & 3;

            const float bayer[16] =
            {
                 0,  8,  2, 10,
                12,  4, 14,  6,
                 3, 11,  1,  9,
                15,  7, 13,  5
            };

            return (bayer[p.x + p.y * 4] + 0.5) / 16.0;
        }


        // ------------------------------------------------
        // BLUE NOISE
        // ------------------------------------------------

        float BlueNoiseDither(float2 pixel)
        {
            // Assumes noise texture tiles.
            float2 uv =
                pixel / 64.0;

            return tex2D(
                _BlueNoise,
                uv
            ).r;
        }


        void surf(Input IN, inout SurfaceOutputStandard o)
        {
            fixed4 tex =
                tex2D(_MainTex, IN.uv_MainTex) * _Color;


            // ------------------------------------------------
            // NORMAL CUTOUT
            // ------------------------------------------------

            clip(tex.a - _Cutoff);


            // ------------------------------------------------
            // CAMERA ANGLE
            // ------------------------------------------------

            float3 N =
                normalize(IN.worldNormal);

            float3 V =
                normalize(
                    _WorldSpaceCameraPos.xyz -
                    IN.worldPos
                );

            float NdotV =
                abs(dot(N, V));


            // ------------------------------------------------
            // ANGLE FADE
            // ------------------------------------------------

            float angleFade =
                smoothstep(
                    _FadeStart,
                    _FadeEnd,
                    NdotV
                );


            // ------------------------------------------------
            // SCREEN PIXEL POSITION
            // ------------------------------------------------

            float2 screenUV =
                IN.screenPos.xy /
                IN.screenPos.w;

            float2 pixel =
                screenUV *
                _ScreenParams.xy /
                _DitherScale;


            // ------------------------------------------------
            // SELECT DITHER
            // ------------------------------------------------

            float dither;

            if (_DitherMode < 0.5)
            {
                dither =
                    HashDither(pixel);
            }
            else if (_DitherMode < 1.5)
            {
                dither =
                    Bayer4x4(pixel);
            }
            else
            {
                dither =
                    BlueNoiseDither(pixel);
            }


            // ------------------------------------------------
            // HARD DITHER CUTOUT
            // ------------------------------------------------

            clip(angleFade - dither);


            // ------------------------------------------------
            // STANDARD SURFACE
            // ------------------------------------------------

            o.Albedo = tex.rgb;
            o.Metallic = _Metallic;
            o.Smoothness = _Smoothness;
            o.Alpha = 1;
        }

        ENDCG
    }

    FallBack "Transparent/Cutout/VertexLit"
}