using System.Collections;
using System.Collections.Generic;
using UnityEngine;


[ExecuteInEditMode]


public class DummyColour : MonoBehaviour
{

    public Gradient myGradient;
    // Start is called before the first frame update

    

    void Awake()
    {
        DestroyImmediate(GetComponent<DummyColour>()); // destory on start
    }

    // Update is called once per frame
    void Update()
    {
        var c = myGradient.Evaluate(((transform.position.x / 20f % 1f + transform.position.y / 20f % 1f + transform.position.z / 20f % 1f) % 1f));
        c.a = 0.6f;
        Renderer r = GetComponent<Renderer>();

            r.material.color = c;
       
    }
}
