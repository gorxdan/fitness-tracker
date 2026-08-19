#!/usr/bin/env bash
# Creates App Store Connect resources for Mac-less code signing:
#   1. Bundle ID (+ HealthKit capability)
#   2. App record (for TestFlight)
#   3. IOS_DISTRIBUTION certificate (CSR + key generated locally with openssl)
#   4. App Store provisioning profile
#
# Requires an App Store Connect API key with Admin or App Manager role.
# Usage:
#   ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_P8_PATH=./AuthKey.p8 ./scripts/asc-setup.sh
# Optional env: BUNDLE_ID APP_NAME PROFILE_NAME
set -euo pipefail

: "${ASC_KEY_ID:?set ASC_KEY_ID}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"
: "${ASC_P8_PATH:?set ASC_P8_PATH}"
BUNDLE_ID="${BUNDLE_ID:-com.gorxfitness.pulse}"
APP_NAME="${APP_NAME:-Pulse}"
PROFILE_NAME="${PROFILE_NAME:-Pulse CI}"
API="https://api.appstoreconnect.apple.com"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ---------- App Store Connect JWT (ES256, signed via openssl) ----------
jwt() {
  python3 - "$ASC_KEY_ID" "$ASC_ISSUER_ID" "$ASC_P8_PATH" <<'PY'
import base64, json, subprocess, sys, time

key_id, issuer, p8 = sys.argv[1:4]

def b64(b):
    return base64.urlsafe_b64encode(b).rstrip(b"=")

now = int(time.time())
header = b64(json.dumps({"alg": "ES256", "kid": key_id}).encode())
payload = b64(json.dumps({"iss": issuer, "iat": now, "exp": now + 1200}).encode())
signing_input = header + b"." + payload
der = subprocess.run(
    ["openssl", "dgst", "-sha256", "-sign", p8],
    input=signing_input, capture_output=True, check=True
).stdout

def der_to_raw(der):
    # ES256 signature DER: SEQUENCE { INTEGER r, INTEGER s } -> 64-byte r||s
    def read_int(data, i):
        assert data[i] == 0x02, "expected INTEGER tag"
        i += 1
        n = data[i]
        i += 1
        if n & 0x80:
            k = n & 0x7F
            n = int.from_bytes(data[i:i + k], "big")
            i += k
        v = data[i:i + n]
        # ES256 wants exactly 32 bytes: strip DER sign-padding zeros, then left-pad.
        return v.lstrip(b"\x00").rjust(32, b"\0"), i + n

    assert der[0] == 0x30, "expected SEQUENCE tag"
    i = 1
    n = der[i]
    i += 1
    if n & 0x80:
        k = n & 0x7F
        n = int.from_bytes(der[i:i + k], "big")
        i += k
    r, i = read_int(der, i)
    s, _ = read_int(der, i)
    return r + s

print((signing_input + b"." + b64(der_to_raw(der))).decode())
PY
}

asc() { # asc METHOD PATH [JSON_BODY] -> response JSON on stdout
  local method=$1 path=$2 body=${3:-}
  local args=(-sS -X "$method" "$API$path" -H "Authorization: Bearer $(jwt)")
  if [[ -n "$body" ]]; then
    args+=(-H "Content-Type: application/json" -d "$body")
  fi
  curl "${args[@]}"
}

jget() { # jget JSON PYEXPR  (json must be single-quoted python expr)
  python3 -c "import json,sys; d=json.load(sys.stdin); print($2)" <<<"$1"
}

# ---------- 1. Bundle ID + HealthKit ----------
echo "== Bundle ID: $BUNDLE_ID"
RESP=$(asc GET "/v1/bundleIds?filter%5Bidentifier%5D=$BUNDLE_ID")
BID=$(jget "$RESP" "d['data'][0]['id'] if d.get('data') else ''")
if [[ -z "$BID" ]]; then
  RESP=$(asc POST /v1/bundleIds "{\"data\":{\"type\":\"bundleIds\",\"attributes\":{\"identifier\":\"$BUNDLE_ID\",\"platform\":\"IOS\",\"name\":\"Pulse\"}}}")
  BID=$(jget "$RESP" "d['data']['id']")
  echo "   created $BID"
else
  echo "   exists $BID"
fi

CAPS=$(asc GET "/v1/bundleIds/$BID/bundleIdCapabilities")
HAS_HK=$(jget "$CAPS" "any(c['attributes']['capabilityType']=='HEALTHKIT' for c in d.get('data',[]))" 2>/dev/null || echo False)
if [[ "$HAS_HK" != "True" ]]; then
  asc POST /v1/bundleIdCapabilities "{\"data\":{\"type\":\"bundleIdCapabilities\",\"attributes\":{\"capabilityType\":\"HEALTHKIT\"},\"relationships\":{\"bundleId\":{\"data\":{\"type\":\"bundleIds\",\"id\":\"$BID\"}}}}}" >/dev/null
  echo "   HealthKit capability enabled"
else
  echo "   HealthKit capability already enabled"
fi

