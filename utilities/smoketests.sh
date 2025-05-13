# Test queue provider Status in Callback API
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

# Gets status information for Realtime API and its dependencies (Realtime Agent, queues and caches)
# Replace with your realtime host
REALTIME_HOST=https://rpi-realtimeapi.example.com/api/v2/events 
# Replace with your realtime api key
REALTIME_API_KEY=your_realtime_api_key 

curl -X GET "https://$REALTIME_HOST/api/v2/system/status" \
 -H "accept: application/json"\
 -H "rpiauthkey: $REALTIME_API_KEY" \

 