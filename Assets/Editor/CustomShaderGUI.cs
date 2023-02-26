using UnityEngine;
using UnityEditor;
using UnityEngine.Rendering;

public class CustomShaderGUI : ShaderGUI {
    MaterialEditor editor;
    object[] materials;
    MaterialProperty[] properties;

    bool Clipping{set => SetProperty("_Clipping", "_CLIPPING", value);}
    bool PremultiplyAlpha{set => SetProperty("_PremulAlpha", "_PREMULTIPLY_ALPHA", value);}
    BlendMode SrcBlend{set => SetProperty("_SrcBlend", (float)value);}
    BlendMode DstBlend{set => SetProperty("_DstBlend", (float)value);}
    bool ZWrite{set => SetProperty("_ZWrite", value ? 1f : 0f);}
    RenderQueue Queue
    {
        set
        {
            foreach(Material m in materials)
                m.renderQueue = (int)value;
        }
    }

    bool showPresets;

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties) 
    {
        base.OnGUI(materialEditor, properties);
        this.editor = materialEditor;
        this.materials = materialEditor.targets;
        this.properties = properties;    
        EditorGUILayout.Space();
        showPresets = EditorGUILayout.Foldout(showPresets, "Presets", true);
        if(showPresets)
        {
            OpaquePreset();
            ClipPreset();
            FadePreset();
            TransparentPreset();
        }
    }

    bool HasProperty(string name) => FindProperty(name, properties, false) != null;

    bool SetProperty(string name, float value)
    {
        MaterialProperty property = FindProperty(name, properties, false);
        if(property != null)
        {
            property.floatValue = value;
            return true;
        }
        return false;
    }

    void SetProperty(string name, string keyword, bool value)
    {
        if(SetProperty(name, value ? 1f : 0f))
            SetKeyWord(keyword, value);
    }

    void SetKeyWord(string keyword, bool enabled)
    {
        if(enabled)
        {
            foreach(Material m in materials)
                m.EnableKeyword(keyword);
        }
        else
        {
            foreach(Material m in materials)
                m.DisableKeyword(keyword);
        }
    }

    bool PresetButton(string name)
    {
        if(GUILayout.Button(name))
        {
            // Property reset
            editor.RegisterPropertyChangeUndo(name);
            return true;
        }
        return false;
    }

    void OpaquePreset()
    {
        if(PresetButton("Opaque"))
        {
            Clipping = false;
            PremultiplyAlpha = false;
            SrcBlend = BlendMode.One;
            DstBlend = BlendMode.Zero;
            ZWrite = true;
            Queue = RenderQueue.Geometry;
        }
    }

    void ClipPreset()
    {
        if(PresetButton("Clip"))
        {
            Clipping = true;
            PremultiplyAlpha = false;
            SrcBlend = BlendMode.One;
            DstBlend = BlendMode.Zero;
            ZWrite = true;
            Queue = RenderQueue.AlphaTest;
        }
    }

    void FadePreset()
    {
        if(PresetButton("Fade"))
        {
            Clipping = false;
            PremultiplyAlpha = false;
            SrcBlend = BlendMode.SrcAlpha;
            DstBlend = BlendMode.OneMinusSrcAlpha;
            ZWrite = false;
            Queue = RenderQueue.Transparent;
        }
    }

    void TransparentPreset()
    {
        if(HasProperty("_PremulAlpha") && PresetButton("Transparent"))
        {
            Clipping = false;
            PremultiplyAlpha = true;
            SrcBlend = BlendMode.One;
            DstBlend = BlendMode.OneMinusSrcAlpha;
            ZWrite = false;
            Queue = RenderQueue.Transparent;
        }        
    }
}