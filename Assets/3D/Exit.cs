using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Exit : MonoBehaviour
{
    public Transform insideCube1, insideCube2;
    public Fade sceneFade;
    bool endScene = false;
    float timer;
    float scale;
    // Start is called before the first frame update
    void Start()
    {
        scale = transform.localScale.x;
        insideCube1 = transform.Find("cube1").transform;
        insideCube2 = transform.Find("cube2").transform;
        sceneFade = GameObject.Find("sceneFade").GetComponent<Fade>();
    }

    // Update is called once per frame
    void Update()
    {
        transform.Rotate(0,50 * Time.deltaTime,0, Space.World);
        insideCube1.Rotate(0, 70 * Time.deltaTime, 0, Space.World);
        insideCube2.Rotate(0, 100 * Time.deltaTime, 0, Space.World);

        if (endScene)
        {
            if(timer < 1)
            {
                timer += Time.deltaTime;
                transform.localScale = new Vector3(scale, scale, scale) * (1-timer);
            }
            else
            {
                transform.localScale = Vector3.zero;
            }
        }

    }


    private void OnTriggerEnter(Collider other)
    {
        if (other.transform.name == "Player")
        {
            if (!endScene)
            {
                sceneFade.EndScene();
                endScene = true;
            }
        }
    }
}
