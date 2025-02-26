using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Experimental.Rendering.Universal;

[Tooltip("改RenderFeature用于给角色添加内描边效果.")]
public class RimLightColorRenderFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;         //设置渲染事件执行位置，在后处理之前
        public Shader shader;                                                                           //设置shader
    }
    [SerializeField]
    Settings settings = new Settings();                     //class类里面定义的方法，需要再外面在创建出来
    
    RimLightColorRenderPass m_RimLightColorPass;          //声明EdgeDetection脚本，定义渲染Pass

    public override void Create() 
    {
        this.name = "EdgeDetection";
        m_RimLightColorPass = new RimLightColorRenderPass(settings.renderPassEvent , settings.shader);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_RimLightColorPass);     //将该Pass添加到渲染队列中
    }
}
//https://www.xuanyusong.com/archives/4956
