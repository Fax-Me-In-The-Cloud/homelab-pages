import requests
import sys
import hashlib
import datetime
import json

# Setup logging function to track what HA is sending
def log_debug(msg):
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open("/config/heatpump.log", "a") as f:
        f.write(f"[{timestamp}] {msg}\n")

# 1. Capture and Validate Arguments
if len(sys.argv) < 6:
    log_debug(f"Error: Expected 5 arguments, got {len(sys.argv)-1}")
    print(f"Error: Expected 5 arguments, got {len(sys.argv)-1}")
    sys.exit(1)

username = sys.argv[1]
password = sys.argv[2]
device_code = sys.argv[3]
protocolCode = sys.argv[4]
value = sys.argv[5]

# Log input status (masking password)
log_debug(f"Input: User={username}, Device={device_code}, Protocol={protocolCode}, Val={value}")

# Check for shell expansion failure
if username.startswith("$") or device_code.startswith("$"):
    log_debug("FAILED: Environment variables were not expanded by the shell.")
    print("Error: Shell expansion failed")
    sys.exit(1)

allowed_protocol_codes = {"compensate_offset", "Mode"}
if protocolCode not in allowed_protocol_codes:
    log_debug(f"FAILED: Invalid protocolCode: {protocolCode}")
    print("Error: protocolCode must be 'compensate_offset' or 'Mode'")
    sys.exit(1)

login_url = 'https://cloud.linked-go.com:449/crmservice/api/app/user/login'
control_url = 'https://cloud.linked-go.com:449/crmservice/api/app/device/control'

try:
    # 2. Get Token
    password_md5 = hashlib.md5(password.encode("utf-8")).hexdigest()
    login_data = {"userName": username, "password": password_md5}
    
    r = requests.post(login_url, json=login_data, timeout=10)
    login_response = r.json()
    
    if 'objectResult' not in login_response:
        log_debug(f"FAILED at Login. Raw Response: {json.dumps(login_response)}")
        print(f"Error: 'objectResult' missing from login. Check credentials.")
        sys.exit(1)
        
    token = login_response['objectResult']['x-token']

    # 3. Set Temperature
    headers = {"x-token": token, "Content-Type": "application/json; charset=utf-8"}
    payload = {
        "param": [
            {"deviceCode": device_code, "protocolCode": protocolCode, "value": value},
            {"deviceCode": device_code, "protocolCode": "22", "value": value}
        ]
    }
    
    response = requests.post(control_url, headers=headers, json=payload, timeout=10)
    res_json = response.json()
    
    log_debug(f"API Success: {json.dumps(res_json)}")
    print(f"Success: {res_json.get('error_msg')}")

except Exception as e:
    log_debug(f"CRITICAL ERROR: {str(e)}")
    print(f"Error: {str(e)}")
    sys.exit(1)