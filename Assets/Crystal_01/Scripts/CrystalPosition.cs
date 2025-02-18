using UnityEngine;

// [ExecuteInEditMode]
public class CrystalPosition : MonoBehaviour
{
    public Transform gameObject;
    
    private Material _material;

    void Start()
    {
        _material = this.GetComponent<Renderer>().material;
    }

    // Update is called once per frame
    void Update()
    {
        _material.SetVector("_GameObjectPosition", gameObject.transform.position);
    }
}
