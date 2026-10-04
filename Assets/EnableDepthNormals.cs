using UnityEngine;

[RequireComponent(typeof(Camera))]
public class EnableDepthNormals : MonoBehaviour
{
    void OnEnable()
    {
        GetComponent<Camera>().depthTextureMode |=
           DepthTextureMode.DepthNormals;
    }
}