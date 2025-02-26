using System.Collections;
using System.Collections.Generic;
using Unity.Mathematics;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Experimental.Rendering.Universal;

public class RimLightColorRenderPass : ScriptableRenderPass
{
    static readonly string K_Rendering = "RimLightColor";
    public Material rimLightColorMat;
    private RimLightColorVolume rimLightColorVolume;

    private RenderQueueType m_renderQueueType;
    private FilteringSettings m_FilteringSettings;
    private SortingCriteria m_SortingCriterial;

    static readonly int MainTexID = Shader.PropertyToID("_MainTex");
    static readonly int bufferTex0 = Shader.PropertyToID("_CustomBuffer0");

    RenderTargetIdentifier sourceTarget;

    public RimLightColorRenderPass(RenderPassEvent renderEvent , Shader m_shader)
    {
        renderPassEvent = renderEvent;      //设置渲染事件位置，这里的renderPassEvent是从ScriptableRenderPass里面得到的
        var shader = m_shader;              //通过shader创建材质，便于后面通过材质参数进行计算
        if(shader == null)
        {
            Debug.LogError("当前未指定shader文件!");
        }
        else
        {
            rimLightColorMat = CoreUtils.CreateEngineMaterial(m_shader);
        }
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if(rimLightColorMat == null)
        {
            Debug.LogWarning("未获取到材质球!");
            return;
        }
        
        if(!renderingData.cameraData.postProcessEnabled)
        {
            Debug.LogWarning("摄像机后处理未激活!");
            return;
        }

        var stack = VolumeManager.instance.stack;
        rimLightColorVolume = stack.GetComponent<RimLightColorVolume>();
        if(rimLightColorVolume == null )
        {
            Debug.LogWarning("Volume获取失败!");
            return;
        }

        CommandBuffer cmd = CommandBufferPool.Get(K_Rendering);

        OnRenderImage(cmd , ref renderingData);

        // var drawingSettings = CreateDrawingSettings(m_ShaderTagIdList, ref renderingData, m_SortingCriterial);
        // context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref m_FilteringSettings);
        context.ExecuteCommandBuffer(cmd); 
        cmd.Clear();
        CommandBufferPool.Release(cmd);
    }

    void OnRenderImage(CommandBuffer cmd, ref RenderingData renderingData)
    {
        sourceTarget = renderingData.cameraData.renderer.cameraColorTargetHandle;
        // var source = sourceTarget;

        //创建一张离屏纹理来存储信息，该描述符包含新建纹理所需的所有信息
        RenderTextureDescriptor inRTDesc = renderingData.cameraData.cameraTargetDescriptor;
        inRTDesc.depthBufferBits = 0;

        float m_thicknessX = rimLightColorVolume.thicknessX.value;
        float m_thicknessY = rimLightColorVolume.thicknessY.value;
        float m_maxThickness = rimLightColorVolume.maxThickness.value;
        float m_intensity = rimLightColorVolume.intensity.value;
        float m_lerpValue = rimLightColorVolume.lerpValue.value;
        float m_distance = rimLightColorVolume.distance.value;    
        Color m_rimLightcolor = rimLightColorVolume.rimLightColor.value;

        int rtWidth = inRTDesc.width;
        int rtHeight = inRTDesc.height;

        cmd.SetGlobalTexture(MainTexID, sourceTarget);
        cmd.GetTemporaryRT(bufferTex0, rtWidth, rtHeight, depthBuffer: 0, FilterMode.Trilinear, format: RenderTextureFormat.Default);

        rimLightColorMat.SetFloat("_ThicknessX" , m_thicknessX);
        rimLightColorMat.SetFloat("_ThicknessY" , m_thicknessY);
        rimLightColorMat.SetFloat("_MaxThickness" , m_maxThickness);
        rimLightColorMat.SetFloat("_Intensity", m_intensity);
        rimLightColorMat.SetFloat("_LerpValue", m_lerpValue);
        rimLightColorMat.SetFloat("_Distance" , m_distance);
        rimLightColorMat.SetColor("_RimLightColor", m_rimLightcolor);

        cmd.Blit(sourceTarget, bufferTex0 , rimLightColorMat , 0);
        cmd.Blit(bufferTex0, sourceTarget);

        cmd.ReleaseTemporaryRT(bufferTex0);
    }
}
