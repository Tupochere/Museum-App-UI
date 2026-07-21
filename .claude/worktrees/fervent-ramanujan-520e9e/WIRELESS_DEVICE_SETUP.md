# How to Connect Your Android Device Wirelessly for Flutter Debugging

This guide details exactly how to connect your **Samsung Galaxy A12** or **A53** to your development machine without a permanent cable connection.

**Prerequisite:** Your computer and your phone MUST be connected to the **SAME Wi-Fi network**.

---

## Phase 1: Enable Developer Options (One-Time Setup)

If you haven't done this yet:

1.  Go to **Settings** > **About phone** > **Software information**.
2.  Find **Build number**.
3.  Tap it **7 times** rapidly. You will see a toast message "Developer mode has been enabled" (you might need to enter your PIN).
4.  Go back to the main **Settings** menu. You should now see **Developer options** at the very bottom.
5.  Open **Developer options** and scroll down to **Debugging**.
6.  Toggle **USB debugging** to **ON**.

---

## Phase 2: The "First Time" Cable Connection

To set up wireless debugging, you must restart the `adb` server in TCP mode. This requires a cable connection first.

1.  **Connect your phone** to your PC using a high-quality USB data cable.
2.  **Unlock your phone**.
3.  Look for a popup: *"Allow USB debugging?"*
    *   Check **"Always allow from this computer"**.
    *   Tap **Allow**.
4.  Open your terminal/command prompt (VS Code terminal is fine).
5.  Run this command to check visibility:
    ```bash
    flutter devices
    ```
    *You should see your device listed (e.g., `SM-A53...`).*

---

## Phase 3: Switch to Wireless Mode (The Port Command)

This is the command that opens the "port" for wireless communication.

1.  In the terminal, run:
    ```bash
    adb tcpip 5555
    ```
    *   **Success:** You verify the output says: `restarting in TCP mode port: 5555`
    *   **Failure:** If it says "device not found" or "unauthorized", check your cable and screen prompts again.

2.  **Disconnect the USB cable** from your phone. The phone is now listening for a connection wirelessly on port 5555.

---

## Phase 4: Connect via IP Address

1.  **Find your Phone's IP Address**:
    *   Go to **Settings** > **Connections** > **Wi-Fi**.
    *   Tap the **gear icon** next to your currently connected Wi-Fi network.
    *   Scroll down to find **IP address** (e.g., `192.168.1.15` or `10.0.0.5`).

2.  **Connect via Terminal**:
    *   Typing the following command (replace with your ACTUAL IP):
    ```bash
            cd C:\Android\platform-tools
        .\adb tcpip 5555
        .\adb connect <YOUR_IP>:5555
    ```
    *(Note: The `:5555` part is optional if you used port 5555, but good practice).*

3.  **Verify Success**:
    *   Terminal should say: `connected to 192.168.1.15:5555`
    *   Run `flutter devices` again. You should see your phone listed as `192.168.1.15:5555`.

---

## Phase 5: Run Your App

You can now run your app as normal without the cable:

```bash
flutter run
```

---

## Troubleshooting & Resetting

### "Connection Refused" or "Host is down"
1.  Verify PC and Phone are on the **exact same Wi-Fi**.
2.  Ping the phone to verify range: `ping 192.168.1.15`
3.  Some public/corporate Wi-Fi networks block device-to-device communication. Use a private home Wi-Fi or Mobile Hotspot.

### "Target machine actively refused it"
The TCP mode might have timed out or been reset (happens if phone reboots).
*   **Fix:** Plug the cable back in and repeat **Phase 3** (`adb tcpip 5555`).

### How to switch back to USB Mode
If you want to stop wireless debugging:
1.  Run:
    ```bash
    adb usb
    ```
    *(Requires cable to be plugged in if you lost wireless connection, otherwise works wirelessly).*
2.  Or simply **Reboot the phone** (this resets the port listener).



### RECONNECTION 
cd C:\Android\platform-tools
.\adb connect 10.173.155.166:5555



The "Quick Reconnect" Workflow
You don't need to navigate to the folder every time if adb is in your System Path, but sticking to your specific folder structure, here is the command:

Open your Terminal/PowerShell.

Run the connect command:

PowerShell
cd C:\Android\platform-tools
.\adb connect 192.168.1.15:5555
(Replace 192.168.1.15 with whatever your phone's IP is today).

Check your IDE: Your device should automatically pop up in the Flutter/VS Code/Android Studio device selector.

Troubleshooting the "Morning After"
If you try to connect and get an error like cannot connect to ... :5555, one of two things happened:

IP Shift: Your router gave your phone a new IP address (e.g., it was .15 yesterday, but it's .18 today).

Phone Reboot: If your phone restarted, it "forgot" to listen on port 5555. You will have to plug the USB cable back in once and run .\adb tcpip 5555 again to jumpstart it.

💡 The "One-Click" Shortcut (Recommended)
Instead of typing this every morning, you can create a Desktop Shortcut.

Right-click your Desktop > New > Text Document.

Paste this inside:

Code snippet
@echo off
cd /d C:\Android\platform-tools
set /p ip="Enter Phone IP: "
adb connect %ip%:5555
pause
Save the file as ConnectPhone.bat (make sure it ends in .bat, not .txt).

Next time: Just double-click it, type the last digits of your IP, and hit Enter.

Would you like me to show you how to add adb to your Windows Environment Variables so you can run these commands from any folder without typing the cd path?