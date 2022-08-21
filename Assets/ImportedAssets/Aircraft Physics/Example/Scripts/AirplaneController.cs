using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class AirplaneController : MonoBehaviour
{
    public GameObject target;
    [SerializeField]
    List<AeroSurface> controlSurfaces = null;
    [SerializeField]
    List<WheelCollider> wheels = null;
    [SerializeField]
    float rollControlSensitivity = 0.2f;
    [SerializeField]
    float pitchControlSensitivity = 0.2f;
    [SerializeField]
    float yawControlSensitivity = 0.2f;

    [Range(-1, 1)]
    public float Pitch;
    [Range(-1, 1)]
    public float Yaw;
    [Range(-1, 1)]
    public float Roll;
    [Range(0, 1)]
    public float Flap;
    [SerializeField]
    Text displayText = null;

    [Header("Missile holders")]
    [SerializeField] private FixedJoint HolderOne;
    [SerializeField] private FixedJoint HolderTwo;
    [SerializeField] private Transform LocationOne;
    [SerializeField] private Transform LocationTwo;

    [Header("Missiles")]
    [SerializeField] private GameObject AGM;

    float thrustPercent;
    float brakesTorque;

    AircraftPhysics aircraftPhysics;
    Rigidbody rb;

    private void Start()
    {
        aircraftPhysics = GetComponent<AircraftPhysics>();
        rb = GetComponent<Rigidbody>();
    }

    private void Update()
    {
        if (Input.GetKeyDown(KeyCode.Alpha1))
        {
            StartCoroutine(SendFirstRocket());
        }
        if (Input.GetKeyDown(KeyCode.Alpha2))
        {
            StartCoroutine(SendSecondRocket());
        }
        if (Input.GetKeyDown(KeyCode.Z))
        {
            RestockRockes();
        }
        Pitch = Input.GetAxis("Vertical");
        Roll = Input.GetAxis("Horizontal");
        Yaw = Input.GetAxis("Yaw");

        if (Input.GetKeyDown(KeyCode.Space))
        {
            thrustPercent = thrustPercent > 0 ? 0 : 1f;
        }

        if (Input.GetKeyDown(KeyCode.F))
        {
            Flap = Flap > 0 ? 0 : 0.3f;
        }

        if (Input.GetKeyDown(KeyCode.B))
        {
            brakesTorque = brakesTorque > 0 ? 0 : 100f;
        }

      //  displayText.text =  "V: " + ((int)rb.velocity.magnitude).ToString("D3") + " m/s\n";
      //  displayText.text += "A: " + ((int)transform.position.y).ToString("D4") + " m\n";
      //  displayText.text += "T: " + (int)(thrustPercent * 100) + "%\n";
      //  displayText.text += brakesTorque > 0 ? "B: ON" : "B: OFF";
    }

    private void FixedUpdate()
    {
        SetControlSurfecesAngles(Pitch, Roll, Yaw, Flap);
        aircraftPhysics.SetThrustPercent(thrustPercent);
        foreach (var wheel in wheels)
        {
            wheel.brakeTorque = brakesTorque;
            // small torque to wake up wheel collider
            wheel.motorTorque = 0.01f;
        }
    }

    public void SetControlSurfecesAngles(float pitch, float roll, float yaw, float flap)
    {
        foreach (var surface in controlSurfaces)
        {
            if (surface == null || !surface.IsControlSurface) continue;
            switch (surface.InputType)
            {
                case ControlInputType.Pitch:
                    surface.SetFlapAngle(pitch * pitchControlSensitivity * surface.InputMultiplyer);
                    break;
                case ControlInputType.Roll:
                    surface.SetFlapAngle(roll * rollControlSensitivity * surface.InputMultiplyer);
                    break;
                case ControlInputType.Yaw:
                    surface.SetFlapAngle(yaw * yawControlSensitivity * surface.InputMultiplyer);
                    break;
                case ControlInputType.Flap:
                    surface.SetFlapAngle(Flap * surface.InputMultiplyer);
                    break;
            }
        }
    }
    public void RestockRockes()
    {
        Vector3 spawnPoint = LocationOne.position;
        Vector3 spawnPoint2 = LocationTwo.position;
        HolderOne = gameObject.AddComponent<FixedJoint>();
        HolderTwo = gameObject.AddComponent<FixedJoint>();
        HolderOne.connectedBody = Instantiate(AGM, LocationOne.position, LocationOne.rotation).GetComponent<Rigidbody>();
        HolderTwo.connectedBody = Instantiate(AGM, LocationTwo.position, LocationTwo.rotation).GetComponent<Rigidbody>();
        HolderOne.connectedBody.GetComponent<MissileController>()._target = target;
        HolderTwo.connectedBody.GetComponent<MissileController>()._target = target;
        HolderOne.connectedBody.GetComponent<MissileController>().Activated = false;
        HolderTwo.connectedBody.GetComponent<MissileController>().Activated = false;

    }
    IEnumerator SendFirstRocket()
    {
        MissileController missileOne = HolderOne.connectedBody.GetComponent<MissileController>();
        Destroy(HolderOne);
        yield return new WaitForSeconds(1f);
        missileOne.Activated = true;
        yield return null;
    }
    IEnumerator SendSecondRocket()
    {
        MissileController missileTwo = HolderTwo.connectedBody.GetComponent<MissileController>();
        Destroy(HolderTwo);
        yield return new WaitForSeconds(1f);
        missileTwo.Activated = true;
        yield return null;
    }

    private void OnDrawGizmos()
    {
        if (!Application.isPlaying)
            SetControlSurfecesAngles(Pitch, Roll, Yaw, Flap);
    }
}
