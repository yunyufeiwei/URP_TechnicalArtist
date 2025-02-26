using System;
using UnityEngine;
using UnityEngine.Rendering;

[ImageEffectAllowedInSceneView]
[Serializable, VolumeComponentMenu("CustomPostProcessing/RimLightColor")]
public class RimLightColorVolume : VolumeComponent
{
    public FloatParameter thicknessX = new FloatParameter(0.01f , true);
    public FloatParameter thicknessY = new FloatParameter(0.01f , true);
    public ClampedFloatParameter maxThickness = new ClampedFloatParameter(0.01f, 0.0f, 0.5f);
    public FloatParameter intensity = new FloatParameter(1 , true); 
    public ClampedFloatParameter lerpValue = new ClampedFloatParameter(1.0f , 0.0f , 1.0f);
    public FloatParameter distance = new FloatParameter(0.01f , true);
    public ColorParameter rimLightColor = new ColorParameter(Color.white, true);
}
