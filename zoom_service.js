

let client = null;

async function initZoom(meetingNumber, password, userName, sdkKey, sdkSecret) {
    // Ensure strict cleanup before trying to initialize a new session
    await leaveZoom();

    // Create new client instance (since we destroy it on leave)
    if (!client) {
        client = ZoomMtgEmbedded.createClient();
    }

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
    meetingElement.style.display = 'block'; // Ensure visibility if it was hidden

    const role = 0;

    // Generate JWT Signature using CryptoJS
    // Spec: https://developers.zoom.us/docs/meeting-sdk/auth/#generate-a-signature

    // SPECIFIC FIX: Ensure meetingNumber is a clean integer
    // Remove any non-digits (spaces, dashes) and parse as int
    const mnInt = parseInt(String(meetingNumber).replace(/\D/g, ''), 10);
    const safeSdkKey = sdkKey.trim();
    const safeSdkSecret = sdkSecret.trim();

    const iat = Math.round(new Date().getTime() / 1000) - 30;
    const exp = iat + 60 * 60 * 2;

    const oHeader = { alg: 'HS256', typ: 'JWT' };
    const oPayload = {
        sdkKey: safeSdkKey,
        mn: mnInt,
        role: role,
        iat: iat,
        exp: exp,
        appKey: safeSdkKey,
        tokenExp: exp
    };

    const sHeader = JSON.stringify(oHeader);
    const sPayload = JSON.stringify(oPayload);

    // Helper to base64url encode
    const base64UrlEncode = (str) => {
        const encoded = CryptoJS.enc.Base64.stringify(CryptoJS.enc.Utf8.parse(str));
        return encoded.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    };

    const base64UrlHeader = base64UrlEncode(sHeader);
    const base64UrlPayload = base64UrlEncode(sPayload);

    const signature = CryptoJS.HmacSHA256(base64UrlHeader + "." + base64UrlPayload, sdkSecret);
    const base64UrlSignature = CryptoJS.enc.Base64.stringify(signature)
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=+$/, '');

    const jwtSignature = base64UrlHeader + "." + base64UrlPayload + "." + base64UrlSignature;

    try {
        console.log('Initializing Zoom client...');
        await client.init({
            zoomAppRoot: meetingElement,
            language: 'ru-RU',
            // patchJsMedia: true, // Removed as it might conflict without SharedArrayBuffer
            customize: {
                video: {
                    isResizable: true,
                    poi: { isShow: false },
                    disableVideo: false,
                    viewSizes: {
                        default: {
                            width: 960,
                            height: 540
                        }
                    }
                }
            }
        });

        console.log('Joining Zoom meeting...');
        await client.join({
            signature: jwtSignature,
            sdkKey: safeSdkKey,
            meetingNumber: mnInt,
            password: password,
            userName: userName,
            userEmail: '',
            tk: ''
        });

        console.log('Joined Zoom meeting successfully');

        // Re-attach listener only if initialization succeeded
        try {
            // DYNAMIC SCALING LOGIC
            // We forced a large resolution (960x540) to enable Desktop UI features (Gallery View).
            // Now we must scale it down to fit the actual container using CSS transforms.
            const scaleZoomContent = () => {
                const container = findZoomContainer();
                if (!container) return;

                const targetWidth = 960; // Must match the viewSizes we set
                const targetHeight = 540;

                const containerWidth = container.clientWidth || window.innerWidth;
                const containerHeight = container.clientHeight || window.innerHeight;

                // Calculate ratios
                const scaleX = containerWidth / targetWidth;
                const scaleY = containerHeight / targetHeight;

                // Use minimum scale to fit entire video content (contain)
                // Or use max to cover. "Fit" is usually safer for UI.
                const scale = Math.min(scaleX, scaleY);

                const zoomRoot = document.getElementById('zmmtg-root') || container.firstElementChild;
                if (zoomRoot) {
                    zoomRoot.style.transform = "scale(" + scale + ")";
                    zoomRoot.style.transformOrigin = 'top left';

                    // Force explicit size to match target, so scale works predictably
                    zoomRoot.style.width = targetWidth + "px";
                    zoomRoot.style.height = targetHeight + "px";

                    // Optional: Center if there is extra space
                    if (scale === scaleY && scale < scaleX) {
                        // Extra width available
                        const extraX = (containerWidth - (targetWidth * scale)) / 2;
                        zoomRoot.style.marginLeft = extraX + "px";
                        zoomRoot.style.marginTop = "0px";
                    } else if (scale === scaleX && scale < scaleY) {
                        // Extra height available
                        const extraY = (containerHeight - (targetHeight * scale)) / 2;
                        zoomRoot.style.marginTop = extraY + "px";
                        zoomRoot.style.marginLeft = "0px";
                    } else {
                        zoomRoot.style.margin = "0";
                    }
                }
            };

            // Run once and on resize
            scaleZoomContent();
            window.addEventListener('resize', scaleZoomContent);

            client.on('connection-change', (e) => {
                if (e.state === 'Closed') {
                    const el = findZoomContainer();
                    if (el) {
                        el.innerHTML = '';
                        el.style.display = 'none';
                        window.removeEventListener('resize', scaleZoomContent);
                    }
                }
            });
        } catch (e) { console.warn('Could not attach listener', e); }

    } catch (error) {
        console.error('Zoom join error:', error);
    }
}

