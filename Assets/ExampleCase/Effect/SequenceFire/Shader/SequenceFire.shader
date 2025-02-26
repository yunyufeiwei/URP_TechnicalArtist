Shader "Art_URP/Effect/SequenceFire"
{
    Properties
    {
        [Header(BlendMode)]
        [Enum(UnityEngine.Rendering.BlendMode)]_SrcFactor("SrcFactor",int) = 0
        [Enum(UnityEngine.Rendering.BlendMode)]_DstFactor("DstFactor",int) = 0
        [Enum(Billboard,1,verticalBillboard,0)]_BillboardType("BillboardType",int) = 1
        
        [Header(BaseProperty)]
        _BaseMap("BaseMap" , 2D) = "white"{}
        _Color("Color",Color) = (1,1,1,1)
        _RowAmount("HorizontalAmount",float) = 4                    //垂直方向的数量
        _ColumnAmount("VerticalAmount",float) = 4                   //水平方向的数量
        _Speed("Speed",Range(1,100)) = 1
    }
    SubShader
    {
        //"IgnoreProjector"="True"告诉Unity3D，我们不希望任何投影类型材质或者贴图，影响我们的物体或者着色器。这个特性往往那个用在GUI上。程序默认"IgnoreProjector"="Flase"
        Tags{"RenderPipeline" = "UniversalPipeline" "Queue" = "Transparent" "RenderType" = "Transparent" "IgnoreProjector" = "“Flase" "PreviewType" = "Plane"}
        Blend [_SrcFactor][_DstFactor]
        ZWrite Off
        LOD 100

        pass
        {
            Tags{"LightMode" = "UniversalForward"}
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 texcoord     : TEXCOORD;
            };
            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD;
                float  fogCoord     : TEXCOORD1;
            };
            
            TEXTURE2D(_BaseMap);SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseMap_ST;
                half4 _Color;
                half  _RowAmount;
                half  _ColumnAmount;
                half  _Speed;
                half  _BillboardType;
            CBUFFER_END

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;

                //广告牌技术的计算都是在模型空间下进行的，因此选择模型空间的原点作为广告牌的锚点
                //将时间空间下的相机位置转换到模型空间
                float3 viewDir = normalize(mul(GetWorldToObjectMatrix() , float4(_WorldSpaceCameraPos , 1))).xyz;
                //控制从垂直方向看时候的效果，避免从上往下看的时候，广告牌仍然面向摄像机
                viewDir.y *= _BillboardType;
                //假设向上的向量为世界坐标系下的向上向量
                float3 upDir = float3(0,1,0);
                //利用叉积（左手法则）计算出向右的向量
                float3 rightDir = normalize(cross(viewDir , upDir));
                //利用叉积计算出精确的向上向量
                upDir = normalize(cross(rightDir , viewDir));

                //矩阵的写法
                // float4x4 M = float4x4(
                //     rightDir.x,upDir.x,viewDir.x,0,
                //     rightDir.y,upDir.y,viewDir.y,0,
                //     rightDir.z,upDir.z,viewDir.z,0,
                //     0,0,0,1
                // );
                // float3 newVertex = mul(M,v.positionOS.xyz);
                
                //向量乘法的写法
                float3 newVertex = rightDir * v.positionOS.x  + upDir * v.positionOS.y + viewDir * v.positionOS.z;

                // o.positionHCS = TransformObjectToHClip(v.positionOS.xyz);
                o.positionHCS = TransformObjectToHClip(newVertex);
                // o.uv = TRANSFORM_TEX(v.texcoord,_BaseMap);

                //控制序列帧播放算法(方案一)
                o.uv = float2(v.texcoord.x/_ColumnAmount , v.texcoord.y/_RowAmount + 1/_RowAmount * (_RowAmount - 1));
                o.uv.x += frac(floor(_Time.y * _Speed)/_ColumnAmount);
                o.uv.y -= frac(floor(_Time.y * _Speed/_ColumnAmount)/_RowAmount);

                //通过ComputeFogFactor方法，使用裁剪空间的Z方向深度得到雾的坐标
                o.fogCoord = ComputeFogFactor(o.positionHCS.z);

                return o;
            }

            half4 frag(Varyings i):SV_TARGET
            {
                half4 FinalColor; 
                //方案一
                half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap , i.uv);     

                //控制序列真播放算法(方案二)
                // half time = floor(_Time.y * _Speed);
                // half row = floor(time / _RowAmount);
                // half column = time - row * _ColumnAmount;
                // half2 SequenceUv = i.uv + half2(column ,-row);
                // SequenceUv.x /= _RowAmount;
                // SequenceUv.y /= _ColumnAmount;
                // half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap , SequenceUv);                

                FinalColor = baseMap * _Color * baseMap.a;
                //混合雾效
                FinalColor.rgb = MixFog(FinalColor.rgb , i.fogCoord);

                return FinalColor;
            }
            ENDHLSL  
        }
    }
}
