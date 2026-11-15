
using UnityEngine;

[ExecuteAlways]
public class S_CameraLookAt : MonoBehaviour
{
    [Header("Target")]
    public Transform target;
    public Vector3 targetOffset = Vector3.zero;

    [Header("Rotation")]
    public float rotationSpeed = 5f;
    public float smoothStop = 3f;

    private float currentAngle;
    private float rotationVelocity;

    void OnEnable()
    {
        UpdateAngle();
    }

    void Update()
    {
        if (target == null)
            return;

        if (Application.isPlaying)
        {
            if (Input.GetMouseButton(0))
            {
                rotationVelocity = Input.GetAxis("Mouse X") * rotationSpeed;
            }
            else
            {
                // Ralentissement progressif
                rotationVelocity = Mathf.Lerp(
                    rotationVelocity,
                    0f,
                    smoothStop * Time.deltaTime
                );
            }

            currentAngle += rotationVelocity;
        }

        Vector3 center = target.position + targetOffset;

        float height = transform.position.y;

        float distance = Vector3.Distance(
            new Vector3(transform.position.x, 0, transform.position.z),
            new Vector3(center.x, 0, center.z)
        );

        float angle = currentAngle * Mathf.Deg2Rad;

        Vector3 newPosition = new Vector3(
            center.x + Mathf.Sin(angle) * distance,
            height,
            center.z + Mathf.Cos(angle) * distance
        );

        transform.position = newPosition;

        Vector3 direction = center - transform.position;

        if (direction.sqrMagnitude > 0.001f)
        {
            transform.rotation = Quaternion.LookRotation(direction);
        }
    }

    void UpdateAngle()
    {
        if (target == null)
            return;

        Vector3 direction = transform.position - target.position;

        currentAngle = Mathf.Atan2(
            direction.x,
            direction.z
        ) * Mathf.Rad2Deg;
    }

    void OnDrawGizmos()
    {
        if (target == null)
            return;

        Gizmos.color = Color.yellow;
        Gizmos.DrawLine(transform.position, target.position + targetOffset);

        Gizmos.color = Color.red;
        Gizmos.DrawSphere(target.position + targetOffset, 0.1f);
    }
}
