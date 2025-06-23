# ==========================
# Smoke testing the Callback API
   - # Test queue provider Status in Callback API
CALLABACK_API_ADDRESS=rpi-callbackapi.example.com
curl -X GET "https://$CALLABACK_API_ADDRESS/api/status/" | jq .


# ==========================
# Smoke testing the Realtime API
# API Key example
REALTIME_API_ADDRESS=rpi-realtimeapi.example.com
REALTIME_API_KEY=your_realtime_api_key 

 - # Get system status using api key
curl -X GET "https://$REALTIME_API_ADDRESS/api/v2/system/status" \
 -H "accept: application/json"\
 -H "rpiauthkey: $REALTIME_API_KEY" \

# Smoke testing using OAuth example
TOKEN=$(curl -L -X POST \
  "http://$REALTIME_API_ADDRESS/connect/token/" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=password" \
  --data-urlencode "client_id=$CLIENT_ID" \
  --data-urlencode "username=$USERNAME" \
  --data-urlencode "password=$PASSWORD" \
  --data-urlencode "client_secret=$CLIENT_SECRET" | jq -r '.access_token')

# Get version information for Realtime API and Realtime Agent
curl -X GET "https://$REALTIME_API_ADDRESS/api/v2/system/version" \
 -H "accept: application/json" \
 -H "Authorization: Bearer $TOKEN" | jq .

# Gets status information for Realtime API and 
# its dependencies (Realtime Agent, queues and caches)
curl -X GET "https://$REALTIME_API_ADDRESS/api/v2/system/status" \
 -H "accept: application/json" \
 -H "Authorization: Bearer $TOKEN" | jq .

# Gets status information for Realtime API cache
curl -X GET "https://$REALTIME_API_ADDRESS/api/v2/system/status/cache/mongodb" \
 -H "accept: application/json" \
 -H "Authorization: Bearer $TOKEN" | jq .

# Returns the queues configuration
curl -X GET "https://$REALTIME_API_ADDRESS/api/v2/configuration/queues" \
 -H "accept: text/plain" \
 -H "Authorization: Bearer $TOKEN" | jq .

# Returns the cache settings configuration
curl -X GET "https://$REALTIME_API_ADDRESS/api/v2/configuration/cache-settings" \
 -H "accept: text/plain" \
 -H "Authorization: Bearer $TOKEN" | jq .