function findZoomContainer() {
    // Try global match first
    let element = document.getElementById('zoom-meeting-container');
    if (element) return element;

    // Search in Flutter Platform Views (Shadow DOM)
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
    console.log('Attempting to leave Zoom...');

    // Attempt SDK leave, but don't let it block cleanup
    try {
        if (client) {
            console.log('Client object keys:', Object.keys(client));
            if (typeof client.leave === 'function') {
                // Give it 2 seconds to leave gracefully
                const leavePromise = client.leave();
                const timeoutPromise = new Promise(resolve => setTimeout(resolve, 2000));
                await Promise.race([leavePromise, timeoutPromise]);
                console.log('Client leave completed (or timed out)');
            } else {
                console.warn('client.leave is not a function', client);
            }
        }
    } catch (error) {
        console.warn('Zoom SDK leave warning (ignoring):', error);
    }

    // Try to destroy the client instance if method exists (cleaner teardown)
    try {
        if (typeof ZoomMtgEmbedded.destroyClient === 'function') {
            ZoomMtgEmbedded.destroyClient();
            client = null; // Important: reset global variable
            console.log('Destroyed Zoom Client');
        }
    } catch (e) { console.warn('Destroy client failed', e); }

    // FORCE CLEANUP: This is the nuclear option to stop audio.
    const meetingElement = findZoomContainer();
    if (meetingElement) {
        // DO NOT use remove() as it breaks Flutter's Platform View Registry
        meetingElement.innerHTML = '';
        meetingElement.style.display = 'none';

        // Reload to force-kill audio? User requested "exit". 
        // window.location.reload(); // Too aggressive for SPA.
    }

    // Re-finding to clear innerHTML specifically
    const container = document.getElementById('zoom-meeting-container');
    // Note: findZoomContainer handles ShadowDOM, but for 'remove' operations we want to be careful.

    // BETTER APPROACH: Reload the page is the only 100% way if SDK is buggy.
    // But we want to avoid that.

    // Let's try to clear the DOM content aggressively.
    const aggressiveCleanup = findZoomContainer();
    if (aggressiveCleanup) {
        aggressiveCleanup.innerHTML = '';
        aggressiveCleanup.style.display = 'none';

        // Force reload of the window location if we are stuck?
        // No, let's trust that clearing the 'zoomAppRoot' kills the iframe/rendering logic.
    }

    // Explicitly unmount if React was used internally? No access.
    // We will rely on innerHTML = '' hitting the root.
}

window.initZoom = initZoom;
window.leaveZoom = leaveZoom;
