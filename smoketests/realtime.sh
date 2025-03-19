REALTIME_HOST=https://rpi-realtimeapi.example.com/api/v2/events # Replace with your realtime host
REALTIME_API_KEY=your_realtime_api_key # Replace with your realtime api key
VISITOR_ID=AA7E023B-2F96-485B-BAE4-866DF21A5DFD

# Gets status information for Realtime API and its 
# dependencies (Realtime Agent, queues and caches)
curl -X GET "https://$REALTIME_HOST/api/v2/system/status" \
 -H "accept: application/json"\
 -H "rpiauthkey: $REALTIME_API_KEY" \


# Adds one or more realtime event
curl -X POST "https://$REALTIME_HOST/api/v2/events" \
  -H "accept: application/json" \
  -H "content-type: application/json" \
  -H "rpiauthkey: $REALTIME_API_KEY" \
  -d '{
    "DeviceID": "MyDeviceId",
    "Identity": {
      "VisitorID": "'"$VISITOR_ID"'",
      "IdentityKeys": {
        "CustomerKey": "11000"
      }
    },
    "TrackingMode": "Standard",
    "EnableProfileMergeUpdate": false,
    "SessionID": "string",
    "Events": [
      {
        "EventName": "PageVisit",
        "EventDetail": "mypage.htm",
        "MetricValue": 0,
        "ChannelExecutionID": 99,
        "RPContactID": "999",
        "PagePublishedID": 1,
        "ContentID": "string",
        "GoalDetails": {
          "GoalName": "string",
          "GoalContentID": "string",
          "DecisionResults": [
            {
              "ContentID": "string",
              "IndexResult": "string",
              "PublishedInstanceID": 0,
              "PageName": "string"
            }
          ],
          "GoalAssets": ["string"]
        },
        "PageReferral": "myreferralpage.htm",
        "RequestURL": "string",
        "ImpressionID": "impression123",
        "MergeDetails": {
          "ObjectName": "string",
          "FromVisitorID": "string",
          "ToVisitorID": "string",
          "Direction": "MergeFrom",
          "IsToMaster": false,
          "MergeDate": "1970-01-01T00:00:00.000Z"
        },
        "Metadata": [
          {
            "Name": "string",
            "Value": "string",
            "IgnoreForCache": false
          }
        ],
        "EventTime": "string",
        "MessageListID": 0,
        "MessageID": 0,
        "MessageName": "string"
      }
    ]
  }'


# Response
{
  "VisitorID": "AA7E023B-2F96-485B-BAE4-866DF21A5DFD",
  "DeviceID": "MyDeviceId",
  "SessionID": null
}