# ---------- 2. App record ----------
echo "== App: $APP_NAME"
RESP=$(asc GET "/v1/apps?filter%5BbundleId%5D=$BUNDLE_ID")
APP_ID=$(jget "$RESP" "d['data'][0]['id'] if d.get('data') else ''")
if [[ -z "$APP_ID" ]]; then
  RESP=$(asc POST /v1/apps "{\"data\":{\"type\":\"apps\",\"attributes\":{\"name\":\"$APP_NAME\",\"bundleId\":\"$BUNDLE_ID\",\"platform\":\"IOS\",\"primaryLocale\":\"en-US\"}}}")
  if jget "$RESP" "'errors' in d" | grep -q True; then
    echo "   FAILED to create app (name may be taken): set APP_NAME='Your Name' and rerun"
    jget "$RESP" "d['errors']"
    exit 1
  fi
  APP_ID=$(jget "$RESP" "d['data']['id']")
  echo "   created $APP_ID"
else
  echo "   exists $APP_ID"
fi

# ---------- 3. Distribution certificate ----------
echo "== Certificate: IOS_DISTRIBUTION"
openssl req -new -newkey rsa:2048 -nodes \
  -keyout "$WORK/key.pem" -out "$WORK/csr.pem" \
  -subj "/CN=Pulse CI/O=Pulse/C=US" 2>/dev/null
CSR=$(python3 -c "print(open('$WORK/csr.pem').read().strip())")
RESP=$(asc POST /v1/certificates "{\"data\":{\"type\":\"certificates\",\"attributes\":{\"certificateType\":\"IOS_DISTRIBUTION\",\"csrContent\":\"$CSR\"}}}")
if jget "$RESP" "'errors' in d" | grep -q True; then
  echo "   certificate creation failed:"
  jget "$RESP" "d['errors']"
  exit 1
fi
CERT_B64=$(jget "$RESP" "d['data']['attributes']['certificateContent']")
CERT_ID=$(jget "$RESP" "d['data']['id']")
base64 -d <<<"$CERT_B64" > "$WORK/cert.pem"
openssl pkcs12 -export -out "$WORK/dist.p12" \
  -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
  -passout pass:pulse -name "Pulse Distribution"
echo "   created $CERT_ID -> dist.p12 (password: pulse)"

# ---------- 4. Provisioning profile ----------
echo "== Profile: $PROFILE_NAME"
RESP=$(asc GET "/v1/profiles?filter%5Bname%5D=$(python3 -c "import urllib.parse;print(urllib.parse.quote('$PROFILE_NAME'))")&filter%5BprofileState%5D=ACTIVE")
PROFILE_ID=$(jget "$RESP" "d['data'][0]['id'] if d.get('data') else ''")
if [[ -z "$PROFILE_ID" ]]; then
  RESP=$(asc POST /v1/profiles "{\"data\":{\"type\":\"profiles\",\"attributes\":{\"name\":\"$PROFILE_NAME\",\"profileType\":\"IOS_APP_STORE\"},\"relationships\":{\"bundleId\":{\"data\":{\"type\":\"bundleIds\",\"id\":\"$BID\"}},\"certificate\":{\"data\":{\"type\":\"certificates\",\"id\":\"$CERT_ID\"}}}}}")
  if jget "$RESP" "'errors' in d" | grep -q True; then
    echo "   profile creation failed:"
    jget "$RESP" "d['errors']"
    exit 1
  fi
  PROFILE_ID=$(jget "$RESP" "d['data']['id']")
  echo "   created $PROFILE_ID"
else
  echo "   exists $PROFILE_ID"
fi
asc GET "/v1/profiles/$PROFILE_ID/profileContent" | python3 -c "import json,sys,base64; d=json.load(sys.stdin); sys.stdout.buffer.write(base64.b64decode(d['data']['attributes']['profileContent']))" > "$WORK/profile.mobileprovision"
echo "   -> profile.mobileprovision"

# ---------- 5. Print GitHub secret commands ----------
P12_B64=$(base64 -w0 < "$WORK/dist.p12")
PROFILE_B64=$(base64 -w0 < "$WORK/profile.mobileprovision")
KEY_B64=$(base64 -w0 < "$ASC_P8_PATH")

cat <<EOF

== Done. Now set the GitHub secrets (from the repo root):

  gh secret set ASC_TEAM_ID      --body "YOUR_TEAM_ID"        # Membership page
  gh secret set ASC_KEY_ID       --body "$ASC_KEY_ID"
  gh secret set ASC_ISSUER_ID    --body "$ASC_ISSUER_ID"
  gh secret set ASC_KEY          --body "$KEY_B64"
  gh secret set DIST_P12         --body "$P12_B64"
  gh secret set P12_PASSWORD     --body "pulse"
  gh secret set PROFILE          --body "$PROFILE_B64"

Then trigger TestFlight: gh workflow run testflight.yml
Builds appear in TestFlight after Apple processes them (minutes to ~1h; first build
needs a completed export-compliance answer in App Store Connect — answer "no" to
encryption questions for internal-only use).
EOF
