
using UnityEngine;

public class S_Player : MonoBehaviour
{
    [Header("Movement")]
    public float speed = 5f;
    public float jumpForce = 5f;
    public float gravity = -9.81f;

    [Header("Mouse Look")]
    public float mouseSensitivity = 100f;
    public Transform playerCamera;

    private CharacterController controller;
    private Vector3 velocity;
    private float xRotation = 0f;

    void Start()
    {
        controller = GetComponent<CharacterController>();

        Cursor.lockState = CursorLockMode.Locked;
    }

    void Update()
    {
        Move();
        MouseLook();
    }

    void Move()
    {
        float x = 0f;
        float z = 0f;

        if (Input.GetKey(KeyCode.A) || Input.GetKey(KeyCode.Q))
            x = -1f;

        if (Input.GetKey(KeyCode.D))
            x = 1f;

        if (Input.GetKey(KeyCode.W) || Input.GetKey(KeyCode.Z))
            z = 1f;

        if (Input.GetKey(KeyCode.S))
            z = -1f;

        Vector3 move = transform.right * x + transform.forward * z;

        controller.Move(move.normalized * speed * Time.deltaTime);

        // Gravity
        if (controller.isGrounded && velocity.y < 0)
        {
            velocity.y = -2f;
        }

        // Jump
        // if (controller.isGrounded && Input.GetKeyDown(KeyCode.Space))
        // {
        //     velocity.y = Mathf.Sqrt(jumpForce * -2f * gravity);
        // }

        velocity.y += gravity * Time.deltaTime;

        controller.Move(velocity * Time.deltaTime);
    }

    void MouseLook()
    {
        float mouseX = Input.GetAxis("Mouse X") * mouseSensitivity * Time.deltaTime;
        float mouseY = Input.GetAxis("Mouse Y") * mouseSensitivity * Time.deltaTime;

        xRotation -= mouseY;
        xRotation = Mathf.Clamp(xRotation, -90f, 90f);

        playerCamera.localRotation = Quaternion.Euler(xRotation, 0f, 0f);

        transform.Rotate(Vector3.up * mouseX);
    }
}
