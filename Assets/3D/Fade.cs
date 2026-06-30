using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class Fade : MonoBehaviour
{

    CanvasGroup group;
    float timer;
    bool startScene = true;
    bool endScene = false;
    private void Awake()
    {
        group = GetComponent<CanvasGroup>();
        group.alpha = 1.0f;
    }



    // Update is called once per frame
    void Update()
    {
        

        if (startScene)
        {
            timer += Time.deltaTime / 3; // 3 seconds
            if (timer < 1) group.alpha = 1 - timer;
            else { group.alpha = 0; startScene = false; timer = 0; }
            
        }

        if (endScene)
        {
            timer += Time.deltaTime / 2; // 2 seconds
            if (timer < 1) group.alpha = timer;
            else {
                group.alpha = 1;
                endScene = false;
                timer = 0;

                int currentSceneIndex = SceneManager.GetActiveScene().buildIndex;
                int nextSceneIndex = currentSceneIndex + 1;

                // Check if next index is within the build settings range
                if (nextSceneIndex < SceneManager.sceneCountInBuildSettings)
                {
                    SceneManager.LoadScene(nextSceneIndex);
                } else
                {
                    SceneManager.LoadScene(0); // go to 0 if out of scenes
                }


            }

        }

    }

    public void EndScene()
    {
        endScene = true;

    }
}
