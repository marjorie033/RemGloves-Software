using System;
using UnityEngine;
using FlutterUnityIntegration;


public class HandController : MonoBehaviour
{
    [Header("Finger Bone Transforms")]
    public Transform indexFinger;
    public Transform middleFinger;
    public Transform ringFinger;
    public Transform pinkyFinger;
    public Transform thumb;

    [Header("Rotation Settings")]
    public float maxBendAngle = 90f;
    public float lerpSpeed = 8f;

    private float _indexTarget, _middleTarget, _ringTarget, _pinkyTarget;

    void Start()
    {
        UnityMessageManager.Instance.SendMessageToFlutter("Open Palm");
    }

    // Called by Flutter: controller.postMessage('HandController', 'ReceiveFlexData', '72,68,45,30')
    public void ReceiveFlexData(string data)
    {
        try
        {
            string[] parts = data.Split(',');
            if (parts.Length < 4) return;

            float index  = Mathf.Clamp(float.Parse(parts[0]), 0f, 100f);
            float middle = Mathf.Clamp(float.Parse(parts[1]), 0f, 100f);
            float ring   = Mathf.Clamp(float.Parse(parts[2]), 0f, 100f);
            float pinky  = Mathf.Clamp(float.Parse(parts[3]), 0f, 100f);

            _indexTarget  = (index  / 100f) * maxBendAngle;
            _middleTarget = (middle / 100f) * maxBendAngle;
            _ringTarget   = (ring   / 100f) * maxBendAngle;
            _pinkyTarget  = (pinky  / 100f) * maxBendAngle;

            string gesture = DetectGesture(index, middle, ring, pinky);
            UnityMessageManager.Instance.SendMessageToFlutter(gesture);
        }
        catch (Exception e)
        {
            Debug.LogError("HandController parse error: " + e.Message);
        }
    }

    void Update()
    {
        ApplyRotation(indexFinger,  _indexTarget);
        ApplyRotation(middleFinger, _middleTarget);
        ApplyRotation(ringFinger,   _ringTarget);
        ApplyRotation(pinkyFinger,  _pinkyTarget);
    }

    private void ApplyRotation(Transform bone, float targetAngle)
    {
        if (bone == null) return;
        Quaternion target = Quaternion.Euler(targetAngle, 0f, 0f);
        bone.localRotation = Quaternion.Lerp(
            bone.localRotation, target, Time.deltaTime * lerpSpeed);
    }

    private string DetectGesture(float i, float m, float r, float p)
    {
        if (i < 20 && m < 20 && r < 20 && p < 20) return "Open Palm";
        if (i > 70 && m > 70 && r > 70 && p > 70) return "Closed Fist";
        if (i < 20 && m < 20 && r > 70 && p > 70) return "Peace Sign";
        if (i < 20 && m > 70 && r > 70 && p > 70) return "Point Up";
        return "Custom Gesture";
    }
}
    
