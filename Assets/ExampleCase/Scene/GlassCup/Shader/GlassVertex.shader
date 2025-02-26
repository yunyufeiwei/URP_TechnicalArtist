Shader "TechnicalArt/GlassVertex"
{
    Properties
    {
        [Enum(UnityEngine.Rendering.BlendMode)]_SrcFactor("SrcFactor",int) = 0
        [Enum(UnityEngine.Rendering.BlendMode)]_DstFactor("DstFactor",int) = 0
        
        [Header(Matcap)]
        _MatCap("MatCap" , 2D) = "blcak"{}
        
        [Space(20)]
        [Header(RefractProperty)]
        _RefractMatcap("RefractMatcap" , 2D) = "black"{ }
        _RefractIntensity("refractIntensity" , float) = 1
        _RefractColor("RefractColor" , Color) = (1,1,1,1)
        _MinRefractRange("MinRefractRange",Float) = 0
        _MaxRefractRange("MaxRefractRange",Float) = 1
        
        [Space(20)]
        [Header(Mask)]
        _EdgeMask("EdgeMask" , 2D) = "white"{}
        _ObjectPivotOffset("_ObjectPivotOffset" , float) = 0
        [PowerSlider(1)]_ObjectHeight("_ObjectHeight" , Range(0,2)) = 0.35
        _DirtMap("DirtMap",2D) = "black"{}
        _DirtIntensity("DirtIntensity",Float) = 1
        _Alpha("Alpha",Float) = 1
        
        _VertexColor("VertexColor",Color) = (1,1,1,1)
        _VertexColorIntensity("VertexColorIntensity",Float) = 1
    }
    SubShader
    {
        Tags{"RenderPipeline" = "UniversalPipeline" "RenderType" = "Transparent"  "Queue" = "Transparent"}
        LOD 100
        Blend [_SrcFactor][_DstFactor]
        ZWrite Off
        ZTest On
        Cull Back

        Pass
        {
            Tags{"LightMode" = "UniversalForward"}
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 texcoord     : TEXCOORD;
                float3 normalOS     : NORMAL;
                float4 color        : COLOR;
            };
            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD;
                float3 positionWS   : TEXCOORD1;
                float3 normalWS     : TEXCOORD2;
                float3 viewWS       : TEXCOORD3;
                float4 color        : TEXCOORD4;
            };

            TEXTURE2D(_MatCap);SAMPLER(sampler_MatCap);
            TEXTURE2D(_RefractMatcap);SAMPLER(sampler_RefractMatcap);
            TEXTURE2D(_EdgeMask);SAMPLER(sampler_EdgeMask);
            TEXTURE2D(_DirtMap);SAMPLER(sampler_DirtMap);

            CBUFFER_START(UnityPerMaterial)
                float  _RefractIntensity;
                float4 _RefractColor;
                float  _MinRefractRange;
                float  _MaxRefractRange;
                float  _ObjectPivotOffset;
                float  _ObjectHeight;
                float4 _DirtMap_ST;
                float  _DirtIntensity;
                float  _Alpha;
                float4 _VertexColor;
                float  _VertexColorIntensity;
            CBUFFER_END

            Varyings vert (Attributes v)
            {
                Varyings o=(Varyings)0;

                o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
                o.positionHCS = TransformObjectToHClip(v.positionOS.xyz);

                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                o.viewWS = GetWorldSpaceViewDir(o.positionWS);
                
                o.uv = TRANSFORM_TEX(v.texcoord , _DirtMap);
                o.color = v.color;
                return o;
            }

            half4 frag (Varyings i) : SV_Target
            {
                half4 FinalColor;

                //世界空间下的向量
                half3 worldViewDir = SafeNormalize(i.viewWS);
                half3 worldNormalDir = normalize(i.normalWS);

                //视图空间下的向量
                half3 ViewSpaceNormalDir = TransformWorldToViewDir(worldNormalDir.xyz);         //视图空间下法线到相机的向量
                half3 ViewSpacePosition = normalize(TransformWorldToView(i.positionWS));        //视图空间下点到相机的向量

                half3 matCapDir = cross(ViewSpaceNormalDir,ViewSpacePosition);
                matCapDir = half3(-matCapDir.y,matCapDir.x,matCapDir.z);
                half2 matCapUV = matCapDir.xy * 0.5 + 0.5;
                half3 matcapMap = SAMPLE_TEXTURE2D(_MatCap , sampler_MatCap , matCapUV).rgb;
                half3 matcapMapColor = matcapMap;

                //计算折射，折射主要发生在玻璃杯边缘，因此通过菲涅尔遮罩来计算产生折射
                half fresnelMask = saturate(1 - smoothstep(_MinRefractRange , _MaxRefractRange , dot(worldNormalDir,worldViewDir))); //折射范围过渡对比
                half edgeMaskUV =  (i.positionWS.y - TransformObjectToWorld(half3(0,0,0)).y - _ObjectPivotOffset) / _ObjectHeight;
                half edgeMask = SAMPLE_TEXTURE2D(_EdgeMask , sampler_EdgeMask , edgeMaskUV.xx).r;

                half dirtMap = SAMPLE_TEXTURE2D(_DirtMap , sampler_DirtMap , i.uv).a * _DirtIntensity;

                //计算厚度图，菲涅尔的中间透明，dirtMap则显示除了指纹的地方是透明的，而1-edgeMask则是遮蔽不需要有折射的地方(杯底座)
                half Thickness = saturate(fresnelMask +  (edgeMask * 0.15) + dirtMap * (1 - edgeMask)).r;

                half refractivity = Thickness * _RefractIntensity;
                half2 refractUV = matCapUV + refractivity;
                half3 refractMap = SAMPLE_TEXTURE2D(_RefractMatcap , sampler_RefractMatcap , refractUV).rgb;
                half3 refractColor = lerp(_RefractColor.rgb * 0.5 , refractMap * _RefractColor.rgb , refractivity);

                half Alpha = saturate(max(matcapMap.r , Thickness) * _Alpha);

                half3 vertexColor = _VertexColor.rgb * _VertexColorIntensity;
                FinalColor = half4(lerp(vertexColor , matcapMapColor + refractColor , i.color.r),Alpha);
                
                return FinalColor;
            }
            ENDHLSL
        }
    }
}
