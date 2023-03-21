using UnityEngine;

[DisallowMultipleComponent]
public class PerObjectMaterialProperties : MonoBehaviour 
{
    static int baseColorId = Shader.PropertyToID("_BaseColor");
    static int metallicId = Shader.PropertyToID("_Metallic");
    static int smoothnessId = Shader.PropertyToID("_Smoothness");
    static int emissionColorId = Shader.PropertyToID("_EmissionColor");

    [SerializeField]
    Color baseColor = Color.white;
    
    [SerializeField, Range(0f, 1f)]
    float metallic = 0f;
    
    [SerializeField, Range(0f, 1f)]
    float smoothness = 0.5f;
    
    [SerializeField, ColorUsage(false, true)]
    Color emissionColor = Color.black;

    static MaterialPropertyBlock block;

    private void OnValidate() 
    {
        if(block == null) 
        {
            block = new MaterialPropertyBlock();
        }

        block.SetColor(baseColorId, baseColor);
        block.SetFloat(metallicId, metallic);
        block.SetFloat(smoothnessId, smoothness);
        block.SetColor(emissionColorId, emissionColor);
        GetComponent<Renderer>().SetPropertyBlock(block);
    }

    private void Awake() 
    {
        OnValidate();
    }
}