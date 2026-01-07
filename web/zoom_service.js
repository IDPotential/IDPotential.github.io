

let client = null;

async function initZoom(meetingNumber, password, userName, sdkKey, sdkSecret, customization = {}) {
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

    // Merge default settings with passed customization
    // Defaults: 960x540, no POI
    const defaultCustomize = {
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
        },
        toolbar: {
            // Default buttons to show/hide if not specified can go here
            // buttons: [] 
        }
    };

    // Deep merge or simple assign? Simple assign for top levels is usually enough for this SDK
    // But we want to preserve nested objects like viewSizes if not overridden.

    // Simplistic merge for 2 levels:
    const finalCustomize = {
        ...defaultCustomize,
        ...customization,
        video: { ...defaultCustomize.video, ...(customization.video || {}) },
        toolbar: { ...defaultCustomize.toolbar, ...(customization.toolbar || {}) },
    };

    // Ensure viewSizes isn't lost if only some video props were passed
    if (customization.video && customization.video.viewSizes) {
        finalCustomize.video.viewSizes = customization.video.viewSizes;
    } else {
        finalCustomize.video.viewSizes = defaultCustomize.video.viewSizes;
    }


    try {
        console.log('Initializing Zoom client with customization:', finalCustomize);
        await client.init({
            zoomAppRoot: meetingElement,
            language: 'ru-RU',
            customize: finalCustomize
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

                // Do not fallback to window size, as we are in a sub-container
                const containerWidth = container.clientWidth;
                const containerHeight = container.clientHeight;

                // Avoid division by zero or invalid layout
                if (!containerWidth || !containerHeight) return;

                // Calculate ratios
                const scaleX = containerWidth / targetWidth;
                const scaleY = containerHeight / targetHeight;

                // Use minimum scale to fit entire video content (contain)
                // Or use max to cover. "Fit" is usually safer for UI.
                const scale = Math.min(scaleX, scaleY);

                const zoomRoot = document.getElementById('zmmtg-root') || container.firstElementChild;
                if (zoomRoot) {
                    // FLEXBOX CENTERING APPROACH
                    // Enable flex on the container to center the 960x540 content
                    container.style.display = 'flex';
                    container.style.justifyContent = 'center';
                    container.style.alignItems = 'center';
                    container.style.position = 'relative';
                    container.style.overflow = 'hidden'; // Keep hidden to clip content that scales out? Or visible? 
                    // Usually hidden is safer for iframe boundaries, but might clip popups.
                    // However, we are centering popups now with CSS.

                    // Prepare the content content
                    // IMPORTANT: Reset position to relative so flexbox controls layout
                    zoomRoot.style.position = 'absolute'; // Changed to absolute for reliable transform origin centering
                    zoomRoot.style.width = targetWidth + "px";
                    zoomRoot.style.height = targetHeight + "px";

                    // Reset positioning
                    zoomRoot.style.margin = "0";
                    zoomRoot.style.left = "50%";
                    zoomRoot.style.top = "50%";

                    // APPLY SCALE & CENTERING
                    // Shift up by 50px (calc(-50% - 50px))
                    zoomRoot.style.transform = `translate(-50%, calc(-50% - 50px)) scale(${scale})`;
                    zoomRoot.style.transformOrigin = 'center center';
                }
            };

            // Inject Custom CSS to force popups to center
            const injectCustomCss = () => {
                const styleId = 'zoom-custom-style-overrides';
                if (!document.getElementById(styleId)) {
                    const style = document.createElement('style');
                    style.id = styleId;
                    style.innerHTML = `
                        /* Force Center Zoom Popups (Settings, Chat, Participants) */
                        .zm-modal, .ant-modal, .suspension-window, .dialog-window-wrap, .img-layer, .chat-window, .chat-panel-wrap {
                            left: 50% !important;
                            top: 50% !important;
                            transform: translate(-50%, calc(-50% - 50px)) !important; /* Shift UP 50px */
                            position: fixed !important; /* Fixed relative to viewport/iframe */
                            z-index: 9999 !important; /* Ensure ON TOP */
                            max-height: 80vh !important;
                            max-width: 90vw !important;
                        }
                        
                        /* Specific Chat fixes */
                         #chat-app, .chat-window-wrap, .chat-panel {
                            left: 50% !important;
                            top: 50% !important;
                            transform: translate(-50%, calc(-50% - 50px)) !important;
                            z-index: 10000 !important;
                            position: fixed !important;
                         }

                        /* Fix overlap issues by ensuring the bottom toolbar has clearance if needed */
                        .footer__toolbar {
                            margin-bottom: 0px !important; 
                        }

                        /* --- LARGER ZOOM BUTTONS --- */
                        /* Footer Toolbar Container */
                        .footer {
                            height: 100px !important; /* Increase bar height */
                            padding-bottom: 15px !important;
                        }
                        
                        .footer__toolbar {
                            margin-bottom: 0px !important;
                            height: 100% !important;
                        }

                        /* Button Container - Aggressive Selectors */
                        .footer-button__button, 
                        .footer-button-base__button,
                        #zmmtg-root .footer button,
                        [class*="footer-button"],
                        [class*="ax-outline"] {
                            width: 120px !important; 
                            height: 90px !important; 
                            margin: 0 10px !important;
                            transform: scale(2.0) !important;
                            transform-origin: center bottom !important; 
                        }

                        /* Icons */
                        .footer-button__button-icon, 
                        .footer-button-base__img-layer,
                        svg {
                            transform: scale(1.5) !important; /* Scale icons inside buttons */
                        }

                        /* Labels */
                        .footer-button__button-label {
                            font-size: 14px !important; /* Larger text */
                            margin-top: 4px !important;
                        }
                        
                        /* "End" Button - Make it very prominent */
                        .footer__leave-btn {
                             transform: scale(1.3) !important;
                             margin-left: 20px !important;
                        }
                    `;
                    document.head.appendChild(style);
                }
            };

            injectCustomCss();

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
