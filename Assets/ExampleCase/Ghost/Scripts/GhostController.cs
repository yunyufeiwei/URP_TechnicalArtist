using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class GhostController : MonoBehaviour
{
    public GameObject Character;
    public Button     RandomColor;
    public Slider     RotateSpeed;
    public Toggle     ShowPlayer;

    private Material CharacterMat;

    // Start is called before the first frame update
    void Start()
    {
        RandomColor.onClick.AddListener(RandomColorButton);
        RotateSpeed.onValueChanged.AddListener(RotateSpeedSlider);
        ShowPlayer.onValueChanged.AddListener(ShowPlayerToggle);

        CharacterMat = Character.GetComponentInChildren<SkinnedMeshRenderer>().sharedMaterial;
    }

    void RandomColorButton()
    {
        float R = Random.value;
        float G = Random.value;
        float B = Random.value;

        Vector4 ChangeColor = new Color(R,G,B,1);

        //这里的_FresnelColor是材质shader里面的属性名，并不是面板上面显示的名字
        CharacterMat.SetColor("_FresnelColor",ChangeColor);
        Debug.Log(ChangeColor);
    }

    void RotateSpeedSlider(float value)
    {
        //使用GetComponent方法获取该GameObject下面的组件，这里的组件是用代码写的旋转逻辑RotatorSelf
        Character.GetComponent<RotatorSelf>().Speed = value;
    }

    void ShowPlayerToggle(bool isOn)
    {
        Character.SetActive(isOn);
    }
}
