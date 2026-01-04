
const client = ZoomMtgEmbedded.createClient();

async function initZoom(meetingNumber, password, userName, sdkKey, sdkSecret) {
    let meetingElement = findZoomContainer();

    // Retry finding container if not found immediately (give it up to 2 seconds)
    if (!meetingElement) {
        for (let i = 0; i < 10; i++) {
            await new Promise(r => setTimeout(r, 200));
            meetingElement = findZoomContainer();
            if (meetingElement) break;
        }
    }

    if (!meetingElement) {
        console.error('Zoom container not found after retries');
        return;
    }

    // Clear previous content if any (important for re-joining)
    meetingElement.innerHTML = '';

    const role = 0;
    const timestamp = Math.round(new Date().getTime() / 1000) - 30;

    // Generate Signature using CryptoJS
    // Signature format: Header.Payload.Signature
    // Header: Base64(sdkKey)
    // Payload: Base64(meetingNumber.timestamp.role)
    // Signature: Base64(HMAC-SHA256(secret, msg))

    const iat = Math.round(new Date().getTime() / 1000) - 30;
    const exp = iat + 60 * 60 * 2; // 2 hours expiration

    // Official Zoom SDK Signature for Web (JWT-like or internal format)
    // For Embedded Client, it typically expects the unified signature.
    // Spec: https://developers.zoom.us/docs/meeting-sdk/auth/#generate-a-signature

    // SDK Key . Meeting Number . Timestamp . Role . HMAC(Secret, Msg)
    // Msg = Base64(SDK Key . Meeting Number . Timestamp . Role)

    const msgData = `${sdkKey}${meetingNumber}${iat}${role}`;
    const msg = btoa(msgData);
    const hash = CryptoJS.HmacSHA256(msg, sdkSecret).toString(CryptoJS.enc.Base64);
    const signature = `${sdkKey}.${meetingNumber}.${iat}.${role}.${hash}`;
    // Based on previous code, wrapping entire thing in btoa might have been the issue OR expectation.
    // Let's stick to the structure: SDKKey.MN.TS.Role.Hash(Base64)
    // Actually, checking Zoom docs: 
    // ECDSA is for Server-to-Server. 
    // Client SDK uses: 
    // timestamp = now
    // msg = base64(apiKey + meetingNumber + timestamp + role)
    // hash = hmac_sha256(msg, apiSecret) (base64)
    // signature = base64(apiKey + "." + meetingNumber + "." + timestamp + "." + role + "." + hash)

    const signatureInput = `${sdkKey}.${meetingNumber}.${iat}.${role}.${hash}`;
    const finalSignature = btoa(signatureInput);

    try {
        await client.init({
            zoomAppRoot: meetingElement,
            language: 'ru-RU',
            patchJsMedia: true,
            customize: {
                video: {
                    isResizable: true,
                    viewSizes: {
                        default: {
                            width: 1000,
                            height: 600
                        },
                        ribbon: {
                            width: 300,
                            height: 600
                        }
                    }
                }
            }
        });

        await client.join({
            signature: signature,
            sdkKey: sdkKey,
            meetingNumber: meetingNumber,
            password: password,
            userName: userName,
            userEmail: '',
            tk: ''
        });

        console.log('Joined Zoom meeting successfully');
    } catch (error) {
        console.error('Zoom join error:', error);
    }
}

function findZoomContainer() {
    // Try global match first
    let element = document.getElementById('zoom-meeting-container');
    if (element) return element;

    // Search in Flutter Platform Views (Shadow DOM)
    // Flutter Web typically renders platform views inside <flt-platform-view> elements
    const platformViews = document.querySelectorAll('flt-platform-view');
    for (let view of platformViews) {
        if (view.shadowRoot) {
            element = view.shadowRoot.getElementById('zoom-meeting-container');
            if (element) return element;
        }
    }
    return null;
}

async function leaveZoom() {
    try {
        await client.leave();
        console.log('Left Zoom meeting');
    } catch (error) {
        console.error('Zoom leave error:', error);
    }
}

window.initZoom = initZoom;
window.leaveZoom = leaveZoom;
