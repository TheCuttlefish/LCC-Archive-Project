using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement; // this is a scene manager library, it is used for loading scenes! (I use it for resetting the scene)

public class FPS : MonoBehaviour
{

    GameObject feet;// feet variable
    Rigidbody rb;// rigibBody varatiable
    float forwardInput;// forward and back movemnt
    float sideInput; // strafing
    Vector3 upDown; // vector for calculating up/down regardless of player's orientation
    Vector3 controlledVel;//controller velocity
    bool isGrounded; // boolean to track is player is grounded of jumping

    [Range(1f, 10f)]
    public float lookAroundSpeed = 2f;
    [Range(0.5f,10f)]
    public float playerSpeed = 7f;
    [Range(2f,20f)]
    public float jumpThrust = 10f;
    [Range(0f, 20f)]
    public float gravityPush = 10f;

    void Start()
    {
        feet = transform.Find("feet").gameObject; // find feet object
        rb = GetComponent<Rigidbody>();// find rigidBody
        Cursor.visible = false;// hide cursor (you need to click on the game window to acrivate it, press escape to re-enable cursor)
        //in your build version, the cursor will be completely hidden!
    }
    float yRot; // local variable for stroing x mouse movement (for looking around)
    float xRot; // local variable for stroing y mouse movement (for looking around)
    void Update()
    {


        //now for the mouse rotation
        yRot += Input.GetAxis("Mouse Y") * lookAroundSpeed;
        xRot += Input.GetAxis("Mouse X") * lookAroundSpeed;
        yRot = Mathf.Clamp(yRot, -90f, 90f); // Clamping yRotation to avoid camera glitching when reaching -90 or 90
        Camera.main.transform.rotation = Quaternion.Euler(-yRot,xRot, 0f);
        



        if (Input.GetKeyDown(KeyCode.R))   SceneManager.LoadScene(SceneManager.GetActiveScene().buildIndex); // reload scene!

        forwardInput = Input.GetAxis("Vertical"); // store vertical input in the forward movement variable
        sideInput = Input.GetAxis("Horizontal"); // store horizontal ( strafing) input for horizontal movement

        upDown = Vector3.Cross(Vector3.up, Camera.main.transform.right);//-- cam up/down axis - this is to avoid ghost cam effect
        controlledVel = ((-upDown * forwardInput ) + (Camera.main.transform.right * sideInput)) * playerSpeed;// player movement X and Z direction

        if (Input.GetKey(KeyCode.Space) && isGrounded) // check if holding space AND feet are groudned!
        {
            rb.AddForce(0, jumpThrust * Time.deltaTime * 500, 0); // jump thrust
            isGrounded = false;// set grounded to false
        }

        if(!isGrounded) isGrounded = feet.GetComponent<GroundCheck>().isGrounded; // check if feet are grounded

    }

    void FixedUpdate(){

        rb.velocity = new Vector3(controlledVel.x, rb.velocity.y, controlledVel.z);  // apply velocity from player controller
        rb.AddForce(0,-gravityPush, 0); // continiously push player down - so it doesn't float
    }
    
}
