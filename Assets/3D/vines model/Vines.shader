Shader "Custom/Vines_DitherCutout_Modes_Wind"
{
    Properties
    {
        _MainTex ("Albedo (RGB) Alpha (A)", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)

        _Cutoff ("Alpha Cutoff", Range(0,1)) = 0.5

        _FadeStart ("Angle Fade Start", Range(0,1)) = 0.05
        _FadeEnd ("Angle Fade End", Range(0,1)) = 0.25

        _DitherScale ("Dither Scale", Range(0.25,4)) = 1

        // 0 = Hash
        // 1 = Bayer 4x4
        // 2 = Blue Noise
        _DitherMode ("Dither Mode", Range(0,2)) = 1

        _BlueNoise ("Blue Noise", 2D) = "gray" {}

        _Metallic ("Metallic", Range(0,1)) = 0
        _Smoothness ("Smoothness", Range(0,1)) = 0

        // -----------------------------
        // WIND
        // -----------------------------

        _WindStrength ("Wind Strength", Range(0,0.5)) = 0.05
        _WindSpeed ("Wind Speed", Range(0,10)) = 1.5
        _WindFrequency ("Wind Frequency", Range(0.1,10)) = 2.0

        _WindDirectionX ("Wind Direction X", Range(-1,1)) = 1
        _WindDirectionZ ("Wind Direction Z", Range(-1,1)) = 0.3

        _WindVertical ("Vertical Wobble", Range(0,1)) = 0.15

        // 0 = ignore vertex colors
        // 1 = use vertex color red as wind mask
        _UseVertexMask ("Use Vertex Color Mask", Range(0,1)) = 0
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

        #pragma surface surf Standard fullforwardshadows addshadow vertex:vert
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

        half _WindStrength;
        half _WindSpeed;
        half _WindFrequency;
        half _WindDirectionX;
        half _WindDirectionZ;
        half _WindVertical;
        half _UseVertexMask;


        struct Input
        {
            float2 uv_MainTex;

            float3 worldPos;
            float3 worldNormal;

            float4 screenPos;

            INTERNAL_DATA
        };


        // ------------------------------------------------
        // VERTEX WIND
        // ------------------------------------------------

        void vert(inout appdata_full v)
        {
            float3 worldPos =
                mul(unity_ObjectToWorld, v.vertex).xyz;

            float2 windDir =
                normalize(
                    float2(
                        _WindDirectionX,
                        _WindDirectionZ
                    ) + 0.0001
                );

            // World-space phase keeps nearby cards from
            // all moving in perfect sync.
            float phase =
                dot(worldPos.xz, windDir) *
                _WindFrequency;

            float time =
                _Time.y * _WindSpeed;

            // Main sway
            float wave =
                sin(phase + time);

            // Small secondary wave to make it less robotic
            float wave2 =
                sin(
                    phase * 1.73 -
                    time * 1.31 +
                    worldPos.y * 0.7
                );

            float wobble =
                wave * 0.7 +
                wave2 * 0.3;

            // Optional vertex-color red mask.
            // Red = 1 moves fully
            // Red = 0 stays pinned
            float vertexMask = v.color.r;

            float windMask =
                lerp(
                    1.0,
                    vertexMask,
                    _UseVertexMask
                );

            float amount =
                wobble *
                _WindStrength *
                windMask;

            // Move mostly horizontally with a tiny vertical wobble.
            float3 worldOffset;

            worldOffset.x =
                windDir.x * amount;

            worldOffset.z =
                windDir.y * amount;

            worldOffset.y =
                amount * _WindVertical;

            // Convert world-space offset back to object space.
            float3 objectOffset =
                mul(
                    (float3x3)unity_WorldToObject,
                    worldOffset
                );

            v.vertex.xyz += objectOffset;
        }


        // ------------------------------------------------
        // HASH DITHER
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