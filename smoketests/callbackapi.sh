curl -X GET "https://rpi-callbackapi.redpointcdp.com/api/status/" | jq .


# Response
{
  "queueProviderStatus": {
    "type": "RedPoint.Azure.Server",
    "queueEnabled": true,
    "channelLabel": "SendGrid",
    "queuePath": "RPICallbackApiQueue",
    "status": "Success",
    "errorMessage": null
  }
}