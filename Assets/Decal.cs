using UnityEngine;

[RequireComponent(typeof(Renderer))]
public class DecalSortOrder : MonoBehaviour
{
    private static int nextOrder = 0;

    private Renderer decalRenderer;

    private void Awake()
    {
        decalRenderer = GetComponent<Renderer>();

        // Stable transparent sorting.
        decalRenderer.sortingOrder = nextOrder++;

        // Prevent occlusion culling from removing
        // the projector unexpectedly.
        decalRenderer.allowOcclusionWhenDynamic = false;

        // Keep within a sensible sorting range.
        if (nextOrder > 30000)
            nextOrder = 0;
    }
}